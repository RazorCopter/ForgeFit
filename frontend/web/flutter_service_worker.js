const CACHE_NAME = 'forgefit-v2.3.0';

// Lista dei file principali da mettere in cache. 
// Aggiungiamo i file di bootstrap e index.html per permettere il caricamento offline base.
const RESOURCES_TO_CACHE = [
  '/',
  '/index.html',
  '/manifest.json',
  '/favicon.ico',
  '/flutter_bootstrap.js',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png'
];

// Installazione del Service Worker e caching delle risorse iniziali
self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(RESOURCES_TO_CACHE);
    })
  );
});

// Attivazione e pulizia delle cache obsolete
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_NAME) {
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
});

// Intercettazione delle richieste di rete:
// Strategia: Network First, fallback su Cache.
self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;

  event.respondWith(
    fetch(event.request)
      .then((response) => {
        // Se la richiesta va a buon fine, copiamola nella cache per un uso offline futuro.
        const responseClone = response.clone();
        caches.open(CACHE_NAME).then((cache) => {
          cache.put(event.request, responseClone);
        });
        return response;
      })
      .catch(() => {
        // Se offline, cerca nella cache
        return caches.match(event.request);
      })
  );
});
