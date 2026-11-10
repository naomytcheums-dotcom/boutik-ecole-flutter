# Test SQL du réseau social, des Lives et des cadeaux (sans Docker, PGlite)

Rejoue schema.sql et toutes les migrations sur un Postgres embarqué, puis le scénario `scenario.mjs` (publications multi-médias, commentaires et réponses,
histoires, Lives, chat, signalement, bannissement, crédits, cadeaux idempotents, tableau créateur). Attendu : 56 OK, 0 ECHEC.

    mkdir /tmp/pg && cd /tmp/pg && npm init -y && npm i @electric-sql/pglite
    cp <depot>/supabase/tests/reseau_pglite/{replay,scenario}.mjs .
    SUPABASE_DIR=<depot>/supabase node replay.mjs all ./scenario.mjs
