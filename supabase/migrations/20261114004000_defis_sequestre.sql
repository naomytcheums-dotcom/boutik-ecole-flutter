-- Défis et concours sponsorisés avec séquestre : la récompense en argent promise par une entreprise est payée À L'AVANCE (Mobile Money, Tara Money)
-- et conservée par Boutik-École. Une annonce avec récompense ne peut pas être publiée tant que la somme n'est pas en séquestre.
-- Le sponsor désigne le gagnant ; la somme revient alors EN ENTIER au gagnant (aucune commission prélevée sur la récompense) mais n'est versée
-- qu'après déblocage par l'administrateur (écran Séquestre existant). Sans gagnant, l'administrateur rembourse le sponsor.
-- Retour arrière : drop trigger trg_prize_paid on payment_transactions, trg_ann_prize_gate on contest_announcements ; drop function ann_prize_*, on_prize_paid(), ann_prize_gate() ;
--   alter table contest_announcements drop column prize_amount, prize_status, prize_entry, prize_winner ; recréer _ann_card depuis 20261114001400.

alter table contest_announcements add column if not exists prize_amount integer not null default 0 check (prize_amount between 0 and 100000000);
alter table contest_announcements add column if not exists prize_status text not null default 'none' check (prize_status in ('none', 'awaiting', 'held', 'awarded', 'refunded'));
alter table contest_announcements add column if not exists prize_entry uuid references money_entries(id) on delete set null;
alter table contest_announcements add column if not exists prize_winner uuid references profiles(id) on delete set null;

-- La carte d'annonce gagne le montant, l'état du séquestre et le nom du gagnant.
create or replace function _ann_card(a contest_announcements, p_user uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', a.id, 'title', a.title, 'organizer', a.organizer, 'organizer_kind', a.organizer_kind, 'country', a.country, 'place_kind', a.place_kind, 'place', a.place, 'domain', a.domain, 'kind', a.kind,
    'deadline', a.deadline, 'reward', a.reward, 'eligible_level', a.eligible_level, 'eligible_age', a.eligible_age, 'eligible_department', a.eligible_department, 'eligible_country', a.eligible_country, 'iut_only', a.iut_only,
    'free', a.free, 'cost_amount', a.cost_amount, 'cost_currency', a.cost_currency, 'verified', a.verified, 'status', a.status, 'created_at', a.created_at,
    'prize_amount', a.prize_amount, 'prize_status', a.prize_status,
    'prize_winner_name', case when a.prize_status = 'awarded' then display_name(a.prize_winner) else null end,
    'popular', (select count(*) from contest_ann_saves s where s.announcement_id = a.id) >= 5 or a.views >= 100,
    'saved', exists (select 1 from contest_ann_saves s where s.announcement_id = a.id and s.user_id = p_user))
$$;
revoke all on function _ann_card(contest_announcements, uuid) from public, anon, authenticated;

-- Garde-fou : pas de publication d'une annonce avec récompense tant que la somme n'est pas en séquestre.
create or replace function ann_prize_gate() returns trigger
language plpgsql as $$
begin
  if new.status = 'published' and old.status is distinct from 'published' and new.prize_amount > 0 and new.prize_status not in ('held', 'awarded') then
    raise exception 'La récompense de % FCFA doit d''abord être payée et mise sous séquestre par l''organisateur', new.prize_amount;
  end if;
  return new;
end $$;
drop trigger if exists trg_ann_prize_gate on contest_announcements;
create trigger trg_ann_prize_gate before update of status on contest_announcements for each row execute function ann_prize_gate();

-- L'organisateur fixe (ou retire, avec 0) la récompense en argent, tant que l'annonce n'est pas publiée.
create or replace function ann_prize_set(p_ann uuid, p_amount integer) returns text
language plpgsql security definer set search_path = public as $$
declare a contest_announcements%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into a from contest_announcements where id = p_ann and poster_id = auth.uid();
  if not found then raise exception 'Annonce introuvable'; end if;
  if a.status not in ('pending', 'rejected') then raise exception 'La récompense se fixe avant la publication'; end if;
  if a.prize_status in ('held', 'awarded') then raise exception 'La récompense est déjà sous séquestre'; end if;
  if p_amount is null or p_amount < 0 or p_amount > 100000000 then raise exception 'Montant invalide'; end if;
  if p_amount > 0 and p_amount < 1000 then raise exception 'La récompense est d''au moins 1 000 FCFA'; end if;
  update contest_announcements set prize_amount = p_amount, prize_status = case when p_amount > 0 then 'awaiting' else 'none' end where id = p_ann;
  return case when p_amount > 0 then 'awaiting' else 'none' end;
end $$;

-- Démarre le paiement de la récompense : transaction Tara Money dont le montant vient de la base.
create or replace function ann_prize_checkout(p_ann uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare a contest_announcements%rowtype; v_id uuid; v_ref text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into a from contest_announcements where id = p_ann and poster_id = auth.uid();
  if not found then raise exception 'Annonce introuvable'; end if;
  if a.prize_status <> 'awaiting' or a.prize_amount <= 0 then raise exception 'Aucune récompense à payer pour cette annonce'; end if;
  v_id := payment_start('event', 'prize:' || a.id, a.prize_amount, 'tara');
  select reference into v_ref from payment_transactions where id = v_id;
  return jsonb_build_object('id', v_id, 'reference', v_ref, 'amount', a.prize_amount, 'title', a.title);
end $$;

-- Paiement confirmé par le fournisseur -> récompense mise sous séquestre (une seule fois ; le montant doit couvrir la récompense).
create or replace function on_prize_paid() returns trigger
language plpgsql security definer set search_path = public as $$
declare a contest_announcements%rowtype; v_entry uuid;
begin
  if new.status = 'confirmed' and old.status is distinct from 'confirmed' and new.kind = 'event' and new.subject like 'prize:%' then
    select * into a from contest_announcements where id::text = substr(new.subject, 7);
    if found and a.prize_status = 'awaiting' and a.poster_id = new.payer_id and new.amount >= a.prize_amount then
      insert into money_entries (kind, ref, payer_id, beneficiary_id, gross, platform_amount, split, status)
      values ('event', new.reference, new.payer_id, null, new.amount, new.amount, 'séquestre défi', 'held') returning id into v_entry;
      update contest_announcements set prize_status = 'held', prize_entry = v_entry where id = a.id;
      insert into notifications (user_id, kind, title, body, data)
        values (a.poster_id, 'contest_prize', 'Récompense sous séquestre', a.prize_amount || ' FCFA sont conservés par Boutik-École pour « ' || a.title || ' ». L''annonce peut maintenant être validée.', jsonb_build_object('announcement', a.id));
    end if;
  end if;
  return null;
end $$;
drop trigger if exists trg_prize_paid on payment_transactions;
create trigger trg_prize_paid after update of status on payment_transactions for each row execute function on_prize_paid();

-- Le sponsor désigne le gagnant (compte étudiant, par e-mail). La somme lui est réservée en entier ; l'administrateur la débloque.
create or replace function ann_prize_award(p_ann uuid, p_winner_email text) returns text
language plpgsql security definer set search_path = public as $$
declare a contest_announcements%rowtype; w profiles%rowtype; e money_entries%rowtype; r record;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into a from contest_announcements where id = p_ann and poster_id = auth.uid();
  if not found then raise exception 'Annonce introuvable'; end if;
  if a.prize_status <> 'held' then raise exception 'Aucune récompense en séquestre à attribuer'; end if;
  select * into w from profiles where lower(email) = lower(btrim(coalesce(p_winner_email, ''))) and role = 'student' and not suspended;
  if not found then raise exception 'Aucun compte étudiant avec cette adresse e-mail'; end if;
  if w.id = a.poster_id then raise exception 'Vous ne pouvez pas vous attribuer la récompense'; end if;
  select * into e from money_entries where id = a.prize_entry for update;
  if not found or e.status <> 'held' then raise exception 'Le séquestre de cette récompense n''est plus disponible'; end if;
  update money_entries set beneficiary_id = w.id, beneficiary_amount = a.prize_amount, platform_amount = e.gross - a.prize_amount, split = 'défi : 100 % au gagnant' where id = e.id;
  update contest_announcements set prize_status = 'awarded', prize_winner = w.id where id = a.id;
  perform notify_user(w.id, 'contest_prize', 'Récompense attribuée', 'Bravo ! ' || a.organizer || ' vous attribue ' || a.prize_amount || ' FCFA pour « ' || a.title || ' ». L''équipe Boutik-École la débloque sur votre solde.', jsonb_build_object('announcement', a.id));
  for r in select id from profiles where role = 'admin' and not suspended limit 20 loop
    perform notify_user(r.id, 'contest_prize', 'Récompense à débloquer', a.prize_amount || ' FCFA pour « ' || a.title || ' » : le gagnant est désigné, à débloquer dans Séquestre.', jsonb_build_object('announcement', a.id, 'entry', e.id));
  end loop;
  return 'awarded';
end $$;

-- Sans gagnant : l'administrateur marque la somme remboursée au sponsor (le remboursement Mobile Money se fait hors de l'application).
create or replace function ann_prize_refund(p_ann uuid, p_note text default '') returns text
language plpgsql security definer set search_path = public as $$
declare a contest_announcements%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  select * into a from contest_announcements where id = p_ann;
  if not found then raise exception 'Annonce introuvable'; end if;
  if a.prize_status <> 'held' then raise exception 'Seule une récompense sans gagnant peut être remboursée'; end if;
  update money_entries set status = 'refunded', frozen_reason = nullif(left(btrim(coalesce(p_note, '')), 300), '') where id = a.prize_entry and status = 'held';
  if not found then raise exception 'Séquestre introuvable'; end if;
  update contest_announcements set prize_status = 'refunded' where id = a.id;
  perform notify_user(a.poster_id, 'contest_prize', 'Récompense remboursée', a.prize_amount || ' FCFA vous sont remboursés pour « ' || a.title || ' » (aucun gagnant désigné).', jsonb_build_object('announcement', a.id));
  return 'refunded';
end $$;

revoke all on function ann_prize_gate(), on_prize_paid() from public, anon, authenticated;
revoke all on function ann_prize_set(uuid, integer), ann_prize_checkout(uuid), ann_prize_award(uuid, text), ann_prize_refund(uuid, text) from public, anon;
grant execute on function ann_prize_set(uuid, integer), ann_prize_checkout(uuid), ann_prize_award(uuid, text), ann_prize_refund(uuid, text) to authenticated;
