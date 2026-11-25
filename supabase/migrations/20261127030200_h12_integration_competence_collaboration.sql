-- Lot H12 / INTEGRATION-SQL (3/3) : branche « compétence démontrée » (skill_demonstrated) et « collaboration » sur le moteur de score (_talent_event_record, 20261127010200).
--  1. skill_demonstrated : une compétence du Talent Passport (talent_skills) dont le justificatif (user_documents) est VÉRIFIÉ par un humain (status = 'verified', document du même titulaire).
--     L'auteur de l'action est le vérificateur du document. Justificatif retiré, rejeté ou repassé en attente, compétence supprimée => activité annulée. Une compétence sans justificatif
--     vérifié n'est jamais branchée (déclaration simple).
--  2. collaboration : un projet APPROUVÉ (projects.status = 'approved') avec au moins deux étudiants réels actifs (le propriétaire + les membres ayant ACCEPTÉ l'invitation, project_members).
--     Une activité par membre (origine = projet:membre) ; l'auteur de l'action est un autre membre, non lié si possible : si tous les autres membres sont des comptes liés (même matricule ou
--     même e-mail à l'alias près), l'activité est NEUTRALISÉE (0 point, alerte ouverte) comme en partie A. Projet repassé hors « approved », membre parti ou supprimé, moins de deux membres
--     réels => activités annulées. Les missions ne sont pas branchées : une mission n'a qu'un prestataire (déjà comptée par mission_validated), donc aucune collaboration multi-membres réelle.
--  Aucune pondération fixée (règles en brouillon), aucun rattrapage de l'existant. Additive et rejouable. Retour arrière :
--   drop trigger trg_talent_skills on talent_skills ; drop trigger trg_talent_skill_docs on user_documents ; drop trigger trg_talent_collab_projects on projects ;
--   drop trigger trg_talent_collab_projects_delete on projects ; drop trigger trg_talent_collab_members on project_members ;
--   drop function _talent_trg_skill(), _talent_trg_skill_doc(), _talent_trg_collab(), _talent_sync_skill(uuid), _talent_sync_collab(uuid).

create or replace function _talent_sync_skill(p_skill uuid) returns void
language plpgsql security definer set search_path = public as $$
declare s talent_skills; d user_documents;
begin
  select * into s from talent_skills where id = p_skill;
  if s.id is not null and s.proof_document_id is not null then
    select * into d from user_documents where id = s.proof_document_id;
  end if;
  if s.id is not null and d.id is not null and d.status = 'verified' and d.owner_id = s.owner_id then
    perform _talent_event_record(s.owner_id, 'skill_demonstrated', 'talent_skill', s.id::text, coalesce(d.reviewed_at, s.updated_at), null, d.reviewed_by,
      jsonb_build_object('skill', s.skill, 'level', s.level, 'document', d.id));
  else
    perform _talent_event_cancel('skill_demonstrated', 'talent_skill', p_skill::text, 'Justificatif non vérifié, retiré, ou compétence supprimée');
  end if;
end $$;
revoke all on function _talent_sync_skill(uuid) from public, anon, authenticated;

create or replace function _talent_trg_skill() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  begin
    perform _talent_sync_skill(case when tg_op = 'DELETE' then old.id else new.id end);
  exception when others then raise warning 'talent collecte (compétence) : %', sqlerrm;
  end;
  return coalesce(new, old);
end $$;
revoke all on function _talent_trg_skill() from public, anon, authenticated;
drop trigger if exists trg_talent_skills on talent_skills;
create trigger trg_talent_skills after insert or update of proof_document_id, owner_id or delete on talent_skills for each row execute function _talent_trg_skill();

create or replace function _talent_trg_skill_doc() returns trigger
language plpgsql security definer set search_path = public as $$
declare s record;
begin
  begin
    for s in select id from talent_skills where proof_document_id = new.id loop
      perform _talent_sync_skill(s.id);
    end loop;
  exception when others then raise warning 'talent collecte (justificatif) : %', sqlerrm;
  end;
  return new;
end $$;
revoke all on function _talent_trg_skill_doc() from public, anon, authenticated;
drop trigger if exists trg_talent_skill_docs on user_documents;
create trigger trg_talent_skill_docs after update of status on user_documents for each row execute function _talent_trg_skill_doc();

create or replace function _talent_sync_collab(p_project uuid) returns void
language plpgsql security definer set search_path = public as $$
declare p projects; v_members uuid[] := '{}'; v_uid uuid; v_other uuid; v_keep text[] := '{}'; e record;
begin
  select * into p from projects where id = p_project;
  if p.id is not null and p.status = 'approved' then
    select coalesce(array_agg(x.uid order by x.uid), '{}') into v_members
      from (select p.owner_id as uid union select pm.user_id from project_members pm where pm.project_id = p.id and pm.status = 'accepted') x
      where _talent_is_student(x.uid);
    if cardinality(v_members) >= 2 then
      foreach v_uid in array v_members loop
        select t.o into v_other from unnest(v_members) as t(o) where t.o <> v_uid order by _talent_linked(v_uid, t.o), t.o limit 1;
        perform _talent_event_record(v_uid, 'collaboration', 'project', p.id::text || ':' || v_uid::text, p.updated_at, null, v_other,
          jsonb_build_object('project', p.id, 'members', cardinality(v_members)));
        v_keep := v_keep || (p.id::text || ':' || v_uid::text);
      end loop;
    end if;
  end if;
  for e in select source_id from talent_events
           where rule_code = 'collaboration' and source_kind = 'project' and source_id like p_project::text || ':%' and status = 'confirmed' and not (source_id = any (v_keep)) loop
    perform _talent_event_cancel('collaboration', 'project', e.source_id, 'Projet non approuvé, membre parti ou moins de deux membres réels');
  end loop;
end $$;
revoke all on function _talent_sync_collab(uuid) from public, anon, authenticated;

create or replace function _talent_trg_collab() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_project uuid;
begin
  begin
    if tg_table_name = 'projects' then v_project := case when tg_op = 'DELETE' then old.id else new.id end;
    else v_project := case when tg_op = 'DELETE' then old.project_id else new.project_id end;
    end if;
    perform _talent_sync_collab(v_project);
  exception when others then raise warning 'talent collecte (collaboration) : %', sqlerrm;
  end;
  return coalesce(new, old);
end $$;
revoke all on function _talent_trg_collab() from public, anon, authenticated;
drop trigger if exists trg_talent_collab_projects on projects;
create trigger trg_talent_collab_projects after update of status, owner_id on projects for each row execute function _talent_trg_collab();
drop trigger if exists trg_talent_collab_projects_delete on projects;
create trigger trg_talent_collab_projects_delete after delete on projects for each row execute function _talent_trg_collab();
drop trigger if exists trg_talent_collab_members on project_members;
create trigger trg_talent_collab_members after insert or update of status or delete on project_members for each row execute function _talent_trg_collab();
