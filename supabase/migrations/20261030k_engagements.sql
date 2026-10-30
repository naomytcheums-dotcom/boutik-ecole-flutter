-- Engagements : inscriptions, candidatures, votes, alertes, suivis, préférences, consentements, demandes (export, suppression, contact).
-- Une table unique, des types autorisés explicitement, un enregistrement par personne et par cible. Aucune écriture directe.

create table if not exists engagements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  kind text not null check (kind in (
    'event_registration', 'application', 'preorder', 'vote', 'stock_alert', 'follow', 'portfolio_item', 'contact_request',
    'alert_prefs', 'channel_prefs', 'terms_accepted', 'data_export_request', 'account_deletion_request', 'internship_offer')),
  ref text not null check (char_length(ref) between 1 and 160),
  data jsonb not null default '{}'::jsonb check (pg_column_size(data) <= 4000),
  status text not null default 'active' check (status in ('active', 'cancelled', 'done')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, kind, ref)
);
alter table engagements enable row level security;
revoke all on engagements from anon, authenticated;
grant select on engagements to authenticated;
drop policy if exists "engagements : propriétaire et modération" on engagements;
create policy "engagements : propriétaire et modération" on engagements for select
  using (user_id = auth.uid() or current_role_name() in ('dept', 'admin', 'support'));

-- Enregistre (ou met à jour) un engagement. Les préférences et consentements sont mis à jour ; les autres types refusent le doublon.
create or replace function engage(p_kind text, p_ref text, p_data jsonb default '{}'::jsonb) returns text
language plpgsql security definer set search_path = public as $$
declare existing engagements%rowtype; updatable boolean;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from profiles where id = auth.uid()) then raise exception 'Complétez votre profil avant cette action'; end if;
  if p_kind not in ('event_registration', 'application', 'preorder', 'vote', 'stock_alert', 'follow', 'portfolio_item', 'contact_request',
                    'alert_prefs', 'channel_prefs', 'terms_accepted', 'data_export_request', 'account_deletion_request', 'internship_offer') then
    raise exception 'Action inconnue';
  end if;
  if p_ref is null or char_length(trim(p_ref)) = 0 then raise exception 'Cible manquante'; end if;
  updatable := p_kind in ('alert_prefs', 'channel_prefs', 'terms_accepted');
  select * into existing from engagements where user_id = auth.uid() and kind = p_kind and ref = left(trim(p_ref), 160);
  if found then
    if updatable then
      update engagements set data = coalesce(p_data, '{}'::jsonb), status = 'active', updated_at = now() where id = existing.id;
      return 'updated';
    end if;
    if existing.status = 'cancelled' then
      update engagements set status = 'active', data = coalesce(p_data, '{}'::jsonb), updated_at = now() where id = existing.id;
      return 'created';
    end if;
    raise exception 'Déjà enregistré';
  end if;
  insert into engagements (user_id, kind, ref, data) values (auth.uid(), p_kind, left(trim(p_ref), 160), coalesce(p_data, '{}'::jsonb));
  return 'created';
end $$;

-- Annule un engagement (désinscription, fin de suivi…). Les demandes d'export et de suppression ne s'annulent pas ici : elles sont traitées par l'équipe.
create or replace function cancel_engagement(p_kind text, p_ref text) returns text
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_kind in ('data_export_request', 'account_deletion_request', 'terms_accepted') then raise exception 'Cette action ne peut pas être annulée ici'; end if;
  update engagements set status = 'cancelled', updated_at = now() where user_id = auth.uid() and kind = p_kind and ref = p_ref and status = 'active';
  if not found then raise exception 'Aucun enregistrement à annuler'; end if;
  return 'cancelled';
end $$;

revoke all on function engage(text, text, jsonb), cancel_engagement(text, text) from public, anon;
grant execute on function engage(text, text, jsonb), cancel_engagement(text, text) to authenticated;
