// Service worker des notifications du navigateur : affiche la notification reçue et ouvre l'application au toucher.
self.addEventListener('push', (event) => {
  let data = { title: 'Boutik-École', body: '' };
  try { data = Object.assign(data, event.data ? event.data.json() : {}); } catch (e) {}
  event.waitUntil(self.registration.showNotification(data.title, { body: data.body, icon: 'icons/Icon-192.png', badge: 'icons/Icon-192.png' }));
});
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(self.clients.matchAll({ type: 'window' }).then((cs) => (cs.length ? cs[0].focus() : self.clients.openWindow('./'))));
});
