-- Flying Cobra · 0008 Supabase-platform-only objects (skipped by the PGlite test harness)
-- Storage bucket for card art + scheduled period close.

-- Card art bucket: public read (cards are shared), admin write
insert into storage.buckets (id, name, public)
values ('card-art', 'card-art', true)
on conflict (id) do nothing;

drop policy if exists "card art public read" on storage.objects;
create policy "card art public read" on storage.objects for select using (bucket_id = 'card-art');

drop policy if exists "card art admin write" on storage.objects;
create policy "card art admin write" on storage.objects for all
  using (bucket_id = 'card-art' and public.is_admin())
  with check (bucket_id = 'card-art' and public.is_admin());

-- Weekly/monthly close every day at 03:10 IST (21:40 UTC) — belt and braces alongside claim_pending_cards()
do $$ begin
  create extension if not exists pg_cron;
  perform cron.unschedule('flyingcobra-close-periods');
exception when others then null; end $$;
do $$ begin
  perform cron.schedule('flyingcobra-close-periods', '40 21 * * *', $cron$ select public.close_periods(); $cron$);
exception when others then raise notice 'pg_cron not available: enable it in Dashboard → Database → Extensions, then re-run this file'; end $$;
