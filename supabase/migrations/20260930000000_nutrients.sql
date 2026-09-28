-- Full nutrient capture for logged foods and saved foods (Cronometer-style detail).
--   nutrients    per-serving amounts keyed by the app's nutrient registry (e.g. {"vitC": 8.4, "fe": 0.81, "na": 24}),
--                in the registry's units (mg / µg / g). A key that is absent means the data source doesn't report it;
--                0 means the source reports zero. Entries logged before this feature have no nutrients (macros only).
--   ingredients  ingredient list from the source (USDA Branded "ingredients", Open Food Facts "ingredients_text")
--   source       data source label, e.g. "USDA FoodData Central · SR Legacy" or "Open Food Facts"
--   source_id    the source's id for the food, e.g. "usda:168462" or "off:0049000028911"
-- Older app versions never send these columns, so their upserts leave them untouched.
do $$
declare t text;
begin
  foreach t in array array['food_entries', 'saved_foods'] loop
    execute format('alter table public.%I add column if not exists nutrients jsonb', t);
    execute format('alter table public.%I add column if not exists ingredients text', t);
    execute format('alter table public.%I add column if not exists source text', t);
    execute format('alter table public.%I add column if not exists source_id text', t);
    execute format('alter table public.%I drop constraint if exists %I', t, t || '_nutrients_ok');
    execute format('alter table public.%I add constraint %I check (nutrients is null or (jsonb_typeof(nutrients) = ''object'' and pg_column_size(nutrients) <= 8192))', t, t || '_nutrients_ok');
    execute format('alter table public.%I drop constraint if exists %I', t, t || '_ingredients_len');
    execute format('alter table public.%I add constraint %I check (ingredients is null or length(ingredients) <= 4000)', t, t || '_ingredients_len');
    execute format('alter table public.%I drop constraint if exists %I', t, t || '_source_len');
    execute format('alter table public.%I add constraint %I check ((source is null or length(source) <= 120) and (source_id is null or length(source_id) <= 80))', t, t || '_source_len');
  end loop;
end $$;

notify pgrst, 'reload schema';
