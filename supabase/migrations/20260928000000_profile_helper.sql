-- Goal-helper profile (sex, age, height, activity level, goal, protein per lb), synced with the rest of the profile.
-- One small JSON object; older app versions never send it, so their profile upserts leave it untouched.
alter table public.profiles add column if not exists helper jsonb
  check (helper is null or (jsonb_typeof(helper) = 'object' and pg_column_size(helper) < 2000));
notify pgrst, 'reload schema';
