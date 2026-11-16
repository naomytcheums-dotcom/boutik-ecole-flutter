-- Lot S8 (profil Étudiant-vendeur) — alertes et dossier.
--  1. S8-4  Les alertes d'offres, résultats de candidature, rappels, invitations, demandes de mentor et pièces du dossier partent aussi par e-mail, SMS et
--           WhatsApp lorsque la personne a activé le canal (réglage « * » de l'écran 156) : passage par notifications -> enqueue_notification -> notification_outbox.
--  2. S8-5  La personne est prévenue (notification « verification » portant « document » et « status ») quand une de ses pièces est vérifiée ou refusée ;
--           réglage « Pièces du dossier » de l'écran 156, appliqué par notification_filter, donc aussi à document_decide du lot S1.
--  3. S8-6  Un seul réglage « Offres compatibles » : l'interrupteur de /opportunites et celui de l'écran 156 pilotent les mêmes données.
-- Aucune donnée existante n'est supprimée. Rejouable. Retour arrière : voir le bas du fichier.

-- ============================================================ 1. Canaux e-mail / SMS / WhatsApp pour les alertes d'opportunités
-- Même fonction que 20261115160000 ; seule la liste des types « importants » s'allonge (un canal activé en « * » les reçoit).
create or replace function enqueue_notification() returns trigger
language plpgsql security definer set search_path = public as $$
declare ch text; ok boolean; v_explicit boolean; v_star boolean; pr profiles%rowtype; addr text; wa text;
  important boolean := new.kind in ('order', 'payment', 'claim', 'dispute', 'quote', 'money', 'mission', 'listing', 'support',
    'opportunity_alert', 'opportunity_application', 'opportunity_invite', 'opportunity_reminder', 'verification', 'mentor_request', 'mentor_profile');
begin
  select * into pr from profiles where id = new.user_id;
  select whatsapp_number into wa from notification_contacts where user_id = new.user_id;
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
        addr := normalize_msisdn(pr.phone);
      else
        addr := normalize_msisdn(coalesce(wa, pr.phone));
      end if;
      ok := ok and addr is not null;
    end if;
    if ok then
      insert into notification_outbox (notification_id, user_id, channel, kind, title, body, to_address)
        values (new.id, new.user_id, ch, new.kind, new.title, left(new.body, 500), addr);
    end if;
  end loop;
  return null;
end $$;
revoke execute on function enqueue_notification() from public, anon, authenticated;

-- ============================================================ 3. Un seul réglage « Offres compatibles »
alter table opportunity_alert_prefs add column if not exists documents boolean not null default true;

-- offers = l'alerte est réellement active (réglage voulu ET alerte de filière enregistrée) ; needs_department = réglage voulu mais aucune filière au profil.
create or replace function alert_prefs_get() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'offers', coalesce(p.offers, true) and exists (select 1 from opportunity_alerts a where a.user_id = auth.uid()),
    'results', coalesce(p.results, true),
    'documents', coalesce(p.documents, true),
    'needs_department', coalesce(p.offers, false) and not exists (select 1 from opportunity_alerts a where a.user_id = auth.uid())
                        and char_length(btrim(coalesce((select pr.department from profiles pr where pr.id = auth.uid()), ''))) < 2)
  from (select 1) d left join opportunity_alert_prefs p on p.user_id = auth.uid()
$$;

drop function if exists alert_prefs_set(boolean, boolean);
create or replace function alert_prefs_set(p_offers boolean, p_results boolean, p_documents boolean default null) returns void
language plpgsql security definer set search_path = public as $$
declare v_dept text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_offers is null or p_results is null then raise exception 'Préférences incomplètes'; end if;
  insert into opportunity_alert_prefs (user_id, offers, results, documents) values (auth.uid(), p_offers, p_results, coalesce(p_documents, true))
  on conflict (user_id) do update set offers = excluded.offers, results = excluded.results, documents = coalesce(p_documents, opportunity_alert_prefs.documents), updated_at = now();
  if p_offers then
    select btrim(coalesce(department, '')) into v_dept from profiles where id = auth.uid();
    if char_length(coalesce(v_dept, '')) >= 2 then
      insert into opportunity_alerts (user_id, department) values (auth.uid(), v_dept) on conflict do nothing;
    end if;
  else
    delete from opportunity_alerts where user_id = auth.uid();
  end if;
end $$;
revoke all on function alert_prefs_get(), alert_prefs_set(boolean, boolean, boolean) from public, anon;
grant execute on function alert_prefs_get(), alert_prefs_set(boolean, boolean, boolean) to authenticated;

-- L'interrupteur de /opportunites écrit aussi le réglage « Offres compatibles » (même donnée que l'écran 156).
create or replace function opp_alert_set(p_department text, p_on boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(p_on, true) then
    if char_length(btrim(coalesce(p_department, ''))) < 2 then raise exception 'Indiquez votre filière dans votre profil'; end if;
    insert into opportunity_alerts (user_id, department) values (auth.uid(), btrim(p_department)) on conflict do nothing;
    insert into opportunity_alert_prefs (user_id, offers) values (auth.uid(), true)
      on conflict (user_id) do update set offers = true, updated_at = now();
  else
    if char_length(btrim(coalesce(p_department, ''))) < 2 then
      delete from opportunity_alerts where user_id = auth.uid();
    else
      delete from opportunity_alerts where user_id = auth.uid() and lower(department) = lower(btrim(p_department));
    end if;
    if not exists (select 1 from opportunity_alerts where user_id = auth.uid()) then
      insert into opportunity_alert_prefs (user_id, offers) values (auth.uid(), false)
        on conflict (user_id) do update set offers = false, updated_at = now();
    end if;
  end if;
end $$;
revoke all on function opp_alert_set(text, boolean) from public, anon;
grant execute on function opp_alert_set(text, boolean) to authenticated;

-- État de l'interrupteur de /opportunites : alerte enregistrée ET réglage « Offres compatibles » non coupé.
create or replace function opp_my_alert() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from opportunity_alerts where user_id = auth.uid())
     and coalesce((select p.offers from opportunity_alert_prefs p where p.user_id = auth.uid()), true)
$$;
revoke all on function opp_my_alert() from public, anon;
grant execute on function opp_my_alert() to authenticated;

-- Nouvelle offre : prévient les personnes dont l'alerte est active ; la filière actuelle du profil prime sur celle enregistrée.
create or replace function _opp_alert_matching(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare o opportunities%rowtype; r record;
begin
  select * into o from opportunities where id = p_id;
  if not found then return; end if;
  for r in select a.user_id, min(coalesce(nullif(btrim(pr.department), ''), a.department)) dep from opportunity_alerts a
           join profiles pr on pr.id = a.user_id
           left join opportunity_alert_prefs pf on pf.user_id = a.user_id
           where a.user_id <> o.poster_id and coalesce(pf.offers, true) and not coalesce(pr.suspended, false)
           group by a.user_id order by a.user_id limit 1000 loop
    if o.department_target = '' or lower(o.department_target) like '%' || lower(r.dep) || '%' or lower(r.dep) like '%' || lower(o.department_target) || '%' then
      perform notify_user(r.user_id, 'opportunity_alert', 'Nouvelle offre pour votre filière', o.org_name || ' : ' || o.title, jsonb_build_object('opportunity', p_id));
    end if;
  end loop;
end $$;
revoke all on function _opp_alert_matching(uuid) from public, anon, authenticated;

-- ============================================================ 2. Pièce vérifiée ou refusée : la personne est prévenue
-- Les décisions sur une pièce (document_review ci-dessous et document_decide du lot S1) créent une notification de type « verification » dont les
-- données portent « document » et « status » : le réglage « Pièces du dossier » (documents) de l'écran 156 la coupe à l'insertion.
create or replace function notification_filter() returns trigger
language plpgsql security definer set search_path = public as $$
declare cat text := notification_category(new.kind);
begin
  if cat <> 'other' and exists (select 1 from notification_preferences
       where user_id = new.user_id and channel = 'inapp' and kind = 'cat:' || cat and not enabled) then
    return null;
  end if;
  if new.kind = 'verification' and new.data ? 'document' and new.data ? 'status'
     and not coalesce((select pf.documents from opportunity_alert_prefs pf where pf.user_id = new.user_id), true) then
    return null;
  end if;
  return new;
end $$;

-- Même effet que 20261104000100 ; la personne est en plus prévenue (revérifier avec le même statut ne renotifie pas).
create or replace function document_review(p_id uuid, p_status text, p_note text default null) returns void
language plpgsql security definer set search_path = public as $$
declare d user_documents%rowtype; v_old text; v_label text;
begin
  if not is_platform_staff() then raise exception 'Action non autorisée'; end if;
  if p_status not in ('verified', 'rejected') then raise exception 'Statut invalide'; end if;
  select * into d from user_documents where id = p_id;
  if not found then raise exception 'Document introuvable'; end if;
  v_old := d.status;
  update user_documents set status = p_status, review_note = left(p_note, 500), reviewed_by = auth.uid(), reviewed_at = now() where id = p_id;
  insert into user_document_history (document_id, status, note, actor_id) values (p_id, p_status, left(p_note, 500), auth.uid());
  if p_status = 'verified' then perform _mentor_auto_verify(d.owner_id); end if;
  if v_old is distinct from p_status then
    v_label := case d.kind when 'student_card' then 'Carte d''étudiant' when 'enrollment_certificate' then 'Certificat de scolarité' when 'diploma' then 'Diplôme'
                           when 'certificate' then 'Certificat' when 'cv' then 'CV' else 'Document' end;
    perform notify_user(d.owner_id, 'verification', case p_status when 'verified' then 'Pièce validée' else 'Pièce refusée' end,
      v_label || ' (' || left(d.name, 60) || ') : ' || case p_status when 'verified' then 'validée par l''équipe.'
        else 'refusée' || coalesce(' — ' || nullif(btrim(left(p_note, 200)), ''), '') || '. Vous pouvez en déposer une nouvelle dans « Mon dossier ».' end,
      jsonb_build_object('document', p_id, 'kind', d.kind, 'status', p_status));
  end if;
end $$;
revoke all on function document_review(uuid, text, text) from public, anon;
grant execute on function document_review(uuid, text, text) to authenticated;

-- Retour arrière :
--   recréer enqueue_notification (20261115160000), notification_filter (20261115160000), _opp_alert_matching (20261115180000), document_review (20261104000100), opp_alert_set et opp_my_alert (20261114004200 / 20261114001300) ;
--   drop function alert_prefs_get(), alert_prefs_set(boolean, boolean, boolean) ; recréer alert_prefs_get() et alert_prefs_set(boolean, boolean) depuis 20261115180000 ;
--   alter table opportunity_alert_prefs drop column documents;
