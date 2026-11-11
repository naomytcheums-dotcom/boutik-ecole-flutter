-- Moyens de paiement du compte : numéros Mobile Money (Orange Money, MTN MoMo) et moyen par défaut.
-- Non destructif : une table et trois fonctions. Aucune donnée existante n'est modifiée.
-- Retour arrière : drop function save_payment_method(text, text, boolean), delete_payment_method(uuid), set_default_payment_method(uuid) ; drop table payment_methods ;

create table if not exists payment_methods (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles(id) on delete cascade,
  provider text not null check (provider in ('orange_money', 'mtn_momo')),
  phone text not null check (phone ~ '^6[0-9]{8}$'),
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  unique (owner_id, provider, phone)
);
create unique index if not exists payment_methods_one_default on payment_methods (owner_id) where is_default;
alter table payment_methods enable row level security;
revoke all on payment_methods from anon, authenticated;
grant select on payment_methods to authenticated;
drop policy if exists "moyens de paiement : les miens" on payment_methods;
create policy "moyens de paiement : les miens" on payment_methods for select to authenticated using (owner_id = auth.uid());

create or replace function save_payment_method(p_provider text, p_phone text, p_default boolean) returns uuid
language plpgsql security definer set search_path = public as $$
declare pid uuid; ph text := regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_provider not in ('orange_money', 'mtn_momo') then raise exception 'Moyen de paiement invalide'; end if;
  if left(ph, 3) = '237' and char_length(ph) = 12 then ph := substr(ph, 4); end if;
  if ph !~ '^6[0-9]{8}$' then raise exception 'Numéro invalide : 9 chiffres commençant par 6'; end if;
  if (select count(*) from payment_methods where owner_id = auth.uid()) >= 6 then raise exception '6 moyens de paiement au plus'; end if;
  if p_default or not exists (select 1 from payment_methods where owner_id = auth.uid()) then
    update payment_methods set is_default = false where owner_id = auth.uid();
    p_default := true;
  end if;
  insert into payment_methods (owner_id, provider, phone, is_default) values (auth.uid(), p_provider, ph, coalesce(p_default, false))
  on conflict (owner_id, provider, phone) do update set is_default = excluded.is_default or payment_methods.is_default
  returning id into pid;
  return pid;
end $$;

create or replace function set_default_payment_method(p_id uuid) returns text
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from payment_methods where id = p_id and owner_id = auth.uid()) then raise exception 'Moyen de paiement introuvable'; end if;
  update payment_methods set is_default = (id = p_id) where owner_id = auth.uid();
  return 'défini';
end $$;

create or replace function delete_payment_method(p_id uuid) returns text
language plpgsql security definer set search_path = public as $$
declare was_default boolean;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  delete from payment_methods where id = p_id and owner_id = auth.uid() returning is_default into was_default;
  if not found then raise exception 'Moyen de paiement introuvable'; end if;
  if was_default then
    update payment_methods set is_default = true where id = (select id from payment_methods where owner_id = auth.uid() order by created_at limit 1);
  end if;
  return 'supprimé';
end $$;

revoke all on function save_payment_method(text, text, boolean), set_default_payment_method(uuid), delete_payment_method(uuid) from public, anon;
grant execute on function save_payment_method(text, text, boolean), set_default_payment_method(uuid), delete_payment_method(uuid) to authenticated;
