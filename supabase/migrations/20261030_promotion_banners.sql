begin;
create table if not exists public.jt_promotions (
 id uuid primary key default gen_random_uuid(),
 title text not null check(char_length(trim(title)) between 1 and 100),
 description text not null default '' check(char_length(description)<=400),
 image_url text not null default '' check(image_url='' or image_url ~ '^https://[^[:space:]]+$'),
 image_alt text not null default '' check(char_length(image_alt)<=160),
 button_label text not null default 'Lihat Selengkapnya' check(char_length(button_label) between 1 and 50),
 target_url text not null default '/kategori.html' check(target_url ~ '^/[^/[:space:]][^[:space:]]*$' or target_url ~ '^https://[^[:space:]]+$'),
 sort_order integer not null default 0 check(sort_order between 0 and 999),
 is_published boolean not null default false,
 updated_at timestamptz not null default now()
);
alter table public.jt_promotions enable row level security;
revoke all on public.jt_promotions from anon,authenticated;
grant select on public.jt_promotions to anon,authenticated;
grant insert,update,delete on public.jt_promotions to authenticated;
drop policy if exists jt_promotions_public on public.jt_promotions;
create policy jt_promotions_public on public.jt_promotions for select to anon,authenticated using(is_published);
drop policy if exists jt_promotions_admin on public.jt_promotions;
create policy jt_promotions_admin on public.jt_promotions for all to authenticated using(public.jt_is_admin()) with check(public.jt_is_admin());
insert into public.jt_promotions(id,title,description,button_label,target_url,sort_order,is_published)
 values('8a638fde-3915-4876-b5fb-0a67489e8051','Siapkan langkahmu bersama Jenius Tryout','Temukan kategori latihan sesuai jenjang dan tujuan belajarmu.','Jelajahi Kategori','/kategori.html',0,true)
 on conflict(id) do nothing;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 values('jt-promotion-media','jt-promotion-media',true,3145728,array['image/jpeg','image/png','image/webp'])
 on conflict(id) do update set public=true,file_size_limit=3145728,allowed_mime_types=excluded.allowed_mime_types;
drop policy if exists jt_promotions_media_read on storage.objects;
create policy jt_promotions_media_read on storage.objects for select to anon,authenticated using(bucket_id='jt-promotion-media');
drop policy if exists jt_promotions_media_insert on storage.objects;
create policy jt_promotions_media_insert on storage.objects for insert to authenticated with check(bucket_id='jt-promotion-media' and public.jt_is_admin());
drop policy if exists jt_promotions_media_update on storage.objects;
create policy jt_promotions_media_update on storage.objects for update to authenticated using(bucket_id='jt-promotion-media' and public.jt_is_admin()) with check(bucket_id='jt-promotion-media' and public.jt_is_admin());
drop policy if exists jt_promotions_media_delete on storage.objects;
create policy jt_promotions_media_delete on storage.objects for delete to authenticated using(bucket_id='jt-promotion-media' and public.jt_is_admin());
notify pgrst,'reload schema';
commit;
