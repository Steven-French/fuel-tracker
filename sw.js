/* Fuel service worker: caches the app shell for offline use.
   - index.html / navigations: network-first (revalidated), so a new deploy shows up on the next open.
   - other same-origin static files (icons, manifest): stale-while-revalidate.
   - cross-origin requests (USDA, Open Food Facts APIs) are never intercepted or cached.
   - localStorage is never touched. VERSION is bumped automatically by deploy.sh. */
const VERSION = '20260927-201052';
const CACHE = 'fuel-shell-' + VERSION;
const SHELL = ['./', './index.html', './manifest.webmanifest', './icons/apple-touch-icon.png', './icons/icon-192.png', './icons/icon-512.png', './icons/icon-512-maskable.png'];

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
  if (url.origin !== self.location.origin) return;          // APIs & anything cross-origin: straight to network, never cached
  if (url.pathname.endsWith('/sw.js')) return;
  const isPage = req.mode === 'navigate' || url.pathname.endsWith('/') || url.pathname.endsWith('/index.html');
  if (isPage) {
    event.respondWith((async () => {
      try {
        const res = await fetch(req, {cache: 'no-cache'});    // revalidate with the server (bypasses stale HTTP cache)
        if (res.ok) { const c = await caches.open(CACHE); c.put('./index.html', res.clone()); }
        return res;
      } catch (e) {
        const c = await caches.open(CACHE);
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
