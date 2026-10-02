-- Pugmark · 0009 account lifecycle (DPDP: the user can erase everything)

-- Deletes the signed-in user's auth account; every table cascades from profiles → auth.users.
-- Cards already issued keep their serial numbers reserved (the counter never decrements) but the rows are removed,
-- so a public lookup of that serial returns "not found" rather than a stranger's name.
create or replace function delete_my_account() returns void language plpgsql volatile security definer set search_path = public as $$
declare u uuid := auth.uid();
begin
  if u is null then raise exception 'not signed in' using errcode = '28000'; end if;
  delete from auth.users where id = u;
end $$;
revoke execute on function delete_my_account() from public, anon;
grant execute on function delete_my_account() to authenticated;

-- Everything we hold about the signed-in user, as one JSON document (DPDP data portability).
create or replace function export_my_data() returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'profile', (select to_jsonb(p) - 'is_admin' from profiles p where p.id = auth.uid()),
    'runs', (select coalesce(jsonb_agg(to_jsonb(r) - 'trust_detail' order by r.started_at), '[]'::jsonb) from runs r where r.user_id = auth.uid()),
    'tracks', (select coalesce(jsonb_agg(jsonb_build_object('run_id', t.run_id, 'points', t.points)), '[]'::jsonb) from run_tracks t where t.user_id = auth.uid()),
    'cards', (select coalesce(jsonb_agg(card_json(c) order by c.issued_at), '[]'::jsonb) from cards c where c.user_id = auth.uid()),
    'bonds', (select coalesce(jsonb_agg(to_jsonb(b)), '[]'::jsonb) from bonds b where b.user_id = auth.uid()),
    'exported_at', now())
$$;
revoke execute on function export_my_data() from public, anon;
grant execute on function export_my_data() to authenticated;

-- Admins grant/revoke admin on other accounts (RLS forbids changing is_admin directly). An admin cannot demote themselves.
create or replace function admin_set_user_admin(p_user uuid, p_is_admin boolean) returns void language plpgsql volatile security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'admin only' using errcode = '42501'; end if;
  if p_user = auth.uid() and not p_is_admin then raise exception 'you cannot remove your own admin access' using errcode = '42501'; end if;
  update profiles set is_admin = p_is_admin where id = p_user;
end $$;
revoke execute on function admin_set_user_admin(uuid, boolean) from public, anon;
grant execute on function admin_set_user_admin(uuid, boolean) to authenticated;
