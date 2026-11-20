-- MENUX: avaliações verificadas por pedido concluído.
-- Execute no SQL Editor do Supabase antes de habilitar a interface.
create table if not exists public.menux_store_reviews (
 id uuid primary key default gen_random_uuid(),
 restaurant_id uuid not null references public.restaurants(id) on delete cascade,
 order_id uuid not null unique references public.menux_checkout_orders(id) on delete cascade,
 rating integer not null check (rating between 1 and 5),
 comment text not null default '' check (char_length(comment)<=600),
 created_at timestamptz not null default now()
);
create index if not exists menux_store_reviews_restaurant_created_idx on public.menux_store_reviews(restaurant_id,created_at desc);
alter table public.menux_store_reviews enable row level security;
revoke all on public.menux_store_reviews from anon,authenticated;
grant select on public.menux_store_reviews to authenticated;
drop policy if exists menux_store_reviews_manager_read on public.menux_store_reviews;
create policy menux_store_reviews_manager_read on public.menux_store_reviews for select to authenticated
using (public.can_manage_restaurant(restaurant_id));
create or replace function public.menux_submit_store_review(p_order_id uuid,p_token text,p_rating integer,p_comment text default '')
returns jsonb language plpgsql security definer set search_path=public
as $$
declare v_order public.menux_checkout_orders%rowtype;v_comment text;
begin
 if p_rating is null or p_rating not between 1 and 5 then raise exception 'Selecione de 1 a 5 estrelas.';end if;
 v_comment:=trim(coalesce(p_comment,''));
 if char_length(v_comment)>600 then raise exception 'O comentário deve ter no máximo 600 caracteres.';end if;
 select * into v_order from public.menux_checkout_orders
 where id=p_order_id and tracking_token=p_token;
 if not found then raise exception 'Pedido não encontrado ou link inválido.';end if;
 if lower(coalesce(v_order.status,'')) not in ('completed','concluido','concluído','delivered') then
  raise exception 'A avaliação fica disponível após a conclusão do pedido.';
 end if;
 insert into public.menux_store_reviews(restaurant_id,order_id,rating,comment)
 values(v_order.restaurant_id,p_order_id,p_rating,v_comment)
 on conflict (order_id) do nothing;
 if not found then raise exception 'Este pedido já foi avaliado.';end if;
 return jsonb_build_object('ok',true);
end $$;
revoke all on function public.menux_submit_store_review(uuid,text,integer,text) from public;
grant execute on function public.menux_submit_store_review(uuid,text,integer,text) to anon,authenticated;
