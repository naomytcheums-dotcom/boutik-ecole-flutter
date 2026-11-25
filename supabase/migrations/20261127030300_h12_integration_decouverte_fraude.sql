-- Lot H12 / INTEGRATION-SQL (4/4) : un talent sous alerte de fraude (ouverte ou confirmée) n'est plus joignable par la découverte.
--  _discovery_ok (20261127020300) conditionne favori, vivier, comparaison et demande de contact : il exigeait le consentement, la vérification et la visibilité, mais pas l'absence d'alerte
--  de fraude, alors que le classement et la recherche excluent déjà ces comptes. Ajout de la même exclusion (talent_fraud_flags ouverte ou confirmée) ; rien d'autre ne change.
-- Aucune donnée touchée. Additive et rejouable. Retour arrière : remettre _discovery_ok de 20261127020300.

create or replace function _discovery_ok(p_student uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select p_student is not null and exists (select 1 from talent_visibility_settings v where v.user_id = p_student and v.public_ranking)
    and _talent_listable(p_student)
    and not exists (select 1 from talent_fraud_flags f where f.user_id = p_student and f.status in ('open', 'confirmed'))
    and not exists (select 1 from user_blocks b where (b.blocker_id = p_student and b.blocked_id = auth.uid()) or (b.blocker_id = auth.uid() and b.blocked_id = p_student))
$$;
revoke all on function _discovery_ok(uuid) from public, anon, authenticated;
