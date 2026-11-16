-- Création de profil : seules les colonnes de l'inscription sont écrivables par l'utilisateur (S1-86). Le reste (certification, test, suspension,
-- matricule, établissement, avatar, vérification du téléphone…) ne se pose que par des procédures ou par l'équipe.
-- Retour arrière : grant insert on profiles to authenticated.
revoke insert on profiles from anon, authenticated;
grant insert (id, name, email, role, phone) on profiles to authenticated;
