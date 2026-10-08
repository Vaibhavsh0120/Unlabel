// Run with: node --test frontend/test/local_ocr_web_test.cjs
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../web/local_ocr.js'), 'utf8');
const deferred = () => {
  let resolve;
  const promise = new Promise(value => { resolve = value; });
  return {promise, resolve};
};

function harness({creation, recognition, dimensions = [200, 100]} = {}) {
  const state = {scripts: [], options: [], closes: 0, terminates: 0, canvases: []};
  const worker = {
    recognize: () => recognition?.promise ?? Promise.resolve({data: {text: 'Ingredients: oats'}}),
    terminate: async () => { state.terminates++; },
  };
  const tesseract = {
    createWorker: async (language, oem, options) => {
      state.options.push({language, oem, ...options});
      return creation ? creation.promise : worker;
    },
  };
  const window = {};
  const document = {
    baseURI: 'https://unlabel.test/app/',
    createElement(type) {
      if (type === 'script') return {remove() {}};
      assert.equal(type, 'canvas');
      const canvas = {getContext: () => ({drawImage() {}})};
      state.canvases.push(canvas);
      return canvas;
    },
    head: {
      appendChild(script) {
        state.scripts.push(script.src);
        window.Tesseract = tesseract;
        queueMicrotask(() => script.onload());
      },
    },
  };
  vm.runInNewContext(source, {
    window, document, URL, AbortController, Blob, queueMicrotask, setTimeout, clearTimeout,
    createImageBitmap: async () => ({
      width: dimensions[0], height: dimensions[1], close: () => { state.closes++; },
    }),
  });
  return {api: window.unlabelOcr, state, worker};
}

const image = new Uint8Array([1, 2, 3]);
const flush = () => new Promise(resolve => setImmediate(resolve));

test('startup loads no OCR engine, while recognition uses only same-origin assets', async () => {
  const {api, state} = harness();
  assert.deepEqual(state.scripts, []);
  assert.deepEqual(state.options, []);
  assert.equal(await api.recognize(image, 'hi', () => {}), 'Ingredients: oats');
  assert.deepEqual(state.scripts, ['https://unlabel.test/app/ocr/tesseract.min.js']);
  const options = state.options[0];
  assert.equal(Array.from(options.language).join(','), 'eng,hin');
  for (const key of ['workerPath', 'corePath', 'langPath']) {
    assert.equal(new URL(options[key]).origin, 'https://unlabel.test');
  }
  assert.equal(options.workerBlobURL, false);
  assert.equal(options.cacheMethod, 'none');
  assert.equal(state.closes, 1);
  assert.equal(state.terminates, 0);
  api.cancel();
  assert.equal(state.terminates, 1);
  assert.equal(state.canvases[0].width, 0);
});

test('oversize image or bytes and invalid language stop before model acquisition', async () => {
  const {api, state} = harness({dimensions: [6000, 5000]});
  await assert.rejects(api.recognize(image, 'en', () => {}), /ocr_dimensions/);
  await assert.rejects(api.recognize(new Uint8Array(12 * 1024 * 1024 + 1), 'en', () => {}), /ocr_input/);
  await assert.rejects(api.recognize(image, 'fr', () => {}), /ocr_input/);
  assert.deepEqual(state.scripts, []);
  assert.equal(state.closes, 1);
});

test('cancel while model loads ignores late worker and permits retry', async () => {
  const creation = deferred();
  const {api, state, worker} = harness({creation});
  const pending = api.recognize(image, 'en', () => {});
  const rejected = assert.rejects(pending, /ocr_cancelled/);
  await flush();
  api.cancel();
  await rejected;
  creation.resolve(worker);
  await flush();
  assert.equal(state.terminates, 1);
  assert.equal(await api.recognize(image, 'en', () => {}), 'Ingredients: oats');
  assert.equal(state.closes, 2);
  assert.equal(state.terminates, 1);
  api.cancel();
  assert.equal(state.terminates, 2);
});

test('adjacent front/back reads reuse one local model and release it on leaving Scan', async () => {
  const {api, state} = harness();
  await api.recognize(image, 'en', () => {});
  await api.recognize(image, 'en', () => {});
  assert.equal(state.options.length, 1);
  assert.equal(state.terminates, 0);
  assert.equal(state.closes, 2);
  api.cancel();
  assert.equal(state.terminates, 1);
});

test('language change replaces the warm worker rather than mixing models', async () => {
  const {api, state} = harness();
  await api.recognize(image, 'en', () => {});
  await api.recognize(image, 'hi', () => {});
  assert.equal(state.options.length, 2);
  assert.equal(state.terminates, 1);
  api.cancel();
  assert.equal(state.terminates, 2);
});

test('cancel during recognition rejects private late text and disables late progress', async () => {
  const recognition = deferred();
  const {api, state} = harness({recognition});
  let progressCalls = 0;
  const pending = api.recognize(image, 'en', () => { progressCalls++; });
  const rejected = assert.rejects(pending, /ocr_cancelled/);
  await flush();
  await assert.rejects(api.recognize(image, 'en', () => {}), /ocr_busy/);
  api.cancel();
  state.options[0].logger({status: 'recognizing text', progress: 1});
  recognition.resolve({data: {text: 'Private late text'}});
  await rejected;
  assert.equal(progressCalls, 0);
  assert.equal(state.closes, 1);
  assert.ok(state.terminates >= 1);
});
