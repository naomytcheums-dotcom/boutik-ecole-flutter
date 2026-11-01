-- Précaution (audit de sécurité du 01/11, 07_SECURITE_PAIEMENTS.md) : le rôle anonyme gardait des droits techniques
-- d'écriture sur 8 tables. Ils étaient sans effet (toutes les politiques d'écriture exigent un compte, et orders,
-- order_lines, audit_log n'ont aucune politique d'écriture), mais une politique future mal écrite les rendrait exploitables.
-- Les comptes connectés (authenticated) gardent leurs droits ; la lecture anonyme n'est pas modifiée.
revoke insert, update, delete, truncate, references, trigger on
  audit_log, favorites, hackathon_teams, kiosk_sessions, listings, order_lines, orders, profiles
  from anon;

-- Retour arrière (manuel) : grant insert, update, delete on <table> to anon; pour chaque table (déconseillé).
