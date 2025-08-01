// Firebase Messaging Service Worker for Web Push Notifications
// This file is required for Firebase Cloud Messaging to work in web browsers

// Import Firebase scripts for service worker
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-messaging-compat.js');

// Firebase configuration
const firebaseConfig = {
  apiKey: "AIzaSyBO5TpEyjl1fgN2dE9Nxo9yE7yX0cq8c8k",
  authDomain: "goat-goat-8e3da.firebaseapp.com",
  projectId: "goat-goat-8e3da",
  storageBucket: "goat-goat-8e3da.firebasestorage.app",
  messagingSenderId: "188247457782",
  appId: "1:188247457782:web:e0a140ed5104e96c2f91d7",
  measurementId: "G-MM945XX1C5"
};

// Initialize Firebase
firebase.initializeApp(firebaseConfig);

// Retrieve Firebase Messaging object
const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);

  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: 'goat-goat-notification',
    requireInteraction: true,
    actions: [
      {
        action: 'open',
        title: 'Open App'
      },
      {
        action: 'close',
        title: 'Close'
      }
    ]
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification click events
self.addEventListener('notificationclick', function(event) {
  console.log('[firebase-messaging-sw.js] Notification click received.');

  event.notification.close();

  if (event.action === 'open') {
    // Open the app when notification is clicked
    event.waitUntil(
      clients.openWindow('https://goatgoat.info')
    );
  }
});