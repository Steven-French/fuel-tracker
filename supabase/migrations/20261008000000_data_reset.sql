-- Per-user data reset ("start over" while keeping the account).
-- An admin (scripts/fuel-admin/reset-user-data.js, postgres / service role) deletes a user's rows, resets their profile to
-- new-signup defaults and stamps profiles.data_reset_at = now(). Then:
--   * the app sees a server reset newer than the one it last applied, wipes that user's local copy and re-pulls;
--   * this trigger silently drops any row whose change time (updated_at) is not after the reset, so an old cached
--     copy on some device (or an older app version) can never re-upload pre-reset data;
--   * app clients (roles anon / authenticated) can never set, move or clear the marker.
alter table public.profiles add column if not exists data_reset_at timestamptz;

create or replace function public.fuel_sync_row()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := least(coalesce(new.updated_at, now()), now() + interval '5 minutes');
  if tg_table_name = 'profiles' then
    if current_user in ('anon', 'authenticated') then
      if tg_op = 'UPDATE' then new.data_reset_at := old.data_reset_at; else new.data_reset_at := null; end if;
    end if;
  elsif exists (select 1 from public.profiles p
                where p.user_id = new.user_id and p.data_reset_at is not null and new.updated_at <= p.data_reset_at) then
    return null;                                   -- a pre-reset copy of a record: ignore it
  end if;
  if tg_op = 'UPDATE' then
    if new.user_id is distinct from old.user_id then
      raise exception 'user_id cannot be changed';
    end if;
    if new.updated_at < old.updated_at then
      return null;
    end if;
  end if;
  new.synced_at := clock_timestamp();
  return new;
end;
$$;
revoke all on function public.fuel_sync_row() from public, anon, authenticated;

notify pgrst, 'reload schema';
