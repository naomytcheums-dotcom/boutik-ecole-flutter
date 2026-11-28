-- H13.2 (agent 6) : log_audit appelable par le client ne journalise plus que des catégories non sensibles.
-- Constat : n'importe quel compte connecté pouvait écrire une ligne « Finances », « Comptes », « Paramètres »… (falsification,
-- doublons avec les lignes écrites par les fonctions serveur). Désormais :
--  * catégories acceptées depuis le client : Connexions, Validations (événements d'usage, niveau plafonné comme avant) ;
--  * toute autre catégorie est ignorée silencieusement (le client n'attend aucun retour) ;
--  * les actions sensibles (finances, comptes, paramètres, modération, sécurité…) sont écrites par leur fonction serveur
--    (admin_set_account, set_report_status, enveloppes _h13_audit, webhooks de paiement…) ;
--  * les lignes écrites par cette fonction portent origin = 'client' (les lignes serveur restent à NULL).
-- Strictement additive : une colonne nullable, une fonction remplacée ; aucun droit élargi, aucune donnée supprimée.
-- Retour arrière : recréer log_audit depuis 20261117000100_securite_etudiant.sql (la colonne origin peut rester).

alter table audit_log add column if not exists origin text;

create or replace function log_audit(p_action text, p_target text, p_category text, p_level text) returns void
language plpgsql security definer set search_path = public as $$
declare who text; r text := coalesce(current_role_name()::text, ''); v_level text; v_cat text := btrim(coalesce(p_category, ''));
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if r = '' then return; end if;                                    -- compte suspendu : rien n'est journalisé en son nom
  if v_cat not in ('Connexions', 'Validations') then return; end if; -- catégories sensibles : écrites par le serveur uniquement
  if r not in ('admin', 'direction', 'finance', 'support', 'dept')
     and (select count(*) from audit_log where actor_id = auth.uid() and created_at > now() - interval '1 day') >= 200 then
    return;
  end if;
  select name into who from profiles where id = auth.uid();
  v_level := case when p_level in ('Normal', 'Info') then p_level
                  when p_level in ('Sensible', 'Critique') and r in ('admin', 'direction', 'finance', 'support', 'dept') then p_level
                  else 'Normal' end;
  insert into audit_log (actor, actor_id, action, target, category, level, origin)
  values (coalesce(who, 'Utilisateur'), auth.uid(), left(coalesce(p_action, ''), 120), left(coalesce(p_target, ''), 200), v_cat, v_level, 'client');
end $$;
revoke all on function log_audit(text, text, text, text) from public, anon;
grant execute on function log_audit(text, text, text, text) to authenticated;
