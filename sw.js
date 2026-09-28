/* Fuel service worker: caches the app shell for offline use.
   - index.html / navigations: network-first (revalidated), so a new deploy shows up on the next open.
   - other same-origin static files (icons, manifest, vendor/zxing barcode decoder): precached + stale-while-revalidate.
   - config.js (Supabase project URL + public key): network-first like the page, so a changed config applies on the next open.
   - vendor/supabase (sync library): precached like the other static files so sign-in state and sync code work offline.
   - cross-origin requests (USDA, Open Food Facts, and the Supabase auth/database API) are never intercepted or cached.
   - localStorage is never touched. VERSION is bumped automatically by deploy.sh. */
const VERSION = '20260927-224801';
const CACHE = 'fuel-shell-' + VERSION;
const SHELL = ['./', './index.html', './manifest.webmanifest', './icons/apple-touch-icon.png', './icons/icon-192.png', './icons/icon-512.png', './icons/icon-512-maskable.png',
  './vendor/zxing/zxing-reader.js', './vendor/zxing/zxing_reader.wasm', // barcode decoder for browsers without BarcodeDetector (iPhone) — precached so scanning works offline
  './config.js', './vendor/supabase/supabase.js'];                         // cloud sync config + library (the Supabase API itself is never cached)

self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL.map(u => new Request(u, {cache: 'reload'})))).then(() => self.skipWaiting()));
});
self.addEventListener('activate', event => {
  event.waitUntil(caches.keys()
    .then(keys => Promise.all(keys.filter(k => k.startsWith('fuel-shell-') && k !== CACHE).map(k => caches.delete(k))))
    .then(() => self.clients.claim()));
});
self.addEventListener('fetch', event => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;          // APIs & anything cross-origin (incl. Supabase): straight to network, never cached
  if (/\/(auth|rest|realtime|storage|functions)\/v1\//.test(url.pathname)) return; // Supabase-style API paths: never intercepted, even if same-origin
  if (url.pathname.endsWith('/sw.js')) return;
  const isPage = req.mode === 'navigate' || url.pathname.endsWith('/') || url.pathname.endsWith('/index.html') || url.pathname.endsWith('/config.js');
  if (isPage) {
    event.respondWith((async () => {
      try {
        const res = await fetch(req, {cache: 'no-cache'});    // revalidate with the server (bypasses stale HTTP cache)
        const key = url.pathname.endsWith('/config.js') ? './config.js' : './index.html';
        if (res.ok) { const c = await caches.open(CACHE); c.put(key, res.clone()); }
        return res;
      } catch (e) {
        const c = await caches.open(CACHE);
        if (url.pathname.endsWith('/config.js')) return (await c.match('./config.js')) || Response.error();
        return (await c.match('./index.html')) || (await c.match('./')) || Response.error();
      }
    })());
    return;
  }
  event.respondWith((async () => {
    const c = await caches.open(CACHE);
    const cached = await c.match(req, {ignoreSearch: true});
    const fresh = fetch(req).then(res => { if (res.ok) c.put(req, res.clone()); return res; }).catch(() => null);
    if (cached) { event.waitUntil(fresh); return cached; }
    return (await fresh) || Response.error();
  })());
});
