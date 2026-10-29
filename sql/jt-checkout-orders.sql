-- Jenius Tryout: checkout manual, klaim gratis, bukti pembayaran, dan struk.
-- Jalankan setelah jt_vouchers, jt_exams.price_idr dan jt_enrollments tersedia.
create table if not exists public.jt_orders(
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id),
 exam_id uuid not null references public.jt_exams(id),
 voucher_id uuid references public.jt_vouchers(id),
 voucher_code text,
 subtotal integer not null check(subtotal>=0),
 discount integer not null default 0 check(discount>=0),
 admin_fee integer not null default 1500 check(admin_fee>=0),
 total integer not null check(total>=0),
 status text not null default 'pending' check(status in ('pending','awaiting_review','approved','rejected')),
 proof_path text,
 created_at timestamptz not null default now(),
 verified_at timestamptz,
 verified_by uuid references auth.users(id)
);
create index if not exists jt_orders_user_idx on public.jt_orders(user_id,created_at desc);
create index if not exists jt_orders_status_idx on public.jt_orders(status,created_at desc);
alter table public.jt_orders enable row level security;
drop policy if exists jt_orders_owner_read on public.jt_orders;
drop policy if exists jt_orders_admin_read on public.jt_orders;
create policy jt_orders_owner_read on public.jt_orders for select to authenticated using(user_id=auth.uid());
create policy jt_orders_admin_read on public.jt_orders for select to authenticated using((auth.jwt()->'app_metadata'->>'role') in ('admin','pengelola','administrator'));
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('jt-payment-proofs','jt-payment-proofs',false,5242880,array['image/jpeg','image/png','application/pdf'])
on conflict(id) do update set public=false,file_size_limit=5242880,allowed_mime_types=excluded.allowed_mime_types;
drop policy if exists jt_proof_upload on storage.objects;
drop policy if exists jt_proof_read on storage.objects;
create policy jt_proof_upload on storage.objects for insert to authenticated
with check(bucket_id='jt-payment-proofs' and (storage.foldername(name))[1]=auth.uid()::text);
create policy jt_proof_read on storage.objects for select to authenticated
using(bucket_id='jt-payment-proofs' and ((storage.foldername(name))[1]=auth.uid()::text or (auth.jwt()->'app_metadata'->>'role') in ('admin','pengelola','administrator')));
create or replace function public.jt_create_order(p_exam_id uuid,p_code text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare e record;v public.jt_vouchers%rowtype;o uuid;d integer:=0;fee integer:=1500;amt integer;uid uuid:=auth.uid();
begin
 if uid is null then raise exception 'Silakan login'; end if;
 select id,price_idr,is_published into e from public.jt_exams where id=p_exam_id for share;
 if not found or e.is_published is distinct from true or e.price_idr is null then raise exception 'Paket belum tersedia'; end if;
 v.id:=null; v.code:=null;
 if nullif(trim(p_code),'') is not null then
 select * into v from public.jt_vouchers where code=upper(trim(p_code)) for update;
 if not found or not v.is_active or (v.expires_at is not null and v.expires_at<=now()) or (v.max_uses is not null and v.used_count>=v.max_uses) then raise exception 'Voucher tidak valid atau kuota habis'; end if;
 d:=case when v.discount_type='free' then e.price_idr when v.discount_type='percent' then floor(e.price_idr*v.discount_value/100)::integer else least(e.price_idr,v.discount_value::integer) end;
 if v.discount_type='free' then fee:=0; end if;
 end if;
 amt:=greatest(0,e.price_idr-d)+fee;
 if amt=0 then
   if exists(select 1 from public.jt_enrollments where user_id=uid and exam_id=p_exam_id and status='active') then raise exception 'Paket sudah aktif'; end if;
   if v.id is null then raise exception 'Voucher gratis diperlukan'; end if;
   update public.jt_vouchers set used_count=used_count+1 where id=v.id;
 end if;
 insert into public.jt_orders(user_id,exam_id,voucher_id,voucher_code,subtotal,discount,admin_fee,total,status,verified_at)
 values(uid,p_exam_id,v.id,v.code,e.price_idr,d,fee,amt,case when amt=0 then 'approved' else 'pending' end,case when amt=0 then now() else null end) returning id into o;
 if amt=0 then
   insert into public.jt_enrollments(user_id,exam_id,status) values(uid,p_exam_id,'active')
   on conflict(user_id,exam_id) do update set status='active';
 end if;
 return o;
end $$;
revoke all on function public.jt_create_order(uuid,text) from public,anon;
grant execute on function public.jt_create_order(uuid,text) to authenticated;
create or replace function public.jt_submit_proof(p_order_id uuid,p_path text)
returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Silakan login'; end if;
 if not exists(select 1 from storage.objects where bucket_id='jt-payment-proofs' and name=p_path and (storage.foldername(name))[1]=auth.uid()::text) then raise exception 'Bukti transfer belum ditemukan'; end if;
 update public.jt_orders set proof_path=p_path,status='awaiting_review' where id=p_order_id and user_id=auth.uid() and status in ('pending','rejected') and total>0;
 if not found then raise exception 'Pesanan tidak dapat dikonfirmasi'; end if;
end $$;
revoke all on function public.jt_submit_proof(uuid,text) from public,anon;
grant execute on function public.jt_submit_proof(uuid,text) to authenticated;
create or replace function public.jt_review_order(p_order_id uuid,p_approve boolean)
returns void language plpgsql security definer set search_path='' as $$
declare o record;
begin
 if auth.uid() is null or (auth.jwt()->'app_metadata'->>'role') not in ('admin','pengelola','administrator') then raise exception 'Akses pengelola diperlukan'; end if;
 select * into o from public.jt_orders where id=p_order_id for update;
 if not found or o.status<>'awaiting_review' then raise exception 'Pesanan tidak menunggu verifikasi'; end if;
 if p_approve and o.voucher_id is not null then
   perform 1 from public.jt_vouchers where id=o.voucher_id for update;
   if not found then raise exception 'Voucher tidak ditemukan'; end if;
   update public.jt_vouchers set used_count=used_count+1 where id=o.voucher_id and (max_uses is null or used_count<max_uses) and is_active;
   if not found then raise exception 'Kuota voucher habis atau voucher nonaktif'; end if;
 end if;
 update public.jt_orders set status=case when p_approve then 'approved' else 'rejected' end,verified_at=now(),verified_by=auth.uid() where id=p_order_id;
 if p_approve then
 insert into public.jt_enrollments(user_id,exam_id,status) values(o.user_id,o.exam_id,'active')
 on conflict(user_id,exam_id) do update set status='active';
 end if;
end $$;
revoke all on function public.jt_review_order(uuid,boolean) from public,anon;
grant execute on function public.jt_review_order(uuid,boolean) to authenticated;
