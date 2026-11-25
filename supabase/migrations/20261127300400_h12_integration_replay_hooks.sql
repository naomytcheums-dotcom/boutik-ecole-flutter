-- H12 · Intégration : les tables `replay_completions` et `user_badges` sont créées en 20261127300100, APRÈS 20261127030000 : les déclencheurs de collecte du score
-- (replay terminé, badge de suivi) ne pouvaient donc pas être posés à ce moment. On les pose ici, une fois les tables présentes. Idempotent, additif ;
-- aucune règle de score n'est activée (les points restent à la décision du propriétaire). Retour arrière : drop trigger des deux tables (voir 20261127030000).
select _talent_install_replay_hooks();
