-- H13.2 (agent 6) : Storage ne sert plus les requêtes d'une session fermée ni d'un compte suspendu.
-- Constat (limite documentée dans 20261129020000_h131_sessions_garde.sql) : un jeton d'accès déjà émis reste valable jusqu'à son expiration pour l'API Storage ;
-- les politiques de storage.objects ne consultaient pas _session_is_live(). Un compte suspendu ou une session fermée pouvait donc encore déposer, supprimer
-- ou lire (compartiments privés) pendant la durée de vie du jeton.
-- Correctif : UNE politique RESTRICTIVE (s'ajoute en ET à toutes les politiques existantes, qui ne sont pas modifiées) pour le rôle authenticated.
--   _session_is_live() renvoie vrai sans revendication exploitable (requête de service, anonyme) : jamais d'indisponibilité du stockage en cas de doute.
-- Hors périmètre : les URL signées déjà émises (valables jusqu'à leur expiration, vérifiées par Storage lui-même) et les URL publiques des compartiments publics.
-- Strictement additive. Retour arrière : drop policy "H13.2 session ouverte" on storage.objects; drop policy "H13.2 <compartiment> : lecture de son dossier" (4).

drop policy if exists "H13.2 session ouverte" on storage.objects;
create policy "H13.2 session ouverte" on storage.objects as restrictive for all to authenticated
  using ((select public._session_is_live()))
  with check ((select public._session_is_live()));

-- Compartiments publics sans politique de lecture : l'API Storage lit la ligne avant de la supprimer (DELETE ... RETURNING exige aussi SELECT), si bien que
-- la suppression par le propriétaire de son propre fichier n'avait aucun effet et laissait le fichier « supprimé » accessible par son URL publique.
-- Lecture limitée au dossier du propriétaire (le contenu de ces compartiments reste public par URL, rien n'est rendu public).
do $$
declare b text;
begin
  foreach b in array array['avatars', 'portfolio-media', 'project-media', 'listing-videos'] loop
    execute format('drop policy if exists %I on storage.objects', 'H13.2 ' || b || ' : lecture de son dossier');
    execute format('create policy %I on storage.objects for select to authenticated using (bucket_id = %L and (storage.foldername(name))[1] = auth.uid()::text)', 'H13.2 ' || b || ' : lecture de son dossier', b);
  end loop;
end $$;
