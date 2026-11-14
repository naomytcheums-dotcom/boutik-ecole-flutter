-- Verrouille la fonction-déclencheur ajoutée par 20261114004200 : elle n'est appelée que par ses déclencheurs (aucun droit d'exécution à vérifier à ce moment-là).
revoke all on function block_suspended_author() from public, anon, authenticated;
-- RETOUR ARRIÈRE : grant execute on function block_suspended_author() to public;
