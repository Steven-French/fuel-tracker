-- Recipes ("Recipes" tab in the Log food sheet): a name, how many servings the whole recipe makes, and its ingredient list.
-- Same sync pattern as saved_foods: client UUIDs, (user_id, id) primary key, last-write-wins + data-reset trigger
-- (public.fuel_sync_row, shared), tombstones for deletes, and row-level security limiting every row to its owner.
-- A separate table (not saved_foods + a discriminator) so older app versions, which pull every saved_foods row into
-- "My foods", never see recipes as foods. Older versions simply don't know this table and ignore it.
--   servings  how many servings the whole recipe makes
--   items     jsonb array of ingredients: [{name, serv, servings, cal, p, c, f, fib, nut?, ing?, src?, fid?}] — each ingredient
--             holds per-serving values (like a saved food) and how many servings of it go into the recipe.
--             Totals / per-serving numbers are always derived from this list (never stored twice).
create table if not exists public.recipes (
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id          uuid not null,
  name        text check (name is null or length(name) <= 200),
  servings    double precision check (servings is null or (servings > 0 and servings < 100000)),
  items       jsonb check (items is null or (jsonb_typeof(items) = 'array' and jsonb_array_length(items) <= 100 and length(items::text) <= 400000)),
  deleted     boolean not null default false,
  updated_at  timestamptz not null default now(),
  synced_at   timestamptz not null default clock_timestamp(),
  primary key (user_id, id),
  constraint recipes_live_has_data check (deleted or (name is not null and servings is not null and items is not null))
);

create index if not exists recipes_synced_idx on public.recipes (user_id, synced_at, id);

drop trigger if exists fuel_sync_row on public.recipes;
create trigger fuel_sync_row before insert or update on public.recipes for each row execute function public.fuel_sync_row();

-- privileges + row-level security (identical to saved_foods)
do $$
declare t text;
begin
  foreach t in array array['recipes'] loop
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

notify pgrst, 'reload schema';
