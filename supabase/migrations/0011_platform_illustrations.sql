-- Flying Cobra · 0011 Supabase-platform-only objects for the illustration pipeline (skipped by the PGlite harness)
-- Storage bucket `animal-art` (public read, immutable per path) and a daily worker pass.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('animal-art', 'animal-art', true, 10485760, array['image/png','image/svg+xml'])
on conflict (id) do update set public = true, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "animal art public read" on storage.objects;
create policy "animal art public read" on storage.objects for select using (bucket_id = 'animal-art');

-- Only the worker (service role) writes; admins may delete a file when retiring a rejected version.
drop policy if exists "animal art admin delete" on storage.objects;
create policy "animal art admin delete" on storage.objects for delete using (bucket_id = 'animal-art' and public.is_admin());

-- Daily pass at 03:30 IST (22:00 UTC): asks the Edge Function to process up to 20 passes × 3 images.
-- Requires pg_cron and pg_net (Dashboard → Database → Extensions) and the two settings below, set once:
--   select vault.create_secret('https://YOUR-PROJECT.supabase.co', 'project_url');
--   select vault.create_secret('YOUR-SERVICE-ROLE-KEY', 'service_role_key');
do $$ begin
  create extension if not exists pg_cron;
  create extension if not exists pg_net;
  perform cron.unschedule('flyingcobra-illustrate');
exception when others then null; end $$;
do $$ begin
  perform cron.schedule('flyingcobra-illustrate', '0 22 * * *', $cron$
    select net.http_post(
      url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url') || '/functions/v1/illustrate',
      headers := jsonb_build_object('content-type', 'application/json', 'authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key')),
      body := '{"action":"run","passes":20,"batch":3}'::jsonb);
  $cron$);
exception when others then raise notice 'pg_cron/pg_net not available: enable them in Dashboard → Database → Extensions, then re-run this file (the daily pass is optional; Generate missing in the admin panel does the same by hand)'; end $$;
