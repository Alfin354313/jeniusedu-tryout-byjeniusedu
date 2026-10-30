begin;
alter table public.jt_categories add column if not exists price_idr integer;
alter table public.jt_exams add column if not exists price_idr integer;
alter table public.jt_categories drop constraint if exists jt_category_price_valid;
alter table public.jt_categories add constraint jt_category_price_valid check(price_idr between 0 and 100000000);
alter table public.jt_exams drop constraint if exists jt_exams_price_idr_nonnegative;
alter table public.jt_exams add constraint jt_exams_price_idr_nonnegative check(price_idr>=0);
-- Preserve existing package prices: initialize a category only if all its known prices agree.
with uniform_prices as (
 select category_id,min(price_idr) price from public.jt_exams where price_idr is not null group by category_id having count(distinct price_idr)=1
) update public.jt_categories c set price_idr=u.price from uniform_prices u where c.id=u.category_id and c.price_idr is null and u.price between 0 and 100000000;

create or replace function public.jt_apply_category_price() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if new.price_idr is not null and new.price_idr is distinct from old.price_idr then
  update public.jt_exams set price_idr=new.price_idr where category_id=new.id and price_idr is distinct from new.price_idr;
 end if;
 return new;
end $$;
revoke all on function public.jt_apply_category_price() from public,anon,authenticated;
drop trigger if exists jt_category_price_changed on public.jt_categories;
create trigger jt_category_price_changed after update of price_idr on public.jt_categories for each row execute function public.jt_apply_category_price();

create or replace function public.jt_inherit_category_price() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
declare category_price integer;
begin
 select price_idr into category_price from public.jt_categories where id=new.category_id for share;
 if category_price is not null then new.price_idr=category_price;end if;
 return new;
end $$;
revoke all on function public.jt_inherit_category_price() from public,anon,authenticated;
drop trigger if exists jt_exam_category_price on public.jt_exams;
create trigger jt_exam_category_price before insert or update of category_id,price_idr on public.jt_exams for each row execute function public.jt_inherit_category_price();
-- Align existing packages to categories already configured; never touches orders.
update public.jt_exams e set price_idr=c.price_idr from public.jt_categories c where e.category_id=c.id and c.price_idr is not null and e.price_idr is distinct from c.price_idr;

create or replace function public.jt_admin_set_category_price(p_category_id uuid,p_price_idr integer) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare c public.jt_categories;
begin
 if auth.uid() is null or not public.jt_is_admin() then raise exception 'Akses Pengelola diperlukan.';end if;
 if p_price_idr is null or p_price_idr<0 or p_price_idr>100000000 then raise exception 'Harga harus rupiah bulat antara 0 dan 100.000.000.';end if;
 select * into c from public.jt_categories where id=p_category_id for update;
 if not found then raise exception 'Kategori tidak ditemukan.';end if;
 if regexp_replace(lower(c.slug),'[^a-z0-9]','','g') not in ('sd','smp','sma','utbksnbt','cpns','sekolahkedinasan','mtsnman','paketbundling')
  and regexp_replace(lower(c.title),'[^a-z0-9]','','g') not in ('sd','smp','sma','utbksnbt','cpns','sekolahkedinasan','mtsnman','paketbundling') then raise exception 'Pilih salah satu dari delapan kategori Tryout.';end if;
 update public.jt_categories set price_idr=p_price_idr where id=c.id;
 return jsonb_build_object('id',c.id,'price_idr',p_price_idr,'packages',(select count(*) from public.jt_exams where category_id=c.id));
end $$;
revoke all on function public.jt_admin_set_category_price(uuid,integer) from public,anon;
grant execute on function public.jt_admin_set_category_price(uuid,integer) to authenticated;
notify pgrst,'reload schema';
commit;
