-- H13.2 agent 4 SOCIAL : confidentialité des contenus sociaux (profil privé, compte suspendu, compte bloqué).
-- Avant : les RPC de fil et de profil filtraient déjà ces cas, mais la lecture directe des tables (posts, post_comments, portfolio_items) et quelques RPC
-- (public_profile, talent_passport, public_projects, public_project_get, _post_accessible) laissaient voir les contenus d'un compte privé, suspendu ou bloqué.
--  * posts : une publication d'un compte suspendu n'est plus lisible ; hors communauté, elle respecte la visibilité du profil ; un compte bloqué (dans un sens ou l'autre) ne la voit plus ;
--  * post_comments : les commentaires d'un compte suspendu ou bloqué ne sont plus lisibles (ils suivent aussi la politique de posts) ;
--  * _post_accessible (commentaires, pièces jointes, médias privés) : même règle que la politique de posts ;
--  * portfolio_items, public_profile, talent_passport, public_projects, public_project_get, _talent_visible : un compte bloqué avec le propriétaire ne voit rien ; projets d'un profil privé masqués.
--    Pour le profil et le passeport, seule la personne bloquée perd l'accès (la personne qui bloque garde l'accès au profil bloqué pour pouvoir le débloquer).
-- Les politiques et fonctions déjà modifiées en place par H2/K1/H13 (dont l'enveloppe _rl_public_projects) sont MODIFIÉES SUR PLACE (condition ajoutée) et non recréées :
-- cloisonnement par département, permissions d'équipe et limite de débit restent intacts. Strictement additif (aucune donnée supprimée).
-- Retour arrière : retirer la condition « _h132_author_visible / _h132_viewer_blocked » des politiques posts, post_comments, portfolio_items et des fonctions modifiées ;
--   recréer _post_accessible depuis 20261120020300 et _talent_visible depuis 20261117080000, record_post_share depuis 20261117070000 ;
--   drop function _h132_viewer_blocked(uuid), _h132_blocked_by(uuid), _h132_author_visible(uuid, boolean).

-- L'appelant et p_owner sont-ils bloqués l'un avec l'autre ?
create or replace function _h132_viewer_blocked(p_owner uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and p_owner is not null and p_owner <> auth.uid()
     and exists (select 1 from user_blocks b where (b.blocker_id = auth.uid() and b.blocked_id = p_owner) or (b.blocker_id = p_owner and b.blocked_id = auth.uid()))
$$;
-- Le propriétaire a-t-il bloqué l'appelant ?
create or replace function _h132_blocked_by(p_owner uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and exists (select 1 from user_blocks b where b.blocker_id = p_owner and b.blocked_id = auth.uid())
$$;
-- Le contenu public de p_author est-il montrable à l'appelant (non suspendu, non bloqué, et profil visible si p_profile) ?
create or replace function _h132_author_visible(p_author uuid, p_profile boolean default true) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(p_author = auth.uid(), false)
      or (exists (select 1 from profiles a where a.id = p_author and not coalesce(a.suspended, false) and (not p_profile or profile_visible(p_author)))
          and not _h132_viewer_blocked(p_author))
$$;
revoke all on function _h132_viewer_blocked(uuid), _h132_blocked_by(uuid), _h132_author_visible(uuid, boolean) from public;
grant execute on function _h132_viewer_blocked(uuid), _h132_blocked_by(uuid), _h132_author_visible(uuid, boolean) to anon, authenticated;

-- Ajoute une condition à une politique de lecture existante (définition en vigueur relue, jamais recréée).
create or replace function _h132_and_policy(p_table text, p_policy text, p_extra text) returns void
language plpgsql set search_path = public as $$
declare v_q text;
begin
  select qual into v_q from pg_policies where schemaname = 'public' and tablename = p_table and policyname = p_policy;
  if v_q is null then raise exception 'H13.2 : politique introuvable % / %', p_table, p_policy; end if;
  if position('_h132_' in v_q) > 0 then return; end if;
  execute format('alter policy %I on public.%I using ((%s) and (%s))', p_policy, p_table, v_q, p_extra);
end $$;

select _h132_and_policy('posts', 'publications visibles',
  $e$status <> 'published' or author_id = auth.uid() or _h132_author_visible(author_id, community_id is null)
     or coalesce(current_role_name()::text, '') in ('admin', 'support') or _dept_sees(author_id)
     or (auth.uid() is not null and _staff_perm(array['security.moderation', 'security.reports']))$e$);
select _h132_and_policy('post_comments', 'commentaires visibles',
  $e$author_id = auth.uid() or _h132_author_visible(author_id, false)
     or coalesce(current_role_name()::text, '') in ('admin', 'support') or _dept_sees(author_id)
     or (auth.uid() is not null and _staff_perm(array['security.moderation', 'security.reports']))$e$);
select _h132_and_policy('portfolio_items', 'portfolio : selon la visibilité du profil', $e$owner_id = auth.uid() or not _h132_viewer_blocked(owner_id)$e$);

-- Modification sur place d'une fonction (définition en vigueur, enveloppes _rl_/_au_ comprises) : première occurrence du motif remplacée.
create or replace function _h132_patch_fn(p_name text, p_old text, p_new text) returns integer
language plpgsql set search_path = public as $$
declare r record; v_def text; n integer := 0; v_done integer := 0; pos integer;
begin
  for r in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.prokind = 'f' and p.proname in (p_name, '_rl_' || p_name, '_au_' || p_name) loop
    v_def := replace(pg_get_functiondef(r.oid), E'\r\n', E'\n');
    if position(p_new in v_def) > 0 then v_done := v_done + 1; continue; end if;
    pos := position(p_old in v_def);
    if pos = 0 then continue; end if;
    execute overlay(v_def placing p_new from pos for char_length(p_old));
    n := n + 1;
  end loop;
  if n = 0 and v_done = 0 then raise exception 'H13.2 : fonction ou motif introuvable : %', p_name; end if;
  return n;
end $$;

select _h132_patch_fn('public_profile', 'and profile_visible(p.id)', 'and profile_visible(p.id) and not _h132_blocked_by(p.id)');
select _h132_patch_fn('talent_passport', 'if not found or not profile_visible(v_user) then return null; end if;',
                      'if not found or not profile_visible(v_user) or _h132_blocked_by(v_user) then return null; end if;');
select _h132_patch_fn('public_projects', 'and not exists (select 1 from profiles z where z.id = pr.owner_id and coalesce(z.suspended, false))', 'and _h132_author_visible(pr.owner_id, true)');
select _h132_patch_fn('public_project_get', 'not exists (select 1 from profiles z where z.id = p.owner_id and coalesce(z.suspended, false))', '_h132_author_visible(p.owner_id, true)');
select _h132_patch_fn('_post_accessible', 'where p.id = p_post and p.status = ''published''',
                      'where p.id = p_post and p.status = ''published'' and (_h132_author_visible(p.author_id, p.community_id is null) or coalesce(current_role_name()::text, '''') in (''admin'', ''support'') or (coalesce(current_role_name()::text, '''') = ''dept'' and _dept_sees(p.author_id)))');

drop function _h132_patch_fn(text, text, text);
drop function _h132_and_policy(text, text, text);

-- Vrai tant que l'étudiant n'a pas retiré sa visibilité ; faux pour un compte bloqué avec l'appelant.
create or replace function _talent_visible(p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select t.visible_to_recruiters from student_talent_prefs t where t.user_id = p_user), true) and not _h132_viewer_blocked(p_user)
$$;
revoke all on function _talent_visible(uuid) from public, anon, authenticated;

-- Partage : un compte bloqué avec l'auteur reçoit un refus explicite (au lieu d'un retour silencieux depuis que _post_accessible exclut les comptes bloqués).
create or replace function record_post_share(p_post uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return; end if;
  if not _post_accessible(p_post) then
    if is_blocked_between(auth.uid(), (select author_id from posts where id = p_post)) then raise exception 'Partage impossible avec ce compte'; end if;
    return;
  end if;
  insert into post_shares (post_id, user_id) values (p_post, auth.uid()) on conflict do nothing;
end $$;
