(() => {
  'use strict';
  const query = new URLSearchParams(location.search);
  const code = query.getAll('code');
  // Remove the one-time code before displaying any further content.
  history.replaceState(null, '', '/auth-callback.html');
  const tabKey = 'unlabel.google.tab.v1';
  const tabRaw = sessionStorage.getItem(tabKey);
  sessionStorage.removeItem(tabKey);
  if (tabRaw) {
    try {
      const saved = JSON.parse(tabRaw);
      const age = Date.now() - saved.createdAt;
      if (!/^[A-Za-z0-9_-]{32}$/.test(saved.channel) || !Number.isFinite(age) ||
          age < 0 || age > 180000) throw new Error('invalid_return');
      const result = code.length === 1 && /^[A-Za-z0-9_-]{1,4096}$/.test(code[0])
        ? {type: 'unlabel-oauth', code: code[0]} : {type: 'unlabel-oauth', error: true};
      if (typeof BroadcastChannel !== 'undefined') {
        const channel = new BroadcastChannel('unlabel-google-' + saved.channel);
        channel.postMessage(result);
        setTimeout(() => { channel.close(); window.close(); }, 100);
      } else if (window.opener) {
        window.opener.postMessage(result, location.origin);
        window.close();
      }
      document.getElementById('status').textContent = result.error
        ? 'Google sign-in was cancelled. Return to Unlabel and try again.'
        : 'Google sign-in finished. You can return to Unlabel.';
    } catch {
      document.getElementById('status').textContent = 'Google sign-in could not finish. Return to Unlabel and try again.';
    }
    return;
  }
  {
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
