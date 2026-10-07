# Local browser OCR assets

Pinned Tesseract.js 7.0.0, Tesseract.js-core 7.0.0 and English/Hindi
`tessdata_fast` models support local text suggestions after label capture.
These are pre-trained public OCR components, not a custom Unlabel model.

`../local_ocr.js` loads engine, worker, WebAssembly and language data from the
same app origin only when text reading begins. Images and recognized text are
processed in browser memory; neither is sent to the backend or an OCR provider.
First use requires the static files to download. This is not a promise of offline
app startup or OCR accuracy on every package.

`provenance.json` records pinned source URLs, npm SHA-512 integrity, model
revision, acquired model hashes and every tracked runtime file SHA-256/size.
Upstream licenses and bundled dependency notices are retained in `licenses/`
and `*.LICENSE.txt`. Sources are Apache-2.0; bundled notices preserve the
dependency-specific terms. No billing, API key or card is required.

From repository root, verify files without network access:

```powershell
backend/.venv/Scripts/python.exe scripts/vendor_web_ocr.py --check
```

`scripts/vendor_web_ocr.py` without `--check` deliberately reacquires exactly
the pinned sources, verifies npm integrity and writes deterministic model gzip.
There is no runtime or scheduled source refresh. Review hashes/licenses and
browser recognition/cancellation/network evidence after any manual replacement.

Only editable section/name suggestions are offered. Nutrition rows remain
manual because OCR text order cannot establish an unambiguous printed table.
The existing package confirmations precede report submission.
