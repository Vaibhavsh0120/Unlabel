'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');
const {destinationFor, run} = require('./auth-bridge/account-action.js');

const authOrigin = 'https://unlabel-india-catalogue.firebaseapp.com';
const frontendOrigin = 'https://unlabel-india.vercel.app';

function action(params = {}) {
  const url = new URL('/account-action.html', authOrigin);
  url.search = new URLSearchParams({mode: 'resetPassword', oobCode: 'synthetic-code', ...params});
  return url.href;
}

function browser(href) {
  const replacements = [];
  const history = [];
  const status = {textContent: 'Opening your account action…'};
  const window = {
    location: {
      href,
      pathname: '/account-action.html',
      replace: value => replacements.push(value),
    },
    history: {
      state: null,
      replaceState: (...args) => history.push(args),
    },
    fetch: () => assert.fail('The bridge must not send network requests.'),
  };
  Object.defineProperty(window, 'localStorage', {
    get: () => assert.fail('The bridge must not access persistent storage.'),
  });
  const document = {getElementById: id => id === 'status' ? status : null};
  return {window, document, replacements, history, status};
}

test('reset stays in Firebase and uses the fixed sign-in Continue return', () => {
  const destination = new URL(destinationFor(action({
    oobCode: 'opaque+code%2F',
    apiKey: 'synthetic-public-api-key',
    continueUrl: 'https://attacker.invalid/',
    redirect: 'https://attacker.invalid/',
  })));
  assert.equal(destination.origin, authOrigin);
  assert.equal(destination.pathname, '/__/auth/action');
  assert.equal(destination.hash, '');
  assert.deepEqual([...destination.searchParams], [
    ['mode', 'resetPassword'],
    ['oobCode', 'opaque+code%2F'],
    ['apiKey', 'synthetic-public-api-key'],
    ['continueUrl', `${frontendOrigin}/#/account-signin`],
  ]);
});

test('reset never accepts a supplied Continue destination or returns its code to the app', () => {
  for (const continueUrl of ['', 'https://attacker.invalid/', `${frontendOrigin}/known-return`, `${authOrigin}/known-return`]) {
    const destination = new URL(destinationFor(action({continueUrl})));
    const target = new URL(destination.searchParams.get('continueUrl'));
    assert.equal(target.href, `${frontendOrigin}/#/account-signin`);
    assert.equal(target.search, '');
    assert.equal(target.href.includes('oobCode'), false);
    assert.equal(target.href.includes('synthetic-code'), false);
  }
});

test('all other recognized actions retain the reserved Firebase handler', () => {
  for (const mode of ['verifyEmail', 'recoverEmail', 'verifyAndChangeEmail', 'revertSecondFactorAddition', 'signIn']) {
    const destination = new URL(destinationFor(action({
      mode,
      apiKey: 'synthetic-public-api-key',
      lang: 'en-IN',
      continueUrl: `${frontendOrigin}/#/`,
      redirect: 'https://attacker.invalid/',
    })));
    assert.equal(destination.origin, authOrigin);
    assert.equal(destination.pathname, '/__/auth/action');
    assert.equal(destination.hash, '');
    assert.deepEqual([...destination.searchParams], [
      ['mode', mode],
      ['oobCode', 'synthetic-code'],
      ['apiKey', 'synthetic-public-api-key'],
      ['lang', 'en-IN'],
      ['continueUrl', `${frontendOrigin}/#/`],
    ]);
  }
});

test('unknown modes, missing codes and malformed inputs never redirect', () => {
  for (const value of [null, '', 'not a URL', action({mode: 'deleteAccount'}), action({mode: '<script>alert(1)</script>'}), action({oobCode: ''}), action({oobCode: 'x'.repeat(2049)}), action({oobCode: 'a\nb'}), action({oobCode: 'a b'})]) {
    assert.equal(destinationFor(value), null);
  }
  const missing = new URL(action());
  missing.searchParams.delete('oobCode');
  assert.equal(destinationFor(missing.href), null);
  assert.notEqual(destinationFor(action({oobCode: 'x'.repeat(2048)})), null);
});

test('origin, callback path and duplicate security parameters fail closed', () => {
  for (const url of [
    action().replace(authOrigin, 'https://attacker.invalid'),
    action().replace('https:', 'http:'),
    action().replace('/account-action.html', '/another-page.html'),
    action().replace(authOrigin, 'https://user@unlabel-india-catalogue.firebaseapp.com'),
    `${action()}&mode=verifyEmail`,
    `${action()}&oobCode=another-code`,
    `${action({apiKey: 'synthetic'})}&apiKey=another-key`,
    `${action({lang: 'en'})}&lang=hi`,
    `${action({continueUrl: frontendOrigin})}&continueUrl=${authOrigin}`,
  ]) assert.equal(destinationFor(url), null);
});

test('fallback handler never receives an arbitrary external continue target', () => {
  for (const continueUrl of ['https://attacker.invalid/', 'javascript:alert(1)', '//attacker.invalid/', `${frontendOrigin}.attacker.invalid/`, 'https://attacker@unlabel-india.vercel.app/', `${frontendOrigin}:444/`]) {
    const destination = new URL(destinationFor(action({mode: 'verifyEmail', continueUrl})));
    assert.equal(destination.searchParams.has('continueUrl'), false);
  }
  for (const origin of [frontendOrigin, authOrigin, 'https://unlabel-india-catalogue.web.app']) {
    const destination = new URL(destinationFor(action({mode: 'verifyEmail', continueUrl: `${origin}/known-return`})));
    assert.equal(destination.searchParams.get('continueUrl'), `${origin}/known-return`);
  }
});

test('browser navigation replaces the history entry without persisting the code', () => {
  const state = browser(action());
  run(state.window, state.document);
  assert.deepEqual(state.history, [[null, '', '/account-action.html']]);
  assert.equal(state.replacements.length, 1);
  const destination = new URL(state.replacements[0]);
  assert.equal(destination.origin, authOrigin);
  assert.equal(destination.pathname, '/__/auth/action');
  assert.equal(destination.searchParams.get('continueUrl'), `${frontendOrigin}/#/account-signin`);
});

test('failure text never includes the input URL, code or HTML', () => {
  const href = action({mode: 'unknown', oobCode: 'synthetic-private-code', apiKey: 'synthetic-key'});
  const state = browser(href);
  run(state.window, state.document);
  assert.equal(state.replacements.length, 0);
  assert.match(state.status.textContent, /Request a new link/);
  for (const input of [href, 'synthetic-private-code', 'synthetic-key', '<script>']) {
    assert.equal(state.status.textContent.includes(input), false);
  }
  assert.deepEqual(state.history, [[null, '', '/account-action.html']]);
});

test('navigation or history failures expose only a generic status', () => {
  const state = browser(action());
  state.window.history.replaceState = () => {throw Error('synthetic history failure');};
  state.window.location.replace = () => {throw Error('synthetic navigation failure');};
  run(state.window, state.document);
  assert.match(state.status.textContent, /Request a new link/);
  assert.equal(state.status.textContent.includes('synthetic-code'), false);
});

test('browser script boots without module globals, external calls or logging', () => {
  const state = browser(action());
  const source = fs.readFileSync(path.join(__dirname, 'auth-bridge/account-action.js'), 'utf8');
  vm.runInNewContext(source, {
    window: state.window,
    document: state.document,
    URL,
    URLSearchParams,
    console: new Proxy({}, {get: () => () => assert.fail('The bridge must not log action data.')}),
  });
  assert.equal(state.replacements.length, 1);
});

test('HTML suppresses referrers and permits only a local external script', () => {
  const html = fs.readFileSync(path.join(__dirname, 'auth-bridge/account-action.html'), 'utf8');
  assert.match(html, /name="referrer" content="no-referrer"/);
  assert.match(html, /default-src 'none'; script-src 'self'/);
  assert.match(html, /base-uri 'none'; form-action 'none'/);
  assert.deepEqual([...html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)].map(match => [match[1].trim(), match[2].trim()]), [['src="account-action.js" defer', '']]);
  assert.equal(/<(img|iframe|link|form)\b/i.test(html), false);
});
