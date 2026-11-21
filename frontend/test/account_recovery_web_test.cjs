const test = require('node:test');
const assert = require('node:assert/strict');
const { randomBytes } = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '../web/account-recovery.js'), 'utf8');
const flush = () => new Promise(resolve => setImmediate(resolve));
// Generated only for mocked fetch calls; never used by a real identity service.
const testPassword = () => randomBytes(24).toString('base64url') + 'aA1!';

test('confirmation discards grants without creating a browser session or sending tokens', () => {
  const script = fs.readFileSync(path.join(__dirname, '../web/account-confirmation.js'), 'utf8');
  const status = { textContent: '' };
  const events = [];
  vm.runInNewContext(script, { URLSearchParams,
    location: { hash: '#access_token=private-grant&type=signup', search: '' },
    history: { replaceState: (...args) => events.push(args[2]) },
    document: { getElementById: () => status } });
  assert.deepEqual(events, ['/account-confirmation.html']);
  assert.match(status.textContent, /has been confirmed/);
});

function boot({ hash = '#access_token=synthetic-token&type=recovery', status = 200, anonymous = false } = {}) {
  const calls = [], replaced = [], handlers = {};
  const elements = Object.fromEntries(['status', 'recovery', 'password', 'confirm', 'submit'].map(id =>
    [id, { value: '', textContent: '', hidden: id === 'recovery', disabled: false,
      addEventListener: (event, fn) => { handlers[id + ':' + event] = fn; },
      reportValidity: () => true, focus() { this.focused = true; },
      reset() { elements.password.value = elements.confirm.value = ''; } }]));
  vm.runInNewContext(source, {
    location: { hash }, history: { replaceState: (...args) => replaced.push(args) },
    document: { getElementById: id => elements[id] },
    window: { addEventListener: (event, fn) => { handlers[event] = fn; } },
    URLSearchParams, TextEncoder, AbortSignal,
    fetch: async (url, options) => { calls.push({ url, options });
      return { ok: status === 200, status, json: async () => ({ is_anonymous: anonymous }) }; }
  });
  return { calls, replaced, handlers, elements,
    submit: () => handlers['recovery:submit']({ preventDefault() {} }) };
}

test('recovery scrubs the URL before verifying the token, and never activates an app session', async () => {
  const app = boot();
  assert.equal(app.replaced[0][2], '/account-recovery.html');
  await flush();
  assert.equal(app.calls[0].options.method, 'GET');
  assert.equal(app.calls[0].options.headers.Authorization, 'Bearer synthetic-token');
  assert.equal(app.elements.recovery.hidden, false);
  const password = testPassword();
  app.elements.password.value = app.elements.confirm.value = password;
  await app.submit();
  assert.equal(app.calls[1].options.method, 'PUT');
  assert.equal(JSON.parse(app.calls[1].options.body).password, password);
  assert.ok(app.calls[2].url.endsWith('/logout?scope=local'));
  assert.equal(app.elements.password.value, '');
  assert.equal(app.elements.recovery.hidden, true);
  assert.match(app.elements.status.textContent, /has been updated/);
  await app.submit();
  assert.equal(app.calls.length, 3);
});

test('duplicate tokens, nonrecovery links, revoked tokens and guests cannot open the password form', async () => {
  for (const hash of ['#access_token=a&access_token=b&type=recovery', '#access_token=a&type=signup', '#access_token=a&type=recovery&type=recovery']) {
    const app = boot({ hash });
    await flush();
    assert.equal(app.calls.length, 0);
    assert.equal(app.elements.recovery.hidden, true);
  }
  for (const config of [{ status: 401 }, { anonymous: true }]) {
    const app = boot(config);
    await flush();
    assert.equal(app.elements.recovery.hidden, true);
    assert.match(app.elements.status.textContent, /invalid or expired/);
  }
});

test('mismatch and weak passwords do not mutate identity; leaving clears secret fields', async () => {
  const app = boot();
  await flush();
  app.elements.password.value = testPassword();
  app.elements.confirm.value = testPassword();
  await app.submit();
  assert.equal(app.calls.length, 1);
  assert.match(app.elements.status.textContent, /do not match/);
  app.elements.password.value = app.elements.confirm.value = 'weak';
  await app.submit();
  assert.equal(app.calls.length, 1);
  app.handlers.pagehide();
  assert.equal(app.elements.password.value, '');
});

test('callback sends only a unique code to the same-origin opener after scrubbing its URL', () => {
  const source = fs.readFileSync(path.join(__dirname, '../web/auth-callback.js'), 'utf8');
  for (const search of ['?code=one-time', '?code=one&code=two', '?error=denied']) {
    const events = [];
    vm.runInNewContext(source, { URLSearchParams,
      location: { search, origin: 'https://unlabel.example' },
      history: { replaceState: () => events.push('scrub') },
      window: { opener: { postMessage: (data, origin) => events.push({ data, origin }) } } });
    assert.equal(events[0], 'scrub');
    assert.equal(events[1].origin, 'https://unlabel.example');
    assert.equal(events[1].data.type, 'unlabel-oauth');
    assert.equal(Boolean(events[1].data.code), search === '?code=one-time');
  }
});
