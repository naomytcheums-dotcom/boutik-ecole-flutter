-- Lot S1 — partie 2 : sécurité du compte et suppression de compte.
--   S1-51 : codes de secours 2FA (8 codes à usage unique, haché en base, montrés une seule fois) + procédure d'équipe (admin_mfa_reset).
--           Un code de secours ouvre la récupération : la double authentification du compte est désactivée (Supabase ne permet pas de fabriquer
--           une session aal2 côté SQL) et la personne doit la réactiver ; 5 essais ratés par 15 minutes au plus.
--   S1-55 / S1-56 / S1-13 : la suppression de compte est réellement exécutée après le délai de 30 jours : le compte est ANONYMISÉ (jamais supprimé) ;
--           commandes, paiements, gains et écritures comptables restent en place. Une demande est refusée tant que des commandes sont en cours.
--           process_account_deletions() : à planifier par le chef (pg_cron, une fois par jour) ; admin_process_account_deletions() : bouton de l'administrateur.
--   S1-57 : l'export des données comprend aussi les ventes du vendeur, ses paiements et ses candidatures.
--   S1-60 / S1-61 : l'acceptation distingue les CGU (cgu-AAAA-MM) et les CGV (cgv-AAAA-MM).
-- Additive et rejouable. Retour arrière : voir la fin du fichier.

-- ============================================================ 1. Codes de secours 2FA
create table if not exists mfa_backup_codes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  code_hash text not null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists mfa_backup_codes_user on mfa_backup_codes (user_id);
create table if not exists mfa_backup_attempts (
  id bigint generated always as identity primary key,
  user_id uuid not null,
  created_at timestamptz not null default now()
);
create index if not exists mfa_backup_attempts_user on mfa_backup_attempts (user_id, created_at desc);
alter table mfa_backup_codes enable row level security;
alter table mfa_backup_attempts enable row level security;
revoke all on mfa_backup_codes, mfa_backup_attempts from anon, authenticated;

create or replace function _session_is_aal2() returns boolean
language plpgsql stable set search_path = public as $$
declare c jsonb;
begin
  begin
    c := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
  exception when others then
    return false;
  end;
  return coalesce(c ->> 'aal', '') = 'aal2';
end $$;
revoke all on function _session_is_aal2() from public, anon, authenticated;

-- Opération d'équipe sensible : si l'équipier a la 2FA, la session doit être aal2 (cette garde n'est pas dans enforce_mfa_on_sensitive).
create or replace function _require_staff_aal2() returns void
language plpgsql stable security definer set search_path = public, auth as $$
begin
  if exists (select 1 from auth.mfa_factors where user_id = auth.uid() and status = 'verified') and not _session_is_aal2() then
    raise exception 'Confirmez votre identité avec votre code de double authentification pour effectuer cette opération.' using errcode = '42501';
  end if;
end $$;
revoke all on function _require_staff_aal2() from public, anon, authenticated;

create or replace function _mfa_code_hash(p_user uuid, p_code text) returns text
language sql immutable set search_path = public as $$
  select encode(sha256(convert_to(p_user::text || ':' || upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g')), 'UTF8')), 'hex')
$$;
revoke all on function _mfa_code_hash(uuid, text) from public, anon, authenticated;

-- Génère 8 nouveaux codes (les anciens sont invalidés) : session vérifiée (aal2) et 2FA activée exigées. Les codes ne sont renvoyés QU'ICI.
create or replace function mfa_backup_codes_generate() returns jsonb
language plpgsql security definer set search_path = public, auth as $$
declare v_codes text[] := '{}'; v text; i integer;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from auth.mfa_factors where user_id = auth.uid() and status = 'verified') then
    raise exception 'Activez d''abord la double authentification pour créer des codes de secours';
  end if;
  if not _session_is_aal2() then
    raise exception 'Confirmez votre identité avec votre code de double authentification pour effectuer cette opération.' using errcode = '42501';
  end if;
  delete from mfa_backup_codes where user_id = auth.uid();
  for i in 1..8 loop
    v := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12));
    v := substr(v, 1, 6) || '-' || substr(v, 7, 6);
    v_codes := v_codes || v;
    insert into mfa_backup_codes (user_id, code_hash) values (auth.uid(), _mfa_code_hash(auth.uid(), v));
  end loop;
  return to_jsonb(v_codes);
end $$;

create or replace function mfa_backup_codes_status() returns jsonb
language plpgsql stable security definer set search_path = public, auth as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return jsonb_build_object(
    'enrolled', exists (select 1 from auth.mfa_factors where user_id = auth.uid() and status = 'verified'),
    'remaining', (select count(*)::int from mfa_backup_codes where user_id = auth.uid() and used_at is null),
    'generated', (select count(*)::int from mfa_backup_codes where user_id = auth.uid()));
end $$;

-- Récupération : renvoie 'ok' (code valide, consommé ; la 2FA du compte est désactivée, à réactiver), 'invalid' ou 'locked'.
-- Les essais ratés sont enregistrés (aucune exception : elle annulerait l'enregistrement).
create or replace function mfa_use_backup_code(p_code text) returns text
language plpgsql security definer set search_path = public, auth as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from auth.mfa_factors where user_id = auth.uid()) then raise exception 'Aucune double authentification à récupérer sur ce compte'; end if;
  if (select count(*) from mfa_backup_attempts where user_id = auth.uid() and created_at > now() - interval '15 minutes') >= 5 then return 'locked'; end if;
  select id into v_id from mfa_backup_codes where user_id = auth.uid() and used_at is null and code_hash = _mfa_code_hash(auth.uid(), p_code) limit 1;
  if v_id is null then
    insert into mfa_backup_attempts (user_id) values (auth.uid());
    return 'invalid';
  end if;
  update mfa_backup_codes set used_at = now() where id = v_id;
  delete from auth.mfa_factors where user_id = auth.uid();
  delete from mfa_backup_attempts where user_id = auth.uid();
  insert into notifications (user_id, kind, title, body, data)
    values (auth.uid(), 'security', 'Double authentification désactivée', 'Un code de secours vient d''être utilisé : la double authentification est désactivée. Réactivez-la depuis Sécurité du compte et créez de nouveaux codes.', '{}'::jsonb);
  insert into audit_log (actor, action, target, category, level)
    values (coalesce((select name from profiles where id = auth.uid()), 'Compte'), 'Récupération 2FA par code de secours', auth.uid()::text, 'Sécurité', 'Sensible');
  return 'ok';
end $$;

-- Procédure d'équipe (perte du téléphone ET des codes) : après vérification d'identité hors application (voir docs/transformation/PROCEDURE_2FA_SECOURS.md),
-- l'administrateur ou le support retire la 2FA du compte. Le support ne peut pas agir sur un compte de l'équipe.
create or replace function admin_mfa_reset(p_user uuid, p_note text) returns text
language plpgsql security definer set search_path = public, auth as $$
declare r text := coalesce(current_role_name()::text, ''); t text; v_name text; v_who text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if r not in ('admin', 'support') then raise exception 'Action non autorisée'; end if;
  perform _require_staff_aal2();
  if p_user = auth.uid() then raise exception 'Vous ne pouvez pas réinitialiser votre propre double authentification'; end if;
  if char_length(btrim(coalesce(p_note, ''))) < 10 then raise exception 'Indiquez comment l''identité a été vérifiée (10 caractères au moins)'; end if;
  select role::text, name into t, v_name from profiles where id = p_user;
  if t is null then raise exception 'Compte introuvable'; end if;
  if r = 'support' and t in ('admin', 'dept', 'direction', 'finance', 'support') then raise exception 'Seul l''administrateur réinitialise un compte de l''équipe'; end if;
  delete from auth.mfa_factors where user_id = p_user;
  delete from mfa_backup_codes where user_id = p_user;
  select name into v_who from profiles where id = auth.uid();
  insert into audit_log (actor, action, target, category, level)
    values (coalesce(v_who, 'Équipe'), 'Réinitialisation 2FA : ' || left(btrim(p_note), 120), coalesce(v_name, p_user::text), 'Sécurité', 'Critique');
  insert into notifications (user_id, kind, title, body, data)
    values (p_user, 'security', 'Double authentification réinitialisée', 'L''équipe a retiré la double authentification de votre compte après vérification de votre identité. Réactivez-la depuis Sécurité du compte. Si vous n''êtes pas à l''origine de cette demande, changez votre mot de passe.', '{}'::jsonb);
  return 'reset';
end $$;

revoke all on function mfa_backup_codes_generate(), mfa_backup_codes_status(), mfa_use_backup_code(text), admin_mfa_reset(uuid, text) from public, anon;
grant execute on function mfa_backup_codes_generate(), mfa_backup_codes_status(), mfa_use_backup_code(text), admin_mfa_reset(uuid, text) to authenticated;

-- Même opération à partir de l'adresse e-mail du compte (écran d'équipe).
create or replace function admin_mfa_reset_by_email(p_email text, p_note text) returns text
language plpgsql security definer set search_path = public, auth as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('admin', 'support') then raise exception 'Action non autorisée'; end if;
  select id into v_id from profiles where lower(email) = lower(btrim(coalesce(p_email, '')));
  if v_id is null then raise exception 'Compte introuvable'; end if;
  return admin_mfa_reset(v_id, p_note);
end $$;
revoke all on function admin_mfa_reset_by_email(text, text) from public, anon;
grant execute on function admin_mfa_reset_by_email(text, text) to authenticated;

-- ============================================================ 2. Conditions : CGU et CGV
do $$ begin
  alter table terms_acceptances drop constraint if exists terms_acceptances_version_check;
  alter table terms_acceptances add constraint terms_acceptances_version_check check (version ~ '^(cgu|cgv)-[0-9]{4}-[0-9]{2}$');
exception when others then raise notice 'terms_acceptances_version_check non modifiée : %', sqlerrm;
end $$;

create or replace function accept_terms(p_version text default 'cgu-2026-10') returns text
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_version is null or p_version !~ '^(cgu|cgv)-[0-9]{4}-[0-9]{2}$' then raise exception 'Version des conditions inconnue'; end if;
  insert into terms_acceptances (user_id, version) values (auth.uid(), p_version) on conflict do nothing;
  return case when found then 'recorded' else 'already' end;
end $$;

-- Dernière version des CGU acceptée (les CGV ont leur propre fonction : my_sales_terms).
create or replace function my_terms() returns text
language sql stable security definer set search_path = public as $$
  select version from terms_acceptances where user_id = auth.uid() and version like 'cgu-%' order by accepted_at desc limit 1
$$;
create or replace function my_sales_terms() returns text
language sql stable security definer set search_path = public as $$
  select version from terms_acceptances where user_id = auth.uid() and version like 'cgv-%' order by accepted_at desc limit 1
$$;
revoke all on function accept_terms(text), my_terms(), my_sales_terms() from public, anon;
grant execute on function accept_terms(text), my_terms(), my_sales_terms() to authenticated;

-- ============================================================ 3. Suppression de compte
-- Commandes en cours : non annulées, payées ou en cours de paiement, dont une ligne n'est pas livrée ; comme acheteur ou comme vendeur.
create or replace function _open_orders(p_user uuid) returns integer
language sql stable security definer set search_path = public as $$
  select count(distinct o.id)::int from orders o
  where o.cancelled_at is null and not o.cancelled and (o.paid or o.reference is not null)
    and (o.buyer_id = p_user or exists (select 1 from order_lines x join listings l on l.id = x.listing_id where x.order_id = o.id and l.seller_id = p_user))
    and exists (select 1 from order_lines y where y.order_id = o.id and y.fulfillment < 4)
$$;
revoke all on function _open_orders(uuid) from public, anon, authenticated;

create or replace function request_account_deletion(p_reason text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_role text; v_name text; v_when timestamptz; r account_deletion_requests%rowtype; v_open integer;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select role::text, name into v_role, v_name from profiles where id = auth.uid();
  if v_role is null then raise exception 'Aucun profil à supprimer'; end if;
  if v_role in ('admin', 'dept', 'direction', 'finance', 'support') then
    raise exception 'Les comptes de l''équipe sont supprimés par l''administration globale : contactez-la';
  end if;
  select * into r from account_deletion_requests where user_id = auth.uid();
  if found and r.status = 'pending' then
    return jsonb_build_object('status', 'pending', 'scheduled_for', r.scheduled_for, 'already', true);
  end if;
  v_open := _open_orders(auth.uid());
  if v_open > 0 then
    raise exception 'Vous avez % commande(s) en cours (à recevoir ou à livrer) : terminez-les avant de demander la suppression du compte', v_open;
  end if;
  v_when := now() + interval '30 days';
  insert into account_deletion_requests (user_id, status, reason, requested_at, scheduled_for)
    values (auth.uid(), 'pending', left(nullif(btrim(coalesce(p_reason, '')), ''), 500), now(), v_when)
  on conflict (user_id) do update set status = 'pending', reason = excluded.reason, requested_at = now(), scheduled_for = v_when,
    cancelled_at = null, processed_at = null, processed_by = null;
  insert into notifications (user_id, kind, title, body, data)
    select a.id, 'account_deletion', 'Demande de suppression de compte',
           coalesce(v_name, 'Un compte') || ' demande la suppression de son compte. Suppression possible à partir du ' || to_char(v_when, 'DD/MM/YYYY') || ' (délai de rétractation de 30 jours).',
           jsonb_build_object('user', auth.uid(), 'scheduled_for', v_when)
    from profiles a where a.role::text in ('admin', 'support');
  insert into notifications (user_id, kind, title, body, data)
    values (auth.uid(), 'account_deletion', 'Demande de suppression enregistrée',
            'Votre compte sera supprimé à partir du ' || to_char(v_when, 'DD/MM/YYYY') || '. Jusqu''à cette date, vous pouvez annuler la demande depuis « Mes données ».',
            jsonb_build_object('scheduled_for', v_when));
  return jsonb_build_object('status', 'pending', 'scheduled_for', v_when, 'already', false);
end $$;

-- Demandes en attente (équipe) : « due » = délai écoulé ; « open_orders » = commandes qui bloquent encore l'exécution.
create or replace function account_deletions_pending() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_platform_staff() then raise exception 'Action non autorisée'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('user_id', d.user_id, 'name', p.name, 'email', p.email, 'role', p.role::text, 'requested_at', d.requested_at,
                                        'scheduled_for', d.scheduled_for, 'due', d.scheduled_for <= now(), 'open_orders', _open_orders(d.user_id)) order by d.scheduled_for)
    from account_deletion_requests d join profiles p on p.id = d.user_id where d.status = 'pending'), '[]'::jsonb);
end $$;

-- Anonymisation d'un compte : le profil perd toute donnée personnelle et est désactivé ; les lignes comptables (commandes, paiements, gains,
-- écritures) ne sont ni supprimées ni modifiées. Les fichiers privés sont retirés de la table du stockage.
create or replace function _anonymize_account(p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
declare t record;
begin
  perform set_config('app.cert_rpc', '1', true);
  update profiles set name = 'Compte supprimé', email = null, phone = null, bio = '', skills = '', links = '[]'::jsonb, city = null, birth = null,
    avatar_url = null, cover_path = null, cover_kind = null, matricule = null, study_level = null, institution = '', department = '',
    institution_id = null, department_id = null, certification = 'none', suspended = true
  where id = p_user;
  perform set_config('app.cert_rpc', '', true);
  begin update shops set status = 'closed' where owner_id = p_user and status <> 'closed'; exception when others then null; end;
  begin update listings set status = 'removed' where seller_id = p_user and status in ('draft', 'pending', 'approved'); exception when others then null; end;
  for t in select * from (values
    ('addresses', 'user_id'), ('notifications', 'user_id'), ('notification_preferences', 'user_id'), ('notification_contacts', 'user_id'), ('device_tokens', 'user_id'),
    ('favorites', 'user_id'), ('price_alerts', 'user_id'), ('shop_follows', 'user_id'), ('payment_methods', 'owner_id'), ('momo_numbers', 'user_id'),
    ('user_documents', 'owner_id'), ('certification_requests', 'user_id'), ('mentor_profiles', 'user_id'), ('opportunity_saves', 'user_id'),
    ('opportunity_alerts', 'user_id'), ('cv_links', 'owner_id'), ('mfa_backup_codes', 'user_id')
  ) as x(tbl, col) loop
    begin
      if to_regclass('public.' || t.tbl) is not null then execute format('delete from public.%I where %I = $1', t.tbl, t.col) using p_user; end if;
    exception when others then null;
    end;
  end loop;
  begin
    delete from storage.objects where bucket_id in ('profile-documents', 'avatars') and (storage.foldername(name))[1] = p_user::text;
  exception when others then null;
  end;
  -- l'accès : adresse rendue inutilisable, session fermée, connexion interdite
  begin
    update auth.users set email = 'supprime-' || p_user::text || '@supprime.invalid', raw_user_meta_data = '{}'::jsonb, banned_until = 'infinity', encrypted_password = ''
      where id = p_user;
  exception when others then null;
  end;
  begin delete from auth.sessions where user_id = p_user; exception when others then null; end;
  begin delete from auth.mfa_factors where user_id = p_user; exception when others then null; end;
end $$;
revoke all on function _anonymize_account(uuid) from public, anon, authenticated;

-- Exécute les demandes échues (délai de 30 jours écoulé) sans commande en cours ; les autres restent en attente. À planifier chaque jour :
--   select cron.schedule('process-account-deletions', '30 3 * * *', $$select public.process_account_deletions()$$);
create or replace function process_account_deletions(p_limit integer default 50) returns jsonb
language plpgsql security definer set search_path = public as $$
declare d record; v_done integer := 0; v_blocked jsonb := '[]'::jsonb; v_role text; v_name text;
begin
  for d in select * from account_deletion_requests where status = 'pending' and scheduled_for <= now() order by scheduled_for limit least(greatest(p_limit, 1), 200) for update skip locked loop
    select role::text, name into v_role, v_name from profiles where id = d.user_id;
    if v_role is null or v_role in ('admin', 'dept', 'direction', 'finance', 'support') then
      v_blocked := v_blocked || to_jsonb(d.user_id);
      continue;
    end if;
    if _open_orders(d.user_id) > 0 then
      v_blocked := v_blocked || to_jsonb(d.user_id);
      continue;
    end if;
    perform _anonymize_account(d.user_id);
    update account_deletion_requests set status = 'done', processed_at = now(), processed_by = auth.uid() where user_id = d.user_id;
    insert into audit_log (actor, action, target, category, level)
      values (coalesce((select name from profiles where id = auth.uid()), 'Système'), 'Compte supprimé (anonymisé)', d.user_id::text, 'Comptes', 'Sensible');
    v_done := v_done + 1;
  end loop;
  return jsonb_build_object('processed', v_done, 'blocked', v_blocked);
end $$;
revoke all on function process_account_deletions(integer) from public, anon, authenticated;

create or replace function admin_process_account_deletions() returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  perform _require_staff_aal2();
  return process_account_deletions(50);
end $$;
revoke all on function admin_process_account_deletions() from public, anon;
grant execute on function admin_process_account_deletions() to authenticated;
revoke all on function request_account_deletion(text), account_deletions_pending() from public, anon;
grant execute on function request_account_deletion(text), account_deletions_pending() to authenticated;

-- ============================================================ 4. Export complet : ventes, paiements, candidatures du vendeur
create or replace function export_my_data() returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid(); v_out jsonb := '{}'::jsonb; v_skipped jsonb := '[]'::jsonb; v_trunc jsonb := '[]'::jsonb;
  t record; v_n bigint; v_rows jsonb;
  v_secret text[] := array['token', 'pickup_code', 'secret', 'code_hash', 'access_token', 'refresh_token', 'p256dh', 'auth', 'otp', 'token_hash', 'api_key', 'key_hash'];
begin
  if v_uid is null then raise exception 'Connexion requise'; end if;
  for t in select * from (values
    ('profiles', 'id', 'profiles'), ('terms_acceptances', 'user_id', 'terms_acceptances'), ('account_deletion_requests', 'user_id', 'account_deletion_requests'),
    ('listings', 'seller_id', 'listings'), ('orders', 'buyer_id', 'orders'), ('order_cancellations', 'user_id', 'order_cancellations'), ('order_disputes', 'buyer_id', 'order_disputes'),
    ('claims', 'claimant_id', 'claims'), ('quote_requests', 'requester_id', 'quote_requests'), ('addresses', 'user_id', 'addresses'),
    ('notifications', 'user_id', 'notifications'), ('notification_preferences', 'user_id', 'notification_preferences'), ('notification_contacts', 'user_id', 'notification_contacts'),
    ('user_documents', 'owner_id', 'user_documents'), ('certification_requests', 'user_id', 'certification_requests'),
    ('engagements', 'user_id', 'engagements'), ('favorites', 'user_id', 'favorites'), ('price_alerts', 'user_id', 'price_alerts'), ('shop_follows', 'user_id', 'shop_follows'),
    ('messages', 'sender_id', 'messages'), ('conversation_participants', 'user_id', 'conversation_participants'), ('support_tickets', 'user_id', 'support_tickets'),
    ('posts', 'author_id', 'posts'), ('post_comments', 'author_id', 'post_comments'), ('post_likes', 'user_id', 'post_likes'), ('post_saves', 'user_id', 'post_saves'),
    ('post_reactions', 'user_id', 'post_reactions'), ('stories', 'author_id', 'stories'), ('portfolio_items', 'owner_id', 'portfolio_items'), ('profile_covers', 'user_id', 'profile_covers'),
    ('earnings', 'user_id', 'earnings'), ('credit_wallets', 'user_id', 'credit_wallets'), ('credit_ledger', 'user_id', 'credit_ledger'), ('points_ledger', 'user_id', 'points_ledger'),
    ('referral_codes', 'user_id', 'referral_codes'), ('referrals', 'referrer_id', 'referrals_parrain'), ('referrals', 'referee_id', 'referrals_filleul'),
    ('event_registrations', 'user_id', 'event_registrations'), ('community_members', 'user_id', 'community_members'), ('community_messages', 'sender_id', 'community_messages'),
    ('mentor_profiles', 'user_id', 'mentor_profiles'), ('mentor_requests', 'student_id', 'mentor_requests'), ('mentor_reviews', 'student_id', 'mentor_reviews'),
    ('opportunity_saves', 'user_id', 'opportunity_saves'), ('opportunity_alerts', 'user_id', 'opportunity_alerts'), ('wishes', 'author_id', 'wishes'), ('wish_preorders', 'user_id', 'wish_preorders'),
    ('mission_proposals', 'author_id', 'mission_proposals'), ('momo_numbers', 'user_id', 'momo_numbers'), ('payment_methods', 'owner_id', 'payment_methods'),
    ('shops', 'owner_id', 'shops'), ('company_profiles', 'owner_id', 'company_profiles'), ('projects', 'owner_id', 'projects'), ('device_tokens', 'user_id', 'appareils'),
    ('opportunity_applications', 'applicant_id', 'opportunity_applications'), ('opportunity_invites', 'student_id', 'opportunity_invites'),
    ('payment_transactions', 'payer_id', 'payment_transactions'), ('talent_contacts', 'target_id', 'talent_contacts_recus')
  ) as x(tbl, col, k) loop
    begin
      if to_regclass('public.' || t.tbl) is null
         or not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = t.tbl and column_name = t.col) then
        continue; -- table absente de ce schéma : rien à exporter
      end if;
      execute format('select count(*) from public.%I where %I = $1', t.tbl, t.col) into v_n using v_uid;
      execute format('select coalesce(jsonb_agg(to_jsonb(x) - $2), ''[]''::jsonb) from (select * from public.%I where %I = $1 limit 5000) x', t.tbl, t.col)
        into v_rows using v_uid, v_secret;
      v_out := v_out || jsonb_build_object(t.k, v_rows);
      if v_n > 5000 then v_trunc := v_trunc || to_jsonb(t.k); end if;
    exception when others then
      v_skipped := v_skipped || to_jsonb(t.tbl || '.' || t.col);
    end;
  end loop;
  -- ventes du vendeur : ses lignes de commande (sans aucune donnée sur l'acheteur)
  begin
    v_out := v_out || jsonb_build_object('ventes', coalesce((
      select jsonb_agg(jsonb_build_object('commande', s.number, 'titre', s.title, 'quantite', s.qty, 'prix_unitaire', s.unit_price, 'preparation', s.fulfillment,
                                          'payee', s.paid, 'annulee', s.cancelled_at is not null, 'date', s.created_at) order by s.created_at desc)
      from (select o.number, ol.title, ol.qty, ol.unit_price, ol.fulfillment, o.paid, o.cancelled_at, o.created_at
            from order_lines ol join listings l on l.id = ol.listing_id join orders o on o.id = ol.order_id
            where l.seller_id = v_uid order by o.created_at desc limit 5000) s), '[]'::jsonb));
  exception when others then
    v_skipped := v_skipped || to_jsonb('ventes'::text);
  end;
  return jsonb_build_object('compte', v_uid, 'exporte_le', now(), 'donnees', v_out, 'tables_non_lues', v_skipped, 'tronque', v_trunc);
end $$;
revoke all on function export_my_data() from public, anon;
grant execute on function export_my_data() to authenticated;

-- Retour arrière :
--   drop function if exists mfa_backup_codes_generate(), mfa_backup_codes_status(), mfa_use_backup_code(text), admin_mfa_reset(uuid, text), _session_is_aal2(), _require_staff_aal2(),
--     _mfa_code_hash(uuid, text), my_sales_terms(), _open_orders(uuid), _anonymize_account(uuid), process_account_deletions(integer), admin_process_account_deletions();
--   drop table if exists mfa_backup_codes, mfa_backup_attempts ;
--   réappliquer accept_terms/my_terms/request_account_deletion/account_deletions_pending/export_my_data de 20261115110000_l1_compte_onboarding.sql ;
--   alter table terms_acceptances drop constraint terms_acceptances_version_check, add check (version ~ '^cgu-[0-9]{4}-[0-9]{2}$') (après suppression des lignes cgv-*).
