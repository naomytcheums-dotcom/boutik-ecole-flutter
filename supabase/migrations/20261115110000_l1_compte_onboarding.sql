-- Lot L1 « Démarrage, compte, onboarding » :
--   1. acceptation des conditions réellement enregistrée (accept_terms, my_terms) ;
--   2. suppression de compte : demande avec délai de rétractation de 30 jours, annulation possible, administration prévenue ;
--   3. export complet des données personnelles (export_my_data) ;
--   4. dépôt d'une pièce justificative : contrôle du fichier réellement stocké et notification de l'équipe de validation.
-- Retour arrière : voir la fin du fichier.

-- ============================================================ 1. Conditions d'utilisation
-- Pas de clé vers profiles : l'acceptation est donnée à l'inscription, avant la création du profil (écran 13).
create table if not exists terms_acceptances (
  user_id uuid not null references auth.users(id) on delete cascade,
  version text not null check (version ~ '^cgu-[0-9]{4}-[0-9]{2}$'),
  accepted_at timestamptz not null default now(),
  primary key (user_id, version)
);
alter table terms_acceptances enable row level security;
revoke all on terms_acceptances from anon, authenticated;
grant select on terms_acceptances to authenticated;
drop policy if exists "conditions acceptées : titulaire et équipe" on terms_acceptances;
create policy "conditions acceptées : titulaire et équipe" on terms_acceptances for select
  using (user_id = auth.uid() or is_platform_staff());

-- Les acceptations déjà enregistrées par l'ancienne action « engage » sont reprises.
insert into terms_acceptances (user_id, version, accepted_at)
  select e.user_id, e.ref, e.created_at from engagements e
  where e.kind = 'terms_accepted' and e.ref ~ '^cgu-[0-9]{4}-[0-9]{2}$'
    and exists (select 1 from auth.users u where u.id = e.user_id)
on conflict do nothing;

-- 'recorded' : acceptation enregistrée ; 'already' : cette version était déjà acceptée.
create or replace function accept_terms(p_version text default 'cgu-2026-10') returns text
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_version is null or p_version !~ '^cgu-[0-9]{4}-[0-9]{2}$' then raise exception 'Version des conditions inconnue'; end if;
  insert into terms_acceptances (user_id, version) values (auth.uid(), p_version) on conflict do nothing;
  return case when found then 'recorded' else 'already' end;
end $$;

-- Dernière version acceptée par la personne connectée, ou null.
create or replace function my_terms() returns text
language sql stable security definer set search_path = public as $$
  select version from terms_acceptances where user_id = auth.uid() order by accepted_at desc limit 1
$$;

revoke all on function accept_terms(text), my_terms() from public, anon;
grant execute on function accept_terms(text), my_terms() to authenticated;

-- ============================================================ 2. Suppression de compte (délai de rétractation de 30 jours)
create table if not exists account_deletion_requests (
  user_id uuid primary key references profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'cancelled', 'done')),
  reason text check (reason is null or char_length(reason) <= 500),
  requested_at timestamptz not null default now(),
  scheduled_for timestamptz not null,
  cancelled_at timestamptz,
  processed_at timestamptz,
  processed_by uuid references profiles(id) on delete set null
);
create index if not exists account_deletion_requests_due on account_deletion_requests (scheduled_for) where status = 'pending';
alter table account_deletion_requests enable row level security;
revoke all on account_deletion_requests from anon, authenticated;
grant select on account_deletion_requests to authenticated;
drop policy if exists "suppression de compte : titulaire et administration" on account_deletion_requests;
create policy "suppression de compte : titulaire et administration" on account_deletion_requests for select
  using (user_id = auth.uid() or is_platform_staff());

-- Demandes déjà déposées par l'ancienne action « engage » : elles entrent dans le même circuit (délai compté depuis leur dépôt).
insert into account_deletion_requests (user_id, status, requested_at, scheduled_for)
  select e.user_id, 'pending', e.created_at, e.created_at + interval '30 days' from engagements e
  where e.kind = 'account_deletion_request' and e.status = 'active' and exists (select 1 from profiles p where p.id = e.user_id)
on conflict do nothing;

-- Dépose la demande : 30 jours de rétractation, l'administration et le support sont notifiés. Retourne {status, scheduled_for, already}.
create or replace function request_account_deletion(p_reason text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_role text; v_name text; v_when timestamptz; r account_deletion_requests%rowtype;
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

create or replace function cancel_account_deletion() returns text
language plpgsql security definer set search_path = public as $$
declare v_name text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  update account_deletion_requests set status = 'cancelled', cancelled_at = now() where user_id = auth.uid() and status = 'pending';
  if not found then raise exception 'Aucune demande de suppression en cours'; end if;
  select name into v_name from profiles where id = auth.uid();
  insert into notifications (user_id, kind, title, body, data)
    select a.id, 'account_deletion', 'Suppression de compte annulée', coalesce(v_name, 'Un compte') || ' a annulé sa demande de suppression.', jsonb_build_object('user', auth.uid())
    from profiles a where a.role::text in ('admin', 'support');
  return 'cancelled';
end $$;

-- Demande en cours de la personne connectée ({status, requested_at, scheduled_for}) ou null.
create or replace function my_account_deletion() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('status', status, 'requested_at', requested_at, 'scheduled_for', scheduled_for)
  from account_deletion_requests where user_id = auth.uid() and status = 'pending'
$$;

-- Équipe (administration, support) : demandes en attente, les plus proches de leur échéance d'abord. « due » : le délai de 30 jours est écoulé.
create or replace function account_deletions_pending() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_platform_staff() then raise exception 'Action non autorisée'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('user_id', d.user_id, 'name', p.name, 'email', p.email, 'role', p.role::text, 'requested_at', d.requested_at,
                                        'scheduled_for', d.scheduled_for, 'due', d.scheduled_for <= now()) order by d.scheduled_for)
    from account_deletion_requests d join profiles p on p.id = d.user_id where d.status = 'pending'), '[]'::jsonb);
end $$;

revoke all on function request_account_deletion(text), cancel_account_deletion(), my_account_deletion(), account_deletions_pending() from public, anon;
grant execute on function request_account_deletion(text), cancel_account_deletion(), my_account_deletion(), account_deletions_pending() to authenticated;

-- ============================================================ 3. Export complet des données personnelles
-- Parcourt une liste fixe (table, colonne propriétaire) : une table absente de ce schéma est ignorée, une lecture en erreur est signalée (« tables_non_lues »), jamais fatale.
-- Seules les lignes de la personne connectée sont lues (jamais celles d'un tiers, même quand elles figurent dans une conversation ou une commande).
-- Les jetons actifs (codes de retrait, codes QR, jetons d'appareil, clés) sont retirés du résultat. 5 000 lignes au plus par table (« tronque » l'indique).
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
    ('shops', 'owner_id', 'shops'), ('company_profiles', 'owner_id', 'company_profiles'), ('projects', 'owner_id', 'projects'), ('device_tokens', 'user_id', 'appareils')
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
  return jsonb_build_object('compte', v_uid, 'exporte_le', now(), 'donnees', v_out, 'tables_non_lues', v_skipped, 'tronque', v_trunc);
end $$;

revoke all on function export_my_data() from public, anon;
grant execute on function export_my_data() to authenticated;

-- ============================================================ 4. Pièces justificatives : fichier réellement stocké, équipe prévenue
-- Définition précédente : 20261104000100. Nouveautés : type, format et poids contrôlés (le poids et le format du fichier stocké font foi, pas ceux
-- déclarés par l'application) ; l'administration et le support reçoivent une notification pour la première pièce en attente d'une personne.
create or replace function document_register(p_kind text, p_path text, p_name text, p_mime text, p_size int) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_meta jsonb; v_mime text := p_mime; v_size int := p_size; v_owner text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if (storage.foldername(p_path))[1] is distinct from auth.uid()::text then raise exception 'Chemin de fichier non autorisé'; end if;
  select metadata into v_meta from storage.objects where bucket_id = 'profile-documents' and name = p_path;
  if not found then raise exception 'Fichier absent du stockage'; end if;
  if p_kind is null or p_kind not in ('student_card', 'enrollment_certificate', 'diploma', 'certificate', 'cv', 'other') then raise exception 'Type de pièce inconnu'; end if;
  if v_meta is not null then
    v_mime := coalesce(nullif(v_meta ->> 'mimetype', ''), v_mime);
    begin
      v_size := coalesce((v_meta ->> 'size')::int, v_size);
    exception when others then
      v_size := p_size;
    end;
  end if;
  if v_mime is null or v_mime not in ('image/jpeg', 'image/png', 'image/webp', 'application/pdf') then raise exception 'Format non accepté (PDF, JPG, PNG ou WebP)'; end if;
  if v_size is null or v_size < 1 or v_size > 10485760 then raise exception 'Fichier trop lourd (10 Mo au maximum)'; end if;
  if exists (select 1 from user_documents where path = p_path) then raise exception 'Ce fichier est déjà enregistré'; end if;
  if (select count(*) from user_documents where owner_id = auth.uid()) >= 30 then raise exception 'Trop de documents : supprimez-en avant d''en ajouter'; end if;
  insert into user_documents (owner_id, kind, name, path, mime, size_bytes) values (auth.uid(), p_kind, left(coalesce(nullif(btrim(p_name), ''), 'document'), 160), p_path, v_mime, v_size) returning id into v_id;
  insert into user_document_history (document_id, status, actor_id) values (v_id, 'pending', auth.uid());
  if (select count(*) from user_documents where owner_id = auth.uid() and status = 'pending') = 1 then
    select coalesce(name, 'Un compte') into v_owner from profiles where id = auth.uid();
    insert into notifications (user_id, kind, title, body, data)
      select a.id, 'verification', 'Pièce justificative à examiner', v_owner || ' a déposé une pièce justificative en attente de validation.',
             jsonb_build_object('user', auth.uid(), 'document', v_id)
      from profiles a where a.role::text in ('admin', 'support');
  end if;
  return v_id;
end $$;

revoke all on function document_register(text, text, text, text, int) from public, anon;
grant execute on function document_register(text, text, text, text, int) to authenticated;

-- Retour arrière :
--   drop function if exists accept_terms(text), my_terms(), request_account_deletion(text), cancel_account_deletion(), my_account_deletion(),
--     account_deletions_pending(), export_my_data();
--   drop table if exists terms_acceptances, account_deletion_requests;
--   document_register : réappliquer la définition de 20261104000100_referentiels_profil_documents.sql.
