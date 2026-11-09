# Test SQL de la marketplace sans Docker (Postgres embarqué PGlite)

Rejoue schema.sql et toutes les migrations sur un Postgres embarqué (avec des substituts minimaux pour `auth` et `storage` de Supabase),
puis exécute le scénario `scenario.mjs` (boutiques, RLS, commande multi-boutiques, stock, flash, code promo, idempotence, modération).

    cd supabase/tests/marketplace_pglite
    npm i @electric-sql/pglite
    node replay.mjs all ./scenario.mjs      # attendu : 57/57

Ne remplace pas le test sur la base locale Docker (`run_all_local.py`) quand Docker est disponible.
