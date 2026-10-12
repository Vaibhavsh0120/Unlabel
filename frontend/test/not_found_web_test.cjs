const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../web/not-found.js'), 'utf8');

function boot(fallback) {
  const events = new EventTarget();
  const window = { addEventListener: events.addEventListener.bind(events) };
  const document = { getElementById: () => fallback };
  vm.runInNewContext(source, { window, document });
  return { window, events };
}

test('missing-page host requests app recovery and keeps fallback until first frame', () => {
  let removals = 0;
  const { window, events } = boot({ remove: () => removals++ });
  assert.equal(window.unlabelNotFound, true);
  assert.equal(removals, 0, 'loading or failed app keeps a useful recovery page');
  events.dispatchEvent(new Event('flutter-first-frame'));
  assert.equal(removals, 1);
  events.dispatchEvent(new Event('flutter-first-frame'));
  assert.equal(removals, 1, 'the cleanup runs once');
});

test('first-frame cleanup tolerates a previously removed fallback', () => {
  const { events } = boot(null);
  assert.doesNotThrow(() => events.dispatchEvent(new Event('flutter-first-frame')));
});
