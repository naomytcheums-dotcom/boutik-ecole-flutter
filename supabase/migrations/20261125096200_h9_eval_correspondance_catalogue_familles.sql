-- Lot H9 / EVAL-SQL (3/3) : rattachement du catalogue de compétences (skill_catalog) aux 33 familles d'évaluation (CDC 8.1).
--  1. table de correspondance assessment_family_skill_map (entrée du catalogue <-> famille ; une entrée peut relever de plusieurs familles) ;
--  2. la table est VIDE à la livraison : aucune correspondance n'est inventée, elle est alimentée par l'administrateur global (2FA, journal d'audit) ;
--  3. lecture par les comptes connectés (assessment_family_map) ; contrôle d'administration des domaines encore sans famille (assessment_family_map_unmapped).
-- Additive et rejouable. Retour arrière : drop function assessment_family_map_set(uuid, text, boolean), assessment_family_map(text), assessment_family_map_unmapped(); drop table assessment_family_skill_map;

create table if not exists assessment_family_skill_map (
  catalog_id uuid not null references skill_catalog (id) on delete cascade,
  family_code text not null references assessment_families (code) on delete cascade,
  created_by uuid references profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (catalog_id, family_code)
);
create index if not exists assessment_family_skill_map_family on assessment_family_skill_map (family_code);

alter table assessment_family_skill_map enable row level security;
revoke all on assessment_family_skill_map from public, anon, authenticated;
grant select on assessment_family_skill_map to authenticated;
drop policy if exists "correspondance catalogue - familles : connectés" on assessment_family_skill_map;
create policy "correspondance catalogue - familles : connectés" on assessment_family_skill_map for select to authenticated using (auth.uid() is not null);

create or replace function assessment_family_map_set(p_catalog uuid, p_family text, p_linked boolean default true) returns void
language plpgsql security definer set search_path = public as $$
declare e skill_catalog;
begin
  perform _assessment_admin_only();
  select * into e from skill_catalog where id = p_catalog;
  if e.id is null then raise exception 'Entrée du catalogue introuvable'; end if;
  if e.status <> 'approved' then raise exception 'Seule une entrée validée du catalogue peut être rattachée à une famille'; end if;
  if not exists (select 1 from assessment_families where code = p_family) then raise exception 'Famille inconnue'; end if;
  if coalesce(p_linked, true) then
    insert into assessment_family_skill_map (catalog_id, family_code, created_by) values (e.id, p_family, auth.uid()) on conflict do nothing;
  else
    delete from assessment_family_skill_map where catalog_id = e.id and family_code = p_family;
  end if;
  perform _assessment_audit('Correspondance catalogue - famille ' || case when coalesce(p_linked, true) then 'ajoutée' else 'retirée' end,
    left(e.domain || coalesce(nullif(' > ' || e.job, ' > '), '') || coalesce(nullif(' > ' || e.skill, ' > '), ''), 120) || ' / ' || p_family, 'Info');
end $$;

create or replace function assessment_family_map(p_family text default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('family_code', m.family_code, 'catalog_id', c.id, 'domain', c.domain, 'job', c.job, 'skill', c.skill)
      order by m.family_code, c.domain, c.job, c.skill)
    from assessment_family_skill_map m join skill_catalog c on c.id = m.catalog_id
    where c.status = 'approved' and (p_family is null or m.family_code = p_family)), '[]'::jsonb);
end $$;

-- Contrôle d'administration : domaines validés du catalogue qui n'ont encore aucune famille.
create or replace function assessment_family_map_unmapped() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not _assessment_staff() then raise exception 'Réservé à l''administrateur global'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('catalog_id', c.id, 'domain', c.domain) order by c.domain)
    from skill_catalog c where c.status = 'approved' and c.job = '' and c.skill = ''
      and not exists (select 1 from assessment_family_skill_map m where m.catalog_id = c.id)), '[]'::jsonb);
end $$;

revoke all on function assessment_family_map_set(uuid, text, boolean), assessment_family_map(text), assessment_family_map_unmapped() from public, anon;
grant execute on function assessment_family_map_set(uuid, text, boolean), assessment_family_map(text), assessment_family_map_unmapped() to authenticated;
