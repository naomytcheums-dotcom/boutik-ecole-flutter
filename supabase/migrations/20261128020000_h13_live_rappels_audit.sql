-- H13 · Lives : audit de send_live_reminders (versions 20261115200200 puis 20261127500000) et correctifs. Strictement additif (create or replace de deux fonctions, aucune table modifiée).
-- Défauts corrigés (voir docs/transformation/H13_SEND_LIVE_REMINDERS.md) :
--  1. deux exécutions simultanées pouvaient envoyer deux fois le même rappel (lecture sans verrou) : les lignes sont maintenant verrouillées (for update skip locked) ;
--  2. une seule ligne en échec (déclencheur, contrainte) faisait échouer toute la tâche planifiée et bloquait tous les rappels : chaque rappel est isolé ;
--  3. rappels désactivés par l'hôte après inscription : ils partaient quand même ; ils sont désormais ignorés ;
--  4. live programmé dont l'heure est dépassée de plus de 3 h (jamais démarré) : « commence dans moins de 30 minutes » partait à tort ; ignoré puis nettoyé ;
--  5. hôte suspendu, destinataire suspendu, destinataire banni ou sans accès à un live privé (titre privé divulgué par la notification) : ignorés ;
--  6. le message de l'hôte est nettoyé une seconde fois à l'envoi (liens retirés, 200 caractères) ;
--  7. live_remind_set refuse un live privé sans invitation (même règle d'accès que le direct) ;
--  8. ordre déterministe (les plus proches d'abord) pour la limite de 500.
-- Permissions inchangées : fonction réservée à la tâche pg_cron (rôle postgres) et à service_role ; aucun utilisateur connecté ni visiteur.
-- Retour arrière : recréer les deux fonctions depuis 20261127500000 (send_live_reminders) et 20261115200200 (live_remind_set).

create or replace function send_live_reminders() returns integer
language plpgsql security definer set search_path = public as $$
declare r record; n integer := 0; acc text; msg text;
begin
  for r in
    select rm.live_id, rm.user_id, l.title, l.status, l.scheduled_at, s.notify_message
    from live_reminders rm
    join lives l on l.id = rm.live_id
    join profiles h on h.id = l.host_id and not coalesce(h.suspended, false)
    left join live_settings s on s.live_id = l.id
    where not rm.notified
      and coalesce(s.reminders_enabled, true)
      and ((l.status = 'scheduled' and l.scheduled_at <= now() + interval '30 minutes' and l.scheduled_at > now() - interval '3 hours') or l.status = 'live')
    order by l.scheduled_at nulls last, rm.created_at
    limit 500
    for update of rm skip locked
  loop
    begin
      acc := _live_access(r.live_id, r.user_id);
      if acc not in ('ok', 'billet_requis') then
        -- destinataire suspendu, banni, ou live privé sans invitation : aucun rappel, ligne conservée jusqu'à la fin du live (nettoyée ci-dessous)
        continue;
      end if;
      msg := nullif(left(_clean_live_title(r.notify_message), 200), '');
      insert into notifications (user_id, kind, title, body, data)
      values (r.user_id, 'live_reminder', case when r.status = 'live' then 'Le live a commencé' else 'Un live commence bientôt' end,
              left('« ' || r.title || ' »' || case when r.status = 'live' then ' est en direct.'
                                                    when r.scheduled_at <= now() then ' est sur le point de commencer.'
                                                    else ' commence dans moins de 30 minutes.' end || coalesce(' ' || msg, ''), 500),
              jsonb_build_object('live', r.live_id));
      update live_reminders set notified = true where live_id = r.live_id and user_id = r.user_id;
      n := n + 1;
    exception when others then
      -- un rappel en échec ne bloque pas les autres ; il est clos pour ne pas être rejoué indéfiniment
      raise warning 'send_live_reminders : rappel % / % non envoyé (%)', r.live_id, r.user_id, sqlerrm;
      update live_reminders set notified = true where live_id = r.live_id and user_id = r.user_id;
    end;
  end loop;
  delete from live_reminders rm using lives l
   where l.id = rm.live_id
     and (l.status in ('ended', 'cancelled') or l.created_at < now() - interval '90 days'
          or (l.status = 'scheduled' and l.scheduled_at is not null and l.scheduled_at < now() - interval '1 day'));
  return n;
end $$;
revoke all on function send_live_reminders() from public, anon, authenticated;
grant execute on function send_live_reminders() to service_role;

create or replace function live_remind_set(p_live uuid, p_on boolean default true) returns boolean
language plpgsql security definer set search_path = public as $$
declare l lives%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if current_role_name() is null then raise exception 'Compte suspendu : rappel impossible'; end if;
  select * into l from lives where id = p_live;
  if not found or l.status <> 'scheduled' then raise exception 'Ce live n''est plus programmé'; end if;
  if coalesce(p_on, true) then
    if _live_access(l.id, auth.uid()) not in ('ok', 'billet_requis') then raise exception 'Ce live est privé : rappel impossible sans invitation'; end if;
    if l.scheduled_at is null or l.scheduled_at <= now() then raise exception 'Ce live n''a pas de date à venir'; end if;
    if l.host_id = auth.uid() then raise exception 'Vous êtes l''hôte de ce live'; end if;
    if (select count(*) from live_reminders where user_id = auth.uid() and not notified) >= 50 then raise exception 'Cinquante rappels actifs au plus'; end if;
    insert into live_reminders (live_id, user_id) values (l.id, auth.uid()) on conflict do nothing;
  else
    delete from live_reminders where live_id = l.id and user_id = auth.uid();
  end if;
  return coalesce(p_on, true);
end $$;
revoke all on function live_remind_set(uuid, boolean) from public, anon;
grant execute on function live_remind_set(uuid, boolean) to authenticated;
