/* Decoder executes off the UI thread; only bounded upright RGBA is accepted. */
'use strict';
let prepared;
const vendor = new URL('vendor/zxing-wasm/3.1.3/', self.location.href);

function prepare() {
  if (!prepared) {
    importScripts(new URL('index.js', vendor).href);
    if (self.ZXingWASM?.ZXING_WASM_VERSION !== '3.1.3') throw new Error();
    prepared = self.ZXingWASM.prepareZXingModule({
      overrides: {locateFile: path => new URL(path, vendor).href},
      fireImmediately: true,
    });
  }
  return prepared;
}

self.onmessage = async event => {
  const {job, buffer, width, height, thorough} = event.data ?? {};
  try {
    if (!Number.isInteger(width) || !Number.isInteger(height) ||
        width < 1 || height < 1 || width > 1400 || height > 1400 ||
        !(buffer instanceof ArrayBuffer) || buffer.byteLength !== width * height * 4) {
      throw new Error();
    }
    await prepare();
    const pixels = new Uint8ClampedArray(buffer);
    // ImageData's grayscale path ignores alpha. Composite transparent pixels
    // onto white before decoding so a transparent quiet zone stays light.
    for (let i = 0; i < pixels.length; i += 4) {
      const alpha = pixels[i + 3];
      if (alpha !== 255) {
        for (let channel = 0; channel < 3; channel++) {
          pixels[i + channel] = Math.round((pixels[i + channel] * alpha + 255 * (255 - alpha)) / 255);
        }
        pixels[i + 3] = 255;
      }
    }
    const image = {data: pixels, width, height};
    const options = {
      formats: ['EAN13', 'EAN8', 'UPCA', 'UPCE'],
      maxNumberOfSymbols: 1,
      tryHarder: !!thorough,
      tryRotate: true,
      tryInvert: true,
      returnErrors: false,
    };
    const acceptable = value => value.isValid !== false &&
      ['EAN13', 'EAN8', 'UPCA', 'UPCE'].includes(value.format);
    let found = (await self.ZXingWASM.readBarcodes(image, options)).find(acceptable);
    if (!found && thorough) {
      // ZXing's automatic inversion is format-dependent. A single explicit
      // luminance-polarity retry also covers inverted EAN/UPC labels.
      for (let i = 0; i < pixels.length; i += 4) {
        pixels[i] = 255 - pixels[i];
        pixels[i + 1] = 255 - pixels[i + 1];
        pixels[i + 2] = 255 - pixels[i + 2];
      }
      found = (await self.ZXingWASM.readBarcodes(image, options)).find(acceptable);
    }
    const position = found?.position;
    const points = position ? [position.topLeft, position.topRight,
      position.bottomRight, position.bottomLeft].filter(point =>
      Number.isFinite(point?.x) && Number.isFinite(point?.y)).map(point =>
      [point.x / width, point.y / height]) : [];
    self.postMessage({job, result: found ? {
      text: found.text, format: found.format, points,
    } : null});
  } catch (_) {
    self.postMessage({job, error: true});
  }
};
