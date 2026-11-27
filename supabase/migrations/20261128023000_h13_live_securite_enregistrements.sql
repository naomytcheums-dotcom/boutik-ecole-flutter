-- H13 · Sécurité des enregistrements de live : durcissement du retour du webhook LiveKit (live_recording_egress_event). Strictement additif (create or replace, mêmes droits) ; rien n'est supprimé ni modifié dans les données.
-- Le webhook est déjà signé (fonction live-egress-webhook), mais le chemin de fichier qu'il transmet devient le chemin de LECTURE du replay (ticket de stockage) : le serveur le revérifie lui aussi.
--  * chemin sobre : relatif, caractères [A-Za-z0-9._/-], 4 à 251 caractères, ni « .. » ni « // » (aucune remontée d'arborescence, aucun chemin absolu) ;
--  * un fichier déjà attribué à un autre enregistrement n'est jamais repris (un retour forgé ne peut pas pointer vers le replay privé d'un autre live) ;
--  * un chemin refusé donne « échec » avec un motif honnête, jamais « prêt ». Un événement rejoué sur un replay déjà prêt reste sans effet (comportement H12 conservé).
-- Retour arrière : recréer live_recording_egress_event depuis 20261127300000.

create or replace function live_recording_egress_event(p_egress text, p_status text, p_path text, p_duration integer, p_error text) returns text
language plpgsql security definer set search_path = public as $$
declare r live_recordings%rowtype;
begin
  select * into r from live_recordings where egress_id = p_egress for update;
  if not found then return 'inconnu'; end if;
  if r.status = 'pret' then return 'pret'; end if;
  if p_status = 'active' then
    update live_recordings set egress_status = 'active' where id = r.id and egress_status in ('starting', 'active');
    return 'active';
  elsif p_status = 'complete' then
    if p_path is null or char_length(p_path) < 5 or p_duration is null or p_duration <= 0 then
      update live_recordings set egress_status = 'failed', egress_error = 'Fichier ou durée absents du retour de l''enregistreur', note = 'L''enregistrement a échoué' where id = r.id;
      return 'failed';
    end if;
    if p_path !~ '^[A-Za-z0-9][A-Za-z0-9._/-]{3,250}$' or p_path like '%..%' or p_path like '%//%' then
      update live_recordings set egress_status = 'failed', egress_error = 'Chemin de fichier invalide dans le retour de l''enregistreur', note = 'L''enregistrement a échoué' where id = r.id;
      return 'failed';
    end if;
    if exists (select 1 from live_recordings o where o.id <> r.id and o.storage_path = p_path) then
      update live_recordings set egress_status = 'failed', egress_error = 'Fichier déjà attribué à un autre enregistrement', note = 'L''enregistrement a échoué' where id = r.id;
      return 'failed';
    end if;
    begin
      perform live_recording_mark_ready(r.id, p_path, p_duration);
    exception when others then
      update live_recordings set egress_status = 'failed', egress_error = left(sqlerrm, 300), note = 'L''enregistrement a échoué' where id = r.id;
      return 'failed';
    end;
    update live_recordings set egress_status = 'complete', egress_error = null,
      tracks = case when tracks = '[]'::jsonb then jsonb_build_array(jsonb_build_object('kind', 'complete', 'path', p_path)) else tracks end
     where id = r.id;
    return 'pret';
  elsif p_status = 'failed' then
    update live_recordings set egress_status = 'failed', egress_error = left(coalesce(p_error, 'Échec de l''enregistreur'), 300), note = 'L''enregistrement a échoué' where id = r.id;
    return 'failed';
  end if;
  return 'ignore';
end $$;
revoke all on function live_recording_egress_event(text, text, text, integer, text) from public, anon, authenticated;
grant execute on function live_recording_egress_event(text, text, text, integer, text) to service_role;
