// =============================================================================
// Service Worker - PWA Offline Support
// =============================================================================
// Version: 1.0.0
// Author: PI5-SETUP Project
// =============================================================================

const CACHE_NAME = 'pi5-control-v2';
const urlsToCache = [
    '/',
    '/offline.html',
    '/css/main.css',
    '/js/main.js',
    '/manifest.json'
];

// Install event
self.addEventListener('install', (event) => {
    console.log('[SW] Installing...');
    event.waitUntil(
        caches.open(CACHE_NAME)
            .then((cache) => {
                console.log('[SW] Caching app shell');
                return cache.addAll(urlsToCache);
            })
            .catch((error) => {
                console.error('[SW] Cache failed:', error);
            })
    );
    self.skipWaiting();
});

// Activate event
self.addEventListener('activate', (event) => {
    console.log('[SW] Activating...');
    event.waitUntil(
        caches.keys().then((cacheNames) => {
            return Promise.all(
                cacheNames.map((cacheName) => {
                    if (cacheName !== CACHE_NAME) {
                        console.log('[SW] Deleting old cache:', cacheName);
                        return caches.delete(cacheName);
                    }
                })
            );
        })
    );
    self.clients.claim();
});

// Fetch event - Network first, fallback to cache
self.addEventListener('fetch', (event) => {
    if (event.request.method !== 'GET') {
        return;
    }

    if (event.request.url.includes('/api/')) {
        return;
    }

    if (event.request.mode === 'navigate') {
        event.respondWith(
            fetch(event.request)
                .catch(async () => (await caches.match('/offline.html')) || Response.error())
        );
        return;
    }

    event.respondWith(
        fetch(event.request)
            .then((response) => {
                const responseToCache = response.clone();
                caches.open(CACHE_NAME)
                    .then((cache) => cache.put(event.request, responseToCache))
                    .catch((error) => console.error('[SW] Failed to cache resource:', error));

                return response;
            })
            .catch(() => caches.match(event.request))
    );
});

// Listen for messages from main thread
self.addEventListener('message', (event) => {
    if (event.data && event.data.type === 'SKIP_WAITING') {
        self.skipWaiting();
    }
});
