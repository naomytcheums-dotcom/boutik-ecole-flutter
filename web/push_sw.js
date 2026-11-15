// Service worker des notifications du navigateur : affiche la notification reçue et, au toucher, ouvre l'application sur la notification
// concernée (adresse « #/notif?n=<identifiant> », routée selon le type et les données par l'application).
self.addEventListener('push', (event) => {
  let data = { title: 'Boutik-École', body: '' };
  try { data = Object.assign(data, event.data ? event.data.json() : {}); } catch (e) {}
  const options = { body: data.body, icon: 'icons/Icon-192.png', badge: 'icons/Icon-192.png', data: { id: data.notification_id || '', kind: data.kind || '' } };
  if (data.notification_id) options.tag = String(data.notification_id);
  event.waitUntil(self.registration.showNotification(data.title, options));
});
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const id = (event.notification.data && event.notification.data.id) || '';
  const hash = id ? '#/notif?n=' + encodeURIComponent(id) : '';
  const base = self.registration.scope;
  event.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((cs) => {
    const open = cs.find((c) => c.url.startsWith(base));
    if (open) {
      return open.focus().then((c) => (hash && c && 'navigate' in c ? c.navigate(base + hash) : c)).catch(() => self.clients.openWindow(base + hash));
    }
    return self.clients.openWindow(base + hash);
  }));
});
