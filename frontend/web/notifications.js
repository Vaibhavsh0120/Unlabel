/* Browser Web Push is separate from the APK/IPA local scheduler. */
(() => {
  'use strict';
  let onOpen = () => {};
  const supported = window.isSecureContext && 'serviceWorker' in navigator &&
    'PushManager' in window && 'Notification' in window;
  const registration = async () => {
    const reg = await navigator.serviceWorker.register('/notifications-sw.js', {scope: '/notifications/'});
    if (reg.active) return reg;
    const worker = reg.installing || reg.waiting;
    if (!worker) throw new Error('service-worker-unavailable');
    await new Promise((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error('service-worker-timeout')), 10000);
      const check = () => {
        if (worker.state === 'activated') { clearTimeout(timeout); resolve(); }
        else if (worker.state === 'redundant') { clearTimeout(timeout); reject(new Error('service-worker-failed')); }
      };
      worker.addEventListener('statechange', check); check();
    });
    return reg;
  };
  const serialize = sub => sub ? JSON.stringify({endpoint: sub.endpoint, keys: sub.toJSON().keys}) : 'null';
  navigator.serviceWorker?.addEventListener('message', e => {
    if (e.data?.type === 'unlabel-open-notifications') onOpen();
  });
  window.unlabelNotifications = {
    supported,
    initialize(callback) {
      onOpen = callback;
      if (new URL(location.href).searchParams.get('notification') === 'reminder') {
        const url = new URL(location.href); url.searchParams.delete('notification');
        history.replaceState(null, '', url); callback();
      }
    },
    async permitted() {
      if (!supported || Notification.permission !== 'granted') return false;
      return !!(await (await registration()).pushManager.getSubscription());
    },
    async requestPermission() {
      return supported && (Notification.permission === 'granted' || await Notification.requestPermission() === 'granted');
    },
    async subscribe(key) {
      if (!supported) throw new Error('unsupported');
      // Must run directly in the user's enable gesture, before awaiting network.
      if (Notification.permission !== 'granted' && await Notification.requestPermission() !== 'granted') throw new Error('permission');
      const reg = await registration();
      let sub = await reg.pushManager.getSubscription();
      const bytes = Uint8Array.from(atob(key.replace(/-/g, '+').replace(/_/g, '/') + '='.repeat((4-key.length%4)%4)), c=>c.charCodeAt(0));
      sub ??= await reg.pushManager.subscribe({userVisibleOnly: true, applicationServerKey: bytes});
      return serialize(sub);
    },
    async subscription() { return supported ? serialize(await (await registration()).pushManager.getSubscription()) : 'null'; },
    async unsubscribe() { if (supported) await (await (await registration()).pushManager.getSubscription())?.unsubscribe(); },
  };
})();
