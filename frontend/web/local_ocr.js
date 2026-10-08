/* Images and recognized text remain in this browser. Models load from this origin. */
(() => {
  'use strict';
  let active = null;
  let library = null;
  let warm = null;
  let idle = null;
  const IDLE_MS = 15000;
  function dropWarm() {
    clearTimeout(idle);
    idle = null;
    const previous = warm;
    warm = null;
    if (previous) void previous.worker.terminate();
  }
  const MAX_BYTES = 12 * 1024 * 1024;
  const MAX_PIXELS = 24000000;
  const localUrl = path => new URL(path, document.baseURI).href;
  function raceAbort(promise, signal) {
    return new Promise((resolve, reject) => {
      const stop = () => reject(new Error('ocr_cancelled'));
      signal.addEventListener('abort', stop, { once: true });
      promise.then(resolve, reject).finally(() => signal.removeEventListener('abort', stop));
      if (signal.aborted) stop();
    });
  }
  function loadLibrary() {
    if (!library) {
      library = new Promise((resolve, reject) => {
        const script = document.createElement('script');
        script.src = localUrl('ocr/tesseract.min.js');
        script.onload = () => {
          if (window.Tesseract) resolve(window.Tesseract);
          else { library = null; reject(new Error('ocr_missing')); }
        };
        script.onerror = () => { script.remove(); library = null; reject(new Error('ocr_missing')); };
        document.head.appendChild(script);
      });
    }
    return library;
  }
  window.unlabelOcr = Object.freeze({
    async recognize(bytes, language, progress) {
      if (active) throw new Error('ocr_busy');
      if (!bytes?.byteLength || bytes.byteLength > MAX_BYTES || !['en', 'hi'].includes(language)) {
        throw new Error('ocr_input');
      }
      const controller = new AbortController();
      controller.progress = progress;
      active = controller;
      const signal = controller.signal;
      let worker, image, canvas, reusable = false;
      clearTimeout(idle);
      idle = null;
      const terminate = () => { dropWarm(); };
      signal.addEventListener('abort', terminate, { once: true });
      try {
        image = await createImageBitmap(new Blob([bytes]));
        if (signal.aborted) throw new Error('ocr_cancelled');
        if (image.width * image.height > MAX_PIXELS) throw new Error('ocr_dimensions');
        const scale = Math.min(1, 2400 / Math.max(image.width, image.height));
        canvas = document.createElement('canvas');
        canvas.width = Math.max(1, Math.round(image.width * scale));
        canvas.height = Math.max(1, Math.round(image.height * scale));
        canvas.getContext('2d').drawImage(image, 0, 0, canvas.width, canvas.height);
        const tesseract = await raceAbort(loadLibrary(), signal);
        if (warm && warm.language !== language) dropWarm();
        const creation = warm ? Promise.resolve(warm.worker) : tesseract.createWorker(language === 'hi' ? ['eng', 'hin'] : 'eng', 1, {
          workerPath: localUrl('ocr/worker.min.js'),
          corePath: localUrl('ocr/core/'),
          langPath: localUrl('ocr/lang/').replace(/\/$/, ''),
          workerBlobURL: false,
          cacheMethod: 'none',
          gzip: true,
          logger: message => {
            if (active && !active.signal.aborted && message.status === 'recognizing text') active.progress(message.progress);
          },
          errorHandler: () => {},
        });
        creation.then(value => { if (signal.aborted) void value.terminate(); }, () => {});
        worker = await raceAbort(creation, signal);
        warm = {worker, language};
        const result = await raceAbort(worker.recognize(canvas), signal);
        if (signal.aborted) throw new Error('ocr_cancelled');
        if (result.data.text.length > 12000) throw new Error('ocr_text_limit');
        reusable = true;
        return result.data.text;
      } finally {
        signal.removeEventListener('abort', terminate);
        image?.close();
        if (canvas) { canvas.width = 0; canvas.height = 0; }
        if (!reusable && warm?.worker === worker) dropWarm();
        if (reusable && warm?.worker === worker) idle = setTimeout(dropWarm, IDLE_MS);
        if (active === controller) active = null;
      }
    },
    cancel() { active?.abort(); dropWarm(); },
  });
})();
