-- Comptes de test sans limite : l'administrateur doit pouvoir essayer tous les boutons. La porte de publication des entreprises
-- (vérification + quotas du forfait) ne s'applique plus aux comptes marqués « test » ; leurs fiches entreprise sont déjà vérifiées.
create or replace function company_gate(p_kind text, p_ignore uuid default null) returns void
language plpgsql security definer set search_path = public as $$
declare v_role text := coalesce(current_role_name()::text, ''); v_status text; pl company_plans%rowtype; v_used integer; v_max integer; v_label text;
begin
  if v_role <> 'company' then return; end if;
  -- Comptes de test de l'administrateur : aucune limite (vérification, quotas), pour tout pouvoir essayer.
  if exists (select 1 from profiles where id = auth.uid() and is_test) then return; end if;
  select status into v_status from company_profiles where owner_id = auth.uid();
  if v_status is distinct from 'approved' then
    raise exception 'Votre entreprise doit être vérifiée par l''administrateur avant de publier : complétez votre fiche entreprise et envoyez vos pièces justificatives.';
  end if;
  select * into pl from company_current_plan(auth.uid());
  if p_kind = 'need' then
    select count(*) into v_used from missions where client_id = auth.uid() and status in ('published', 'assigned', 'in_progress') and (p_ignore is null or id <> p_ignore);
    v_max := pl.max_needs; v_label := 'besoins';
  elsif p_kind = 'offer' then
    select count(*) into v_used from opportunities where poster_id = auth.uid() and status in ('pending', 'published');
    v_max := pl.max_offers; v_label := 'offres';
  else
    select count(*) into v_used from contest_announcements where poster_id = auth.uid() and status in ('pending', 'published') and (p_ignore is null or id <> p_ignore);
    v_max := pl.max_contests; v_label := 'concours';
  end if;
  if v_used >= v_max then
    raise exception 'Votre forfait « % » est atteint : % % actifs sur %. Passez à un forfait supérieur ou clôturez une publication.', pl.name, v_used, v_label, v_max;
  end if;
end $$;
revoke all on function company_gate(text, uuid) from public, anon, authenticated;

update company_profiles c set status = 'approved' where status <> 'approved' and exists (select 1 from profiles p where p.id = c.owner_id and p.is_test);
