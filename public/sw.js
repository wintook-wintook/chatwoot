/* eslint-disable no-restricted-globals, no-console */
/* globals clients */
// Avisos push de la plataforma y del portal de Dali en el teléfono.
// El servidor manda { title, body, tag, url } (Notification::PushNotificationService);
// en el teléfono que activó los avisos desde Dali, url abre Dali con la conversación.
self.addEventListener('push', event => {
  let notification = event.data && event.data.json();

  event.waitUntil(
    self.registration.showNotification(notification.title, {
      body: notification.body || undefined,
      tag: notification.tag,
      icon: '/android-icon-192x192.png',
      badge: '/android-icon-96x96.png',
      data: {
        url: notification.url,
      },
    })
  );
});

self.addEventListener('notificationclick', event => {
  let notification = event.notification;
  const url = notification.data.url;
  notification.close();

  event.waitUntil(
    clients.matchAll({ type: 'window' }).then(windowClients => {
      let matchingWindowClients = windowClients.filter(
        client => client.url === url
      );

      if (matchingWindowClients.length) {
        let firstWindow = matchingWindowClients[0];
        if (firstWindow && 'focus' in firstWindow) {
          firstWindow.focus();
          return;
        }
      }
      // Dali (la app instalada) ya abierta: se usa esa ventana en vez de abrir otra.
      if (url && url.includes('/dali')) {
        const dali = windowClients.find(client => client.url.includes('/dali'));
        if (dali && 'navigate' in dali) {
          dali.navigate(url).then(client => client && client.focus());
          return;
        }
      }
      if (clients.openWindow) {
        clients.openWindow(url);
      }
    })
  );
});
