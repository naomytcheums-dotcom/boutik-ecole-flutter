-- Lot H13 / RANKING (2/5) : PROPOSITION de pondérations initiales du score de talent, documentée (docs/transformation/H13_PROPOSITION_PONDERATIONS_TOP100.md).
--  Le propriétaire décide : cette migration n'active RIEN, ne publie RIEN et n'insère AUCUNE donnée. Elle ajoute seulement :
--   * _talent_rules_proposal() : la table de proposition (famille, catégorie, points, plafonds jour / période, poids qualité, justification) ;
--   * admin_talent_rules_proposal() : lecture de la proposition et écart avec les règles actuelles (ranking.rules), sans écriture ;
--   * admin_talent_rules_apply_proposal(p_reason) : ENREGISTRE les valeurs proposées dans talent_score_rules en les laissant active = false (brouillon, 0 point attribué) ;
--     permission ranking.rules + 2FA, motif obligatoire, versionné (talent_score_rule_history) et audité. Refus si une règle est déjà active ou si un classement est déjà publié
--     (la proposition ne remplace jamais des règles en vigueur). Les réglages de publication (seuil, nombre d'entrées, portées) ne sont PAS écrits : ils restent à décider
--     (ranking_publish refuse tant que ni les réglages ni une règle active n'existent).
--  Principes : la qualité et la réalisation vérifiées comptent plus que la popularité (aucune règle pour vues et likes) ; plafonds par jour et par mois pour chaque famille (donc par catégorie) ;
--  le poids qualité n'est proposé que là où une qualité est réellement mesurée (avis : note 1 à 5) ; équité entre filières : mêmes points quelle que soit la filière, centiles par cohorte.
-- Additive et rejouable. Retour arrière : drop function admin_talent_rules_apply_proposal(text), admin_talent_rules_proposal(), _talent_rules_proposal().

create or replace function _talent_rules_proposal() returns table (code text, category text, points integer, cap_day integer, cap_period integer, quality_weight numeric, rationale text)
language sql immutable set search_path = public as $$
  select * from (values
    ('assessment_validated', 'realisation', 120, 120, 360, 0::numeric, 'Évaluation validée par un humain : preuve de compétence la plus fiable, donc la plus valorisée.'),
    ('mission_validated', 'realisation', 100, 200, 400, 0::numeric, 'Mission réalisée et validée par le client : réalisation concrète et vérifiée.'),
    ('certificate_verified', 'realisation', 80, 80, 240, 0::numeric, 'Certificat émis et non révoqué : preuve vérifiable par son code.'),
    ('project_published_with_proof', 'realisation', 70, 70, 210, 0::numeric, 'Projet approuvé avec preuves : réalisation examinée avant publication.'),
    ('sale_confirmed', 'realisation', 30, 60, 240, 0::numeric, 'Vente payée et non remboursée : réalisation commerciale, plafonnée car plus facile à simuler.'),
    ('skill_demonstrated', 'competence', 50, 50, 150, 0::numeric, 'Compétence adossée à un justificatif vérifié par un humain.'),
    ('collaboration', 'competence', 40, 40, 120, 0::numeric, 'Projet approuvé réalisé à plusieurs étudiants réels : collaboration constatée.'),
    ('badge_verified', 'competence', 15, 15, 45, 0::numeric, 'Badge adossé à un replay réellement terminé : valeur modérée (suivi, pas production).'),
    ('live_hosted', 'engagement', 40, 40, 120, 0::numeric, 'Live réellement animé avec au moins un participant réel : contribution à la communauté.'),
    ('challenge_participation', 'engagement', 25, 25, 75, 0::numeric, 'Participation effective à un challenge : engagement, sans valoriser le résultat.'),
    ('review_verified', 'engagement', 20, 40, 120, 0.8::numeric, 'Avis lié à un achat réel : la note (1 à 5) pèse 80 % des points, donc la qualité prime.'),
    ('replay_completed_100', 'engagement', 10, 20, 60, 0::numeric, 'Replay suivi jusqu''au bout (progression serveur) : consommation, faible poids.'),
    ('event_attended', 'engagement', 10, 10, 40, 0::numeric, 'Présence prouvée par le code de l''organisateur pendant l''événement : faible poids.')
  ) v (code, category, points, cap_day, cap_period, quality_weight, rationale)
$$;
revoke all on function _talent_rules_proposal() from public, anon, authenticated;

-- Seuils proposés, jamais écrits par le serveur (décision du propriétaire).
create or replace function _talent_thresholds_proposal() returns jsonb
language sql immutable set search_path = public as $$
  select jsonb_build_object('min_score', 50, 'min_activities', 3, 'entries_limit', 100, 'scopes', jsonb_build_array('national', 'institution', 'program'), 'min_cohort', 10,
    'burst_count', 8, 'burst_minutes', 10, 'actor_repeat', 3, 'dispute_days', 60,
    'to_set_with', jsonb_build_object('min_score', 'admin_ranking_settings_set', 'min_activities', 'admin_ranking_settings_set', 'entries_limit', 'admin_ranking_settings_set', 'scopes', 'admin_ranking_settings_set',
      'min_cohort', 'admin_talent_setting_set', 'burst_count', 'admin_talent_setting_set', 'burst_minutes', 'admin_talent_setting_set', 'actor_repeat', 'admin_talent_setting_set', 'dispute_days', 'admin_talent_setting_set'))
$$;
revoke all on function _talent_thresholds_proposal() from public, anon, authenticated;

create or replace function admin_talent_rules_proposal() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not has_admin_permission('ranking.rules') then raise exception 'Réservé : exige la permission ranking.rules'; end if;
  return jsonb_build_object('proposal_only', true,
    'rules', coalesce((select jsonb_agg(jsonb_build_object('code', p.code, 'label', r.label, 'category', p.category, 'points', p.points, 'cap_per_day', p.cap_day, 'cap_per_period', p.cap_period,
        'quality_weight', p.quality_weight, 'rationale', p.rationale, 'current', jsonb_build_object('points', r.points, 'cap_per_day', r.cap_per_day, 'cap_per_period', r.cap_per_period,
        'quality_weight', r.quality_weight, 'active', r.active, 'version', r.version),
        'differs', (r.points, r.cap_per_day, r.cap_per_period, r.quality_weight) is distinct from (p.points, p.cap_day, p.cap_period, p.quality_weight::numeric(3, 2))) order by p.category, p.points desc)
      from _talent_rules_proposal() p join talent_score_rules r on r.code = p.code), '[]'::jsonb),
    'thresholds', _talent_thresholds_proposal(),
    'note', 'Proposition non appliquée : aucune règle n''est activée, aucun classement n''est publié. Le propriétaire décide.');
end $$;

create or replace function admin_talent_rules_apply_proposal(p_reason text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_reason text := btrim(coalesce(p_reason, '')); p record; cur talent_score_rules; v_applied integer := 0; v_same integer := 0;
begin
  perform _top100_admin('ranking.rules');
  if char_length(v_reason) not between 10 and 500 then raise exception 'Motivez l''enregistrement de la proposition en 10 à 500 caractères'; end if;
  if exists (select 1 from talent_score_rules where active) then raise exception 'Des règles sont déjà actives : la proposition ne remplace que des règles en brouillon'; end if;
  if exists (select 1 from ranking_periods) then raise exception 'Un classement est déjà publié : les règles ne se remplacent plus par une proposition'; end if;
  perform set_config('app.talent_rule_reason', 'Proposition de pondérations initiales (brouillon) : ' || v_reason, true);
  for p in select * from _talent_rules_proposal() order by code loop
    select * into cur from talent_score_rules where code = p.code for update;
    if cur.code is null then continue; end if;
    if (cur.points, cur.cap_per_day, cur.cap_per_period, cur.quality_weight, cur.active) is not distinct from (p.points, p.cap_day, p.cap_period, p.quality_weight::numeric(3, 2), false) then
      v_same := v_same + 1;
    else
      update talent_score_rules set points = p.points, cap_per_day = p.cap_day, cap_per_period = p.cap_period, quality_weight = p.quality_weight, active = false, updated_by = auth.uid() where code = p.code;
      v_applied := v_applied + 1;
    end if;
  end loop;
  perform set_config('app.talent_rule_reason', '', true);
  perform _top100_audit('Proposition de pondérations enregistrée en brouillon', format('%s règle(s) mises à jour, %s inchangée(s), aucune activée : %s', v_applied, v_same, v_reason));
  return jsonb_build_object('ok', true, 'applied', v_applied, 'unchanged', v_same, 'active_rules', (select count(*)::int from talent_score_rules where active), 'draft_only', true,
    'thresholds_proposed', _talent_thresholds_proposal(),
    'note', 'Règles enregistrées en brouillon (inactives) : rien n''est attribué ni publié tant que le propriétaire ne les active pas.');
end $$;

revoke all on function admin_talent_rules_proposal(), admin_talent_rules_apply_proposal(text) from public, anon;
grant execute on function admin_talent_rules_proposal(), admin_talent_rules_apply_proposal(text) to authenticated;
