-- Lot S6 (3/4) : vœux et précommandes (S6-42, S6-43, S6-47) + lectures de vœux par RPC (sans lire la table wishes en direct).
--  1. fin de campagne : wish_close_expired() prévient le créateur et les précommandeurs (seuil atteint ou non) ; elle est appelée aussi à l'ouverture
--     de la liste des précommandeurs, et peut être planifiée par le chef (pg_cron, par exemple toutes les heures) ;
--  2. le créateur d'un vœu voit qui a précommandé (prénom et initiale, jamais de coordonnées) et peut leur écrire UNE notification par envoi
--     une fois le seuil atteint : jamais de lien, 3 envois par vœu et par semaine, pas de destinataire qui l'a bloqué ou qu'il a bloqué ;
--  3. my_wish_preorders : « Mes précommandes » garde les campagnes échues ;
--  4. my_wishes, wish_draft_get, wishes_to_review : lectures réservées à l'auteur ou au département ;
--  5. withdraw_wish : l'auteur retire un vœu envoyé par erreur (retour au brouillon).
-- Retour arrière : voir le bas du fichier.

create table if not exists wish_closures (
  wish_id uuid primary key references wishes(id) on delete cascade,
  closed_at timestamptz not null default now(),
  preorders integer not null default 0,
  reached boolean not null default false
);
create table if not exists wish_contacts (
  id uuid primary key default gen_random_uuid(),
  wish_id uuid not null references wishes(id) on delete cascade,
  sender_id uuid not null references profiles(id) on delete cascade,
  body text not null check (char_length(body) between 10 and 500),
  recipients integer not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists wish_contacts_wish on wish_contacts (wish_id, created_at desc);
alter table wish_closures enable row level security;
alter table wish_contacts enable row level security;
revoke all on wish_closures, wish_contacts from anon, authenticated;

-- Clôture des campagnes échues : une seule fois par vœu ; notifie le créateur puis chaque précommandeur.
create or replace function wish_close_expired() returns integer
language plpgsql security definer set search_path = public as $$
declare w record; n integer; r boolean; done integer := 0;
begin
  for w in
    select x.* from wishes x
    where _wish_is_open(x.status, x.publish_at) and x.opened_at is not null and x.duration_days is not null
      and x.opened_at + make_interval(days => x.duration_days) <= now()
      and not exists (select 1 from wish_closures c where c.wish_id = x.id)
    order by x.opened_at limit 200
  loop
    select count(*)::int into n from wish_preorders where wish_id = w.id;
    r := w.threshold is not null and n >= w.threshold;
    insert into wish_closures (wish_id, preorders, reached) values (w.id, n, r) on conflict do nothing;
    if not found then continue; end if;
    insert into notifications (user_id, kind, title, body, data)
    values (w.author_id, 'wish', 'Campagne de précommandes terminée',
      left('« ' || w.title || ' » : ' || n || ' précommande(s)' || case when r then ' : le seuil est atteint. Ouvrez la fiche pour écrire aux précommandeurs.' else ', seuil non atteint : aucune fabrication n''est engagée.' end, 500),
      jsonb_build_object('wish_id', w.id, 'count', n, 'reached', r));
    insert into notifications (user_id, kind, title, body, data)
    select p.user_id, 'wish', 'Campagne de précommandes terminée',
      left('« ' || w.title || ' » : ' || case when r then 'le seuil est atteint. Le créateur décide de lancer la fabrication et peut vous écrire ; aucun paiement n''a été demandé.' else 'le seuil n''a pas été atteint, rien ne sera fabriqué et aucun paiement n''a été demandé.' end, 500),
      jsonb_build_object('wish_id', w.id, 'reached', r)
    from wish_preorders p where p.wish_id = w.id and p.user_id <> w.author_id;
    done := done + 1;
  end loop;
  return done;
end $$;

-- Précommandeurs d'un vœu : réservé à l'auteur et au département ; prénom et initiale seulement.
create or replace function wish_preorderers(p_wish uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); w wishes%rowtype; n integer; r boolean; v_ended boolean;
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  select * into w from wishes where id = p_wish;
  if not found or not (w.author_id = uid or coalesce(current_role_name()::text, '') in ('dept', 'admin')) then raise exception 'Réservé au créateur du vœu'; end if;
  perform wish_close_expired();
  select count(*)::int into n from wish_preorders where wish_id = w.id;
  r := w.threshold is not null and n >= w.threshold;
  v_ended := w.opened_at is not null and w.duration_days is not null and w.opened_at + make_interval(days => w.duration_days) <= now();
  return jsonb_build_object(
    'count', n, 'threshold', w.threshold, 'reached', r, 'ended', v_ended,
    'can_contact', w.author_id = uid and r and _wish_is_open(w.status, w.publish_at),
    'sent_this_week', (select count(*)::int from wish_contacts c where c.wish_id = w.id and c.created_at > now() - interval '7 days'),
    'preorderers', coalesce((select jsonb_agg(jsonb_build_object('name', display_name(p.user_id), 'at', p.created_at) order by p.created_at)
                              from (select * from wish_preorders where wish_id = w.id order by created_at limit 200) p), '[]'::jsonb));
end $$;

-- Écrire à tous les précommandeurs (créateur seulement, seuil atteint). Le message part en notification : aucun lien, aucune coordonnée n'est échangée.
create or replace function wish_contact_preorderers(p_wish uuid, p_message text) returns integer
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); w wishes%rowtype; n integer; v_msg text := btrim(coalesce(p_message, '')); v_sent integer;
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  if current_role_name() is null then raise exception 'Compte suspendu : envoi impossible'; end if;
  select * into w from wishes where id = p_wish and author_id = uid;
  if not found then raise exception 'Réservé au créateur du vœu'; end if;
  if not _wish_is_open(w.status, w.publish_at) then raise exception 'Ce vœu n''est pas publié'; end if;
  select count(*)::int into n from wish_preorders where wish_id = w.id;
  if w.threshold is null or n < w.threshold then raise exception 'Le seuil de précommandes n''est pas encore atteint'; end if;
  if char_length(v_msg) not between 10 and 500 then raise exception 'Message : 10 à 500 caractères'; end if;
  if v_msg ~* '(https?://|www\.|[[:alnum:]-]+\.(com|net|org|cm|fr|io|me|app)\y)' then raise exception 'Les liens ne sont pas autorisés : décrivez simplement la suite donnée au vœu'; end if;
  if (select count(*) from wish_contacts where wish_id = w.id and created_at > now() - interval '7 days') >= 3 then raise exception 'Trois messages par vœu et par semaine au plus'; end if;
  if (select count(*) from wish_contacts where sender_id = uid and created_at > now() - interval '1 day') >= 10 then raise exception 'Dix messages par jour au plus'; end if;
  perform chat_guard(null);
  insert into notifications (user_id, kind, title, body, data)
  select p.user_id, 'wish', left('Du créateur du vœu « ' || w.title || ' »', 120), left(display_name(uid) || ' : ' || v_msg, 500),
         jsonb_build_object('wish_id', w.id, 'from_author', true)
  from wish_preorders p
  where p.wish_id = w.id and p.user_id <> uid
    and not exists (select 1 from user_blocks b where (b.blocker_id = uid and b.blocked_id = p.user_id) or (b.blocker_id = p.user_id and b.blocked_id = uid));
  get diagnostics v_sent = row_count;
  insert into wish_contacts (wish_id, sender_id, body, recipients) values (w.id, uid, v_msg, v_sent);
  return v_sent;
end $$;

-- Mes précommandes, y compris celles dont la campagne est terminée.
create or replace function my_wish_preorders(p_limit integer default 50) returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  return coalesce((select jsonb_agg(_wish_card(w, uid) || jsonb_build_object('ended', w.opened_at is not null and w.duration_days is not null and w.opened_at + make_interval(days => w.duration_days) <= now()) order by x.created_at desc)
    from wish_preorders x join wishes w on w.id = x.wish_id
    where x.user_id = uid and _wish_is_open(w.status, w.publish_at)), '[]'::jsonb);
end $$;

-- Mes vœux (tous statuts) avec le motif éventuel de refus : réservé à l'auteur.
create or replace function my_wishes() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', w.id, 'title', w.title, 'status', w.status, 'price', w.price, 'threshold', w.threshold, 'review_note', w.review_note,
      'count', (select count(*)::int from wish_preorders x where x.wish_id = w.id)) order by w.created_at desc)
    from wishes w where w.author_id = auth.uid()), '[]'::jsonb);
end $$;

-- Un de mes vœux (brouillon ou refusé) pour le rouvrir dans le formulaire.
create or replace function wish_draft_get(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return (select jsonb_build_object('id', w.id, 'title', w.title, 'description', w.description, 'price', w.price, 'threshold', w.threshold,
      'duration_days', w.duration_days, 'status', w.status, 'review_note', w.review_note) from wishes w where w.id = p_id and w.author_id = auth.uid());
end $$;

-- Vœux à valider : département (même établissement que le sien quand les deux sont connus) et administrateur.
create or replace function wishes_to_review() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare me profiles%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into me from profiles where id = auth.uid();
  if me.role::text not in ('dept', 'admin') or coalesce(me.suspended, false) then raise exception 'Réservé au département ou à l''administrateur'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', w.id, 'title', w.title, 'description', w.description, 'price', w.price, 'threshold', w.threshold,
      'duration_days', w.duration_days, 'status', w.status) order by w.created_at)
    from wishes w
    where w.status = 'submitted'
      and (me.role::text = 'admin' or w.institution_id is null or me.institution_id is null or w.institution_id = me.institution_id)), '[]'::jsonb);
end $$;

-- L'auteur retire un vœu envoyé pour validation (il redevient un brouillon modifiable).
create or replace function withdraw_wish(p_id uuid) returns text
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  update wishes set status = 'draft', updated_at = now() where id = p_id and author_id = auth.uid() and status = 'submitted';
  if not found then raise exception 'Aucun vœu en attente de validation à retirer'; end if;
  return 'draft';
end $$;

revoke all on function wish_close_expired() from public, anon, authenticated;
revoke all on function wish_preorderers(uuid), wish_contact_preorderers(uuid, text), my_wish_preorders(integer), my_wishes(), wish_draft_get(uuid), wishes_to_review(), withdraw_wish(uuid) from public, anon;
grant execute on function wish_preorderers(uuid), wish_contact_preorderers(uuid, text), my_wish_preorders(integer), my_wishes(), wish_draft_get(uuid), wishes_to_review(), withdraw_wish(uuid) to authenticated;

-- Retour arrière : drop function wish_close_expired(), wish_preorderers(uuid), wish_contact_preorderers(uuid, text), my_wish_preorders(integer), my_wishes(), wish_draft_get(uuid),
--   wishes_to_review(), withdraw_wish(uuid) ; drop table wish_contacts, wish_closures.
