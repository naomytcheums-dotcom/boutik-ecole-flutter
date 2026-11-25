-- Lot H12 / INTEGRATION-SQL (2/3) : branche la famille « live animé » (live_hosted) sur le moteur de score (_talent_event_record, 20261127010200).
--  Source : la table lives (champs existants seulement). Un live compte pour son hôte quand :
--    * status = 'ended', avec started_at et ended_at réels (ended_at > started_at) ;
--    * au moins un participant réel : une ligne de live_viewers d'un autre compte actif (non suspendu), non lié à l'hôte (même matricule / même e-mail à l'alias près).
--  Si les seuls participants sont des comptes liés à l'hôte, l'activité est enregistrée puis NEUTRALISÉE (0 point, alerte ouverte) comme en partie A ; sans aucun participant : aucune activité.
--  Qualité non mesurée : null (compte 0). Aucun seuil de durée ni d'audience n'est inventé : la durée et le nombre de participants réels sont seulement tracés dans le détail de l'activité.
--  Live repassé hors « ended » (annulé) ou supprimé => activité annulée et points retirés. Aucune pondération fixée (règle en brouillon), aucun rattrapage de l'existant.
-- Additive et rejouable. Retour arrière : drop trigger trg_talent_lives on lives ; drop trigger trg_talent_lives_delete on lives ; drop function _talent_trg_live(), _talent_sync_live(uuid).

create or replace function _talent_sync_live(p_live uuid) returns void
language plpgsql security definer set search_path = public as $$
declare l lives; v_total integer := 0; v_real integer := 0; v_linked uuid;
begin
  select * into l from lives where id = p_live;
  if l.id is not null and l.status = 'ended' and l.started_at is not null and l.ended_at is not null and l.ended_at > l.started_at then
    select count(*)::int, count(*) filter (where not _talent_linked(l.host_id, v.user_id))::int,
           (array_agg(v.user_id) filter (where _talent_linked(l.host_id, v.user_id)))[1]
      into v_total, v_real, v_linked
      from live_viewers v join profiles p on p.id = v.user_id
      where v.live_id = l.id and v.user_id <> l.host_id and not coalesce(p.suspended, false);
  end if;
  if v_total > 0 then
    perform _talent_event_record(l.host_id, 'live_hosted', 'live', l.id::text, l.ended_at, null, case when v_real = 0 then v_linked end,
      jsonb_build_object('live', l.id, 'duration_sec', extract(epoch from l.ended_at - l.started_at)::int, 'participants', v_real));
  else
    perform _talent_event_cancel('live_hosted', 'live', p_live::text, 'Live non terminé, annulé ou sans participant réel');
  end if;
end $$;
revoke all on function _talent_sync_live(uuid) from public, anon, authenticated;

create or replace function _talent_trg_live() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  begin
    if tg_op = 'DELETE' then
      perform _talent_sync_live(old.id);
      return old;
    end if;
    perform _talent_sync_live(new.id);
  exception when others then raise warning 'talent collecte (live) : %', sqlerrm;
  end;
  return coalesce(new, old);
end $$;
revoke all on function _talent_trg_live() from public, anon, authenticated;
drop trigger if exists trg_talent_lives on lives;
create trigger trg_talent_lives after insert or update of status, started_at, ended_at on lives for each row execute function _talent_trg_live();
drop trigger if exists trg_talent_lives_delete on lives;
create trigger trg_talent_lives_delete after delete on lives for each row execute function _talent_trg_live();
