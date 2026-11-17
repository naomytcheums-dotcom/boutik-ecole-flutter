-- Lot G5 (profil Étudiant-vendeur) — notifications et interactions inter-acteurs.
--  1. Les notifications d'argent, de paiement, de réclamation, de litige, de retrait, de remboursement, de vérification, de sécurité, de support
--     et de modération ne sont plus supprimables par le réglage « catégorie commandes/avis » (notification_critical) : elles sont toujours reçues dans l'application.
--  2. SMS et WhatsApp partent seulement vers le numéro de téléphone VÉRIFIÉ du compte (profiles.phone_verified) ; le numéro WhatsApp saisi aux réglages
--     doit être ce même numéro. Plafonds par personne et par 24 h : 5 SMS, 5 WhatsApp, 20 e-mails (hors sécurité, argent et retraits).
--  3. Les canaux sortants (push, e-mail, SMS, WhatsApp) ne portent jamais d'adresse e-mail ni de numéro de téléphone (_mask_contact_data) ; l'application les affiche.
--  4. Un expéditeur bloqué par l'étudiant ne peut plus lui adresser de demande de contact (talent_contact_request), d'invitation à postuler (opp_invite)
--     ni de question sur un produit (ask_question) : réponse générique, aucune énumération des blocages.
--  5. 'payout' et 'refund' rejoignent la catégorie « commandes et paiements ».
-- Aucune donnée existante n'est supprimée. Rejouable.
-- Retour arrière : recréer notification_category (20261117050300 puis 20261118020200), notification_filter (20261117080100), enqueue_notification (20261117080100 puis 20261118020200),
--   set_notification_preference (20261115160000), set_whatsapp_number (20261115160000), talent_contact_request (20261118010300), opp_invite (20261117080000),
--   ask_question (20261107000000) ; drop function _mask_contact_data(text), notification_critical(text) ; drop index notification_outbox_quota.

-- ============================================================ 1. Types « importants » non désactivables
create or replace function notification_critical(p_kind text) returns boolean
language sql immutable set search_path = public as $$
  select p_kind in ('money', 'payment', 'claim', 'dispute', 'payout', 'refund', 'verification', 'certification', 'certificate',
                    'security', 'support', 'listing', 'moderation', 'account_deletion')
$$;
revoke all on function notification_critical(text) from public, anon;
grant execute on function notification_critical(text) to authenticated;

create or replace function notification_category(p_kind text) returns text
language sql immutable set search_path = public as $$
  select case
    when p_kind in ('order', 'payment', 'claim', 'dispute', 'money', 'quote', 'payout', 'refund') then 'orders'
    when p_kind in ('message', 'teammate_message') then 'messages'
    when p_kind in ('review', 'question') then 'reviews'
    when p_kind in ('alert', 'ads', 'opportunity_alert') then 'promotions'
    else 'other' end
$$;

create or replace function notification_filter() returns trigger
language plpgsql security definer set search_path = public as $$
declare cat text := notification_category(new.kind);
begin
  if cat <> 'other' and not notification_critical(new.kind) and exists (select 1 from notification_preferences
       where user_id = new.user_id and channel = 'inapp' and kind = 'cat:' || cat and not enabled) then
    return null;
  end if;
  if new.kind = 'verification' and new.data ? 'document' and new.data ? 'status'
     and not coalesce((select pf.documents from opportunity_alert_prefs pf where pf.user_id = new.user_id), true) then
    return null;
  end if;
  return new;
end $$;

-- ============================================================ 2. Texte sortant sans coordonnées
create or replace function _mask_contact_data(p text) returns text
language sql immutable set search_path = public as $$
  select regexp_replace(regexp_replace(regexp_replace(coalesce(p, ''),
    '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}', '[e-mail masqué]', 'g'),
    '\+[0-9][0-9 .-]{7,}[0-9]', '[numéro masqué]', 'g'),
    '(?<![0-9A-Za-z-])(237[ .-]?)?6[ .-]?[0-9]{2}([ .-]?[0-9]{2}){3}(?![0-9A-Za-z-])', '[numéro masqué]', 'g')
$$;
revoke all on function _mask_contact_data(text) from public, anon, authenticated;

create index if not exists notification_outbox_quota on notification_outbox (user_id, channel, created_at);

-- ============================================================ 3. Canaux : numéro vérifié, plafonds, texte masqué
create or replace function enqueue_notification() returns trigger
language plpgsql security definer set search_path = public as $$
declare ch text; ok boolean; v_explicit boolean; v_star boolean; pr profiles%rowtype; addr text; wa text; v_phone text; v_cap integer;
  important boolean := new.kind in ('order', 'payment', 'claim', 'dispute', 'quote', 'money', 'mission', 'listing', 'support',
    'opportunity_alert', 'opportunity_application', 'opportunity_invite', 'opportunity_reminder', 'verification', 'company_review', 'company_plan', 'company_team',
    'talent_contact', 'cv_shared', 'mentor_request', 'mentor_profile', 'payout', 'refund', 'certification', 'security', 'moderation');
  unmetered boolean := new.kind in ('security', 'money', 'payout');
begin
  select * into pr from profiles where id = new.user_id;
  select whatsapp_number into wa from notification_contacts where user_id = new.user_id;
  v_phone := case when pr.phone_verified then normalize_msisdn(pr.phone) end;
  foreach ch in array array['push', 'email', 'sms', 'whatsapp'] loop
    select enabled into v_explicit from notification_preferences where user_id = new.user_id and channel = ch and kind = new.kind;
    select enabled into v_star from notification_preferences where user_id = new.user_id and channel = ch and kind = '*';
    addr := null;
    if ch = 'push' then
      ok := coalesce(v_explicit, v_star, true) and exists (select 1 from device_tokens where user_id = new.user_id);
    else
      ok := coalesce(v_explicit, case when important then v_star end, false);
      if ch = 'email' then
        addr := case when coalesce(pr.email, '') ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then pr.email end;
      elsif ch = 'sms' then
        addr := v_phone;
      else
        addr := case when v_phone is not null and (wa is null or normalize_msisdn(wa) = v_phone) then v_phone end;
      end if;
      ok := ok and addr is not null;
      if ok and not unmetered then
        v_cap := case ch when 'email' then 20 else 5 end;
        ok := (select count(*) from notification_outbox where user_id = new.user_id and channel = ch and created_at > now() - interval '1 day') < v_cap;
      end if;
    end if;
    if ok then
      insert into notification_outbox (notification_id, user_id, channel, kind, title, body, to_address)
        values (new.id, new.user_id, ch, new.kind, left(_mask_contact_data(new.title), 200), left(_mask_contact_data(new.body), 500), addr);
    end if;
  end loop;
  return null;
end $$;
revoke execute on function enqueue_notification() from public, anon, authenticated;

create or replace function set_notification_preference(p_channel text, p_kind text, p_enabled boolean) returns text
language plpgsql security definer set search_path = public as $$
declare v_kind text := coalesce(nullif(trim(p_kind), ''), '*'); pr profiles%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_channel not in ('push', 'email', 'sms', 'whatsapp', 'inapp') then raise exception 'Canal inconnu'; end if;
  if p_channel = 'inapp' and v_kind not in ('cat:orders', 'cat:messages', 'cat:promotions', 'cat:reviews') then raise exception 'Catégorie inconnue'; end if;
  if p_enabled and p_channel in ('email', 'sms', 'whatsapp') then
    select * into pr from profiles where id = auth.uid();
    if p_channel = 'email' and coalesce(pr.email, '') !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'Aucune adresse e-mail valide enregistrée'; end if;
    if p_channel in ('sms', 'whatsapp') and not (coalesce(pr.phone_verified, false) and normalize_msisdn(pr.phone) is not null) then
      raise exception 'Vérifiez d''abord votre numéro de téléphone (Informations personnelles) : les SMS et WhatsApp ne partent que vers un numéro vérifié';
    end if;
  end if;
  insert into notification_preferences (user_id, channel, kind, enabled, consent_at, updated_at)
    values (auth.uid(), p_channel, v_kind, p_enabled, case when p_enabled and p_channel <> 'inapp' then now() end, now())
  on conflict (user_id, channel, kind) do update set enabled = excluded.enabled,
    consent_at = case when excluded.enabled and notification_preferences.channel <> 'inapp' then coalesce(notification_preferences.consent_at, now()) else notification_preferences.consent_at end, updated_at = now();
  return case when p_enabled then 'enabled' else 'disabled' end;
end $$;
revoke all on function set_notification_preference(text, text, boolean) from public, anon;
grant execute on function set_notification_preference(text, text, boolean) to authenticated;

-- Le numéro WhatsApp ne peut être que le numéro vérifié du compte (un numéro non vérifié pourrait être celui d'un tiers).
create or replace function set_whatsapp_number(p_number text) returns text
language plpgsql security definer set search_path = public as $$
declare v text; pr profiles%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if nullif(btrim(coalesce(p_number, '')), '') is null then
    delete from notification_contacts where user_id = auth.uid();
    return '';
  end if;
  v := normalize_msisdn(p_number);
  if v is null then raise exception 'Numéro WhatsApp invalide : utilisez le format +237 6XX XX XX XX'; end if;
  select * into pr from profiles where id = auth.uid();
  if not coalesce(pr.phone_verified, false) or normalize_msisdn(pr.phone) is distinct from v then
    raise exception 'Le numéro WhatsApp doit être votre numéro de téléphone vérifié : vérifiez-le d''abord dans Informations personnelles';
  end if;
  insert into notification_contacts (user_id, whatsapp_number) values (auth.uid(), v)
  on conflict (user_id) do update set whatsapp_number = excluded.whatsapp_number, updated_at = now();
  return v;
end $$;
revoke all on function set_whatsapp_number(text) from public, anon;
grant execute on function set_whatsapp_number(text) to authenticated;

-- ============================================================ 4. Blocages respectés par les contacts reçus
create or replace function talent_contact_request(p_user uuid, p_kind text, p_message text default '') returns text
language plpgsql security definer set search_path = public as $$
declare v_role text := coalesce(current_role_name()::text, ''); v_msg text := left(_clean_text(p_message), 500); v_label text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if v_role not in ('company', 'other', 'client', 'dept', 'admin') then raise exception 'Cette demande est réservée aux entreprises, aux organisations, aux clients et au département'; end if;
  if v_role in ('company', 'other') and not _org_approved(auth.uid()) then
    raise exception '% doit être vérifiée par l''administrateur avant de contacter des talents : complétez votre fiche entreprise et envoyez vos pièces justificatives.', case when v_role = 'other' then 'Votre organisation' else 'Votre entreprise' end;
  end if;
  if p_kind not in ('internship_offer', 'contact') then raise exception 'Type de demande inconnu'; end if;
  if p_kind = 'internship_offer' and v_role = 'client' then raise exception 'Une proposition de stage est réservée aux entreprises vérifiées, aux organisations et au département'; end if;
  if p_user = auth.uid() then raise exception 'Vous ne pouvez pas vous adresser cette demande'; end if;
  if not _talent_listable(p_user) then raise exception 'Talent introuvable'; end if;
  if exists (select 1 from user_blocks where (blocker_id = p_user and blocked_id = auth.uid()) or (blocker_id = auth.uid() and blocked_id = p_user)) then
    raise exception 'Talent introuvable';
  end if;
  if not _cv_published(p_user) then raise exception 'Ce talent n''a pas publié son CV'; end if;
  if p_kind = 'internship_offer' and char_length(v_msg) < 10 then raise exception 'Précisez votre proposition de stage (10 caractères minimum).'; end if;
  if (select count(*) from talent_contacts where sender_id = auth.uid() and created_at > now() - interval '1 day') >= 10 then raise exception 'Dix demandes par jour au plus'; end if;
  if v_msg <> '' and (select count(*) from talent_contacts where sender_id = auth.uid() and message = v_msg and created_at > now() - interval '1 day') >= 3 then
    raise exception 'Ce même message a déjà été envoyé à trois talents aujourd''hui : personnalisez-le.';
  end if;
  begin
    insert into talent_contacts (sender_id, target_id, kind, message) values (auth.uid(), p_user, p_kind, v_msg);
  exception when unique_violation then
    raise exception 'Vous avez déjà adressé cette demande à ce talent aujourd''hui';
  end;
  v_label := _talent_sender_label(auth.uid());
  perform notify_user(p_user, 'talent_contact', case p_kind when 'internship_offer' then 'Proposition de stage' else 'Demande de contact' end,
    left(v_label || case p_kind when 'internship_offer' then ' vous propose un stage' else ' souhaite vous contacter' end || case when v_msg <> '' then ' : ' || v_msg else '.' end, 500),
    jsonb_build_object('from', auth.uid(), 'kind', p_kind));
  return 'sent';
end $$;
revoke all on function talent_contact_request(uuid, text, text) from public, anon;
grant execute on function talent_contact_request(uuid, text, text) to authenticated;

create or replace function opp_invite(p_opp uuid, p_student uuid, p_message text default '') returns text
language plpgsql security definer set search_path = public as $$
declare o opportunities%rowtype; v_msg text := left(btrim(coalesce(p_message, '')), 300);
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into o from opportunities where id = p_opp and poster_id = auth.uid();
  if not found then raise exception 'Offre introuvable'; end if;
  if o.status <> 'published' then raise exception 'Publiez l''offre avant d''inviter des étudiants'; end if;
  if not is_verified_student(p_student) or not _talent_visible(p_student) then raise exception 'Étudiant introuvable'; end if;
  if exists (select 1 from user_blocks where (blocker_id = p_student and blocked_id = auth.uid()) or (blocker_id = auth.uid() and blocked_id = p_student)) then
    raise exception 'Étudiant introuvable';
  end if;
  if exists (select 1 from opportunity_applications where opportunity_id = p_opp and applicant_id = p_student) then raise exception 'Cet étudiant a déjà postulé'; end if;
  if exists (select 1 from opportunity_invites where opportunity_id = p_opp and student_id = p_student) then raise exception 'Cet étudiant est déjà invité'; end if;
  if (select count(*) from opportunity_invites where opportunity_id = p_opp) >= 30 then raise exception '30 invitations au plus par offre'; end if;
  if (select count(*) from opportunity_invites where invited_by = auth.uid() and created_at > now() - interval '1 day') >= 100 then raise exception '100 invitations au plus par jour'; end if;
  insert into opportunity_invites (opportunity_id, student_id, invited_by, message) values (p_opp, p_student, auth.uid(), v_msg);
  perform notify_user(p_student, 'opportunity_invite', o.org_name || ' vous invite à postuler', o.title || case when v_msg <> '' then ' : ' || v_msg else '' end || ' · Ouvrez l''offre dans Opportunités.',
                      jsonb_build_object('opportunity', p_opp));
  return 'invited';
end $$;
revoke all on function opp_invite(uuid, uuid, text) from public, anon;
grant execute on function opp_invite(uuid, uuid, text) to authenticated;

create or replace function ask_question(p_listing uuid, p_question text) returns uuid
language plpgsql security definer set search_path = public as $$
declare l listings%rowtype; v_id uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if char_length(trim(coalesce(p_question, ''))) < 5 then raise exception 'Question trop courte'; end if;
  select * into l from listings where id = p_listing and status = 'approved';
  if not found then raise exception 'Produit introuvable'; end if;
  if l.seller_id = auth.uid() then raise exception 'Vous ne pouvez pas poser une question sur votre propre produit'; end if;
  if l.seller_id is not null and exists (select 1 from user_blocks where (blocker_id = l.seller_id and blocked_id = auth.uid()) or (blocker_id = auth.uid() and blocked_id = l.seller_id)) then
    raise exception 'Produit introuvable';
  end if;
  if (select count(*) from product_questions where asker_id = auth.uid() and created_at > now() - interval '1 hour') >= 10 then raise exception 'Trop de questions : réessayez plus tard'; end if;
  insert into product_questions (listing_id, asker_id, question) values (p_listing, auth.uid(), trim(p_question)) returning id into v_id;
  perform notify_user(l.seller_id, 'question', 'Nouvelle question', l.title || ' : ' || left(trim(p_question), 120), jsonb_build_object('listing', l.id));
  return v_id;
end $$;
revoke all on function ask_question(uuid, text) from public, anon;
grant execute on function ask_question(uuid, text) to authenticated;
