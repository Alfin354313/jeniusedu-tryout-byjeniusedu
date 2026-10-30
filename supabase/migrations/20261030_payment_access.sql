begin;
-- Prerequisite: shared Tryout schema and panel integration. Run once in the shared Supabase project.
create table if not exists public.jt_payment_confirmations (
 order_id uuid primary key references public.jt_orders(id),
 confirmed_by uuid not null references auth.users(id),
 reference text not null check(char_length(reference) between 3 and 160),
 confirmed_at timestamptz not null default now()
);
alter table public.jt_payment_confirmations enable row level security;
revoke all on public.jt_payment_confirmations from anon,authenticated;
grant select on public.jt_payment_confirmations to authenticated;
drop policy if exists jt_payment_confirmations_admin on public.jt_payment_confirmations;
create policy jt_payment_confirmations_admin on public.jt_payment_confirmations for select to authenticated using(public.jt_is_admin());

-- Both admin confirmation and a future trusted payment webhook use the same transaction.
create or replace function public.jt_grant_paid_access() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if TG_OP='UPDATE' and old.status='paid' and (new.user_id is distinct from old.user_id or new.exam_id is distinct from old.exam_id or new.amount_idr is distinct from old.amount_idr) then
  raise exception 'Identitas transaksi lunas tidak dapat diubah.';
 end if;
 if new.status='paid' and (TG_OP='INSERT' or old.status is distinct from 'paid') then
  if new.exam_id is null then raise exception 'Transaksi belum terhubung ke paket.';end if;
  insert into public.jt_enrollments(user_id,exam_id,status) values(new.user_id,new.exam_id,'active')
   on conflict(user_id,exam_id) do update set status='active';
  new.paid_at=coalesce(new.paid_at,now());
 end if;
 return new;
end $$;
revoke all on function public.jt_grant_paid_access() from public,anon,authenticated;
drop trigger if exists jt_order_paid_access on public.jt_orders;
create trigger jt_order_paid_access before insert or update on public.jt_orders for each row execute function public.jt_grant_paid_access();

create or replace function public.jt_request_order(p_exam_id uuid) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare uid uuid:=auth.uid();e public.jt_exams; c text; o public.jt_orders; price bigint;
begin
 if uid is null then raise exception 'Silakan masuk terlebih dahulu.';end if;
 perform pg_advisory_xact_lock(hashtextextended(uid::text||p_exam_id::text,0));
 select * into e from public.jt_exams where id=p_exam_id and is_published for share;
 if not found then raise exception 'Paket belum diterbitkan.';end if;
 if e.ends_at is not null and e.ends_at<=now() then raise exception 'Jadwal paket sudah berakhir.';end if;
 if not exists(select 1 from public.jt_questions where exam_id=e.id) then raise exception 'Soal paket belum tersedia.';end if;
 if exists(select 1 from public.jt_enrollments where user_id=uid and exam_id=e.id and status='active') then return jsonb_build_object('active',true,'exam_id',e.id);end if;
 select regexp_replace(lower(slug),'[^a-z0-9]','','g') into c from public.jt_categories where id=e.category_id;
 if c not in ('sd','smp','sma','utbksnbt','cpns','sekolahkedinasan','mtsnman','paketbundling') then raise exception 'Kategori belum tersedia untuk pembelian.';end if;
 -- Match existing public catalogue prices. Amount is never accepted from the browser.
 price=case when c='paketbundling' then 69990 else 9990 end;
 select * into o from public.jt_orders where user_id=uid and exam_id=e.id and status in ('pending','paid') order by created_at desc limit 1;
 if not found then
  insert into public.jt_orders(user_id,exam_id,amount_idr,status) values(uid,e.id,price,'pending') returning * into o;
 end if;
 return jsonb_build_object('id',o.id,'exam_id',o.exam_id,'amount_idr',o.amount_idr,'status',o.status,'active',false);
end $$;
revoke all on function public.jt_request_order(uuid) from public,anon;
grant execute on function public.jt_request_order(uuid) to authenticated;

create or replace function public.jt_admin_confirm_payment(p_order_id uuid,p_reference text) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare o public.jt_orders;
begin
 if auth.uid() is null or not public.jt_is_admin() then raise exception 'Akses Pengelola diperlukan.';end if;
 if char_length(trim(coalesce(p_reference,''))) not between 3 and 160 then raise exception 'Isi referensi bukti pembayaran (3–160 karakter).';end if;
 select * into o from public.jt_orders where id=p_order_id for update;
 if not found then raise exception 'Transaksi tidak ditemukan.';end if;
 if o.status='paid' then return jsonb_build_object('id',o.id,'status','paid');end if;
 if o.status<>'pending' then raise exception 'Hanya transaksi menunggu pembayaran yang dapat dikonfirmasi.';end if;
 if o.exam_id is null then raise exception 'Transaksi belum terhubung ke paket.';end if;
 insert into public.jt_payment_confirmations(order_id,confirmed_by,reference) values(o.id,auth.uid(),trim(p_reference));
 update public.jt_orders set status='paid',paid_at=now() where id=o.id;
 return jsonb_build_object('id',o.id,'status','paid');
end $$;
revoke all on function public.jt_admin_confirm_payment(uuid,text) from public,anon;
grant execute on function public.jt_admin_confirm_payment(uuid,text) to authenticated;
-- Repair previously paid transactions without changing pending/cancelled transactions or exam publication.
insert into public.jt_enrollments(user_id,exam_id,status)
 select distinct user_id,exam_id,'active' from public.jt_orders where status='paid' and exam_id is not null
 on conflict(user_id,exam_id) do update set status='active';
notify pgrst,'reload schema';
commit;
