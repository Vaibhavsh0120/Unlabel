/* This bridge never verifies a code, reads account data or sends email. Firebase
 * verifies and completes every action in its reserved hosted handler.
 */
(function () {
  'use strict';

  const authOrigin = 'https://unlabel-india-catalogue.firebaseapp.com';
  const frontendOrigin = 'https://unlabel-india.vercel.app';
  const signInReturn = `${frontendOrigin}/#/account-signin`;
  const continueOrigins = new Set([
    frontendOrigin,
    authOrigin,
    'https://unlabel-india-catalogue.web.app',
  ]);
  const firebaseModes = new Set([
    'resetPassword',
    'verifyEmail',
    'recoverEmail',
    'verifyAndChangeEmail',
    'revertSecondFactorAddition',
    'signIn',
  ]);
  const failure = 'This account link could not be opened. Request a new link from Unlabel.';

  function opaqueCode(value) {
    return typeof value === 'string' && value.length >= 1 &&
      value.length <= 2048 && !/[\s\u0000-\u001f\u007f]/u.test(value);
  }

  function safeContinueUrl(value) {
    if (!value || value.length > 4096) return null;
    try {
      const url = new URL(value);
      return continueOrigins.has(url.origin) && !url.username && !url.password
        ? url.href : null;
    } catch (_) {
      return null;
    }
  }

  function destinationFor(value) {
    let action;
    try {
      action = new URL(value);
    } catch (_) {
      return null;
    }
    if (action.origin !== authOrigin || action.username || action.password ||
        action.pathname !== '/account-action.html') return null;
    const query = action.searchParams;
    for (const key of ['mode', 'oobCode', 'apiKey', 'lang', 'continueUrl']) {
      if (query.getAll(key).length > 1) return null;
    }
    const mode = query.get('mode');
    const code = query.get('oobCode');
    if (!opaqueCode(code)) return null;
    if (!firebaseModes.has(mode)) return null;
    const destination = new URL('/__/auth/action', authOrigin);
    destination.searchParams.set('mode', mode);
    destination.searchParams.set('oobCode', code);
    const apiKey = query.get('apiKey');
    if (apiKey && apiKey.length <= 256 && !/[\s\u0000-\u001f\u007f]/u.test(apiKey)) {
      destination.searchParams.set('apiKey', apiKey);
    }
    const lang = query.get('lang');
    if (lang && /^[A-Za-z0-9-]{1,35}$/.test(lang)) {
      destination.searchParams.set('lang', lang);
    }
    const continueUrl = mode === 'resetPassword'
      ? signInReturn : safeContinueUrl(query.get('continueUrl'));
    if (continueUrl) destination.searchParams.set('continueUrl', continueUrl);
    return destination.href;
  }

  function run(window, document) {
    const destination = destinationFor(window.location.href);
    try {
      // Keep neither a consumed code nor an invalid one in this history entry.
      window.history.replaceState(window.history.state, '', window.location.pathname);
    } catch (_) {
      // Redirecting still removes this bridge entry if history is unavailable.
    }
    if (destination) {
      try {
        window.location.replace(destination);
        return;
      } catch (_) {
        // An interrupted navigation gets the same non-sensitive fallback.
      }
    }
    const status = document.getElementById('status');
    if (status) status.textContent = failure;
  }

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = {destinationFor, run};
  } else {
    run(window, document);
  }
})();
