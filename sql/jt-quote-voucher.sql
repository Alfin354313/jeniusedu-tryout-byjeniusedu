-- Validasi voucher Checkout. Hanya mengutip harga, tidak memakai kuota atau mengaktifkan paket.
-- Eksekusi di Supabase SQL Editor sesudah tabel jt_vouchers dan kolom jt_exams.price_idr tersedia.
create or replace function public.jt_quote_voucher(p_exam_id uuid, p_code text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare e record; v record; cut_amount integer; base_amount integer;
begin
 if auth.uid() is null then raise exception 'Silakan login terlebih dahulu'; end if;
 select id, price_idr, is_published into e from public.jt_exams where id=p_exam_id;
 if not found or e.is_published is distinct from true or e.price_idr is null then raise exception 'Paket atau harga tidak tersedia'; end if;
 select id,code,discount_type,discount_value,max_uses,used_count,expires_at,is_active
 into v from public.jt_vouchers where code=upper(trim(p_code)) limit 1;
 if not found or v.is_active is distinct from true or (v.expires_at is not null and v.expires_at <= now())
    or (v.max_uses is not null and v.used_count >= v.max_uses) then
    raise exception 'Voucher tidak tersedia, kedaluwarsa, atau kuota habis';
 end if;
 base_amount:=e.price_idr;
 cut_amount:=case when v.discount_type='free' then base_amount
 when v.discount_type='percent' then floor(base_amount * v.discount_value / 100)::integer
 else least(base_amount,v.discount_value::integer) end;
 return jsonb_build_object('code',v.code,'subtotal',base_amount,'discount',cut_amount,
 'admin_fee',case when v.discount_type='free' then 0 else 1500 end,'total',greatest(0,base_amount-cut_amount)+case when v.discount_type='free' then 0 else 1500 end,
 'requires_payment',greatest(0,base_amount-cut_amount)+case when v.discount_type='free' then 0 else 1500 end>0,
 'note','Estimasi saja. Voucher belum digunakan dan kuota belum berkurang.');
end $$;
revoke all on function public.jt_quote_voucher(uuid,text) from public,anon;
grant execute on function public.jt_quote_voucher(uuid,text) to authenticated;
