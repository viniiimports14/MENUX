-- MENUX: link público do Instagram por estabelecimento
-- Execute uma única vez no SQL Editor do Supabase.
alter table public.storefront_settings
  add column if not exists instagram text;

create or replace function public.menux_public_store_instagram(p_slug text)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select ss.instagram
  from public.restaurants r
  join public.storefront_settings ss on ss.restaurant_id = r.id
  where r.slug = p_slug
  limit 1
$$;

revoke all on function public.menux_public_store_instagram(text) from public;
grant execute on function public.menux_public_store_instagram(text) to anon, authenticated;
