const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { webcrypto } = require('node:crypto');
const source = fs.readFileSync(path.join(__dirname, '../web/account-oauth.js'), 'utf8');

function boot({ blocked = false, providerUrl } = {}) {
  const listeners = new Map();
  const locations = [];
  const requests = [];
  const storage = new Map();
  const redirects = [];
  const sessionStorage = { getItem: key => storage.get(key) ?? null,
    setItem: (key, value) => storage.set(key, value), removeItem: key => storage.delete(key) };
  const popup = { closed: false, close() { this.closed = true; }, location: {
    replace(url) {
      locations.push(url);
      const listener = listeners.get('message');
      listener({ origin: 'https://attacker.invalid', source: popup,
        data: { type: 'unlabel-oauth', code: 'injected' } });
      listener({ origin: 'https://unlabel.example', source: {},
        data: { type: 'unlabel-oauth', code: 'injected' } });
      listener({ origin: 'https://unlabel.example', source: popup,
        data: { type: 'unlabel-oauth', code: 'bound-code' } });
    }
  } };
  const window = { open: () => blocked ? null : popup,
    addEventListener: (name, fn) => listeners.set(name, fn),
    removeEventListener: name => listeners.delete(name) };
  vm.runInNewContext(source, { window, sessionStorage, location: { origin: 'https://unlabel.example',
    assign: value => redirects.push(value) },
    URL, URLSearchParams, crypto: webcrypto, TextEncoder, Uint8Array, btoa,
    AbortSignal, setTimeout, clearTimeout, setInterval, clearInterval,
    fetch: async (url, options) => { requests.push({ url, options });
      return { ok: true, json: async () => ({ url: providerUrl }) }; } });
  return { window, popup, locations, requests, listeners, storage, sessionStorage, redirects };
}

test('ordinary login redirects this tab and consumes its bound PKCE return once', async () => {
  const app = boot({blocked: true});
  app.window.open = () => { throw new Error('Login must not open a popup'); };
  app.window.unlabelGoogleLoginRedirect('https://api.example');
  await new Promise(resolve => setImmediate(resolve));
  const destination = new URL(app.redirects[0]);
  assert.equal(destination.origin, 'https://api.example');
  assert.equal(destination.searchParams.get('code_challenge_method'), 's256');
  const saved = JSON.parse(app.storage.get('unlabel.google.redirect.v1'));
  const callback = fs.readFileSync(path.join(__dirname, '../web/auth-callback.js'), 'utf8');
  const navigations = [];
  const cleared = [];
  vm.runInNewContext(callback, {window: {}, sessionStorage: app.sessionStorage,
    location: {search: '?code=bound-return', origin: 'https://unlabel.example',
      replace: value => navigations.push(value)},
    history: {replaceState: (...args) => cleared.push(args)}, URLSearchParams,
    document: {getElementById: () => { throw new Error('Valid callback must complete'); }}});
  assert.equal(cleared[0][2], '/auth-callback.html');
  assert.deepEqual(navigations, ['/#/account-signin']);
  assert.deepEqual(JSON.parse(app.window.unlabelTakeGoogleRedirect()), {
    auth_code: 'bound-return', code_verifier: saved.verifier,
  });
  assert.equal(app.window.unlabelTakeGoogleRedirect(), null);
  assert.equal(app.storage.size, 0);
});

test('stale and malformed redirect grants are discarded', () => {
  const app = boot();
  for (const createdAt of [Date.now() - 300001, Date.now() + 10000, undefined]) {
    app.storage.set('unlabel.google.grant.v1', JSON.stringify({
      auth_code: 'code', code_verifier: 'a'.repeat(64), createdAt,
    }));
    assert.equal(app.window.unlabelTakeGoogleRedirect(), null);
  }
});

test('Google uses S256 PKCE and accepts a code only from its own same-origin popup', async () => {
  const app = boot();
  const grant = JSON.parse(await app.window.unlabelGoogleOAuth('https://api.example'));
  const target = new URL(app.locations[0]);
  assert.equal(target.origin, 'https://api.example');
  assert.equal(target.pathname, '/auth/v1/authorize');
  assert.equal(target.searchParams.get('provider'), 'google');
  assert.equal(target.searchParams.get('redirect_to'), 'https://unlabel.example/auth-callback.html');
  assert.equal(target.searchParams.get('code_challenge_method'), 's256');
  const hash = await webcrypto.subtle.digest('SHA-256', new TextEncoder().encode(grant.code_verifier));
  assert.equal(target.searchParams.get('code_challenge'), Buffer.from(hash).toString('base64url'));
  assert.equal(grant.auth_code, 'bound-code');
  assert.equal(app.popup.closed, true);
  assert.equal(app.listeners.size, 0);
});

test('blocked popup and untrusted link destination fail without a credential-bearing navigation', async () => {
  await assert.rejects(boot({ blocked: true }).window.unlabelGoogleOAuth('https://api.example'), /popup_blocked/);
  const app = boot({ providerUrl: 'https://attacker.invalid/' });
  await assert.rejects(app.window.unlabelGoogleOAuth('https://api.example', 'synthetic-token'));
  assert.equal(app.locations.length, 0);
  assert.equal(app.requests[0].options.headers.Authorization, 'Bearer synthetic-token');
  assert.equal(app.requests[0].options.redirect, 'error');
  assert.equal(app.popup.closed, true);
});

test('explicit linking carries the owner bearer but no credential in the OAuth URL', async () => {
  const app = boot({ providerUrl: 'https://accounts.google.com/o/oauth2/v2/auth?state=signed' });
  await app.window.unlabelGoogleOAuth('https://api.example', 'synthetic-token');
  assert.equal(app.requests[0].url.pathname, '/auth/v1/user/identities/authorize');
  assert.equal(app.requests[0].url.searchParams.get('skip_http_redirect'), 'true');
  assert.ok(!app.locations[0].includes('synthetic-token'));
});

test('provider replacement can reserve its popup before waiting for password proof', async () => {
  const app = boot();
  app.window.unlabelPrepareGoogleOAuth();
  await new Promise(resolve => setImmediate(resolve));
  const grant = JSON.parse(await app.window.unlabelGoogleOAuth('https://api.example'));
  assert.equal(grant.auth_code, 'bound-code');
  assert.equal(app.locations.length, 1);
  assert.equal(app.popup.closed, true);
});
