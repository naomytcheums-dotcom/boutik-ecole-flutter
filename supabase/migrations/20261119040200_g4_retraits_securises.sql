-- Lot G4 (argent du vendeur) 3/3 : retraits sécurisés.
--   - Un retrait est un pouvoir sensible (décision 2 du chef) : il exige un compte actif, un téléphone VÉRIFIÉ (profiles.phone_verified) et, pour un étudiant, le statut d'étudiant vérifié
--     (is_verified_student : pièce validée ou certification). Le message dit précisément ce qui manque.
--   - Délai de sécurité sur le numéro Mobile Money : un numéro enregistré (ou re-enregistré) depuis moins de « payouts.number_delay_hours » heures (réglage de plateforme, 24 h par défaut)
--     ne reçoit aucun retrait. Sans cela, un accès volé au compte pouvait ajouter un numéro et vider le solde dans la minute. Chaque nouveau numéro est signalé au titulaire (notification + audit_log).
--   - Le minimum (« payouts.min », 1 000 FCFA) et le maximum (« payouts.max », 500 000 FCFA) par demande restent les règles existantes ; AUCUN frais de retrait n'existe dans la base : aucun n'est prélevé ni affiché.
--   - Compte suspendu : plus de nouvelle demande ni de versement par la finance (un rejet reste possible, le montant redevient disponible) ; l'argent déjà en séquestre est gelé (voir money_try_release).
--   - Annulation d'une demande : inscrite dans audit_log ; my_payouts indique les numéros utilisables, la date d'ouverture de chacun, le délai et ce qui bloque un retrait.
-- Retour arrière : recréer request_seller_payout, payout_cancel_request, my_payouts, payout_create, payout_set_status (20261117040300) et save_payment_method (20261113000200) ;
--   drop function _payout_number_delay_hours(), _payout_blocker(uuid), _payout_method_usable_at(payment_methods).

create or replace function _payout_number_delay_hours() returns integer
language sql stable security definer set search_path = public as $$
  select coalesce((select least(greatest((value #>> '{}')::numeric, 0), 720)::int from platform_settings where key = 'payouts.number_delay_hours' and jsonb_typeof(value) = 'number'), 24)
$$;
revoke all on function _payout_number_delay_hours() from public, anon, authenticated;

create or replace function _payout_method_usable_at(pm payment_methods) returns timestamptz
language sql stable security definer set search_path = public as $$
  select pm.created_at + make_interval(hours => _payout_number_delay_hours())
$$;
revoke all on function _payout_method_usable_at(payment_methods) from public, anon, authenticated;

-- Ce qui empêche un vendeur de demander un retrait (null si rien).
create or replace function _payout_blocker(p_user uuid) returns text
language plpgsql stable security definer set search_path = public as $$
declare p profiles%rowtype;
begin
  select * into p from profiles where id = p_user;
  if not found then return 'Compte introuvable'; end if;
  if coalesce(p.suspended, false) then return 'Compte suspendu : les retraits sont gelés jusqu''à la levée de la suspension'; end if;
  if not coalesce(p.phone_verified, false) then return 'Vérifiez d''abord votre numéro de téléphone (Paramètres > Informations personnelles) : un retrait exige un téléphone vérifié'; end if;
  if p.role::text = 'student' and not is_verified_student(p_user) then return 'Votre statut d''étudiant n''est pas vérifié : faites valider votre carte d''étudiant ou votre certification avant de retirer de l''argent'; end if;
  return null;
end $$;
revoke all on function _payout_blocker(uuid) from public, anon, authenticated;

-- ============================================================ numéro de paiement : le titulaire est prévenu de tout nouveau numéro
create or replace function save_payment_method(p_provider text, p_phone text, p_default boolean) returns uuid
language plpgsql security definer set search_path = public as $$
declare pid uuid; ph text := regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g'); v_new boolean;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_provider not in ('orange_money', 'mtn_momo') then raise exception 'Moyen de paiement invalide'; end if;
  if left(ph, 3) = '237' and char_length(ph) = 12 then ph := substr(ph, 4); end if;
  if ph !~ '^6[0-9]{8}$' then raise exception 'Numéro invalide : 9 chiffres commençant par 6'; end if;
  v_new := not exists (select 1 from payment_methods where owner_id = auth.uid() and provider = p_provider and phone = ph);
  if v_new and (select count(*) from payment_methods where owner_id = auth.uid()) >= 6 then raise exception '6 moyens de paiement au plus'; end if;
  if p_default or not exists (select 1 from payment_methods where owner_id = auth.uid()) then
    update payment_methods set is_default = false where owner_id = auth.uid();
    p_default := true;
  end if;
  insert into payment_methods (owner_id, provider, phone, is_default) values (auth.uid(), p_provider, ph, coalesce(p_default, false))
  on conflict (owner_id, provider, phone) do update set is_default = excluded.is_default or payment_methods.is_default
  returning id into pid;
  if v_new then
    insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Numéro de paiement ajouté', right(ph, 3), 'Finance', 'Sensible');
    insert into notifications (user_id, kind, title, body, data)
      values (auth.uid(), 'payout', 'Nouveau numéro de paiement',
              'Le numéro ' || _payout_provider_label(p_provider) || ' se terminant par ' || right(ph, 3) || ' a été ajouté à votre compte. Il pourra recevoir un retrait dans ' || _payout_number_delay_hours() || ' h. Ce n''est pas vous ? Changez votre mot de passe et écrivez au support.',
              jsonb_build_object('payment_method', pid));
  end if;
  return pid;
end $$;
revoke all on function save_payment_method(text, text, boolean) from public, anon;
grant execute on function save_payment_method(text, text, boolean) to authenticated;

-- ============================================================ demande du vendeur
create or replace function request_seller_payout(p_amount integer, p_phone text default null, p_provider text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_avail integer; v_phone text := regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g'); pm payment_methods%rowtype; v_min integer := _payout_limit('payouts.min', 1000); v_max integer := _payout_limit('payouts.max', 500000);
  v_num text; v_block text; v_delay integer := _payout_number_delay_hours();
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  perform 1 from profiles where id = auth.uid() and not suspended for update;
  if not found then raise exception 'Compte inactif ou introuvable'; end if;
  v_block := _payout_blocker(auth.uid());
  if v_block is not null then raise exception '%', v_block; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Montant invalide'; end if;
  if p_amount < v_min then raise exception 'Retrait minimum : % FCFA', v_min; end if;
  if p_amount > v_max then raise exception 'Retrait maximum par demande : % FCFA', v_max; end if;
  if left(v_phone, 3) = '237' and char_length(v_phone) = 12 then v_phone := substr(v_phone, 4); end if;
  if v_phone = '' then
    select * into pm from payment_methods where owner_id = auth.uid() order by (created_at <= now() - make_interval(hours => v_delay)) desc, is_default desc, created_at limit 1;
    if not found then raise exception 'Enregistrez d''abord un numéro Orange Money ou MTN MoMo dans « Moyens de paiement » : c''est là que votre retrait sera versé'; end if;
  else
    select * into pm from payment_methods where owner_id = auth.uid() and phone = v_phone and (nullif(p_provider, '') is null or provider = p_provider) order by is_default desc limit 1;
    if not found then raise exception 'Ce numéro n''est pas enregistré dans vos moyens de paiement : ajoutez-le d''abord'; end if;
  end if;
  if _payout_method_usable_at(pm) > now() then
    raise exception 'Ce numéro vient d''être enregistré : par sécurité, il pourra recevoir un retrait à partir du % (délai de % h)', to_char(_payout_method_usable_at(pm) at time zone 'UTC', 'DD/MM/YYYY "à" HH24:MI "UTC"'), v_delay;
  end if;
  if exists (select 1 from payout_batches where seller_id = auth.uid() and status = 'demande') then raise exception 'Une demande de retrait est déjà en cours de traitement'; end if;
  v_avail := (money_wallet(auth.uid())->>'available')::int;
  if p_amount > v_avail then raise exception 'Montant supérieur à votre solde disponible (% FCFA) : l''argent n''est débloqué qu''après livraison confirmée', v_avail; end if;
  v_num := 'RV-' || nextval('payout_number_seq');
  insert into payout_batches (number, seller_id, amount, method, status, scheduled_on, created_by, source, provider, phone)
  values (v_num, auth.uid(), p_amount, _payout_provider_label(pm.provider), 'demande', current_date, auth.uid(), 'seller', pm.provider, pm.phone)
  returning id into v_id;
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Demande de retrait', v_num, 'Finance', 'Sensible');
  insert into notifications (user_id, kind, title, body, data)
    values (auth.uid(), 'payout', 'Demande de retrait enregistrée', p_amount || ' FCFA seront versés sur ' || _payout_provider_label(pm.provider) || ' ' || pm.phone || ' après traitement par la finance.', jsonb_build_object('payout', v_id, 'number', v_num));
  insert into notifications (user_id, kind, title, body, data)
    select p.id, 'payout', 'Retrait à traiter', p_amount || ' FCFA demandés (' || v_num || ') par ' || display_name(auth.uid()) || '.', jsonb_build_object('payout', v_id, 'number', v_num)
    from profiles p where p.role::text in ('finance', 'admin') and not p.suspended;
  return v_id;
end $$;

create or replace function payout_cancel_request(p_id uuid) returns text
language plpgsql security definer set search_path = public as $$
declare v_num text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  update payout_batches set status = 'rejete', note = 'Annulée par le vendeur', decided_by = auth.uid(), decided_at = now() where id = p_id and seller_id = auth.uid() and status = 'demande' returning number into v_num;
  if not found then raise exception 'Demande introuvable ou déjà traitée'; end if;
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Demande de retrait annulée', v_num, 'Finance', 'Normal');
  return 'cancelled';
end $$;

create or replace function my_payouts() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return jsonb_build_object(
    'min', _payout_limit('payouts.min', 1000), 'max', _payout_limit('payouts.max', 500000),
    'delay_hours', _payout_number_delay_hours(),
    'blocker', _payout_blocker(auth.uid()),
    'deficit', (money_wallet(auth.uid())->>'deficit')::int,
    'methods', coalesce((select jsonb_agg(jsonb_build_object('id', m.id, 'provider', m.provider, 'phone', m.phone, 'is_default', m.is_default,
                             'usable_at', _payout_method_usable_at(m), 'usable', _payout_method_usable_at(m) <= now()) order by m.is_default desc, m.created_at)
                         from payment_methods m where m.owner_id = auth.uid()), '[]'::jsonb),
    'rows', coalesce((select jsonb_agg(jsonb_build_object('id', b.id, 'number', b.number, 'amount', b.amount, 'status', b.status, 'method', b.method, 'phone', b.phone, 'reference', b.reference, 'note', b.note,
        'created_at', b.created_at, 'paid_on', b.paid_on, 'source', b.source) order by b.created_at desc)
      from (select * from payout_batches where seller_id = auth.uid() order by created_at desc limit 30) b), '[]'::jsonb));
end $$;

-- ============================================================ versements par la finance
create or replace function payout_create(p_seller uuid, p_amount int, p_method text default 'Mobile Money', p_on date default current_date) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_avail integer; pm payment_methods%rowtype; v_num text; v_delay integer := _payout_number_delay_hours();
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('finance', 'admin') then raise exception 'Action non autorisée'; end if;
  perform 1 from profiles where id = p_seller for update;
  if not found then raise exception 'Bénéficiaire introuvable'; end if;
  if exists (select 1 from profiles where id = p_seller and coalesce(suspended, false)) then raise exception 'Le compte du bénéficiaire est suspendu : levez la suspension avant tout versement'; end if;
  v_avail := (money_wallet(p_seller)->>'available')::int;
  if p_amount is null or p_amount <= 0 then raise exception 'Montant invalide'; end if;
  if p_amount > v_avail then raise exception 'Montant supérieur au solde disponible (% FCFA) : l''argent n''est débloqué qu''après livraison', v_avail; end if;
  select * into pm from payment_methods where owner_id = p_seller order by (created_at <= now() - make_interval(hours => v_delay)) desc, is_default desc, created_at limit 1;
  if found and _payout_method_usable_at(pm) > now() then
    raise exception 'Le seul numéro enregistré par le bénéficiaire date de moins de % h : attendez la fin du délai de sécurité', v_delay;
  end if;
  v_num := 'RV-' || nextval('payout_number_seq');
  insert into payout_batches (number, seller_id, amount, method, scheduled_on, created_by, provider, phone)
  values (v_num, p_seller, p_amount, coalesce(nullif(trim(p_method), ''), 'Mobile Money'), coalesce(p_on, current_date), auth.uid(), pm.provider, pm.phone)
  returning id into v_id;
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Versement créé', v_num, 'Finance', 'Sensible');
  insert into notifications (user_id, kind, title, body, data)
    values (p_seller, 'payout', 'Versement prévu', p_amount || ' FCFA vous seront versés (' || v_num || ').', jsonb_build_object('payout', v_id, 'number', v_num));
  return v_id;
end $$;

create or replace function payout_set_status(p_id uuid, p_status text, p_reference text default null, p_note text default null) returns void
language plpgsql security definer set search_path = public as $$
declare b payout_batches%rowtype; v_ref text := nullif(left(btrim(coalesce(p_reference, '')), 80), ''); v_note text := nullif(left(btrim(coalesce(p_note, '')), 300), '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('finance', 'admin') then raise exception 'Action non autorisée'; end if;
  if p_status not in ('prevu', 'verse', 'rejete') then raise exception 'Statut invalide'; end if;
  select * into b from payout_batches where id = p_id for update;
  if not found then raise exception 'Versement introuvable'; end if;
  if not ((b.status = 'demande' and p_status in ('prevu', 'verse', 'rejete')) or (b.status = 'prevu' and p_status in ('verse', 'rejete'))) then
    raise exception 'Transition impossible : un versement « % » ne peut pas passer à « % »', b.status, p_status;
  end if;
  if p_status in ('prevu', 'verse') and exists (select 1 from profiles where id = b.seller_id and coalesce(suspended, false)) then
    raise exception 'Le compte du bénéficiaire est suspendu : rejetez le retrait ou levez la suspension';
  end if;
  if p_status = 'verse' and v_ref is null then raise exception 'Indiquez la référence de la transaction Mobile Money'; end if;
  if p_status = 'rejete' and v_note is null then raise exception 'Indiquez le motif du rejet'; end if;
  update payout_batches set status = p_status, paid_on = case when p_status = 'verse' then current_date else null end, reference = coalesce(v_ref, reference), note = coalesce(v_note, note),
    decided_by = auth.uid(), decided_at = now() where id = b.id;
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, case p_status when 'verse' then 'Versement effectué' when 'rejete' then 'Versement rejeté' else 'Versement accepté' end, b.number, 'Finance', 'Sensible');
  insert into notifications (user_id, kind, title, body, data)
    values (b.seller_id, 'payout',
            case p_status when 'verse' then 'Retrait versé' when 'rejete' then 'Retrait rejeté' else 'Retrait accepté' end,
            case p_status when 'verse' then b.amount || ' FCFA versés' || case when b.phone is not null then ' sur ' || _payout_provider_label(b.provider) || ' ' || b.phone else '' end || ' (réf. ' || v_ref || ').'
                          when 'rejete' then 'Votre retrait de ' || b.amount || ' FCFA est rejeté : ' || v_note || ' Le montant est de nouveau disponible.'
                          else 'Votre retrait de ' || b.amount || ' FCFA est accepté et sera versé sous peu.' end,
            jsonb_build_object('payout', b.id, 'number', b.number));
end $$;

revoke all on function request_seller_payout(integer, text, text), payout_cancel_request(uuid), my_payouts(), payout_create(uuid, int, text, date), payout_set_status(uuid, text, text, text) from public, anon;
grant execute on function request_seller_payout(integer, text, text), payout_cancel_request(uuid), my_payouts(), payout_create(uuid, int, text, date), payout_set_status(uuid, text, text, text) to authenticated;
