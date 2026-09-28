-- Fuel: cloud backup & sync schema.
-- Local-first client: localStorage is the working copy; these tables mirror it per user.
--   * every record has a client-generated UUID; primary key is (user_id, id)
--   * updated_at = when the record was last changed on a device (last-write-wins)
--   * synced_at  = server clock, set on every write; clients pull "synced_at >= cursor"
--   * deleted    = soft delete (tombstone) so deletions sync; tombstones keep no food/weight data
-- Row-level security: a signed-in user can only read or write rows where user_id = auth.uid().
-- The anon role gets no access at all.

-- ---------- shared trigger: server timestamps + last-write-wins ----------
create or replace function public.fuel_sync_row()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- a device with a clock set far in the future must not win every conflict forever
  new.updated_at := least(coalesce(new.updated_at, now()), now() + interval '5 minutes');
  if tg_op = 'UPDATE' then
    if new.user_id is distinct from old.user_id then
      raise exception 'user_id cannot be changed';
    end if;
    -- last-write-wins: silently ignore writes older than what the server already has
    if new.updated_at < old.updated_at then
      return null;
    end if;
  end if;
  new.synced_at := clock_timestamp();
  return new;
end;
$$;

-- ---------- profile / goals / settings: one row per user ----------
create table if not exists public.profiles (
  user_id        uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  unit           text not null default 'lb' check (unit in ('lb', 'kg')),
  goal_calories  double precision check (goal_calories is null or (goal_calories > 0 and goal_calories < 100000)),
  goal_protein   double precision check (goal_protein is null or (goal_protein > 0 and goal_protein < 10000)),
  goal_carbs     double precision check (goal_carbs is null or (goal_carbs > 0 and goal_carbs < 10000)),
  goal_fat       double precision check (goal_fat is null or (goal_fat > 0 and goal_fat < 10000)),
  goal_fiber     double precision check (goal_fiber is null or (goal_fiber > 0 and goal_fiber < 10000)),
  goals_set      boolean not null default false,
  usda_key       text check (usda_key is null or length(usda_key) <= 100),
  goal_weight_kg        double precision check (goal_weight_kg is null or (goal_weight_kg > 0 and goal_weight_kg < 1000)),
  goal_weight_start_kg  double precision check (goal_weight_start_kg is null or (goal_weight_start_kg > 0 and goal_weight_start_kg < 1000)),
  updated_at     timestamptz not null default now(),
  synced_at      timestamptz not null default clock_timestamp()
);

-- optional goal weight (added with the Today weight ring); idempotent for databases created before it existed
alter table public.profiles add column if not exists goal_weight_kg double precision
  check (goal_weight_kg is null or (goal_weight_kg > 0 and goal_weight_kg < 1000));
alter table public.profiles add column if not exists goal_weight_start_kg double precision
  check (goal_weight_start_kg is null or (goal_weight_start_kg > 0 and goal_weight_start_kg < 1000));

-- ---------- food log entries ----------
create table if not exists public.food_entries (
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id          uuid not null,
  day         date,
  meal        text check (meal is null or meal in ('breakfast', 'lunch', 'dinner', 'snack')),
  name        text check (name is null or length(name) <= 200),
  servings    double precision check (servings is null or (servings >= 0 and servings < 100000)),
  calories    double precision check (calories is null or (calories >= 0 and calories < 1000000)),
  protein     double precision check (protein is null or (protein >= 0 and protein < 100000)),
  carbs       double precision check (carbs is null or (carbs >= 0 and carbs < 100000)),
  fat         double precision check (fat is null or (fat >= 0 and fat < 100000)),
  fiber       double precision check (fiber is null or (fiber >= 0 and fiber < 100000)),
  serving     text check (serving is null or length(serving) <= 120),
  logged_at   timestamptz,
  deleted     boolean not null default false,
  updated_at  timestamptz not null default now(),
  synced_at   timestamptz not null default clock_timestamp(),
  primary key (user_id, id),
  constraint food_entries_live_has_data check (deleted or (day is not null and name is not null and meal is not null))
);

-- ---------- saved foods ("My foods") ----------
create table if not exists public.saved_foods (
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id          uuid not null,
  name        text check (name is null or length(name) <= 200),
  servings    double precision check (servings is null or (servings >= 0 and servings < 100000)),
  calories    double precision check (calories is null or (calories >= 0 and calories < 1000000)),
  protein     double precision check (protein is null or (protein >= 0 and protein < 100000)),
  carbs       double precision check (carbs is null or (carbs >= 0 and carbs < 100000)),
  fat         double precision check (fat is null or (fat >= 0 and fat < 100000)),
  fiber       double precision check (fiber is null or (fiber >= 0 and fiber < 100000)),
  serving     text check (serving is null or length(serving) <= 120),
  deleted     boolean not null default false,
  updated_at  timestamptz not null default now(),
  synced_at   timestamptz not null default clock_timestamp(),
  primary key (user_id, id),
  constraint saved_foods_live_has_data check (deleted or name is not null)
);

-- ---------- weigh-ins (one per day; the client derives the UUID from the date) ----------
create table if not exists public.weight_entries (
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id          uuid not null,
  day         date,
  kg          double precision check (kg is null or (kg > 0 and kg < 1000)),
  deleted     boolean not null default false,
  updated_at  timestamptz not null default now(),
  synced_at   timestamptz not null default clock_timestamp(),
  primary key (user_id, id),
  constraint weight_entries_live_has_data check (deleted or (day is not null and kg is not null))
);

-- pull queries: where user_id = me and synced_at >= cursor order by synced_at, id
create index if not exists profiles_synced_idx       on public.profiles       (user_id, synced_at);
create index if not exists food_entries_synced_idx   on public.food_entries   (user_id, synced_at, id);
create index if not exists saved_foods_synced_idx    on public.saved_foods    (user_id, synced_at, id);
create index if not exists weight_entries_synced_idx on public.weight_entries (user_id, synced_at, id);

-- triggers
drop trigger if exists fuel_sync_row on public.profiles;
create trigger fuel_sync_row before insert or update on public.profiles       for each row execute function public.fuel_sync_row();
drop trigger if exists fuel_sync_row on public.food_entries;
create trigger fuel_sync_row before insert or update on public.food_entries   for each row execute function public.fuel_sync_row();
drop trigger if exists fuel_sync_row on public.saved_foods;
create trigger fuel_sync_row before insert or update on public.saved_foods    for each row execute function public.fuel_sync_row();
drop trigger if exists fuel_sync_row on public.weight_entries;
create trigger fuel_sync_row before insert or update on public.weight_entries for each row execute function public.fuel_sync_row();

-- ---------- privileges + row-level security ----------
do $$
declare t text;
begin
  foreach t in array array['profiles', 'food_entries', 'saved_foods', 'weight_entries'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon', t);
    execute format('revoke all on public.%I from authenticated', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
    execute format('drop policy if exists "own rows: select" on public.%I', t);
    execute format('drop policy if exists "own rows: insert" on public.%I', t);
    execute format('drop policy if exists "own rows: update" on public.%I', t);
    execute format('drop policy if exists "own rows: delete" on public.%I', t);
    execute format('create policy "own rows: select" on public.%I for select to authenticated using ((select auth.uid()) = user_id)', t);
    execute format('create policy "own rows: insert" on public.%I for insert to authenticated with check ((select auth.uid()) = user_id)', t);
    execute format('create policy "own rows: update" on public.%I for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id)', t);
    execute format('create policy "own rows: delete" on public.%I for delete to authenticated using ((select auth.uid()) = user_id)', t);
  end loop;
end $$;

revoke all on function public.fuel_sync_row() from public, anon, authenticated;
