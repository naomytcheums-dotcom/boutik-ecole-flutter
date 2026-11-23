-- Lot L2 (H6) : résolution des incidents de bornes (écrans 147-2 « Incidents et maintenance », 268 « Analytics de la borne », 277 « Supervision des bornes »).
-- Avant : un incident déclaré (report_kiosk_incident) restait « ouvert » pour toujours : aucune fonction ne le marquait résolu, les compteurs « Incidents ouverts »
-- ne baissaient jamais et la liste « Interventions et résolutions » (147-3) restait vide.
-- Maintenant : `kiosk_incident_resolve(p_id, p_status)` marque l'incident résolu (horodaté), remet si on le demande la borne dans l'état choisi et journalise.
-- Gardes : connexion, compte non suspendu, administrateur global (jamais refusé) ou agent avec la permission de support « commandes et bornes » ou technique « maintenance ».
-- Retour arrière : drop function kiosk_incident_resolve(bigint, text);

create or replace function kiosk_incident_resolve(p_id bigint, p_status text default null) returns void
language plpgsql security definer set search_path = public as $$
declare v_kiosk text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not has_any_admin_permission(array['support.orders', 'tech.maintenance']) then raise exception 'Action non autorisée'; end if;
  if p_status is not null and p_status not in ('online', 'offline', 'fallback', 'maintenance') then raise exception 'État de borne invalide'; end if;
  update kiosk_incidents set resolved_at = now() where id = p_id and resolved_at is null returning kiosk_id into v_kiosk;
  if v_kiosk is null then raise exception 'Incident introuvable ou déjà résolu'; end if;
  if p_status is not null then update kiosks set status = p_status, updated_at = now() where id = v_kiosk; end if;
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Incident de borne résolu', v_kiosk, 'Bornes', 'Info');
end $$;

revoke all on function kiosk_incident_resolve(bigint, text) from public, anon;
grant execute on function kiosk_incident_resolve(bigint, text) to authenticated;
