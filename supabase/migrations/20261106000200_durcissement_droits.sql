-- Durcissement des droits (qualification, constat P1) : les comptes anonymes et connectés ont par défaut le droit TRUNCATE (et REFERENCES, TRIGGER) sur toutes les
-- tables du schéma public. TRUNCATE ignore les politiques RLS : un compte connecté qui disposerait d'une connexion SQL directe pourrait vider par exemple le journal d'audit.
-- L'interface de l'application et l'API ne s'en servent jamais ; on retire ces droits. Aucune donnée n'est touchée, aucune fonction n'est modifiée.
-- Retour arrière : grant truncate, references, trigger on all tables in schema public to anon, authenticated;

revoke truncate, references, trigger on all tables in schema public from anon, authenticated;
alter default privileges in schema public revoke truncate, references, trigger on tables from anon, authenticated;
alter default privileges for role postgres in schema public revoke truncate, references, trigger on tables from anon, authenticated;

-- Fonction d'événement interne (activation automatique de la RLS) : inutile aux comptes de l'API.
do $$ begin
  revoke execute on function public.rls_auto_enable() from public, anon, authenticated;
exception when undefined_function then null;
end $$;
