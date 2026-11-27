-- H13 · Administration, sécurité, performance (6/7) : limites de débit supplémentaires (RPC coûteuses ou énumérables), mêmes mécanismes que 20261128070000.
--  · promo_preview : essai de codes promotionnels (énumération) ; delivery_quote ; recherches publiques ; export complet des données personnelles ; export d'un vivier.
-- Limites volontairement larges, réglables par l'équipe technique (admin_rpc_rate_limit_set). Une erreur du compteur n'empêche jamais l'appel. Additive et rejouable.
-- Retour arrière : voir 20261128070000 (fonctions « _rl_<nom> »).

insert into rpc_rate_limits (rpc, max_per_client, window_seconds, max_global, note) values
  ('promo_preview', 60, 60, 3000, 'essai de codes promotionnels : empêche l''énumération'),
  ('delivery_quote', 120, 60, null, 'devis de livraison'),
  ('replay_search', 300, 60, null, 'recherche publique de replays'),
  ('institutions_search', 300, 60, null, 'recherche publique d''établissements'),
  ('talent_public_profile', 300, 60, null, 'profil public d''un talent'),
  ('export_my_data', 5, 3600, null, 'export complet des données personnelles (opération coûteuse)'),
  ('pool_export', 20, 3600, null, 'export CSV d''un vivier de talents')
on conflict (rpc) do nothing;

do $$
declare r record; v_sig regprocedure;
begin
  for r in select rpc from rpc_rate_limits where rpc <> 'admin_export_csv' loop -- admin_export_csv appelle _rpc_throttle lui-même (après le contrôle de permission)
    for v_sig in select p.oid::regprocedure from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = r.rpc and p.prokind = 'f' loop
      perform _h13_wrap_fn(v_sig, 'throttle');
    end loop;
  end loop;
end $$;
