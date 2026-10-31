-- Correctifs P1 sécurité de l'audit (AN-004, AN-022) — à exécuter dans l'éditeur SQL Supabase.

-- AN-004 : un vendeur ne peut ni publier ni valider sa propre annonce ; seul le département ou l'administrateur change le statut.
create or replace function protect_listing_status() returns trigger
language plpgsql security definer set search_path = public as $$
declare r text := coalesce(current_role_name()::text, '');
begin
  if auth.uid() is null then return new; end if;            -- éditeur SQL / service
  if r in ('dept', 'admin') then
    if tg_op = 'UPDATE' and new.status is distinct from old.status then new.reviewed_by := auth.uid(); end if;
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.status := 'pending';
    new.reviewed_by := null;
  else
    if new.status is distinct from old.status and new.status <> 'removed' then
      raise exception 'Seul le département peut valider ou refuser une annonce';
    end if;
    new.reviewed_by := old.reviewed_by;
    new.seller_id := old.seller_id;
  end if;
  return new;
end $$;

drop trigger if exists trg_protect_listing on listings;
create trigger trg_protect_listing before insert or update on listings for each row execute function protect_listing_status();

drop policy if exists "validation par le departement" on listings;
create policy "validation par le departement" on listings for update
  using (seller_id = auth.uid() or current_role_name() in ('dept', 'admin'))
  with check (seller_id = auth.uid() or current_role_name() in ('dept', 'admin'));

-- AN-022 : le journal d'audit n'est plus écrivable directement ; l'acteur est déterminé par le serveur.
drop policy if exists "journal alimente par les utilisateurs connectes" on audit_log;

create or replace function log_audit(p_action text, p_target text, p_category text, p_level text) returns void
language plpgsql security definer set search_path = public as $$
declare who text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select name into who from profiles where id = auth.uid();
  insert into audit_log (actor, action, target, category, level)
  values (coalesce(who, 'Utilisateur'), left(coalesce(p_action, ''), 120), left(coalesce(p_target, ''), 200), left(coalesce(p_category, ''), 40),
          case when p_level in ('Normal', 'Info', 'Sensible', 'Critique') then p_level else 'Normal' end);
end $$;

revoke all on function log_audit(text, text, text, text) from public, anon;
grant execute on function log_audit(text, text, text, text) to authenticated;

select (select count(*) from pg_trigger where tgname in ('trg_protect_listing', 'trg_protect_profile')) as declencheurs,
       (select count(*) from pg_policies where tablename = 'audit_log' and cmd = 'INSERT') as politiques_insert_audit;
