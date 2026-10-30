begin;
-- Pemasukan hanya dapat dibaca Pengelola. Nilai berasal dari transaksi terverifikasi.
create or replace function public.jt_admin_income_report(
 p_start date,p_end date,p_exam_id uuid default null,p_query text default '',p_page integer default 1
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare result jsonb;
begin
 if auth.uid() is null or not public.jt_is_admin() then raise exception 'Akses Pengelola diperlukan.';end if;
 if p_start is null or p_end is null or p_end<p_start or p_end-p_start>366 then raise exception 'Pilih periode yang valid, maksimal 367 hari.';end if;
 if p_page is null or p_page<1 or char_length(coalesce(p_query,''))>100 then raise exception 'Filter laporan tidak valid.';end if;
 with source as (
  select o.id,o.exam_id,o.user_id,o.status,
   coalesce(e.title,'Paket tidak tersedia') exam_title,coalesce(p.display_name,o.user_id::text) participant,
   coalesce(nullif(to_jsonb(o)->>'total','')::numeric,nullif(to_jsonb(o)->>'amount_idr','')::numeric,0) amount,
   coalesce(nullif(to_jsonb(o)->>'admin_fee','')::numeric,0) admin_fee,
   coalesce(nullif(to_jsonb(o)->>'paid_at','')::timestamptz,nullif(to_jsonb(o)->>'verified_at','')::timestamptz,o.created_at) received_at,
   (nullif(to_jsonb(o)->>'paid_at','') is null and nullif(to_jsonb(o)->>'verified_at','') is null) date_fallback
  from public.jt_orders o left join public.jt_exams e on e.id=o.exam_id left join public.jt_profiles p on p.user_id=o.user_id
  where o.status in ('paid','approved')
 ), filtered as (
  select * from source where (received_at at time zone 'Asia/Jakarta')::date between p_start and p_end
   and (p_exam_id is null or exam_id=p_exam_id)
   and strpos(lower(concat_ws(' ',participant,exam_title,id::text)),lower(trim(coalesce(p_query,''))))>0
 ), page as (
  select * from filtered order by received_at desc,id limit 20 offset ((p_page::bigint-1)*20)
 ), trend as (
  select to_char(received_at at time zone 'Asia/Jakarta',case when p_end-p_start>62 then 'YYYY-MM' else 'YYYY-MM-DD' end) label,sum(amount) amount
  from filtered group by 1 order by 1
 ) select jsonb_build_object(
  'total',coalesce((select sum(amount) from filtered),0),
  'package_total',coalesce((select sum(greatest(amount-admin_fee,0)) from filtered),0),
  'admin_fee',coalesce((select sum(admin_fee) from filtered),0),
  'count',(select count(*) from filtered),'page',p_page,'page_size',20,
  'grain',case when p_end-p_start>62 then 'month' else 'day' end,
  'rows',coalesce((select jsonb_agg(to_jsonb(page)) from page),'[]'::jsonb),
  'trend',coalesce((select jsonb_agg(to_jsonb(trend)) from trend),'[]'::jsonb)
 ) into result;
 return result;
end $$;
revoke all on function public.jt_admin_income_report(date,date,uuid,text,integer) from public,anon;
grant execute on function public.jt_admin_income_report(date,date,uuid,text,integer) to authenticated;

-- Delapan kategori tetap. Tabel berisi teks publik, tanpa akun atau data transaksi.
create table if not exists public.jt_category_information(
 slug text primary key check(slug in ('sd','smp','sma','utbk-snbt','cpns','sekolah-kedinasan','mtsn-man','paket-bundling')),
 headline text not null check(char_length(trim(headline)) between 1 and 120),
 intro text not null check(char_length(trim(intro)) between 1 and 600),
 audience text not null check(char_length(trim(audience)) between 1 and 400),
 topics jsonb not null check(jsonb_typeof(topics)='array' and jsonb_array_length(topics) between 1 and 12),
 note text not null default '' check(char_length(note)<=600),
 updated_at timestamptz not null default now()
);
create or replace function public.jt_validate_category_topics() returns trigger language plpgsql set search_path=public,pg_temp as $$
begin
 if exists(select 1 from jsonb_array_elements(new.topics) t where jsonb_typeof(t)<>'string' or char_length(trim(t#>>'{}')) not between 1 and 180) then raise exception 'Materi harus berupa teks, maksimal 180 karakter per baris.';end if;
 new.updated_at=now();return new;
end $$;
drop trigger if exists jt_category_topics_valid on public.jt_category_information;
create trigger jt_category_topics_valid before insert or update on public.jt_category_information for each row execute function public.jt_validate_category_topics();
alter table public.jt_category_information enable row level security;
revoke all on public.jt_category_information from anon,authenticated;
grant select on public.jt_category_information to anon,authenticated;
grant insert,update on public.jt_category_information to authenticated;
drop policy if exists jt_category_information_public on public.jt_category_information;
create policy jt_category_information_public on public.jt_category_information for select to anon,authenticated using(true);
drop policy if exists jt_category_information_admin on public.jt_category_information;
create policy jt_category_information_admin on public.jt_category_information for all to authenticated using(public.jt_is_admin()) with check(public.jt_is_admin());

insert into public.jt_category_information(slug,headline,intro,audience,topics,note) values
('sd','Persiapan SD','Bangun pemahaman dasar melalui latihan yang sesuai dengan jenjang dan tujuan belajar.','Siswa SD yang ingin memperkuat dasar belajar dan mempersiapkan ujian.','["Numerasi dan pemecahan masalah dasar","Pemahaman bacaan dan penggunaan bahasa","Pengetahuan dasar sesuai materi paket"]','Panduan materi kategori. Cakupan soal setiap paket mengikuti materi yang disiapkan pengelola; periksa informasi paket sebelum membeli.'),
('smp','Persiapan SMP','Latih pemahaman konsep dan penalaran untuk persiapan belajar yang lebih terarah.','Siswa SMP yang mempersiapkan asesmen, ujian sekolah, atau jenjang berikutnya.','["Matematika dan penalaran kuantitatif","Literasi dan pemahaman bacaan","Materi pelajaran sesuai cakupan paket"]','Panduan materi kategori. Cakupan soal setiap paket mengikuti materi yang disiapkan pengelola; periksa informasi paket sebelum membeli.'),
('sma','Persiapan SMA','Perkuat penguasaan materi dan kemampuan menyelesaikan soal secara mandiri.','Siswa SMA yang mempersiapkan asesmen dan ujian sesuai kebutuhan belajarnya.','["Pemahaman konsep pelajaran","Penalaran dan pemecahan masalah","Literasi serta analisis informasi"]','Panduan materi kategori. Cakupan soal setiap paket mengikuti materi yang disiapkan pengelola; periksa informasi paket sebelum membeli.'),
('utbk-snbt','Persiapan UTBK / SNBT','Persiapkan kemampuan bernalar, membaca, dan mengolah informasi melalui latihan terarah.','Siswa SMA/sederajat dan lulusan yang mempersiapkan seleksi masuk perguruan tinggi.','["Potensi skolastik dan penalaran umum","Literasi Bahasa Indonesia dan Bahasa Inggris","Penalaran matematika"]','Panduan materi kategori. Cakupan soal setiap paket mengikuti materi yang disiapkan pengelola; periksa informasi paket sebelum membeli.'),
('cpns','Persiapan CPNS','Kenali jenis kemampuan yang perlu dipersiapkan dan biasakan mengerjakan latihan dengan batas waktu.','Peserta yang mempersiapkan seleksi calon pegawai negeri sipil.','["Tes Wawasan Kebangsaan (TWK)","Tes Intelegensia Umum (TIU)","Tes Karakteristik Pribadi (TKP) sesuai materi paket"]','Panduan materi kategori. Cakupan soal setiap paket mengikuti materi yang disiapkan pengelola; periksa informasi paket sebelum membeli.'),
('sekolah-kedinasan','Persiapan Sekolah Kedinasan','Susun persiapan seleksi dengan latihan akademik dan penalaran sesuai program yang dituju.','Calon peserta seleksi sekolah kedinasan.','["Kemampuan dasar dan penalaran","Literasi serta numerasi","Materi seleksi sesuai sekolah dan paket"]','Panduan materi kategori. Cakupan soal setiap paket mengikuti materi yang disiapkan pengelola; periksa informasi paket sebelum membeli.'),
('mtsn-man','Persiapan MTsN / MAN','Latih kemampuan akademik sesuai jenjang dan kebutuhan seleksi sekolah tujuan.','Calon peserta didik yang mempersiapkan seleksi masuk MTsN atau MAN.','["Numerasi dan penalaran","Pemahaman bacaan","Materi akademik sesuai jenjang paket"]','Panduan materi kategori. Cakupan soal setiap paket mengikuti materi yang disiapkan pengelola; periksa informasi paket sebelum membeli.'),
('paket-bundling','Persiapan Paket Bundling','Periksa rincian program untuk mengetahui komposisi latihan yang ditawarkan.','Peserta yang memilih program dengan komposisi paket gabungan.','["Komposisi program mengikuti paket yang diterbitkan","Materi mengikuti cakupan program pilihan","Akses diberikan ke paket yang tercantum pada pembelian"]','Panduan materi kategori. Cakupan soal setiap paket mengikuti materi yang disiapkan pengelola; periksa informasi paket sebelum membeli.')
on conflict(slug) do nothing;
notify pgrst,'reload schema';
commit;
