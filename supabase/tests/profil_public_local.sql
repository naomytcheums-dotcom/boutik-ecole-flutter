begin;

do $$
declare
  r jsonb;
  n int;
begin
  select public_profile('7ba7711e-b66f-4fd6-8693-14eac6f10e3a') into r;
  if r is null then raise exception 'profil public absent'; end if;
  if r->>'name' <> 'Brice Recette' then raise exception 'nom public incorrect: %', r->>'name'; end if;
  if (r->>'posts_count')::int <> 2 then raise exception 'publications visibles attendues: 2, obtenu %', r->>'posts_count'; end if;
  if (r->>'certified')::boolean then raise exception 'certification inventée'; end if;
  if r ? 'phone' or r ? 'email' then raise exception 'donnée privée exposée'; end if;
  if (r->>'rating_count')::int <> 0 then raise exception 'avis attendus: 0'; end if;

  select count(*) into n from author_posts('7ba7711e-b66f-4fd6-8693-14eac6f10e3a', 30);
  if n <> 2 then raise exception 'author_posts attendus: 2, obtenu %', n; end if;

  select count(*) into n from author_posts('00000000-0000-0000-0000-000000000000', 30);
  if n <> 0 then raise exception 'auteur inconnu: publications indues'; end if;

  if public_profile('00000000-0000-0000-0000-000000000000') is not null then
    raise exception 'profil inconnu visible';
  end if;

  if not has_function_privilege('anon', 'public_profile(uuid)', 'execute') then
    raise exception 'profil public non autorisé aux visiteurs';
  end if;
  if not has_function_privilege('anon', 'author_posts(uuid, integer)', 'execute') then
    raise exception 'publications publiques non autorisées aux visiteurs';
  end if;
end $$;

rollback;
