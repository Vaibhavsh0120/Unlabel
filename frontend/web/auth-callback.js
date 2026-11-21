(() => {
  'use strict';
  const query = new URLSearchParams(location.search);
  const code = query.getAll('code');
  // Remove the one-time code before displaying any further content.
  history.replaceState(null, '', '/auth-callback.html');
  if (window.opener && code.length === 1 && /^[A-Za-z0-9_-]{1,4096}$/.test(code[0])) {
    window.opener.postMessage({ type: 'unlabel-oauth', code: code[0] }, location.origin);
  } else if (window.opener) {
    window.opener.postMessage({ type: 'unlabel-oauth', error: true }, location.origin);
  } else {
    const key = 'unlabel.google.redirect.v1';
    const raw = sessionStorage.getItem(key);
    sessionStorage.removeItem(key);
    try {
      const saved = JSON.parse(raw);
      const age = Date.now() - saved.createdAt;
      if (code.length !== 1 || !/^[A-Za-z0-9_-]{1,4096}$/.test(code[0]) ||
          !/^[A-Za-z0-9_-]{64}$/.test(saved.verifier) || !Number.isFinite(age) || age < 0 || age > 300000) {
        throw new Error('invalid_return');
      }
      sessionStorage.setItem('unlabel.google.grant.v1', JSON.stringify({
        auth_code: code[0], code_verifier: saved.verifier, createdAt: saved.createdAt,
      }));
      location.replace('/#/account-signin');
    } catch {
      document.getElementById('status').textContent = 'Google sign-in could not finish. Open Unlabel and try again.';
    }
  }
})();
