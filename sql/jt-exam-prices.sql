-- Jalankan pada Supabase yang digunakan Jenius Tryout.
-- Harga resmi per paket, dalam rupiah bulat.
alter table public.jt_exams add column if not exists price_idr integer;
alter table public.jt_exams drop constraint if exists jt_exams_price_idr_nonnegative;
alter table public.jt_exams add constraint jt_exams_price_idr_nonnegative check (price_idr >= 0);
comment on column public.jt_exams.price_idr is 'Harga paket Tryout dalam rupiah; null berarti harga belum ditentukan.';
-- Tetapkan harga tiap paket secara eksplisit melalui Panel Pengelola / SQL.
-- Contoh (jangan jalankan tanpa konfirmasi harga):
-- update public.jt_exams set price_idr = 9990 where id = '<UUID_PAKET>';
-- Biaya administrasi Checkout saat ini Rp1.500, bukan otomatis PPN.
