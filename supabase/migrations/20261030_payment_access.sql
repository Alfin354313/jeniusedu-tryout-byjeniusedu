begin;
-- Prerequisite: shared Tryout schema, panel integration and existing checkout SQL.
-- Support both the original amount_idr schema and the checkout total/status schema.
alter table public.jt_orders add column if not exists amount_idr bigint;
alter table public.jt_orders add column if not exists total integer;
alter table public.jt_orders add column if not exists paid_at timestamptz;
alter table public.jt_orders add column if not exists voucher_id uuid;
alter table public.jt_orders add column if not exists proof_path text;
alter table public.jt_orders add column if not exists verified_at timestamptz;
alter table public.jt_orders add column if not exists verified_by uuid references auth.users(id);
update public.jt_orders set amount_idr=coalesce(total,amount_idr),total=coalesce(total,amount_idr) where amount_idr is null or total is null;
do $$ declare c record;begin
 for c in select conname from pg_constraint where conrelid='public.jt_orders'::regclass and contype='c' and pg_get_constraintdef(oid) ~ '\mstatus\M' loop
  execute format('alter table public.jt_orders drop constraint %I',c.conname);
 end loop;
end $$;
alter table public.jt_orders add constraint jt_orders_payment_status check(status in ('pending','awaiting_review','approved','rejected','paid','expired','cancelled','refunded'));
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
 if TG_OP='UPDATE' and old.status in ('paid','approved') and (new.user_id is distinct from old.user_id or new.exam_id is distinct from old.exam_id or new.amount_idr is distinct from old.amount_idr or new.total is distinct from old.total) then
  raise exception 'Identitas transaksi lunas tidak dapat diubah.';
 end if;
 new.amount_idr=coalesce(new.total,new.amount_idr);
 new.total=coalesce(new.total,new.amount_idr);
 if new.status in ('paid','approved') and (TG_OP='INSERT' or old.status not in ('paid','approved')) then
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

-- Harden the existing checkout review RPC, including missing-role JWTs and retries.
create or replace function public.jt_review_order(p_order_id uuid,p_approve boolean)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare o record;
begin
 if auth.uid() is null or not public.jt_is_admin() then raise exception 'Akses Pengelola diperlukan.';end if;
 if p_approve is null then raise exception 'Keputusan verifikasi diperlukan.';end if;
 select * into o from public.jt_orders where id=p_order_id for update;
 if not found then raise exception 'Transaksi tidak ditemukan.';end if;
 if p_approve and o.status in ('approved','paid') then return;end if;
 if o.status<>'awaiting_review' then raise exception 'Pesanan tidak menunggu verifikasi';end if;
 if p_approve and o.voucher_id is not null then
  perform 1 from public.jt_vouchers where id=o.voucher_id for update;
  if not found then raise exception 'Voucher tidak ditemukan';end if;
  update public.jt_vouchers set used_count=used_count+1 where id=o.voucher_id and (max_uses is null or used_count<max_uses) and is_active;
  if not found then raise exception 'Kuota voucher habis atau voucher nonaktif';end if;
 end if;
 update public.jt_orders set status=case when p_approve then 'approved' else 'rejected' end,verified_at=now(),verified_by=auth.uid() where id=o.id;
end $$;
revoke all on function public.jt_review_order(uuid,boolean) from public,anon;
grant execute on function public.jt_review_order(uuid,boolean) to authenticated;

create or replace function public.jt_admin_confirm_payment(p_order_id uuid,p_reference text) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare o public.jt_orders;
begin
 if auth.uid() is null or not public.jt_is_admin() then raise exception 'Akses Pengelola diperlukan.';end if;
 if char_length(trim(coalesce(p_reference,''))) not between 3 and 160 then raise exception 'Isi referensi bukti pembayaran (3–160 karakter).';end if;
 select * into o from public.jt_orders where id=p_order_id for update;
 if not found then raise exception 'Transaksi tidak ditemukan.';end if;
 if o.status in ('paid','approved') then return jsonb_build_object('id',o.id,'status',o.status);end if;
 if o.status not in ('pending','awaiting_review') then raise exception 'Hanya transaksi menunggu pembayaran yang dapat dikonfirmasi.';end if;
 if o.exam_id is null then raise exception 'Transaksi belum terhubung ke paket.';end if;
 insert into public.jt_payment_confirmations(order_id,confirmed_by,reference) values(o.id,auth.uid(),trim(p_reference));
 if o.status='awaiting_review' then
  -- Preserve the checkout's locked voucher quota accounting and proof verification workflow.
  perform public.jt_review_order(o.id,true);
 else
  if o.voucher_id is not null then raise exception 'Unggah bukti melalui struk sebelum memverifikasi transaksi voucher.';end if;
  update public.jt_orders set status='paid',paid_at=now(),verified_at=now(),verified_by=auth.uid() where id=o.id;
 end if;
 return jsonb_build_object('id',o.id,'status','paid');
end $$;
revoke all on function public.jt_admin_confirm_payment(uuid,text) from public,anon;
grant execute on function public.jt_admin_confirm_payment(uuid,text) to authenticated;
-- Repair previously paid transactions without changing pending/cancelled transactions or exam publication.
insert into public.jt_enrollments(user_id,exam_id,status)
 select distinct user_id,exam_id,'active' from public.jt_orders where status in ('paid','approved') and exam_id is not null
 on conflict(user_id,exam_id) do update set status='active';
notify pgrst,'reload schema';
commit;
