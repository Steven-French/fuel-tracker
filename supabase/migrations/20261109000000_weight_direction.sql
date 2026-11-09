-- Weight direction for the gold weight-ring highlight (new all-time low vs new all-time high).
-- null = auto-derive from goal weight vs latest weigh-in until the user picks Losing or Gaining.
alter table public.profiles add column if not exists weight_direction text
  check (weight_direction is null or weight_direction in ('losing', 'gaining'));

notify pgrst, 'reload schema';
