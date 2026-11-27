-- H13 SOCIAL 5/6 : modération — signalements de commentaires décidés, notifiés et audités ; résumé de la file.
--  * comment_report_decide(p_report, p_hide, p_note) : modération (security.moderation / security.reports) ou département (son périmètre) ; masquer exige un motif (3 caractères) ;
--    ferme TOUS les signalements ouverts du commentaire, prévient chaque signalant (une fois) et l'auteur du commentaire masqué, journalise la décision dans audit_log ;
--    idempotent : un signalement déjà clos renvoie 'deja_traite' sans nouvelle notification ni nouvelle ligne d'audit ;
--  * social_moderation_summary() : compteurs réels de la file (publications en attente, publications signalées, publications masquées, commentaires signalés) dans le périmètre de la personne.
-- Les décisions sur les publications (moderate_post, post_reports_dismiss) étaient déjà auditées. Le signalement reste idempotent par personne et par cible (contraintes d'unicité existantes).
-- Strictement additif. Retour arrière : drop function comment_report_decide(uuid, boolean, text), social_moderation_summary().

create or replace function comment_report_decide(p_report uuid, p_hide boolean, p_note text default null) returns text
language plpgsql security definer set search_path = public as $$
declare r comment_reports%rowtype; c post_comments%rowtype; v_note text := nullif(btrim(coalesce(p_note, '')), ''); m record;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not (has_admin_permission('security.moderation') or has_admin_permission('security.reports') or coalesce(current_role_name()::text, '') in ('dept')) then raise exception 'Réservé à la modération'; end if;
  select * into r from comment_reports where id = p_report for update;
  if not found then raise exception 'Signalement introuvable'; end if;
  select * into c from post_comments where id = r.comment_id for update;
  if not found or not _dept_visible(c.author_id) then raise exception 'Signalement introuvable'; end if;
  if r.status <> 'open' then return 'deja_traite'; end if;
  if coalesce(p_hide, false) and char_length(coalesce(v_note, '')) < 3 then raise exception 'Motif obligatoire'; end if;
  if coalesce(p_hide, false) then update post_comments set status = 'hidden' where id = c.id; end if;
  for m in select distinct reporter_id from comment_reports where comment_id = c.id and status = 'open' loop
    perform notify_user(m.reporter_id, 'moderation', 'Signalement examiné',
      case when coalesce(p_hide, false) then 'Le commentaire signalé a été masqué. Merci de votre vigilance.' else 'Le commentaire signalé a été examiné : il respecte les règles et reste en ligne.' end,
      jsonb_build_object('post', c.post_id, 'comment', c.id));
  end loop;
  update comment_reports set status = 'closed' where comment_id = c.id and status = 'open';
  if coalesce(p_hide, false) then
    perform notify_user(c.author_id, 'moderation', 'Commentaire masqué', coalesce(v_note, 'Un de vos commentaires a été masqué par la modération.'), jsonb_build_object('post', c.post_id, 'comment', c.id));
  end if;
  insert into audit_log (actor, actor_id, action, target, category, level)
    values (coalesce((select name from profiles where id = auth.uid()), 'Modération'), auth.uid(),
            case when coalesce(p_hide, false) then 'Commentaire masqué' else 'Signalement de commentaire classé' end, c.id::text, 'Modération', 'Sensible');
  return case when coalesce(p_hide, false) then 'masque' else 'classe' end;
end $$;
revoke all on function comment_report_decide(uuid, boolean, text) from public, anon;
grant execute on function comment_report_decide(uuid, boolean, text) to authenticated;

create or replace function social_moderation_summary() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not (has_admin_permission('security.moderation') or has_admin_permission('security.reports') or coalesce(current_role_name()::text, '') in ('dept')) then raise exception 'Réservé à la modération'; end if;
  return jsonb_build_object(
    'posts_pending', (select count(*)::int from posts p where p.status = 'pending' and _dept_visible(p.author_id)),
    'posts_hidden', (select count(*)::int from posts p where p.status = 'hidden' and _dept_visible(p.author_id)),
    'posts_reported', (select count(*)::int from posts p where p.status = 'published' and _dept_visible(p.author_id) and exists (select 1 from post_reports r where r.post_id = p.id and r.status = 'open')),
    'comments_reported', (select count(distinct x.comment_id)::int from comment_reports x join post_comments c on c.id = x.comment_id where x.status = 'open' and _dept_visible(c.author_id)));
end $$;
revoke all on function social_moderation_summary() from public, anon;
grant execute on function social_moderation_summary() to authenticated;
