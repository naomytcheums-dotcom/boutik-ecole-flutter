-- H13 · Administration, sécurité, performance (3/7) : index sur les clés étrangères (audit h13_audit.mjs).
-- Sans index côté enfant, chaque suppression ou modification d'une ligne parente (profil, boutique, commande…) parcourt séquentiellement toute la table enfant, et les jointures par clé étrangère
-- ne disposent d'aucun chemin d'accès. Cette migration crée, pour chaque clé étrangère du schéma public qui n'a aucun index dont les colonnes de tête sont celles de la clé, un index « fkix_… ».
-- Rejouable (create index if not exists + recherche des seuls manques). Strictement additive : aucune donnée touchée. Tables de taille modeste au lancement : verrou d'écriture de courte durée.
-- Retour arrière : drop index fkix_… (liste : select indexname from pg_indexes where indexname like 'fkix\_%').

do $$
declare r record; v_cols text; v_names text; v_name text;
begin
  for r in
    select c.oid as coid, c.conrelid, c.conname, c.conkey, cl.relname
    from pg_constraint c join pg_class cl on cl.oid = c.conrelid
    where c.contype = 'f' and c.connamespace = 'public'::regnamespace and cl.relkind in ('r', 'p')
      and not exists (
        select 1 from pg_index i
        where i.indrelid = c.conrelid and i.indisvalid and i.indpred is null
          and (i.indkey::int2[])[0:array_length(c.conkey, 1) - 1] = c.conkey)
    order by cl.relname, c.conname
  loop
    select string_agg(quote_ident(a.attname), ', ' order by k.ord), string_agg(a.attname, '_' order by k.ord)
      into v_cols, v_names
    from unnest(r.conkey) with ordinality k(attnum, ord) join pg_attribute a on a.attrelid = r.conrelid and a.attnum = k.attnum;
    v_name := 'fkix_' || left(r.relname || '_' || v_names, 48) || '_' || substr(md5(r.relname || '.' || r.conname), 1, 8);
    execute format('create index if not exists %I on %s (%s)', v_name, r.conrelid::regclass, v_cols);
  end loop;
end $$;
