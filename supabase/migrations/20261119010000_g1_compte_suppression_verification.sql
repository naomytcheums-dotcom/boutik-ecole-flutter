-- Lot G1 (inscription, vérification, compte, CGU/CGV, suppression) — suppression de compte réelle et état de vérification lisible.
--   1. Suppression de compte : la demande est refusée, et l'exécution (process_account_deletions) reste GELÉE, tant que le compte a de l'argent en jeu :
--      commandes en cours, argent gardé en séquestre ou gelé, solde débloqué non retiré, retrait demandé ou prévu, somme à reverser (paiement à la livraison),
--      réclamation ou litige ouvert. Rien n'est perdu : la demande reste en attente, la personne et l'équipe voient ce qui bloque (blocked_reason).
--   2. Exécution : au-delà des données déjà anonymisées, les devis ouverts sont clos, et les contenus strictement personnels (histoires, portfolio,
--      mentions « j'aime », enregistrements, réactions, appartenances, couverture) sont retirés ; commandes, paiements, écritures et gains sont conservés.
--   3. my_student_status : ajoute l'état du téléphone, du département renseigné et de la suspension (l'étudiant voit ce qui manque pour être vérifié).
-- Additive et rejouable. Retour arrière : voir la fin du fichier.

alter table account_deletion_requests add column if not exists blocked_reason text;
alter table account_deletion_requests add column if not exists blocked_at timestamptz;
alter table account_deletion_requests add column if not exists blocked_notified_at timestamptz;

-- ============================================================ 1. Ce qui empêche la suppression
-- Pas de grant : uniquement appelée par les fonctions SECURITY DEFINER ci-dessous.
create or replace function _account_blockers(p_user uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  w jsonb := '{}'::jsonb; v_orders integer := 0; v_cases integer := 0; v_held integer; v_avail integer; v_pending integer; v_owed integer; v_list text[] := '{}';
begin
  v_orders := coalesce(_open_orders(p_user), 0);
  begin w := coalesce(money_wallet(p_user), '{}'::jsonb); exception when others then w := '{}'::jsonb; end;
  v_held := coalesce((w ->> 'held')::int, 0);
  v_avail := coalesce((w ->> 'available')::int, 0);
  v_pending := coalesce((w ->> 'requested')::int, 0) + coalesce((w ->> 'scheduled')::int, 0);
  v_owed := coalesce((w ->> 'owed')::int, 0);
  begin
    v_cases := (select count(*) from claims where claimant_id = p_user and status = 'open')
             + (select count(*) from order_disputes where buyer_id = p_user and status = 'open');
  exception when others then v_cases := 0;
  end;
  if v_orders > 0 then v_list := v_list || (v_orders || ' commande(s) en cours (à recevoir ou à livrer)'); end if;
  if v_held > 0 then v_list := v_list || (v_held || ' FCFA gardés en séquestre jusqu''à la livraison'); end if;
  if v_pending > 0 then v_list := v_list || (v_pending || ' FCFA de retrait demandé ou prévu, pas encore versé'); end if;
  if v_avail >= coalesce(_payout_limit('payouts.min', 1000), 1000) then v_list := v_list || (v_avail || ' FCFA de solde disponible à retirer');
  elsif v_avail > 0 then v_list := v_list || (v_avail || ' FCFA de solde, sous le minimum de retrait : contactez le support pour le recevoir');
  end if;
  if v_owed > 0 then v_list := v_list || (v_owed || ' FCFA à reverser (paiements à la livraison)'); end if;
  if v_cases > 0 then v_list := v_list || (v_cases || ' réclamation(s) ou litige(s) ouvert(s)'); end if;
  return jsonb_build_object('open_orders', v_orders, 'held', v_held, 'available', v_avail, 'payout_pending', v_pending, 'owed', v_owed, 'open_cases', v_cases,
                            'blocking', coalesce(array_length(v_list, 1), 0) > 0, 'reason', array_to_string(v_list, ' ; '));
end $$;
revoke all on function _account_blockers(uuid) from public, anon, authenticated;

-- ============================================================ 2. Demande, lecture, liste d'équipe
create or replace function request_account_deletion(p_reason text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_role text; v_name text; v_when timestamptz; r account_deletion_requests%rowtype; b jsonb;
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
  b := _account_blockers(auth.uid());
  if (b ->> 'blocking')::boolean then
    raise exception 'La suppression du compte est impossible pour le moment : %. Terminez ces opérations (livraison, retrait de votre solde, clôture des réclamations) puis refaites la demande.', b ->> 'reason';
  end if;
  v_when := now() + interval '30 days';
  insert into account_deletion_requests (user_id, status, reason, requested_at, scheduled_for)
    values (auth.uid(), 'pending', left(nullif(btrim(coalesce(p_reason, '')), ''), 500), now(), v_when)
  on conflict (user_id) do update set status = 'pending', reason = excluded.reason, requested_at = now(), scheduled_for = v_when,
    cancelled_at = null, processed_at = null, processed_by = null, blocked_reason = null, blocked_at = null, blocked_notified_at = null;
  insert into notifications (user_id, kind, title, body, data)
    select a.id, 'account_deletion', 'Demande de suppression de compte',
           coalesce(v_name, 'Un compte') || ' demande la suppression de son compte. Suppression possible à partir du ' || to_char(v_when, 'DD/MM/YYYY') || ' (délai de rétractation de 30 jours).',
           jsonb_build_object('user', auth.uid(), 'scheduled_for', v_when)
    from profiles a where a.role::text in ('admin', 'support');
  insert into notifications (user_id, kind, title, body, data)
    values (auth.uid(), 'account_deletion', 'Demande de suppression enregistrée',
            'Votre compte sera supprimé à partir du ' || to_char(v_when, 'DD/MM/YYYY') || ', à condition qu''aucune commande ni aucun argent ne soit encore en jeu. Jusqu''à cette date, vous pouvez annuler la demande depuis « Mes données ».',
            jsonb_build_object('scheduled_for', v_when));
  return jsonb_build_object('status', 'pending', 'scheduled_for', v_when, 'already', false);
end $$;

-- Demande en cours de la personne connectée, avec ce qui bloque aujourd'hui son exécution (null si rien ne bloque).
create or replace function my_account_deletion() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare r account_deletion_requests%rowtype; b jsonb;
begin
  if auth.uid() is null then return null; end if;
  select * into r from account_deletion_requests where user_id = auth.uid() and status = 'pending';
  if not found then return null; end if;
  b := _account_blockers(auth.uid());
  return jsonb_build_object('status', r.status, 'requested_at', r.requested_at, 'scheduled_for', r.scheduled_for,
                            'blocked', (b ->> 'blocking')::boolean, 'blocked_reason', case when (b ->> 'blocking')::boolean then b ->> 'reason' else null end);
end $$;

create or replace function account_deletions_pending() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_platform_staff() then raise exception 'Action non autorisée'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('user_id', d.user_id, 'name', p.name, 'email', p.email, 'role', p.role::text, 'requested_at', d.requested_at,
                                        'scheduled_for', d.scheduled_for, 'due', d.scheduled_for <= now(), 'open_orders', _open_orders(d.user_id),
                                        'blocked', (_account_blockers(d.user_id) ->> 'blocking')::boolean, 'blocked_reason', _account_blockers(d.user_id) ->> 'reason') order by d.scheduled_for)
    from account_deletion_requests d join profiles p on p.id = d.user_id where d.status = 'pending'), '[]'::jsonb);
end $$;

-- ============================================================ 3. Anonymisation : devis clos, contenus personnels retirés
create or replace function _anonymize_account(p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
declare t record;
begin
  perform set_config('app.cert_rpc', '1', true);
  update profiles set name = 'Compte supprimé', email = null, phone = null, phone_verified = false, bio = '', skills = '', links = '[]'::jsonb, city = null, birth = null,
    avatar_url = null, cover_path = null, cover_kind = null, matricule = null, study_level = null, institution = '', department = '',
    institution_id = null, department_id = null, certification = 'none', suspended = true
  where id = p_user;
  perform set_config('app.cert_rpc', '', true);
  begin update shops set status = 'closed' where owner_id = p_user and status <> 'closed'; exception when others then null; end;
  begin update listings set status = 'removed' where seller_id = p_user and status in ('draft', 'pending', 'approved'); exception when others then null; end;
  -- Devis encore ouverts : clos (le demandeur ou le prestataire concerné ne reste pas en attente d'une réponse qui ne viendra plus).
  begin update quote_requests set status = 'cancelled' where requester_id = p_user and status in ('requested', 'quoted'); exception when others then null; end;
  begin update quote_requests set status = 'declined' where provider_id = p_user and status in ('requested', 'quoted'); exception when others then null; end;
  for t in select * from (values
    ('addresses', 'user_id'), ('notifications', 'user_id'), ('notification_preferences', 'user_id'), ('notification_contacts', 'user_id'), ('device_tokens', 'user_id'),
    ('favorites', 'user_id'), ('price_alerts', 'user_id'), ('shop_follows', 'user_id'), ('payment_methods', 'owner_id'), ('momo_numbers', 'user_id'),
    ('user_documents', 'owner_id'), ('certification_requests', 'user_id'), ('mentor_profiles', 'user_id'), ('opportunity_saves', 'user_id'),
    ('opportunity_alerts', 'user_id'), ('cv_links', 'owner_id'), ('mfa_backup_codes', 'user_id'),
    ('stories', 'author_id'), ('portfolio_items', 'owner_id'), ('post_likes', 'user_id'), ('post_saves', 'user_id'), ('post_reactions', 'user_id'),
    ('community_members', 'user_id'), ('profile_covers', 'user_id')
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
  begin
    update auth.users set email = 'supprime-' || p_user::text || '@supprime.invalid', raw_user_meta_data = '{}'::jsonb, banned_until = 'infinity', encrypted_password = ''
      where id = p_user;
  exception when others then null;
  end;
  begin delete from auth.sessions where user_id = p_user; exception when others then null; end;
  begin delete from auth.mfa_factors where user_id = p_user; exception when others then null; end;
end $$;
revoke all on function _anonymize_account(uuid) from public, anon, authenticated;

-- ============================================================ 4. Exécution : gelée tant que de l'argent ou une commande est en jeu
create or replace function process_account_deletions(p_limit integer default 50) returns jsonb
language plpgsql security definer set search_path = public as $$
declare d record; v_done integer := 0; v_blocked jsonb := '[]'::jsonb; v_role text; v_name text; b jsonb;
begin
  for d in select * from account_deletion_requests where status = 'pending' and scheduled_for <= now() order by scheduled_for limit least(greatest(p_limit, 1), 200) for update skip locked loop
    select role::text, name into v_role, v_name from profiles where id = d.user_id;
    if v_role is null or v_role in ('admin', 'dept', 'direction', 'finance', 'support') then
      v_blocked := v_blocked || to_jsonb(d.user_id);
      continue;
    end if;
    b := _account_blockers(d.user_id);
    if (b ->> 'blocking')::boolean then
      v_blocked := v_blocked || to_jsonb(d.user_id);
      update account_deletion_requests set blocked_reason = left(b ->> 'reason', 500), blocked_at = coalesce(blocked_at, now()) where user_id = d.user_id;
      if d.blocked_notified_at is null or d.blocked_notified_at < now() - interval '7 days' then
        insert into notifications (user_id, kind, title, body, data)
          values (d.user_id, 'account_deletion', 'Suppression de compte en attente',
                  'Le délai de 30 jours est écoulé, mais votre compte ne peut pas être supprimé tant que : ' || (b ->> 'reason') || '. Terminez ces opérations ; la suppression sera alors exécutée, ou annulez votre demande depuis « Mes données ».',
                  jsonb_build_object('blocked', true));
        update account_deletion_requests set blocked_notified_at = now() where user_id = d.user_id;
      end if;
      continue;
    end if;
    perform _anonymize_account(d.user_id);
    update account_deletion_requests set status = 'done', processed_at = now(), processed_by = auth.uid(), blocked_reason = null where user_id = d.user_id;
    insert into audit_log (actor, action, target, category, level)
      values (coalesce((select name from profiles where id = auth.uid()), 'Système'), 'Compte supprimé (anonymisé)', d.user_id::text, 'Comptes', 'Sensible');
    v_done := v_done + 1;
  end loop;
  return jsonb_build_object('processed', v_done, 'blocked', v_blocked);
end $$;
revoke all on function process_account_deletions(integer) from public, anon, authenticated;

revoke all on function request_account_deletion(text), my_account_deletion(), account_deletions_pending() from public, anon;
grant execute on function request_account_deletion(text), my_account_deletion(), account_deletions_pending() to authenticated;

-- ============================================================ 5. État de vérification : téléphone, département, suspension
create or replace function my_student_status() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare p profiles%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into p from profiles where id = auth.uid();
  if p.id is null then return null; end if;
  return jsonb_build_object(
    'role', p.role::text, 'certification', p.certification::text, 'verified', is_verified_student(p.id),
    'can_request_certification', p.role::text in ('student', 'company', 'other') and p.certification::text in ('none', 'rejected') and not coalesce(p.suspended, false),
    'has_identity_document', exists (select 1 from user_documents d where d.owner_id = p.id and d.kind in ('student_card', 'enrollment_certificate') and d.status <> 'rejected'),
    'has_phone', coalesce(p.phone, '') <> '', 'phone_verified', coalesce(p.phone_verified, false),
    'has_department', p.department_id is not null or p.institution_id is not null,
    'suspended', coalesce(p.suspended, false),
    'rejected_documents', coalesce((select jsonb_agg(jsonb_build_object('kind', d.kind, 'note', d.review_note) order by d.created_at desc)
                                    from user_documents d where d.owner_id = p.id and d.status = 'rejected' and d.kind in ('student_card', 'enrollment_certificate')), '[]'::jsonb),
    'documents', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'kind', d.kind, 'name', d.name, 'status', d.status, 'review_note', d.review_note) order by d.created_at desc)
                           from user_documents d where d.owner_id = p.id), '[]'::jsonb));
end $$;
revoke all on function my_student_status() from public, anon;
grant execute on function my_student_status() to authenticated;

-- Retour arrière :
--   drop function if exists _account_blockers(uuid) ; alter table account_deletion_requests drop column if exists blocked_reason, drop column if exists blocked_at, drop column if exists blocked_notified_at ;
--   réappliquer request_account_deletion, account_deletions_pending, _anonymize_account, process_account_deletions de 20261117010100_s1_compte_securite.sql,
--   my_account_deletion de 20261115110000_l1_compte_onboarding.sql et my_student_status de 20261117010000_s1_etudiant_verifie.sql.
