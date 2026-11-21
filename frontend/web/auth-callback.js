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
    document.getElementById('status').textContent = 'Open Unlabel and try signing in again.';
  }
})();
