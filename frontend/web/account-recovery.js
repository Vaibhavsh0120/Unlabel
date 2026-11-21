(() => {
  'use strict';
  const params = new URLSearchParams(location.hash.slice(1));
  let token = params.getAll('access_token').length === 1 ? params.get('access_token') : null;
  const recovery = params.getAll('type').length === 1 && params.get('type') === 'recovery';
  history.replaceState(null, '', '/account-recovery.html');
  const form = document.getElementById('recovery');
  const status = document.getElementById('status');
  const button = document.getElementById('submit');
  const api = 'https://unlabel.duckdns.org/auth/v1';
  const expired = () => {
    token = null;
    form.hidden = true;
    status.textContent = 'This reset link is invalid or expired. Return to sign in and request a new link.';
  };
  async function request(method, path, body) {
    return fetch(api + path, { method, headers: { Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json' }, credentials: 'omit', redirect: 'error',
      cache: 'no-store', signal: AbortSignal.timeout(10000),
      ...(body ? { body: JSON.stringify(body) } : {}) });
  }
  async function initialize() {
    if (!recovery || !token || !/^[\x21-\x7e]{1,8192}$/.test(token)) return expired();
    try {
      const response = await request('GET', '/user');
      if (!response.ok) return expired();
      const user = await response.json();
      if (user.is_anonymous !== false) return expired();
      status.textContent = 'Your reset link is ready. Choose a new password.';
      form.hidden = false;
    } catch (_) {
      status.textContent = 'The reset link could not connect. Reload the link from your email to try again.';
    }
  }
  form.addEventListener('submit', async event => {
    event.preventDefault();
    if (!token || button.disabled || !form.reportValidity()) return;
    const password = document.getElementById('password');
    const confirm = document.getElementById('confirm');
    if (password.value.length < 8 || new TextEncoder().encode(password.value).length > 72 ||
        !/[A-Za-z]/.test(password.value) || !/[0-9]/.test(password.value)) {
      status.textContent = 'Use at least 8 characters, with a letter and a number, and at most 72 bytes.';
      password.focus();
      return;
    }
    if (password.value !== confirm.value) {
      status.textContent = 'The passwords do not match.';
      confirm.focus();
      return;
    }
    button.disabled = true;
    try {
      const response = await request('PUT', '/user', { password: password.value });
      if (response.status === 401 || response.status === 403) return expired();
      if (!response.ok) {
        status.textContent = 'The password could not be updated. Choose a different password or request a new link.';
        return;
      }
      try { await request('POST', '/logout?scope=local'); } catch (_) {}
      form.reset();
      form.hidden = true;
      token = null;
      status.textContent = 'Your password has been updated. Return to Unlabel and sign in.';
    } catch (_) {
      status.textContent = 'The update could not be confirmed. Try signing in with the new password before requesting another link.';
    } finally { button.disabled = false; }
  });
  window.addEventListener('pagehide', () => { token = null; form.reset(); });
  initialize();
})();
