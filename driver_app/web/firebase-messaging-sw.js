// FCM background service worker — driver.hoppin.tech
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

try {
  firebase.initializeApp({
    apiKey: 'AIzaSyDeaObkhh_prXXjNadiZQl_Q_A-dfbcHkE',
    authDomain: 'ecom-4f7bc.firebaseapp.com',
    projectId: 'ecom-4f7bc',
    storageBucket: 'ecom-4f7bc.firebasestorage.app',
    messagingSenderId: '381604059820',
    appId: '1:381604059820:web:0f35c93f3f0455b6359d09',
  });

  const messaging = firebase.messaging();

  messaging.onBackgroundMessage((payload) => {
    const n = payload.notification || {};
    self.registration.showNotification(n.title || 'Hoppin', {
      body: n.body || '',
      icon: '/icons/Icon-192.png',
      data: payload.data || {},
    });
  });
} catch (e) {
  console.info('[hoppin] FCM worker inert:', e);
}

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const data = event.notification.data || {};
  const target = typeof data.deep_link === 'string' ? data.deep_link : '/';
  event.waitUntil(clients.openWindow(target));
});
