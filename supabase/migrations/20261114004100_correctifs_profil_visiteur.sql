-- Correctifs issus de l'analyse complète du profil Visiteur (confidentialité, permissions, parrainage, paiement manuel, notifications).
-- Aucune donnée existante n'est modifiée ni supprimée. Retour arrière : voir le bas du fichier.

-- ============================================================ 1. Projets : un projet « privé » ne sort jamais du catalogue public
drop function if exists iut_projects(text, integer, text);
create or replace function iut_projects(p_department text default null, p_limit integer default 40, p_sort text default 'best') returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', p.id, 'title', p.title, 'summary', p.summary, 'department', coalesce(nullif(trim(p.department), ''), 'Autres filières'), 'created_at', p.created_at,
      'owner_id', p.owner_id, 'owner', display_name(p.owner_id), 'avatar_url', o.avatar_url,
      'votes', p.votes, 'voted', exists (select 1 from project_upvotes u where u.project_id = p.id and u.user_id = auth.uid()))
    order by case when coalesce(p_sort, 'best') = 'best' then p.votes end desc nulls last, p.created_at desc), '[]'::jsonb)
  from (select pr.*, (select count(*)::int from project_upvotes u where u.project_id = pr.id) votes
        from projects pr
        where pr.status = 'approved' and pr.visibility = 'public'
          and (nullif(trim(coalesce(p_department, '')), '') is null or lower(coalesce(pr.department, '')) like '%' || lower(trim(p_department)) || '%')
        order by pr.created_at desc limit least(greatest(coalesce(p_limit, 40), 1), 100)) p
  left join profiles o on o.id = p.owner_id
$$;
revoke all on function iut_projects(text, integer, text) from public;
grant execute on function iut_projects(text, integer, text) to anon, authenticated;

-- Un projet soumis à validation prévient le département et l'administration (jusqu'ici, personne n'était notifié).
create or replace function project_save_full(p_id uuid, p_kind text, p_title text, p_summary text, p_department text, p_details jsonb, p_media jsonb, p_visibility text, p_publish boolean) returns uuid
language plpgsql security definer set search_path = public as $$
declare p projects%rowtype; pid uuid; d jsonb := coalesce(p_details, '{}'::jsonb); m jsonb := coalesce(p_media, '[]'::jsonb); miss text[] := '{}';
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('student', 'dept', 'admin') then raise exception 'Réservé aux étudiants'; end if;
  if p_kind not in ('innovation', 'projet') then raise exception 'Type invalide'; end if;
  if p_visibility not in ('private', 'public') then raise exception 'Visibilité invalide'; end if;
  if p_title is null or char_length(trim(p_title)) not between 3 and 120 then raise exception 'Titre : 3 à 120 caractères'; end if;
  if jsonb_typeof(d) <> 'object' or pg_column_size(d) > 40000 then raise exception 'Fiche trop volumineuse'; end if;
  if jsonb_typeof(m) <> 'array' or pg_column_size(m) > 12000 then raise exception 'Trop de médias'; end if;
  if p_publish then
    if char_length(trim(coalesce(p_summary, ''))) < 30 then miss := array_append(miss, 'description (30 caractères minimum)'); end if;
    if char_length(trim(coalesce(d->>'domain', ''))) < 2 then miss := array_append(miss, 'domaine'); end if;
    if char_length(trim(coalesce(d->>'problem', ''))) < 10 then miss := array_append(miss, 'problème résolu'); end if;
    if char_length(trim(coalesce(d->>'solution', ''))) < 10 then miss := array_append(miss, 'solution proposée'); end if;
    if char_length(trim(coalesce(d->>'progress', ''))) < 2 then miss := array_append(miss, 'état d''avancement'); end if;
    if char_length(trim(coalesce(d->>'contact_email', ''))) + char_length(trim(coalesce(d->>'contact_phone', ''))) < 5 then miss := array_append(miss, 'un contact'); end if;
    if array_length(miss, 1) > 0 then raise exception 'Pour publier, complétez : %', array_to_string(miss, ', '); end if;
  end if;
  if p_id is null then
    insert into projects (owner_id, kind, title, summary, department, details, media, visibility, status)
    values (auth.uid(), p_kind, trim(p_title), nullif(left(trim(coalesce(p_summary, '')), 4000), ''), nullif(left(trim(coalesce(p_department, '')), 120), ''), d, m, p_visibility,
      case when p_publish then 'submitted' else 'draft' end) returning id into pid;
  else
    select * into p from projects where id = p_id and owner_id = auth.uid();
    if not found then raise exception 'Projet introuvable'; end if;
    if p.status in ('submitted', 'approved') then raise exception 'Ce projet est en cours d''examen ou déjà publié : il ne peut plus être modifié ici'; end if;
    update projects set kind = p_kind, title = trim(p_title), summary = nullif(left(trim(coalesce(p_summary, '')), 4000), ''), department = nullif(left(trim(coalesce(p_department, '')), 120), ''),
      details = d, media = m, visibility = p_visibility,
      status = case when p_publish then 'submitted' when p.status = 'rejected' then 'draft' else p.status end, updated_at = now()
    where id = p.id;
    pid := p.id;
  end if;
  if p_publish then
    insert into notifications (user_id, kind, title, body, data)
    select a.id, 'project', 'Projet à examiner', trim(p_title), jsonb_build_object('project_id', pid) from profiles a where a.role::text in ('dept', 'admin') and a.id <> auth.uid();
  end if;
  return pid;
end $$;

-- ============================================================ 2. Duels : nom d'affichage abrégé (le nom complet n'est plus exposé aux visiteurs)
create or replace function duels_list() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', d.id, 'need', d.need_title, 'prize', d.prize, 'ends_at', d.ends_at, 'open', d.ends_at > now(),
    'entries', coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'title', e.title, 'author', coalesce(nullif(display_name(e.author_id), ''), 'Étudiant'),
                  'votes', (select count(*)::int from duel_votes v where v.entry_id = e.id)) order by e.created_at)
                from duel_entries e where e.duel_id = d.id), '[]'::jsonb)
  ) order by d.created_at desc), '[]'::jsonb)
  from (select * from duels order by created_at desc limit 50) d;
$$;

-- ============================================================ 3. Compteurs de vues : un compte connecté compte une fois par jour et par fiche
-- (avant : tout visiteur pouvait gonfler les compteurs sans limite).
create table if not exists view_seen (
  user_id uuid not null,
  kind text not null,
  ref_id uuid not null,
  day date not null default current_date,
  primary key (user_id, kind, ref_id, day)
);
alter table view_seen enable row level security;
revoke all on view_seen from anon, authenticated;

create or replace function record_view(p_kind text, p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v_n integer;
begin
  if auth.uid() is null or p_kind not in ('listing', 'shop') then return; end if;
  insert into view_seen (user_id, kind, ref_id) values (auth.uid(), p_kind, p_id) on conflict do nothing;
  get diagnostics v_n = row_count;
  if v_n = 0 then return; end if;
  if random() < 0.01 then delete from view_seen where day < current_date - 3; end if;
  if p_kind = 'listing' and exists (select 1 from listings where id = p_id and status = 'approved' and seller_id is distinct from auth.uid()) then
    insert into listing_views (listing_id, day, views) values (p_id, current_date, 1) on conflict (listing_id, day) do update set views = listing_views.views + 1;
  elsif p_kind = 'shop' and exists (select 1 from shops where id = p_id and status = 'active' and owner_id is distinct from auth.uid()) then
    insert into shop_views (shop_id, day, views) values (p_id, current_date, 1) on conflict (shop_id, day) do update set views = shop_views.views + 1;
  end if;
end $$;

-- Annonce de concours : la note de modération n'est lue que par l'auteur et l'équipe ; les vues sont comptées comme ci-dessus.
create or replace function ann_detail(p_id uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare a contest_announcements%rowtype; uid uuid := auth.uid(); v_staff boolean := coalesce(current_role_name()::text, '') in ('admin', 'dept'); v_n integer;
begin
  select * into a from contest_announcements where id = p_id;
  if not found or (a.status <> 'published' and a.poster_id is distinct from uid and not v_staff) then raise exception 'Annonce introuvable'; end if;
  if a.status = 'published' and uid is not null and a.poster_id is distinct from uid then
    insert into view_seen (user_id, kind, ref_id) values (uid, 'announcement', p_id) on conflict do nothing;
    get diagnostics v_n = row_count;
    if v_n > 0 then update contest_announcements set views = views + 1 where id = p_id; end if;
  end if;
  return _ann_card(a, uid) || jsonb_build_object('description', a.description, 'why', a.why, 'conditions', to_jsonb(a.conditions), 'documents', to_jsonb(a.documents), 'steps', to_jsonb(a.steps), 'criteria', to_jsonb(a.criteria),
    'opens_on', a.opens_on, 'results_on', a.results_on, 'program_start', a.program_start, 'official_url', a.official_url, 'mine', a.poster_id = uid,
    'review_note', case when a.poster_id = uid or v_staff then a.review_note end,
    'reminder', exists (select 1 from contest_ann_reminders r where r.announcement_id = p_id and r.user_id = uid));
end $$;

-- ============================================================ 4. Publications : plus de lecture publique des notes de modération ni de « qui aime quoi »
revoke select on post_likes, post_boosts from anon, authenticated;
do $$
declare cols text;
begin
  select string_agg(quote_ident(column_name), ', ' order by ordinal_position) into cols
    from information_schema.columns where table_schema = 'public' and table_name = 'posts' and column_name <> 'review_note';
  execute 'revoke select on posts from anon, authenticated';
  execute 'grant select (' || cols || ') on posts to anon, authenticated';
end $$;

-- ============================================================ 5. Appareils : « Se déconnecter de tous les appareils » retire aussi les jetons de notification
create or replace function unregister_all_devices() returns integer
language plpgsql security definer set search_path = public as $$
declare v_n integer;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  delete from device_tokens where user_id = auth.uid();
  get diagnostics v_n = row_count;
  return v_n;
end $$;
revoke all on function unregister_all_devices() from public, anon;
grant execute on function unregister_all_devices() to authenticated;

-- ============================================================ 6. Parrainage : le code est enregistré (8 caractères sans ambiguïté), donc reconnu par claim_referral
-- (la version de 20261105001000 renvoyait un code dérivé d'un hachage sans l'enregistrer : « Code de parrainage inconnu » à chaque saisie).
create or replace function my_referral_code() returns text
language plpgsql security definer set search_path = public, extensions as $$
declare c text; alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; b bytea; i int;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select code into c from referral_codes where user_id = auth.uid();
  if found then return c; end if;
  loop
    b := gen_random_bytes(8); c := '';
    for i in 0..7 loop c := c || substr(alphabet, 1 + (get_byte(b, i) % 32), 1); end loop;
    begin
      insert into referral_codes (user_id, code) values (auth.uid(), c);
      return c;
    exception when unique_violation then
      if exists (select 1 from referral_codes where user_id = auth.uid()) then return (select code from referral_codes where user_id = auth.uid()); end if;
    end;
  end loop;
end $$;

-- ============================================================ 7. Paiement par messagerie : la finance est prévenue, et la confirmation marque réellement la commande payée
create or replace function payment_declare(p_id uuid, p_provider_ref text) returns void
language plpgsql security definer set search_path = public as $$
declare t payment_transactions%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into t from payment_transactions where id = p_id and payer_id = auth.uid();
  if not found then raise exception 'Paiement introuvable'; end if;
  if t.status not in ('created', 'failed') then raise exception 'Ce paiement n''est plus modifiable'; end if;
  if p_provider_ref is null or char_length(trim(p_provider_ref)) < 4 then raise exception 'Référence de transaction invalide'; end if;
  update payment_transactions set status = 'pending', provider_ref = left(trim(p_provider_ref), 80), declared_at = now() where id = p_id;
  insert into payment_messages (transaction_id, sender, body) values (p_id, 'payer', 'J''ai payé. Référence : ' || left(trim(p_provider_ref), 80));
  insert into payment_messages (transaction_id, sender, body) values (p_id, 'system', 'Paiement déclaré. La finance le vérifie ; vous serez notifié.');
  insert into notifications (user_id, kind, title, body, data)
    select f.id, 'payment', 'Paiement à vérifier', t.reference || ' · ' || t.amount || ' FCFA · référence ' || left(trim(p_provider_ref), 80), jsonb_build_object('payment_id', p_id)
    from profiles f where f.role::text in ('finance', 'admin');
end $$;

create or replace function payment_set_status(p_id uuid, p_status text, p_note text default null) returns void
language plpgsql security definer set search_path = public as $$
declare t payment_transactions%rowtype; pl plans%rowtype; v_code text; v_num text; o orders%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('admin', 'finance') then raise exception 'Action non autorisée'; end if;
  if p_status not in ('confirmed', 'failed', 'cancelled') then raise exception 'Statut invalide'; end if;
  select * into t from payment_transactions where id = p_id;
  if not found then raise exception 'Paiement introuvable'; end if;
  if t.status = 'confirmed' then raise exception 'Paiement déjà confirmé'; end if;
  if p_status = 'confirmed' and t.kind = 'order' then
    v_num := substring(t.subject from '#BE-[0-9]{4}-[0-9]+');
    if v_num is null then raise exception 'Commande introuvable dans l''objet du paiement'; end if;
    select * into o from orders where number = v_num and buyer_id = t.payer_id for update;
    if not found then raise exception 'Commande introuvable'; end if;
    if o.cancelled or o.cancelled_at is not null then raise exception 'Commande annulée : le paiement ne peut pas être confirmé'; end if;
    if t.amount < o.subtotal + o.fee then raise exception 'Montant inférieur au total de la commande'; end if;
  end if;
  update payment_transactions set status = p_status, decided_at = now(), decided_by = auth.uid(), note = left(p_note, 300) where id = p_id;
  insert into payment_messages (transaction_id, sender, body) values (p_id, 'finance',
    case p_status when 'confirmed' then 'Paiement confirmé. Merci !' when 'failed' then 'Paiement non retrouvé' || coalesce(' : ' || left(p_note, 200), '') || '. Vous pouvez le redéclarer.' else 'Paiement annulé.' end);
  insert into notifications (user_id, kind, title, body, data) values (t.payer_id, 'payment', 'Paiement ' || t.reference,
    case p_status when 'confirmed' then 'Confirmé' when 'failed' then 'Non retrouvé' else 'Annulé' end, jsonb_build_object('payment_id', p_id));
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Paiement ' || p_status, t.reference, 'Finance', 'Info');
  if p_status = 'confirmed' and t.kind = 'subscription' and t.subject like 'plan:%' then
    v_code := split_part(substr(t.subject, 6), ':', 1);
    select * into pl from plans where plans.code = v_code;
    update subscriptions set status = 'active', started_at = now(), current_period_end = now() + make_interval(days => pl.period_days) where payment_id = p_id;
  elsif p_status = 'confirmed' and t.kind = 'campaign' and t.subject like 'campagne:%' then
    update ad_campaigns set status = 'pending_review' where payment_id = p_id and status = 'awaiting_payment';
  elsif p_status = 'confirmed' and t.kind = 'order' then
    update orders set paid = true, status = greatest(status, 1) where id = o.id and not paid;
  end if;
end $$;

-- Paiements déclarés en attente de vérification (finance et administration).
create or replace function payments_to_verify() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('admin', 'finance') then raise exception 'Action non autorisée'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'reference', x.reference, 'amount', x.amount, 'status', x.status, 'subject', x.subject,
      'provider_ref', x.provider_ref, 'payer', display_name(x.payer_id), 'created_at', x.created_at) order by x.declared_at nulls last, x.created_at)
    from (select * from payment_transactions where status = 'pending' order by declared_at nulls last, created_at limit 100) x), '[]'::jsonb);
end $$;
revoke all on function payments_to_verify() from public, anon;
grant execute on function payments_to_verify() to authenticated;

-- ============================================================ 8. Forfaits entreprise : la demande vise l'entreprise consultée (membre admin ou finance), pas toujours la sienne
drop function if exists company_subscription_request(text);
create or replace function company_subscription_request(p_plan text, p_owner uuid default null) returns text
language plpgsql security definer set search_path = public as $$
declare v_owner uuid := company_effective_owner(p_owner); pl company_plans%rowtype; c company_profiles%rowtype;
begin
  if company_role_of(v_owner) not in ('owner', 'admin', 'finance') then raise exception 'Réservé au propriétaire, aux administrateurs et à la finance de l''entreprise'; end if;
  select * into c from company_profiles where owner_id = v_owner;
  if not found or c.status <> 'approved' then raise exception 'Faites d''abord vérifier votre entreprise'; end if;
  select * into pl from company_plans where code = p_plan and active;
  if not found or pl.price_fcfa = 0 then raise exception 'Forfait introuvable'; end if;
  begin
    insert into company_subscriptions (owner_id, plan_code) values (v_owner, pl.code);
  exception when unique_violation then
    update company_subscriptions set plan_code = pl.code, requested_at = now() where owner_id = v_owner and status = 'requested';
  end;
  insert into notifications (user_id, kind, title, body, data)
    select a.id, 'company_plan', 'Forfait demandé', c.company_name || ' demande le forfait « ' || pl.name || ' » (' || pl.price_fcfa || ' FCFA).', jsonb_build_object('owner', v_owner, 'plan', pl.code) from profiles a where a.role::text = 'admin';
  return 'requested';
end $$;
revoke all on function company_subscription_request(text, uuid) from public, anon;
grant execute on function company_subscription_request(text, uuid) to authenticated;

-- ============================================================ 9. Avis d'un produit : lecture publique ciblée (l'écran lisait les 50 derniers avis de tout le site puis filtrait)
create or replace function product_reviews(p_title text, p_limit integer default 50) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('rating', r.rating, 'comment', r.comment, 'created_at', r.created_at) order by r.created_at desc), '[]'::jsonb)
  from (select rv.* from reviews rv join listings l on l.id = rv.listing_id
        where l.title = p_title and l.status = 'approved'
        order by rv.created_at desc limit least(greatest(coalesce(p_limit, 50), 1), 100)) r
$$;
revoke all on function product_reviews(text, integer) from public;
grant execute on function product_reviews(text, integer) to anon, authenticated;

-- ============================================================ 10. Offres : le rôle « client » n'en dépose plus ; le département est prévenu des offres à valider
CREATE OR REPLACE FUNCTION public.opp_save(p_org text, p_kind text, p_contract text, p_title text, p_location text, p_mode text, p_duration text, p_pay_kind text, p_pay_amount integer, p_pay_note text, p_deadline date, p_skills text[], p_description text, p_missions text[], p_profile text, p_department text, p_level text, p_gains text[], p_whatsapp text, p_in_app boolean, p_about text, p_iut_only boolean)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id uuid; v_role text := coalesce(current_role_name()::text, ''); v_staff boolean; v_skills text[]; v_missions text[]; v_gains text[]; r record;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  perform company_gate('offer', null);
  if v_role in ('student', 'visitor', 'client', '') then raise exception 'Réservé aux entreprises, ONG, startups et à l''équipe de l''IUT'; end if;
  v_staff := v_role in ('admin', 'dept');
  if char_length(btrim(coalesce(p_org, ''))) < 2 then raise exception 'Indiquez le nom de l''organisation'; end if;
  if char_length(btrim(coalesce(p_title, ''))) < 3 then raise exception 'Indiquez le poste ou la mission'; end if;
  if p_kind not in ('stage', 'emploi', 'mission', 'defi', 'benevolat', 'formation') then raise exception 'Type d''opportunité inconnu'; end if;
  if p_mode not in ('onsite', 'online', 'hybrid') then raise exception 'Mode inconnu'; end if;
  if p_pay_kind not in ('paid', 'unpaid', 'negotiable') then raise exception 'Rémunération inconnue'; end if;
  if p_deadline is not null and p_deadline < current_date then raise exception 'La date limite doit être dans le futur'; end if;
  if char_length(btrim(coalesce(p_description, ''))) < 20 then raise exception 'Décrivez l''offre en 20 caractères minimum'; end if;
  if coalesce(p_in_app, true) = false and btrim(coalesce(p_whatsapp, '')) = '' then raise exception 'Indiquez au moins un moyen de postuler (dans l''application ou par WhatsApp)'; end if;
  if (select count(*) from opportunities where poster_id = auth.uid() and created_at > now() - interval '1 day') >= 10 then raise exception 'Dix offres par jour au plus'; end if;
  select array_agg(btrim(x)) into v_skills from unnest(coalesce(p_skills, '{}'::text[])) x where char_length(btrim(x)) between 1 and 40;
  select array_agg(btrim(x)) into v_missions from unnest(coalesce(p_missions, '{}'::text[])) x where char_length(btrim(x)) between 2 and 200;
  select array_agg(btrim(x)) into v_gains from unnest(coalesce(p_gains, '{}'::text[])) x where char_length(btrim(x)) between 2 and 60;
  insert into opportunities (poster_id, org_name, kind, contract, title, location, mode, duration, pay_kind, pay_amount, pay_note, deadline, skills, description, missions, profile_wanted,
      department_target, level, gains, apply_whatsapp, apply_in_app, about_org, iut_only, verified, status)
    values (auth.uid(), btrim(p_org), p_kind, left(btrim(coalesce(p_contract, '')), 40), btrim(p_title), left(btrim(coalesce(p_location, '')), 80), p_mode, left(btrim(coalesce(p_duration, '')), 40), p_pay_kind,
      p_pay_amount, left(btrim(coalesce(p_pay_note, '')), 120), p_deadline, coalesce(v_skills, '{}'), btrim(p_description), coalesce(v_missions, '{}'), left(btrim(coalesce(p_profile, '')), 1000),
      left(btrim(coalesce(p_department, '')), 120), left(btrim(coalesce(p_level, '')), 60), coalesce(v_gains, '{}'), btrim(coalesce(p_whatsapp, '')), coalesce(p_in_app, true), left(btrim(coalesce(p_about, '')), 1000),
      coalesce(p_iut_only, false), v_staff, case when v_staff then 'published' else 'pending' end)
    returning id into v_id;
  if v_staff then
    perform _opp_alert_matching(v_id);
  else
    for r in select id from profiles where role::text in ('admin', 'dept') loop
      perform notify_user(r.id, 'opportunity_review', 'Offre à valider', btrim(p_org) || ' propose « ' || btrim(p_title) || ' ».', jsonb_build_object('opportunity', v_id));
    end loop;
  end if;
  return v_id;
end $function$;

-- ============================================================ 11. Communautés : message exact pour un compte suspendu, et l'équipe d'assistance est prévenue des validations
drop function if exists create_community(text, text, text, text, text, uuid, text, text, text);
create or replace function create_community(p_name text, p_description text default '', p_category text default '', p_privacy text default 'public', p_rules text default '', p_department uuid default null,
  p_kind text default 'interest', p_promo text default null, p_interest text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_words integer; r record; v_promo text := nullif(btrim(coalesce(p_promo, '')), ''); v_interest text := nullif(btrim(coalesce(p_interest, '')), '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from profiles where id = auth.uid() and coalesce(suspended, false) = false) then raise exception 'Compte suspendu : création de communauté impossible'; end if;
  if char_length(btrim(coalesce(p_name, ''))) not between 3 and 60 then raise exception 'Le nom doit contenir entre 3 et 60 caractères'; end if;
  if p_privacy not in ('public', 'approval', 'invite') then raise exception 'Confidentialité inconnue'; end if;
  if p_kind not in ('filiere', 'promo', 'interest', 'alumni', 'project') then raise exception 'Type de communauté inconnu'; end if;
  if p_kind = 'promo' and v_promo is null then raise exception 'Indiquez la promotion (ex. Promo 2026)'; end if;
  if p_kind = 'interest' and v_interest is null then raise exception 'Indiquez le centre d''intérêt (ex. Dev Flutter)'; end if;
  if p_kind = 'filiere' and p_department is null then raise exception 'Choisissez la filière'; end if;
  v_words := case when btrim(coalesce(p_description, '')) = '' then 0 else cardinality(regexp_split_to_array(btrim(p_description), '\s+')) end;
  if v_words > 500 then raise exception 'La description ne doit pas dépasser 500 mots (% mots saisis)', v_words; end if;
  if p_department is not null and not exists (select 1 from departments where id = p_department and status = 'verified') then raise exception 'Département inconnu'; end if;
  if (select count(*) from communities where owner_id = auth.uid() and status in ('pending', 'active')) >= 5 then raise exception 'Vous ne pouvez pas avoir plus de 5 communautés'; end if;
  if exists (select 1 from communities where lower(btrim(name)) = lower(btrim(p_name))) then raise exception 'Une communauté porte déjà ce nom'; end if;
  insert into communities (name, description, category, rules, privacy, owner_id, department_id, status, kind, promo_year, interest)
    values (btrim(p_name), btrim(coalesce(p_description, '')), coalesce(p_category, ''), coalesce(p_rules, ''), p_privacy, auth.uid(), p_department, 'pending', p_kind, left(v_promo, 20), left(v_interest, 60)) returning id into v_id;
  insert into community_members (community_id, user_id, role, status) values (v_id, auth.uid(), 'owner', 'active');
  for r in select id from profiles where role::text in ('admin', 'support') loop
    perform notify_user(r.id, 'community_validation', 'Communauté à valider', display_name(auth.uid()) || ' propose la communauté « ' || btrim(p_name) || ' ».', jsonb_build_object('community', v_id));
  end loop;
  return v_id;
end $$;
revoke all on function create_community(text, text, text, text, text, uuid, text, text, text) from public, anon;
grant execute on function create_community(text, text, text, text, text, uuid, text, text, text) to authenticated;

-- RETOUR ARRIÈRE : recréer les fonctions depuis leurs migrations d'origine (iut_projects 20261114001900, project_save_full 20261110010000, duels_list 20261105001000,
--   record_view 20261107000000, ann_detail 20261114001400, payment_declare 20261105001200, payment_set_status 20261106000000, company_subscription_request 20261114002600,
--   opp_save 20261114002600, create_community 20261114000900) ; grant select on post_likes, post_boosts, posts to anon, authenticated ;
--   drop function unregister_all_devices(), payments_to_verify(), product_reviews(text, integer) ; drop table view_seen.
