-- Goal cycle start date ("Goal started Oct 28" on Today). Additive only; null until first goals save / backfill.
alter table public.profiles add column if not exists goal_started_at date;

notify pgrst, 'reload schema';
