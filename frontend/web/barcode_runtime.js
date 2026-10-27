/* Same-origin ZXing-C++ runtime. No camera frames or photos leave this browser. */
(() => {
  'use strict';
  const base = new URL('.', document.baseURI);
  const vendor = new URL('vendor/zxing-wasm/3.1.3/', base);
  const scriptId = 'mobile-scanner-zxing-wasm';
  let preparation;
  let worker;
  let pending;
  let idleTimer;
  let cameraStart;
  let cameraGeneration = 0;
  const cameraStreams = new Set();
  const cameraVideos = new Set();

  function stopTracks(stream) {
    for (const track of stream.getTracks()) {
      try { track.stop(); } catch (_) { /* Continue releasing the other tracks. */ }
    }
  }

  function finishCameraStart() {
    const start = cameraStart;
    if (!start) return;
    start.open = false;
    try {
      if (start.devices.getUserMedia === start.getUserMedia) {
        start.devices.getUserMedia = start.originalGetUserMedia;
      }
    } catch (_) { /* A retained closed wrapper only delegates to the original. */ }
    try {
      if (start.mediaPrototype.play === start.play) {
        start.mediaPrototype.play = start.originalPlay;
      }
    } catch (_) { /* Releasing the tracks must still finish. */ }
    cameraStart = undefined;
  }

  function beginCameraStart() {
    finishCameraStart();
    const devices = navigator.mediaDevices;
    const mediaPrototype = HTMLMediaElement.prototype;
    if (!devices?.getUserMedia) return; // SDK supplies its permission/unavailable UI.
    const start = {
      devices, mediaPrototype, open: true, generation: cameraGeneration,
      originalGetUserMedia: devices.getUserMedia, originalPlay: mediaPrototype.play,
    };
    start.getUserMedia = function(constraints) {
      const capture = start.open && constraints?.video &&
        (constraints.audio === false || constraints.audio == null);
      const operation = start.originalGetUserMedia.call(this, constraints);
      if (!capture) return operation;
      return operation.then(stream => {
        if (start.generation !== cameraGeneration) stopTracks(stream);
        else cameraStreams.add(stream);
        return stream;
      });
    };
    start.play = function(...args) {
      if (start.open && cameraStreams.has(this.srcObject)) {
        // Safari requires these before play(), including on its hidden SDK video.
        this.muted = true;
        this.defaultMuted = true;
        this.playsInline = true;
        this.setAttribute('muted', '');
        this.setAttribute('playsinline', '');
        this.setAttribute('webkit-playsinline', '');
        cameraVideos.add(this);
      }
      return start.originalPlay.apply(this, args);
    };
    cameraStart = start;
    try {
      devices.getUserMedia = start.getUserMedia;
      mediaPrototype.play = start.play;
    } catch (_) {
      finishCameraStart();
      throw new Error('barcode_camera_unavailable');
    }
  }

  function releaseCamera() {
    cameraGeneration++;
    finishCameraStart();
    for (const video of cameraVideos) {
      // Another owner may have reused the element after SDK shutdown.
      if (!cameraStreams.has(video.srcObject)) continue;
      try { video.pause(); } catch (_) { /* Track stop below still releases camera. */ }
      video.srcObject = null;
    }
    for (const stream of cameraStreams) stopTracks(stream);
    cameraVideos.clear();
    cameraStreams.clear();
  }

  function stopWorker() {
    clearTimeout(idleTimer);
    worker?.terminate();
    worker = undefined;
  }

  function cancel(job) {
    if (!pending || pending.job !== job) return;
    const current = pending;
    pending = undefined;
    clearTimeout(current.timer);
    stopWorker();
    current.reject(new Error('barcode_cancelled'));
  }

  function prepare() {
    if (preparation) return preparation;
    preparation = new Promise((resolve, reject) => {
      let script = document.getElementById(scriptId);
      const fail = () => {
        clearTimeout(timer);
        script?.remove();
        preparation = undefined;
        reject(new Error('barcode_runtime_unavailable'));
      };
      const timer = setTimeout(fail, 15000);
      const ready = async () => {
        try {
          const api = window.ZXingWASM;
          if (api?.ZXING_WASM_VERSION !== '3.1.3') throw new Error();
          // Register before SDK decode so its default CDN locator is never used.
          await api.prepareZXingModule({
            overrides: {locateFile: path => new URL(path, vendor).href},
            fireImmediately: true,
          });
          clearTimeout(timer);
          resolve();
        } catch (_) { fail(); }
      };
      if (window.ZXingWASM) { void ready(); return; }
      if (script) {
        if (script.src !== new URL('index.js', vendor).href) { fail(); return; }
        script.addEventListener('load', ready, {once: true});
        script.addEventListener('error', fail, {once: true});
        return;
      }
      script = document.createElement('script');
      script.id = scriptId;
      script.src = new URL('index.js', vendor).href;
      script.async = true;
      script.onload = ready;
      script.onerror = fail;
      document.head.appendChild(script);
    }).catch(error => {
      preparation = undefined;
      throw error;
    });
    return preparation;
  }

  function read(pixels, width, height, thorough, job) {
    if (!Number.isInteger(width) || !Number.isInteger(height) ||
        width < 1 || height < 1 || width > 1400 || height > 1400 ||
        pixels?.byteLength !== width * height * 4 ||
        typeof job !== 'string' || job.length > 80) {
      return Promise.reject(new Error('barcode_input'));
    }
    if (pending) cancel(pending.job);
    clearTimeout(idleTimer);
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => cancel(job), 20000);
      pending = {job, resolve, reject, timer};
      try {
        worker ??= new Worker(new URL('barcode_worker.js', base).href);
        worker.onerror = () => {
          if (!pending) return;
          const current = pending;
          pending = undefined;
          clearTimeout(current.timer);
          stopWorker();
          current.reject(new Error('barcode_runtime_unavailable'));
        };
        worker.onmessage = event => {
          if (!pending || event.data?.job !== pending.job) return;
          const current = pending;
          pending = undefined;
          clearTimeout(current.timer);
          if (event.data.error) {
            stopWorker();
            current.reject(new Error('barcode_decode_unavailable'));
          } else {
            current.resolve(JSON.stringify(event.data.result ?? null));
            // Release an idle WASM heap, while keeping back-to-back scans cheap.
            idleTimer = setTimeout(stopWorker, 30000);
          }
        };
        // Do not detach the Flutter/Dart typed-array backing store.
        const buffer = pixels.slice().buffer;
        worker.postMessage({job, buffer, width, height, thorough: !!thorough}, [buffer]);
      } catch (_) {
        clearTimeout(timer);
        pending = undefined;
        stopWorker();
        reject(new Error('barcode_runtime_unavailable'));
      }
    });
  }

  window.unlabelBarcodes = Object.freeze({prepare, read, cancel,
    beginCameraStart, finishCameraStart, releaseCamera});
})();
