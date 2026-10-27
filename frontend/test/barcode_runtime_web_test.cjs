const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../web/barcode_runtime.js'), 'utf8');

function harness() {
  const state = {scripts: [], workers: [], preparations: [], failScript: false};
  const elements = new Map();
  const window = {};
  const navigator = {mediaDevices: {getUserMedia: async () => state.nextStream}};
  class HTMLMediaElement {
    constructor(stream) { this.srcObject = stream; this.attributes = new Map(); this.pauses = 0; }
    setAttribute(name, value) { this.attributes.set(name, value); }
    async play() { this.playedMuted = this.muted; this.playedInline = this.playsInline; }
    pause() { this.pauses++; }
  }
  const document = {
    baseURI: 'https://unlabel.test/app/',
    getElementById: id => elements.get(id),
    createElement: () => ({remove() { elements.delete(this.id); }}),
    head: {appendChild(script) {
      state.scripts.push(script.src);
      elements.set(script.id, script);
      queueMicrotask(() => {
        if (state.failScript) { script.onerror(); return; }
        window.ZXingWASM = {
          ZXING_WASM_VERSION: '3.1.3',
          async prepareZXingModule(options) { state.preparations.push(options); },
        };
        script.onload();
      });
    }},
  };
  class Worker {
    constructor(url) { this.url = url; this.terminated = 0; state.workers.push(this); }
    terminate() { this.terminated++; }
    postMessage(message, transfer) { this.message = message; this.transfer = transfer; }
    result(result) { this.onmessage({data: {job: this.message.job, result}}); }
  }
  vm.runInNewContext(source, {window, document, URL, Worker, queueMicrotask,
    navigator, HTMLMediaElement,
    setTimeout: (fn, delay) => { const id = setTimeout(fn, delay); id.unref(); return id; },
    clearTimeout});
  return {api: window.unlabelBarcodes, state, navigator, HTMLMediaElement};
}

const pixels = () => new Uint8Array(4 * 12 * 8).fill(255);

test('startup acquires no barcode engine; camera preparation coalesces and pins same origin', async () => {
  const {api, state} = harness();
  assert.equal(state.scripts.length, 0);
  assert.equal(state.workers.length, 0);
  await Promise.all([api.prepare(), api.prepare()]);
  assert.deepEqual(state.scripts, ['https://unlabel.test/app/vendor/zxing-wasm/3.1.3/index.js']);
  assert.equal(state.preparations.length, 1);
  assert.equal(state.preparations[0].overrides.locateFile('zxing_reader.wasm'),
    'https://unlabel.test/app/vendor/zxing-wasm/3.1.3/zxing_reader.wasm');
  assert.equal(state.preparations[0].fireImmediately, true);
});

test('still decode uses a same-origin worker and transfers a copy, preserving Dart pixels', async () => {
  const {api, state} = harness();
  const input = pixels();
  const reading = api.read(input, 12, 8, true, '1:1');
  assert.equal(state.scripts.length, 0);
  const worker = state.workers[0];
  assert.equal(worker.url, 'https://unlabel.test/app/barcode_worker.js');
  assert.notEqual(worker.message.buffer, input.buffer);
  assert.equal(input.byteLength, 384);
  assert.equal(worker.transfer[0], worker.message.buffer);
  worker.result({text: '8901764051258', format: 'EAN13', points: [[.2, .3], [.8, .3]]});
  assert.equal(JSON.parse(await reading).text, '8901764051258');
});

test('cancel terminates work, rejects a stale result, and allows a clean subsequent scan', async () => {
  const {api, state} = harness();
  const first = api.read(pixels(), 12, 8, true, '1:1');
  const rejected = assert.rejects(first, /barcode_cancelled/);
  api.cancel('different-job');
  assert.equal(state.workers[0].terminated, 0);
  api.cancel('1:1');
  await rejected;
  assert.equal(state.workers[0].terminated, 1);
  const second = api.read(pixels(), 12, 8, true, '1:2');
  state.workers[0].result({text: 'stale'});
  state.workers[1].result(null);
  assert.equal(await second, 'null');
});

test('new still request cancels pending work rather than queueing UI-blocking decodes', async () => {
  const {api, state} = harness();
  const first = api.read(pixels(), 12, 8, true, '1:1');
  const rejected = assert.rejects(first, /barcode_cancelled/);
  const second = api.read(pixels(), 12, 8, true, '1:2');
  await rejected;
  state.workers[1].result(null);
  assert.equal(await second, 'null');
});

test('oversized or inconsistent pixels stop before engine acquisition', async () => {
  const {api, state} = harness();
  await assert.rejects(api.read(pixels(), 1401, 8, true, 'a'), /barcode_input/);
  await assert.rejects(api.read(pixels(), 10, 8, true, 'a'), /barcode_input/);
  assert.equal(state.workers.length, 0);
  assert.equal(state.scripts.length, 0);
});

test('runtime acquisition failure remains retryable without selecting another engine', async () => {
  const {api, state} = harness();
  state.failScript = true;
  await assert.rejects(api.prepare(), /barcode_runtime_unavailable/);
  state.failScript = false;
  await api.prepare();
  assert.equal(state.scripts.length, 2);
  const reading = api.read(pixels(), 12, 8, true, '1:1');
  const failure = assert.rejects(reading, /barcode_runtime_unavailable/);
  state.workers[0].onerror();
  await failure;
  assert.equal(state.workers[0].terminated, 1);
});

test('bundled pinned runtime and licenses match acquisition provenance', () => {
  const directory = path.join(__dirname, '../web/vendor/zxing-wasm/3.1.3');
  const provenance = JSON.parse(fs.readFileSync(path.join(directory, 'provenance.json')));
  assert.equal(provenance.version, '3.1.3');
  for (const item of provenance.files) {
    const bytes = fs.readFileSync(path.join(directory, item.path));
    assert.equal(bytes.length, item.bytes);
    assert.equal(crypto.createHash('sha256').update(bytes).digest('hex'), item.sha256);
  }
  assert.ok(provenance.files.some(item => item.path === 'LICENSE'));
  assert.ok(provenance.files.some(item => item.path === 'ZXING_CPP_LICENSE'));
});

function mediaStream() {
  const track = {stops: 0, stop() { this.stops++; }};
  return {track, getTracks: () => [track]};
}

test('SDK start sets Safari video flags before play and releases only its owned stream', async () => {
  const {api, state, navigator, HTMLMediaElement} = harness();
  const originalGetUserMedia = navigator.mediaDevices.getUserMedia;
  const originalPlay = HTMLMediaElement.prototype.play;
  const owned = mediaStream(), unrelated = mediaStream();
  const unrelatedVideo = new HTMLMediaElement(unrelated);
  state.nextStream = owned;
  api.beginCameraStart();
  // mobile_scanner7.4.2 omits audio rather than setting it to false.
  const stream = await navigator.mediaDevices.getUserMedia({video: {facingMode: 'environment'}});
  const video = new HTMLMediaElement(stream);
  await video.play();
  await unrelatedVideo.play();
  assert.equal(video.playedMuted, true);
  assert.equal(video.playedInline, true);
  assert.equal(video.attributes.has('playsinline'), true);
  assert.equal(unrelatedVideo.playedMuted, undefined);
  api.finishCameraStart();
  assert.equal(navigator.mediaDevices.getUserMedia, originalGetUserMedia);
  assert.equal(HTMLMediaElement.prototype.play, originalPlay);
  api.releaseCamera();
  api.releaseCamera();
  assert.equal(video.pauses, 1);
  assert.equal(video.srcObject, null);
  assert.equal(owned.track.stops, 1);
  assert.equal(unrelated.track.stops, 0);
  assert.equal(unrelatedVideo.pauses, 0);
});

test('late camera permission result is stopped after release; later unrelated calls stay untouched', async () => {
  const {api, state, navigator} = harness();
  let resolve;
  navigator.mediaDevices.getUserMedia = () => new Promise(value => { resolve = value; });
  api.beginCameraStart();
  const permission = navigator.mediaDevices.getUserMedia({video: true, audio: false});
  api.finishCameraStart();
  api.releaseCamera();
  const late = mediaStream();
  resolve(late);
  await permission;
  assert.equal(late.track.stops, 1);
  const unrelated = mediaStream();
  state.nextStream = unrelated;
  navigator.mediaDevices.getUserMedia = async () => unrelated;
  await navigator.mediaDevices.getUserMedia({video: true, audio: false});
  api.releaseCamera();
  assert.equal(unrelated.track.stops, 0);
});

test('an owned video reused by another stream is not paused or cleared on scanner release', async () => {
  const {api, state, navigator, HTMLMediaElement} = harness();
  const owned = mediaStream(), replacement = mediaStream();
  state.nextStream = owned;
  api.beginCameraStart();
  const video = new HTMLMediaElement(await navigator.mediaDevices.getUserMedia({video: true, audio: false}));
  await video.play();
  api.finishCameraStart();
  video.srcObject = replacement;
  api.releaseCamera();
  assert.equal(owned.track.stops, 1);
  assert.equal(replacement.track.stops, 0);
  assert.equal(video.pauses, 0);
  assert.equal(video.srcObject, replacement);
});
