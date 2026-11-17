-- Lot F4 (2/3) : achats B2B (E5 « ABSENT », E6-7).
--   · identité de facturation de l'entreprise dans company_profiles (NIU, adresse, ville, e-mail de facturation ; la raison sociale et le RCCM existent déjà),
--     modifiable par le propriétaire, un administrateur ou la finance de l'équipe : company_billing_get / company_billing_set ;
--   · une commande passée au nom d'une entreprise est rattachée à elle (table order_billing, identité figée tant que la commande n'est pas payée) :
--       - automatiquement pour un compte Entreprise / Organisation qui a une fiche ;
--       - pour un membre administrateur ou finance (ou le propriétaire d'un compte administrateur) qui a choisi « acheter au nom de l'entreprise »
--         (company_billing_context_set) ;
--     le rattachement ne touche à aucun flux de paiement : un déclencheur après insertion, qui ne peut jamais faire échouer la commande ;
--   · order_billing_get(commande) : identité à porter sur la facture (« Facturé à ») pour l'acheteur et l'équipe finance ;
--   · company_orders_list : « Achats de l'entreprise » (propriétaire, administrateurs et finance seulement).
-- Retour arrière : drop trigger trg_orders_bill_company on orders ; drop function _orders_bill_company(), order_billing_get(text), company_orders_list(uuid, integer, integer),
--   company_billing_get(uuid), company_billing_set(jsonb, uuid), company_billing_context_set(uuid), company_billing_context_get(), _company_billing_snapshot(uuid) ;
--   drop table order_billing, company_billing_context ; alter table company_profiles drop column tax_id, billing_address, billing_city, billing_email.

alter table company_profiles add column if not exists tax_id text not null default '' check (char_length(tax_id) <= 40);
alter table company_profiles add column if not exists billing_address text not null default '' check (char_length(billing_address) <= 200);
alter table company_profiles add column if not exists billing_city text not null default '' check (char_length(billing_city) <= 80);
alter table company_profiles add column if not exists billing_email text not null default '' check (char_length(billing_email) <= 120);

create table if not exists company_billing_context (
  user_id uuid primary key references profiles(id) on delete cascade,
  owner_id uuid not null references company_profiles(owner_id) on delete cascade,
  updated_at timestamptz not null default now()
);
alter table company_billing_context enable row level security;
revoke all on company_billing_context from anon, authenticated;

create table if not exists order_billing (
  order_id uuid primary key references orders(id) on delete cascade,
  owner_id uuid not null references company_profiles(owner_id) on delete cascade,
  snapshot jsonb not null,
  created_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists order_billing_owner on order_billing (owner_id, created_at desc);
alter table order_billing enable row level security;
revoke all on order_billing from anon, authenticated;

-- Identité de facturation d'une entreprise : jamais le téléphone, l'interlocuteur ni les pièces.
create or replace function _company_billing_snapshot(p_owner uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('owner_id', c.owner_id, 'company_name', c.company_name, 'tax_id', c.tax_id, 'registration_number', c.registration_number,
      'address', c.billing_address, 'city', coalesce(nullif(c.billing_city, ''), c.city), 'email', coalesce(nullif(c.billing_email, ''), p.email, ''))
  from company_profiles c left join profiles p on p.id = c.owner_id where c.owner_id = p_owner
$$;
revoke all on function _company_billing_snapshot(uuid) from public, anon, authenticated;

create or replace function company_billing_get(p_owner uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_owner uuid := company_effective_owner(p_owner);
begin
  if company_role_of(v_owner) not in ('owner', 'admin', 'finance') then raise exception 'Réservé au propriétaire, aux administrateurs et à la finance de l''entreprise'; end if;
  if not exists (select 1 from company_profiles where owner_id = v_owner) then return null; end if;
  return _company_billing_snapshot(v_owner) || jsonb_build_object('my_role', company_role_of(v_owner));
end $$;

create or replace function company_billing_set(p jsonb, p_owner uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_owner uuid := company_effective_owner(p_owner); v_tax text := btrim(coalesce(p->>'tax_id', '')); v_addr text := btrim(coalesce(p->>'billing_address', ''));
        v_city text := btrim(coalesce(p->>'billing_city', '')); v_mail text := lower(btrim(coalesce(p->>'billing_email', '')));
begin
  if company_role_of(v_owner) not in ('owner', 'admin', 'finance') then raise exception 'Réservé au propriétaire, aux administrateurs et à la finance de l''entreprise'; end if;
  if not exists (select 1 from company_profiles where owner_id = v_owner) then raise exception 'Enregistrez d''abord la fiche de l''entreprise'; end if;
  if exists (select 1 from profiles where id = auth.uid() and coalesce(suspended, false)) then raise exception 'Votre compte est suspendu'; end if;
  if char_length(v_tax) > 40 or v_tax !~ '^[A-Za-z0-9 ./-]*$' then raise exception 'NIU invalide : 40 caractères au plus (lettres, chiffres, espaces, points, tirets)'; end if;
  if char_length(v_addr) > 200 then raise exception 'Adresse trop longue (200 caractères au plus)'; end if;
  if char_length(v_city) > 80 then raise exception 'Ville trop longue (80 caractères au plus)'; end if;
  if v_mail <> '' and (char_length(v_mail) > 120 or v_mail !~ '^[^@ ]+@[^@ ]+\.[^@ ]+$') then raise exception 'Adresse e-mail de facturation invalide'; end if;
  update company_profiles set tax_id = v_tax, billing_address = v_addr, billing_city = v_city, billing_email = v_mail, updated_at = now() where owner_id = v_owner;
  insert into audit_log (actor, action, target, category, level)
    values (coalesce((select name from profiles where id = auth.uid()), 'Entreprise'), 'Identité de facturation modifiée', v_owner::text, 'Entreprise', 'Info');
  return _company_billing_snapshot(v_owner);
end $$;

-- « Acheter au nom de l'entreprise » : choix d'un membre administrateur / finance (ou du propriétaire d'un compte administrateur) ; null = acheter pour soi.
create or replace function company_billing_context_set(p_owner uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_owner is null then
    delete from company_billing_context where user_id = auth.uid();
    return null;
  end if;
  if company_role_of(p_owner) is null or company_role_of(p_owner) not in ('owner', 'admin', 'finance') then
    raise exception 'Seuls le propriétaire, les administrateurs et la finance achètent au nom de l''entreprise';
  end if;
  if not exists (select 1 from company_profiles where owner_id = p_owner) then raise exception 'Cette entreprise n''a pas de fiche'; end if;
  insert into company_billing_context (user_id, owner_id) values (auth.uid(), p_owner)
    on conflict (user_id) do update set owner_id = excluded.owner_id, updated_at = now();
  return p_owner;
end $$;

-- Entreprise au nom de laquelle j'achète actuellement (null = moi) ; un rôle retiré depuis le choix annule le choix.
create or replace function company_billing_context_get() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_owner uuid; v_forced boolean := false;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select cp.owner_id into v_owner from company_profiles cp join profiles p on p.id = cp.owner_id where cp.owner_id = auth.uid() and p.role::text in ('company', 'other');
  if v_owner is not null then
    return jsonb_build_object('owner_id', v_owner, 'forced', true, 'company_name', (select company_name from company_profiles where owner_id = v_owner));
  end if;
  select x.owner_id into v_owner from company_billing_context x
    where x.user_id = auth.uid() and company_role_of(x.owner_id) in ('owner', 'admin', 'finance');
  if v_owner is null then return null; end if;
  return jsonb_build_object('owner_id', v_owner, 'forced', false, 'company_name', (select company_name from company_profiles where owner_id = v_owner));
end $$;

-- Rattachement automatique : n'échoue jamais (une commande ne doit pas être bloquée par la facturation).
create or replace function _orders_bill_company() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_owner uuid;
begin
  begin
    select cp.owner_id into v_owner from company_profiles cp join profiles p on p.id = cp.owner_id where cp.owner_id = new.buyer_id and p.role::text in ('company', 'other');
    if v_owner is null then
      select x.owner_id into v_owner from company_billing_context x
        where x.user_id = new.buyer_id
          and (x.owner_id = new.buyer_id or exists (select 1 from company_members m where m.owner_id = x.owner_id and m.user_id = new.buyer_id and m.status = 'active' and m.role in ('admin', 'finance')));
    end if;
    if v_owner is not null then
      insert into order_billing (order_id, owner_id, snapshot, created_by) values (new.id, v_owner, _company_billing_snapshot(v_owner), new.buyer_id) on conflict (order_id) do nothing;
    end if;
  exception when others then
    raise warning 'rattachement de facturation ignoré : %', sqlerrm;
  end;
  return null;
end $$;
revoke all on function _orders_bill_company() from public, anon, authenticated;
drop trigger if exists trg_orders_bill_company on orders;
create trigger trg_orders_bill_company after insert on orders for each row execute function _orders_bill_company();

-- Commandes déjà passées par un compte Entreprise / Organisation : rattachées à sa fiche (sans effet pour les autres comptes).
insert into order_billing (order_id, owner_id, snapshot, created_by)
  select o.id, cp.owner_id, _company_billing_snapshot(cp.owner_id), o.buyer_id
    from orders o join company_profiles cp on cp.owner_id = o.buyer_id join profiles p on p.id = cp.owner_id
   where p.role::text in ('company', 'other')
on conflict (order_id) do nothing;

-- Identité à porter sur la facture d'une commande : l'acheteur, ou le propriétaire / administrateur / finance de l'entreprise facturée. Figée une fois la commande payée.
create or replace function order_billing_get(p_number text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare o orders%rowtype; b order_billing%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into o from orders where number = p_number;
  if not found then return null; end if;
  select * into b from order_billing where order_id = o.id;
  if not found then return null; end if;
  if o.buyer_id is distinct from auth.uid() and coalesce(company_role_of(b.owner_id), '') not in ('owner', 'admin', 'finance') then return null; end if;
  if not o.paid and not o.cancelled and o.cancelled_at is null then
    update order_billing set snapshot = _company_billing_snapshot(b.owner_id) where order_id = o.id returning * into b;
  end if;
  return b.snapshot;
end $$;

-- Achats de l'entreprise : commandes rattachées à l'entreprise (comptes de l'équipe qui achètent en son nom), les plus récentes d'abord.
create or replace function company_orders_list(p_owner uuid default null, p_limit integer default 50, p_offset integer default 0) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_owner uuid := company_effective_owner(p_owner);
begin
  if company_role_of(v_owner) not in ('owner', 'admin', 'finance') then raise exception 'Réservé au propriétaire, aux administrateurs et à la finance de l''entreprise'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'number', x.number, 'invoice_number', 'FA-' || regexp_replace(x.number, '^#?(BE-)?', ''), 'created_at', x.created_at,
      'paid', x.paid, 'cancelled', x.cancelled or x.cancelled_at is not null, 'cod', x.cod,
      'state', case when x.cancelled or x.cancelled_at is not null then 'cancelled' when x.paid then 'paid' when x.cod then 'cod' else 'pending' end,
      'total', x.subtotal + x.fee, 'discount', x.discount, 'fee', x.fee, 'method', x.method,
      'buyer_name', display_name(x.buyer_id), 'by_me', x.buyer_id = auth.uid(),
      'items', coalesce((select jsonb_agg(jsonb_build_object('title', l.title, 'qty', l.qty, 'unit_price', l.unit_price) order by l.title) from order_lines l where l.order_id = x.id), '[]'::jsonb)
    ) order by x.created_at desc)
    from (select o.* from order_billing b join orders o on o.id = b.order_id where b.owner_id = v_owner
           order by o.created_at desc limit least(greatest(coalesce(p_limit, 50), 1), 100) offset greatest(coalesce(p_offset, 0), 0)) x
  ), '[]'::jsonb);
end $$;

revoke all on function company_billing_get(uuid), company_billing_set(jsonb, uuid), company_billing_context_set(uuid), company_billing_context_get(), order_billing_get(text), company_orders_list(uuid, integer, integer) from public, anon;
grant execute on function company_billing_get(uuid), company_billing_set(jsonb, uuid), company_billing_context_set(uuid), company_billing_context_get(), order_billing_get(text), company_orders_list(uuid, integer, integer) to authenticated;
