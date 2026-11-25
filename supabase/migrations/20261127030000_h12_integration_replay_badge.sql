-- Lot H12 / INTEGRATION-SQL (1/3) : branche sur le moteur de score (_talent_event_record, 20261127010200) les familles « replay terminé » et « badge vérifié ».
--  1. replay_completed_100 : une ligne de replay_completions (créée par le serveur quand la progression réelle atteint le seuil de complétion de replay_settings) = une activité du
--     bénéficiaire ; l'auteur de l'action est l'hôte du live (suivre son propre replay ou celui d'un compte lié est neutralisé par _talent_precheck, comme en partie A).
--     Suppression de la complétion (replay retiré, reprise de la progression) => activité annulée.
--  2. badge_verified : une ligne de user_badges rattachée à un replay (ref_kind = 'replay') ET adossée à une complétion réelle. Une autre provenance de badge n'est pas branchée
--     (aucune autre source de badge persistée n'existe). Suppression du badge ou de la complétion => activité annulée.
--  Aucune pondération n'est fixée : les règles restent en brouillon (0 point) tant que l'administration ne les active pas. Aucun rattrapage des lignes existantes (rien n'est inséré).
--  Les déclencheurs ne bloquent jamais l'opération d'origine (erreur de collecte = avertissement). Additive et rejouable. Retour arrière :
--   drop trigger trg_talent_replay_completions on replay_completions ; drop trigger trg_talent_user_badges on user_badges ;
--   drop function _talent_install_replay_hooks(), _talent_trg_replay(), _talent_trg_badge(), _talent_linked(uuid, uuid), _talent_live_host(uuid).

-- Deux comptes sont « liés » s'ils partagent le même matricule ou la même adresse e-mail à l'alias près (même logique que _talent_precheck).
create or replace function _talent_linked(p_a uuid, p_b uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles a join profiles b on b.id = p_b where a.id = p_a
    and ((nullif(btrim(a.matricule), '') is not null and lower(btrim(a.matricule)) = lower(btrim(b.matricule)))
         or (a.email is not null and b.email is not null and _talent_email_key(a.email) = _talent_email_key(b.email))))
$$;
revoke all on function _talent_linked(uuid, uuid) from public, anon, authenticated;

create or replace function _talent_live_host(p_live uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select host_id from lives where id = p_live
$$;
revoke all on function _talent_live_host(uuid) from public, anon, authenticated;

create or replace function _talent_trg_replay() returns trigger
language plpgsql security definer set search_path = public as $$
declare b record;
begin
  begin
    if tg_op = 'DELETE' then
      perform _talent_event_cancel('replay_completed_100', 'replay_completion', old.id::text, 'Complétion du replay retirée');
      for b in select id from user_badges where user_id = old.user_id and ref_kind = 'replay' and ref_id = old.recording_id loop
        perform _talent_event_cancel('badge_verified', 'user_badge', b.id::text, 'Complétion du replay retirée : le badge n''est plus vérifiable');
      end loop;
      return old;
    end if;
    perform _talent_event_record(new.user_id, 'replay_completed_100', 'replay_completion', new.id::text, new.completed_at, null, _talent_live_host(new.live_id),
      jsonb_build_object('recording', new.recording_id, 'live', new.live_id, 'coverage', new.coverage));
  exception when others then raise warning 'talent collecte (replay) : %', sqlerrm;
  end;
  return coalesce(new, old);
end $$;
revoke all on function _talent_trg_replay() from public, anon, authenticated;

create or replace function _talent_trg_badge() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_live uuid;
begin
  begin
    if tg_op = 'DELETE' then
      perform _talent_event_cancel('badge_verified', 'user_badge', old.id::text, 'Badge retiré');
      return old;
    end if;
    if new.ref_kind = 'replay' and exists (select 1 from replay_completions c where c.user_id = new.user_id and c.recording_id = new.ref_id) then
      select r.live_id into v_live from live_recordings r where r.id = new.ref_id;
      perform _talent_event_record(new.user_id, 'badge_verified', 'user_badge', new.id::text, new.awarded_at, null, _talent_live_host(v_live),
        jsonb_build_object('code', new.code, 'recording', new.ref_id));
    end if;
  exception when others then raise warning 'talent collecte (badge) : %', sqlerrm;
  end;
  return coalesce(new, old);
end $$;
revoke all on function _talent_trg_badge() from public, anon, authenticated;

-- ATTENTION À L'ORDRE : les tables replay_completions et user_badges naissent dans 20261127300100, APRÈS cette migration (versions triées). L'installation est donc conditionnelle
-- et idempotente : sans effet tant que les tables sont absentes, elle pose les déclencheurs dès qu'elles existent. À rappeler (select _talent_install_replay_hooks();) par une migration
-- postérieure à 20261127300100, ou à obtenir en renommant ce fichier en 20261127300300 : sans cet appel, replay et badge ne sont PAS collectés.
create or replace function _talent_install_replay_hooks() returns text[]
language plpgsql security definer set search_path = public as $$
declare v_done text[] := '{}';
begin
  if to_regclass('public.replay_completions') is not null then
    execute 'drop trigger if exists trg_talent_replay_completions on public.replay_completions';
    execute 'create trigger trg_talent_replay_completions after insert or delete on public.replay_completions for each row execute function _talent_trg_replay()';
    v_done := array_append(v_done, 'replay_completions'::text);
  end if;
  if to_regclass('public.user_badges') is not null then
    execute 'drop trigger if exists trg_talent_user_badges on public.user_badges';
    execute 'create trigger trg_talent_user_badges after insert or delete on public.user_badges for each row execute function _talent_trg_badge()';
    v_done := array_append(v_done, 'user_badges'::text);
  end if;
  return v_done;
end $$;
revoke all on function _talent_install_replay_hooks() from public, anon, authenticated;
select _talent_install_replay_hooks();
