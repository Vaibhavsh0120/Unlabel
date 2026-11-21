/* Google authorization codes stay bound to the initiating window by PKCE. */
(() => {
  'use strict';
  let pending = false;
  let prepared = null;
  window.unlabelPrepareGoogleOAuth = () => {
    if (pending || (prepared && !prepared.closed)) throw new Error('account_busy');
    prepared = window.open('about:blank', '_blank', 'popup,width=520,height=700');
    if (!prepared) throw new Error('popup_blocked');
  };
  window.unlabelCancelGoogleOAuth = () => {
    if (!pending && prepared) { prepared.close(); prepared = null; }
  };
  window.unlabelGoogleOAuth = async (backend, accessToken = null) => {
    if (pending) throw new Error('account_busy');
    const api = new URL(backend);
    if (api.protocol !== 'https:' || api.username || api.password || api.pathname !== '/') {
      throw new Error('account_unavailable');
    }
    // Open before the first await so Safari and Chromium retain user activation.
    const popup = prepared || window.open('about:blank', '_blank', 'popup,width=520,height=700');
    prepared = null;
    if (!popup) throw new Error('popup_blocked');
    pending = true;
    let timer, closed, listener;
    try {
      const bytes = crypto.getRandomValues(new Uint8Array(48));
      const encode = value => btoa(String.fromCharCode(...value))
        .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
      const verifier = encode(bytes);
      const challenge = encode(new Uint8Array(await crypto.subtle.digest(
        'SHA-256', new TextEncoder().encode(verifier))));
      const redirect = new URL('/auth-callback.html', location.origin).href;
      const url = new URL(accessToken ? '/auth/v1/user/identities/authorize' : '/auth/v1/authorize', api);
      url.search = new URLSearchParams({ provider: 'google', redirect_to: redirect, prompt: 'select_account',
        code_challenge: challenge, code_challenge_method: 's256',
        ...(accessToken ? { skip_http_redirect: 'true' } : {}) }).toString();
      let destination = url.href;
      if (accessToken) {
        const response = await fetch(url, { headers: { Authorization: `Bearer ${accessToken}` },
          credentials: 'omit', cache: 'no-store', redirect: 'error',
          signal: AbortSignal.timeout(10000) });
        if (!response.ok) throw new Error('account_unavailable');
        destination = (await response.json()).url;
        const provider = new URL(destination);
        if (provider.origin !== 'https://accounts.google.com' ||
            provider.pathname !== '/o/oauth2/v2/auth') throw new Error('account_unavailable');
      }
      const code = await new Promise((resolve, reject) => {
        listener = event => {
          if (event.origin !== location.origin || event.source !== popup ||
              event.data?.type !== 'unlabel-oauth') return;
          const result = event.data;
          if (typeof result.code !== 'string' || !/^[A-Za-z0-9_-]{1,4096}$/.test(result.code)) {
            reject(new Error('account_cancelled'));
          } else resolve(result.code);
        };
        window.addEventListener('message', listener);
        timer = setTimeout(() => reject(new Error('account_timeout')), 180000);
        closed = setInterval(() => {
          if (popup.closed) reject(new Error('account_cancelled'));
        }, 500);
        popup.location.replace(destination);
      });
      return JSON.stringify({ auth_code: code, code_verifier: verifier });
    } finally {
      clearTimeout(timer);
      clearInterval(closed);
      if (listener) window.removeEventListener('message', listener);
      popup.close();
      pending = false;
    }
  };
})();
