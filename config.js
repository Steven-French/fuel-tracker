/* Fuel cloud sync configuration.
   Leave both values empty to run local-only (the account / sync feature stays hidden).
   Only the project URL and the PUBLIC anon / publishable key belong here. Never put a service_role or
   sb_secret_ key in this file (the app refuses to use one anyway): row-level security is what protects data. */
window.FUEL_CONFIG = {
  supabaseUrl: '',
  supabaseKey: ''
};
