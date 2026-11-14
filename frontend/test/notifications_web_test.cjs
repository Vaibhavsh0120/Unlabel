const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const source = name => fs.readFileSync(path.join(__dirname, '../web', name), 'utf8');

test('browser permission, active worker subscription and unsubscribe use real browser APIs', async () => {
  let permissions = 0, subscribed = 0, cancelled = 0;
  let current = null;
  const reg = {active: {}, pushManager: {
    async getSubscription() {return current;},
    async subscribe(options) {
      subscribed++; assert.equal(options.userVisibleOnly, true);
      current = {endpoint:'https://fcm.googleapis.com/test', toJSON:()=>({keys:{auth:'test',p256dh:'test'}}),
        async unsubscribe() {cancelled++; current = null; return true;}};
      return current;
    },
  }};
  const notification = {permission:'default', async requestPermission() {permissions++; this.permission='granted'; return 'granted';}};
  const window = {isSecureContext:true,PushManager:function(){},Notification:notification};
  vm.runInNewContext(source('notifications.js'), {window, Notification:notification,
    navigator:{serviceWorker:{async register(url, options) {assert.equal(url,'/notifications-sw.js'); assert.equal(options.scope,'/notifications/'); return reg;},addEventListener(){}}},
    URL, location:{href:'https://example.test/'}, history:{replaceState(){}},Uint8Array,atob,setTimeout,clearTimeout});
  const api = window.unlabelNotifications;
  assert.equal(permissions,0); assert.equal(await api.permitted(),false);
  assert.equal(await api.requestPermission(),true);
  assert.equal(JSON.parse(await api.subscribe('eA')).endpoint,'https://fcm.googleapis.com/test');
  assert.equal(await api.permitted(),true); assert.equal(subscribed,1);
  await api.unsubscribe(); assert.equal(cancelled,1); assert.equal(await api.permitted(),false);
});

test('push worker displays a bounded message and notification clicks open the inbox', async () => {
  const handlers = {}, shown = [], opened = [];
  const self = {location:{origin:'https://example.test'}, addEventListener(type, handler) {handlers[type]=handler;},
    registration:{async showNotification(title, options) {shown.push({title,...options});}},
    clients:{async matchAll(){return [];},async openWindow(url){opened.push(url);}}};
  vm.runInNewContext(source('notifications-sw.js'),{self, URL});
  let completion;
  handlers.push({data:{json:()=>({title:'t'.repeat(120),body:'b'.repeat(400),id:'daily'})},waitUntil(p){completion=p;}});
  await completion; assert.equal(shown[0].title.length,100); assert.equal(shown[0].body.length,360);
  handlers.notificationclick({notification:{close(){}},waitUntil(p){completion=p;}});
  await completion; assert.deepEqual(opened,['/?notification=reminder']);
  handlers.push({data:{json(){throw Error('bad payload');}},waitUntil(){assert.fail('malformed push');}});
});
