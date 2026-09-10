// ─── TupiLingo Hyper Performance Web Engine (HPWE) ──────────────────────────
// Service Worker Enterprise (PWA Offline-First & Cache Multi-Level)
const CACHE_NAME_STATIC = 'tupilingo-static-v1';
const CACHE_NAME_RUNTIME = 'tupilingo-runtime-v1';

// Recursos críticos para pré-aquecimento instantâneo (Zero Network Delay)
const PRECACHE_ASSETS = [
  './',
  'index.html',
  'manifest.json',
  'favicon.png',
  'assets/shaders/mystic_aura.frag'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME_STATIC).then((cache) => {
      return cache.addAll(PRECACHE_ASSETS).catch((err) => {
        console.warn('[HPWE ServiceWorker] Falha ao pré-carregar alguns assets:', err);
      });
    }).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys.map((key) => {
          if (key !== CACHE_NAME_STATIC && key !== CACHE_NAME_RUNTIME) {
            return caches.delete(key);
          }
        })
      );
    }).then(() => self.clients.claim())
  );
});

// Estratégia de Interceptação: Stale-While-Revalidate para APIs e Cache-First para Assets
self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // 1. Ignora requisições de métodos diferentes de GET (POST de respostas, etc.)
  if (event.request.method !== 'GET') {
    return;
  }

  // 2. Assets Estáticos (.wasm, .frag, .png, .svg, .js, .ttf): Cache-First
  if (
    url.pathname.endsWith('.wasm') ||
    url.pathname.endsWith('.frag') ||
    url.pathname.endsWith('.png') ||
    url.pathname.endsWith('.svg') ||
    url.pathname.endsWith('.ttf') ||
    url.pathname.endsWith('.js')
  ) {
    event.respondWith(
      caches.match(event.request).then((cachedResponse) => {
        if (cachedResponse) {
          return cachedResponse;
        }
        return fetch(event.request).then((networkResponse) => {
          if (networkResponse && networkResponse.status === 200) {
            const copy = networkResponse.clone();
            caches.open(CACHE_NAME_STATIC).then((cache) => cache.put(event.request, copy));
          }
          return networkResponse;
        });
      })
    );
    return;
  }

  // 3. APIs de Trilha e Capítulos: Stale-While-Revalidate com ETag
  if (url.pathname.includes('/api/v1/trilha/')) {
    event.respondWith(
      caches.open(CACHE_NAME_RUNTIME).then((cache) => {
        return cache.match(event.request).then((cachedResponse) => {
          const fetchPromise = fetch(event.request).then((networkResponse) => {
            if (networkResponse && networkResponse.status === 200) {
              cache.put(event.request, networkResponse.clone());
            }
            return networkResponse;
          }).catch(() => cachedResponse);

          return cachedResponse || fetchPromise;
        });
      })
    );
    return;
  }

  // 4. Default Network com fallback
  event.respondWith(
    fetch(event.request).catch(() => caches.match(event.request))
  );
});

// Sincronização em Background para Ações Offline
self.addEventListener('sync', (event) => {
  if (event.tag === 'sync:tupi-progress') {
    console.log('[HPWE ServiceWorker] Disparando Background Sync de progresso pendente...');
  }
});
