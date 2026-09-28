-- Exercise log (Compendium activity or custom entry) + the "eat back exercise calories" setting.
-- Same pattern as the other synced tables: client UUIDs, (user_id, id) primary key, last-write-wins trigger,
-- tombstones for deletes, and row-level security limiting every row to its owner.

create table if not exists public.exercise_entries (
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id          uuid not null,
  day         date,
  name        text check (name is null or length(name) <= 200),
  code        text check (code is null or code ~ '^[0-9]{5}$'),                      -- 2024 Adult Compendium code; null = custom
  met         double precision check (met is null or (met > 0 and met < 30)),
  minutes     double precision check (minutes is null or (minutes > 0 and minutes <= 1440)),
  calories    double precision check (calories is null or (calories >= 0 and calories < 20000)),
  logged_at   timestamptz,
  deleted     boolean not null default false,
  updated_at  timestamptz not null default now(),
  synced_at   timestamptz not null default clock_timestamp(),
  primary key (user_id, id),
  constraint exercise_entries_live_has_data check (deleted or (day is not null and name is not null and calories is not null))
);
create index if not exists exercise_entries_synced_idx on public.exercise_entries (user_id, synced_at, id);

drop trigger if exists fuel_sync_row on public.exercise_entries;
create trigger fuel_sync_row before insert or update on public.exercise_entries for each row execute function public.fuel_sync_row();

alter table public.exercise_entries enable row level security;
revoke all on public.exercise_entries from anon;
revoke all on public.exercise_entries from authenticated;
grant select, insert, update, delete on public.exercise_entries to authenticated;
drop policy if exists "own rows: select" on public.exercise_entries;
drop policy if exists "own rows: insert" on public.exercise_entries;
drop policy if exists "own rows: update" on public.exercise_entries;
drop policy if exists "own rows: delete" on public.exercise_entries;
create policy "own rows: select" on public.exercise_entries for select to authenticated using ((select auth.uid()) = user_id);
create policy "own rows: insert" on public.exercise_entries for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "own rows: update" on public.exercise_entries for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "own rows: delete" on public.exercise_entries for delete to authenticated using ((select auth.uid()) = user_id);

-- add exercise calories back to the daily budget (default on); older app versions never send it
alter table public.profiles add column if not exists eat_back boolean not null default true;

notify pgrst, 'reload schema';
