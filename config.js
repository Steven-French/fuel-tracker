/* Fuel cloud sync configuration.
   Leave both values empty to run local-only (the account / sync feature stays hidden).
   Only the project URL and the PUBLIC anon / publishable key belong here. Never put a service_role or
   sb_secret_ key in this file (the app refuses to use one anyway): row-level security is what protects data.
   usdaKey: the app's shared default USDA FoodData Central key (public by design; USDA keys only carry a rate limit).
   Leave it empty to fall back to DEMO_KEY. A key the user saves in Settings always takes precedence. */
window.FUEL_CONFIG = {
  supabaseUrl: 'https://takafdvvrhblmpmkvxtg.supabase.co',
  supabaseKey: 'sb_publishable_-_ODvYJF2-wTWPoU8ov15Q_deissGq-',
  usdaKey: 'Uf92USQY7B922rP5HayXKhWSKRRRAgVrxVReH1IY'
};
