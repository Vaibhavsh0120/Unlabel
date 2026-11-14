'use strict';
self.addEventListener('push', event => {
  let data;
  try { data = event.data.json(); } catch (_) { return; }
  if (!data || typeof data.title !== 'string' || typeof data.body !== 'string') return;
  event.waitUntil(self.registration.showNotification(data.title.slice(0, 100), {
    body: data.body.slice(0, 360), icon: '/icons/Icon-light-192.png',
    badge: '/icons/Icon-light-192.png', tag: String(data.id || 'label-reminder').slice(0, 80),
    data: {url: '/?notification=reminder'},
  }));
});
self.addEventListener('notificationclick', event => {
  event.notification.close();
  event.waitUntil((async () => {
    const clients = await self.clients.matchAll({type: 'window', includeUncontrolled: true});
    for (const client of clients) {
      if (new URL(client.url).origin === self.location.origin) {
        await client.focus(); client.postMessage({type: 'unlabel-open-notifications'}); return;
      }
    }
    await self.clients.openWindow('/?notification=reminder');
  })());
});
