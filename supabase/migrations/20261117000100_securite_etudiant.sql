-- Sécurité et confidentialité du profil Étudiant-vendeur (corrections transversales, propriété du chef).
--  1. Annonces : une annonce APPROUVÉE modifiée dans ses champs de contenu repasse en modération et prévient les valideurs ; colonnes sensibles
--     (created_at, showcase) figées ; médias limités au stockage Supabase public (plus d'URL externes ni http://).
--  2. Lectures publiques : `wishes` (note de relecture) retirée de l'API directe ; `lives` et `live_messages` fermés aux anonymes.
--  3. Noms : un anonyme ne voit que « Prénom N. » (public_profile) ; l'annuaire des talents n'expose le nom complet qu'aux entreprises et à l'équipe ;
--     my_conversations n'expose plus le nom complet de l'interlocuteur.
--  4. log_audit : plafond quotidien, acteur identifié, niveaux sensibles réservés aux comptes équipe.
--  5. Comptes suspendus : la garde de chaque requête API (db_pre_request) refuse désormais aussi les écritures d'un compte suspendu
--     (RPC d'écriture et écritures directes), en plus de la garde 2FA.
--  6. Virements MoMo depuis le compte marchand : réservés à la finance et à l'administration.
--  7. Création de profil : l'e-mail est celui du compte Auth, jamais un e-mail fourni par le client.
-- Retour arrière : voir le bas du fichier.

-- ============================================================ 1. Annonces
create or replace function protect_listing_status() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  r text := coalesce(current_role_name()::text, '');
  v_media text := '^https://[a-z0-9]+\.supabase\.co/storage/v1/object/public/';
  v_u text;
  v_recheck boolean := false;
  v_ping boolean := false;
  v record;
begin
  if auth.uid() is null or coalesce(current_setting('app.internal', true), '') = '1' then return new; end if;  -- éditeur SQL / fonctions serveur
  if r in ('dept', 'admin') then
    if tg_op = 'UPDATE' then
      new.seller_id := old.seller_id;                               -- un produit de la plateforme reste à la plateforme
      if new.status is distinct from old.status then new.reviewed_by := auth.uid(); end if;
    end if;
    new.updated_at := now();
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.seller_id := auth.uid();                                   -- une annonce appartient toujours à son créateur
    if new.status not in ('draft', 'pending') then new.status := 'pending'; end if;
    new.reviewed_by := null;
    new.review_note := null;
    new.showcase := false;
    v_ping := new.status = 'pending';
  else
    if old.seller_id is distinct from auth.uid() then raise exception 'Annonce d''un autre vendeur'; end if;
    if old.status = 'removed' then raise exception 'Annonce supprimée'; end if;
    if new.status is distinct from old.status and not (
         (old.status = 'draft' and new.status in ('pending', 'removed'))
      or (old.status = 'pending' and new.status in ('draft', 'removed'))
      or (old.status = 'rejected' and new.status in ('draft', 'pending', 'removed'))
      or (old.status = 'approved' and new.status = 'removed')) then
      raise exception 'Transition de statut non autorisée (% vers %)', old.status, new.status;
    end if;
    new.seller_id := old.seller_id;
    new.created_at := old.created_at;
    new.showcase := old.showcase;
    new.reviewed_by := old.reviewed_by;
    new.review_note := case when new.status = 'pending' and old.status <> 'pending' then null else old.review_note end;
    -- Une annonce validée ne change pas de contenu sans nouvelle validation (le prix, le stock et les variantes restent libres).
    if old.status = 'approved' and new.status = 'approved'
       and (new.title is distinct from old.title or new.description is distinct from old.description or new.category is distinct from old.category
            or new.image_url is distinct from old.image_url or new.images is distinct from old.images or new.video_url is distinct from old.video_url
            or new.specs is distinct from old.specs or new.supervisor is distinct from old.supervisor or new.department is distinct from old.department) then
      v_recheck := true;
      new.status := 'pending';
      new.reviewed_by := null;
      new.review_note := null;
    end if;
    v_ping := v_recheck or (new.status = 'pending' and old.status <> 'pending');
  end if;
  -- Médias : uniquement des fichiers du stockage public de l'application (https).
  if tg_op = 'INSERT' or new.image_url is distinct from old.image_url then
    if coalesce(new.image_url, '') <> '' and new.image_url !~ v_media then raise exception 'La photo de l''annonce doit provenir du téléversement de l''application'; end if;
  end if;
  if tg_op = 'INSERT' or new.video_url is distinct from old.video_url then
    if coalesce(new.video_url, '') <> '' and new.video_url !~ v_media then raise exception 'La vidéo de l''annonce doit provenir du téléversement de l''application'; end if;
  end if;
  if tg_op = 'INSERT' or new.images is distinct from old.images then
    foreach v_u in array coalesce(new.images, '{}') loop
      if coalesce(v_u, '') <> '' and v_u !~ v_media then raise exception 'Les photos de l''annonce doivent provenir du téléversement de l''application'; end if;
    end loop;
  end if;
  new.updated_at := now();
  if v_ping then
    for v in select p.id from profiles p
             where not coalesce(p.suspended, false)
               and (p.role::text = 'admin' or (p.role::text = 'dept' and lower(coalesce(p.department, '')) = lower(coalesce(new.department, ''))))
               and not exists (select 1 from notifications n where n.user_id = p.id and n.kind = 'listing_review' and n.read_at is null
                               and n.created_at > now() - interval '15 minutes' and n.data ->> 'listing' = new.id::text) loop
      perform notify_user(v.id, 'listing_review', case when v_recheck then 'Annonce modifiée à revalider' else 'Annonce à valider' end,
                          left('« ' || coalesce(new.title, 'Annonce') || ' » attend votre validation.', 300), jsonb_build_object('listing', new.id));
    end loop;
  end if;
  return new;
end $$;
revoke execute on function protect_listing_status() from public, anon, authenticated;

-- ============================================================ 2. Lectures publiques
-- Les vœux se lisent par wishes_market / wish_get / my_wishes (fonctions SECURITY DEFINER) : plus d'accès direct, la note de relecture n'est plus exposée.
revoke all on wishes from anon, authenticated;
-- Un live et son chat se consultent connecté (la diffusion exige déjà un compte) : plus de lecture anonyme de la salle ni des messages.
revoke select on lives, live_messages from anon;

-- ============================================================ 3. Noms
create or replace function public_profile(p_user uuid)
returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', p.id,
    'name', case when auth.uid() is null
                 then coalesce(nullif(trim(split_part(p.name, ' ', 1) || ' ' || case when split_part(p.name, ' ', 2) <> '' then left(split_part(p.name, ' ', 2), 1) || '.' else '' end), ''), 'Un membre')
                 else p.name end,
    'role', case when p.role::text in ('student', 'company', 'other') then p.role::text else 'student' end,
    'city', coalesce(p.city, ''),
    'institution', coalesce(p.institution, ''),
    'department', coalesce(p.department, ''),
    'bio', coalesce(p.bio, ''),
    'skills', coalesce(p.skills, ''),
    'avatar_url', p.avatar_url,
    'certified', p.certification::text = 'approved',
    'posts_count', (select count(*)::int from posts x where x.author_id = p.id and x.status = 'published' and x.kind = 'media' and x.community_id is null),
    'followers_count', (select count(*)::int from engagements e where e.kind = 'follow' and e.ref = p.id::text and e.status = 'active'),
    'following_count', (select count(*)::int from engagements e where e.kind = 'follow' and e.user_id = p.id and e.status = 'active'),
    'rating', coalesce((select round(avg(r.rating)::numeric, 2) from reviews r join listings l on l.id = r.listing_id where l.seller_id = p.id), 0),
    'rating_count', (select count(*)::int from reviews r join listings l on l.id = r.listing_id where l.seller_id = p.id)
  )
  from profiles p
  where p.id = p_user and not coalesce(p.suspended, false)
    and (
      p.id = auth.uid()
      or (p.role::text in ('student', 'company', 'other'))
      or (p.role::text not in ('admin', 'direction', 'finance', 'support', 'client', 'visitor')
          and (exists (select 1 from posts x where x.author_id = p.id and x.status = 'published' and x.community_id is null)
            or exists (select 1 from listings l where l.seller_id = p.id and l.status = 'approved')))
    );
$$;

create or replace function talents_list(p_query text default '', p_limit int default 20) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_full boolean;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  v_full := coalesce(current_role_name()::text, '') in ('company', 'dept', 'direction', 'admin', 'support');
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', t.id,
                                        'name', case when v_full then t.name
                                                     else coalesce(nullif(trim(split_part(t.name, ' ', 1) || ' ' || case when split_part(t.name, ' ', 2) <> '' then left(split_part(t.name, ' ', 2), 1) || '.' else '' end), ''), 'Un membre') end,
                                        'department', coalesce(t.department, ''), 'institution', coalesce(t.institution, ''),
                                        'skills', coalesce(t.skills, ''), 'city', coalesce(t.city, ''), 'avatar_url', t.avatar_url, 'certified', t.certification::text = 'approved',
                                        'cover_path', t.cover_path, 'cover_kind', t.cover_kind))
    from (
      select * from profiles
      where role::text = 'student' and not suspended and nullif(trim(coalesce(skills, '')), '') is not null
        and (coalesce(trim(p_query), '') = '' or name ilike '%' || trim(p_query) || '%' or skills ilike '%' || trim(p_query) || '%' or coalesce(department, '') ilike '%' || trim(p_query) || '%')
      order by (certification::text = 'approved') desc, created_at desc
      limit least(greatest(p_limit, 1), 50)
    ) t
  ), '[]'::jsonb);
end $$;
revoke all on function talents_list(text, int) from public, anon;
grant execute on function talents_list(text, int) to authenticated;

-- Le nom complet de l'interlocuteur n'est plus exposé : « Prénom N. », comme dans les commandes reçues.
create or replace function my_conversations()
returns table (id uuid, listing_title text, other_name text, last_body text, last_at timestamptz, unread integer, order_number text)
language sql stable security definer set search_path = public as $$
  select c.id, l.title, coalesce(display_name(q.user_id), 'Utilisateur'),
         (select case when m.kind = 'text' then m.body when m.kind = 'image' then 'Photo' when m.kind = 'voice' then 'Message vocal' else 'Fichier : ' || coalesce(m.attachment_name, '') end
            from messages m where m.conversation_id = c.id order by m.id desc limit 1),
         c.last_message_at,
         (select count(*)::int from messages m where m.conversation_id = c.id and m.sender_id <> auth.uid() and m.created_at >= p.last_read_at),
         c.order_number
  from conversations c
  join conversation_participants p on p.conversation_id = c.id and p.user_id = auth.uid()
  left join listings l on l.id = c.listing_id
  left join conversation_participants q on q.conversation_id = c.id and q.user_id <> auth.uid()
  order by c.last_message_at desc
$$;
revoke all on function my_conversations() from public, anon;
grant execute on function my_conversations() to authenticated;

-- ============================================================ 4. Journal d'audit
alter table audit_log add column if not exists actor_id uuid;
create or replace function log_audit(p_action text, p_target text, p_category text, p_level text) returns void
language plpgsql security definer set search_path = public as $$
declare who text; r text := coalesce(current_role_name()::text, ''); v_level text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if r = '' then return; end if;                                    -- compte suspendu : rien n'est journalisé en son nom
  if r not in ('admin', 'direction', 'finance', 'support', 'dept')
     and (select count(*) from audit_log where actor_id = auth.uid() and created_at > now() - interval '1 day') >= 200 then
    return;
  end if;
  select name into who from profiles where id = auth.uid();
  v_level := case when p_level in ('Normal', 'Info') then p_level
                  when p_level in ('Sensible', 'Critique') and r in ('admin', 'direction', 'finance', 'support', 'dept') then p_level
                  else 'Normal' end;
  insert into audit_log (actor, actor_id, action, target, category, level)
  values (coalesce(who, 'Utilisateur'), auth.uid(), left(coalesce(p_action, ''), 120), left(coalesce(p_target, ''), 200), left(coalesce(p_category, ''), 40), v_level);
end $$;
revoke all on function log_audit(text, text, text, text) from public, anon;
grant execute on function log_audit(text, text, text, text) to authenticated;

-- ============================================================ 5. Garde de chaque requête API : 2FA + comptes suspendus
create or replace function enforce_mfa_on_sensitive() returns void
language plpgsql stable security definer set search_path = public, auth as $$
declare
  v_path text := coalesce(current_setting('request.path', true), '');
  v_method text := upper(coalesce(current_setting('request.method', true), ''));
  v_claims jsonb;
  v_uid uuid;
  v_deny boolean := false;
  v_susp boolean := false;
begin
  -- Compte suspendu : plus aucune écriture (RPC d'écriture ou écriture directe), même avec un jeton encore valide. Les lectures restent possibles.
  if v_method in ('POST', 'PATCH', 'PUT', 'DELETE') then
    begin
      v_claims := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
      v_uid := nullif(v_claims ->> 'sub', '')::uuid;
      if v_uid is not null and exists (select 1 from public.profiles where id = v_uid and coalesce(suspended, false)) then
        if v_path !~ '^/rpc/' then
          v_susp := true;
        elsif v_path !~ '^/rpc/(support_ticket_create|request_account_deletion|cancel_account_deletion|accept_terms|unregister_device|unregister_all_devices|log_audit)$'
              and (v_path ~ '^/rpc/(create|save|set|submit|update|delete|remove|add|send|post|publish|toggle|register|invite|request|propose|start|end|ban|join|leave|apply|claim|cancel|report|answer|ask|vote|enter|follow|unfollow|like|comment|pay|checkout|order|decide|upload|issue|confirm|withdraw|accept|decline|reply|share|boost|gift|book|reserve|schedule|record|mark|open|close|upsert|insert|edit|change|assign|attach|link|daily|flash|pack|campaign|shop|mentor|opp|quote|dispute|momo|payment|subscription|event|wish|duel|live|story|reel|community|portfolio|profile|project|skill|sos|victory|challenge|qr|kiosk|mission|milestone|document|institution|department|catalog|delivery|promo|company|ad|ann|teammate|hackathon|address|price|notification|device)_'
                  or v_path ~ '_(save|submit|close|cancel|start|checkout|declare|create|update|delete|remove|set|add|publish|apply|decide|answer|reply|toggle|register|invite|join|leave|issue|enter|confirm|claim|checkin|boost)$') then
          v_susp := true;
        end if;
      end if;
    exception when others then
      v_susp := false;
    end;
  end if;
  if v_susp then
    raise exception 'Compte suspendu : cette action est impossible. Contactez le support.' using errcode = '42501';
  end if;

  if v_path !~ '^/rpc/(request_account_deletion|export_my_data|profile_set_phone|set_whatsapp_number|payment_start|payment_declare|payment_set_status|marketplace_checkout|create_order|cancel_order|confirm_cod_order|company_plan_checkout|subscription_start|campaign_contribute|event_checkout|ann_prize_checkout|ann_prize_set|ann_prize_award|ann_prize_refund|request_referral_payout|referral_payout_decide|payout_create|payout_set_status|money_release_now|dispute_decide|admin_set_account|request_seller_payout|seller_payout_decide|momo_prepare_transfer)$' then
    return;
  end if;
  -- Toute erreur de lecture laisse passer la requête : la garde ne doit jamais rendre l'API indisponible.
  begin
    v_claims := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
    v_uid := nullif(v_claims ->> 'sub', '')::uuid;
    if v_uid is not null and coalesce(v_claims ->> 'aal', 'aal1') <> 'aal2'
       and exists (select 1 from auth.mfa_factors where user_id = v_uid and status = 'verified') then
      v_deny := true;
    end if;
  exception when others then
    v_deny := false;
  end;
  if v_deny then
    raise exception 'Confirmez votre identité avec votre code de double authentification pour effectuer cette opération.' using errcode = '42501';
  end if;
end $$;
grant execute on function enforce_mfa_on_sensitive() to anon, authenticated, service_role;

-- ============================================================ 6. MoMo : un virement depuis le compte marchand de la plateforme est une opération de trésorerie
create or replace function momo_prepare_transfer(p_number uuid, p_to text, p_amount int, p_note text, p_idem text) returns text
language plpgsql security definer set search_path = public as $$
declare n momo_numbers%rowtype; v_to text := momo_normalize(p_to); v_ref text; v_max int;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('finance', 'admin') then raise exception 'Les virements Mobile Money sont réservés à la finance'; end if;
  if coalesce(length(p_idem), 0) < 8 then raise exception 'Clé d''unicité manquante'; end if;
  select reference into v_ref from momo_transactions where user_id = auth.uid() and idempotency_key = p_idem;
  if found then return v_ref; end if;
  select * into n from momo_numbers where id = p_number and user_id = auth.uid();
  if not found then raise exception 'Numéro introuvable'; end if;
  if n.verification_status <> 'verified' then raise exception 'Vérifiez ce numéro avant d''envoyer de l''argent'; end if;
  if v_to !~ '^2376[0-9]{8}$' then raise exception 'Numéro du destinataire invalide'; end if;
  if v_to = n.phone then raise exception 'Le destinataire doit être différent de l''expéditeur'; end if;
  v_max := coalesce((select (value #>> '{}')::int from platform_settings where key = 'momo.transfer_max'), 500000);
  if p_amount is null or p_amount < 1 or p_amount > v_max then raise exception 'Montant invalide (1 à % FCFA)', v_max; end if;
  if exists (select 1 from momo_transactions where user_id = auth.uid() and number_id = p_number and counterparty_phone = v_to and amount = p_amount
             and status in ('awaiting_confirmation', 'pending') and created_at > now() - interval '5 minutes') then
    raise exception 'Un envoi identique est déjà en cours';
  end if;
  v_ref := 'MM' || to_char(now(), 'YYMMDD') || lpad(nextval('momo_ref_seq')::text, 6, '0');
  insert into momo_transactions (reference, user_id, number_id, operator, direction, counterparty_phone, amount, note, idempotency_key)
    values (v_ref, auth.uid(), p_number, n.operator, 'out', v_to, p_amount, left(trim(coalesce(p_note, '')), 120), p_idem);
  return v_ref;
end $$;
revoke all on function momo_prepare_transfer(uuid, text, int, text, text) from public, anon;
grant execute on function momo_prepare_transfer(uuid, text, int, text, text) to authenticated;

-- ============================================================ 7. Création de profil : l'e-mail est celui du compte Auth
create or replace function protect_profile_authority() returns trigger
language plpgsql security definer set search_path = public, auth as $$
begin
  if tg_op = 'INSERT' then
    if auth.uid() is not null and coalesce(current_role_name()::text, '') <> 'admin' then
      new.certification := 'none';
      new.certification_decided_by := null;
      new.certification_decided_at := null;
      new.is_test := false;
      new.email := (select u.email from auth.users u where u.id = auth.uid());
    end if;
    return new;
  end if;
  if auth.uid() is not null and coalesce(current_setting('app.cert_rpc', true), '') <> '1'
     and (new.certification is distinct from old.certification
          or new.certification_decided_by is distinct from old.certification_decided_by
          or new.certification_decided_at is distinct from old.certification_decided_at) then
    raise exception 'La certification ne peut être modifiée que par la procédure de certification';
  end if;
  if auth.uid() is not null
     and (new.role is distinct from old.role or new.suspended is distinct from old.suspended or new.is_test is distinct from old.is_test)
     and coalesce(current_role_name()::text, '') <> 'admin' then
    raise exception 'Modification du rôle ou du statut réservée à l''administrateur';
  end if;
  if auth.uid() is not null and coalesce(current_role_name()::text, '') <> 'admin' then
    if new.email is distinct from old.email then
      raise exception 'L''adresse e-mail se change depuis la sécurité du compte';
    end if;
    if new.phone is distinct from old.phone and coalesce(old.phone, '') <> '' and coalesce(current_setting('app.phone_rpc', true), '') <> '1' then
      raise exception 'Pour changer de numéro, contactez le support';
    end if;
  end if;
  return new;
end $$;

-- Retour arrière :
--   protect_listing_status : réappliquer la définition de 20261101000100_produits_plateforme.sql ;
--   grant select on wishes to anon, authenticated ; grant select on lives, live_messages to anon ;
--   public_profile (20261115000100_securite_client.sql), talents_list (20261112000000_couverture_profil.sql), my_conversations (20261115160000_l6_aide_notifications_evenements.sql),
--   log_audit (20261029000100_p1_securite.sql), enforce_mfa_on_sensitive (20261116000100_mfa_serveur.sql), momo_prepare_transfer (20261109000000_integrations_hub.sql),
--   protect_profile_authority (20261115000100_securite_client.sql) ; alter table audit_log drop column actor_id.
