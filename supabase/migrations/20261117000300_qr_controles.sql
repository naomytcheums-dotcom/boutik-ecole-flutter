-- QR codes (SQL1-5) : un compte ne peut plus fabriquer un QR « certificat », « événement » ou « retrait » arbitraire qui serait ensuite affiché comme valide.
--  * order_pickup : seulement pour une commande dont l'appelant est l'acheteur ;
--  * event / certificate : réservés à l'équipe (département, direction, support, administrateur).
-- Retour arrière : réappliquer la définition de qr_issue de 20261110000300_qr_codes.sql.

create or replace function qr_issue(p_kind text, p_target_id text, p_label text default '', p_ttl_seconds integer default null, p_single_use boolean default false) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare r qr_codes%rowtype; tok text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') = '' then raise exception 'Compte suspendu : QR impossible'; end if;
  if p_kind not in ('profile', 'listing', 'order_pickup', 'kiosk_transfer', 'event', 'certificate') then raise exception 'Type de QR inconnu'; end if;
  if p_kind = 'profile' and p_target_id <> auth.uid()::text then raise exception 'Vous ne pouvez créer que votre propre QR de profil'; end if;
  if p_kind = 'listing' and not exists (select 1 from listings where id::text = p_target_id and seller_id = auth.uid()) then raise exception 'Cette annonce ne vous appartient pas'; end if;
  if p_kind = 'order_pickup' and not exists (select 1 from orders o where o.number = p_target_id and o.buyer_id = auth.uid()) then raise exception 'Cette commande ne vous appartient pas'; end if;
  if p_kind in ('event', 'certificate') and coalesce(current_role_name()::text, '') not in ('dept', 'direction', 'support', 'admin') then raise exception 'Ce QR est réservé à l''équipe'; end if;
  if p_ttl_seconds is not null and (p_ttl_seconds < 30 or p_ttl_seconds > 86400) then raise exception 'Durée de validité invalide'; end if;
  if p_ttl_seconds is null then
    select * into r from qr_codes where owner_id = auth.uid() and kind = p_kind and target_id = p_target_id and expires_at is null and not revoked;
    if found then return jsonb_build_object('token', r.token, 'expires_at', null, 'single_use', r.single_use, 'created', false); end if;
  else
    update qr_codes set revoked = true where owner_id = auth.uid() and kind = p_kind and target_id = p_target_id and expires_at is not null and not revoked and used_at is null;
  end if;
  loop
    tok := qr_new_token();
    begin
      insert into qr_codes (token, owner_id, kind, target_id, label, single_use, expires_at)
        values (tok, auth.uid(), p_kind, p_target_id, left(coalesce(p_label, ''), 120), p_single_use or p_ttl_seconds is not null and p_kind in ('kiosk_transfer', 'order_pickup'),
                case when p_ttl_seconds is null then null else now() + make_interval(secs => p_ttl_seconds) end)
        returning * into r;
      exit;
    exception when unique_violation then
      if p_ttl_seconds is null and exists (select 1 from qr_codes where owner_id = auth.uid() and kind = p_kind and target_id = p_target_id and expires_at is null and not revoked) then
        select * into r from qr_codes where owner_id = auth.uid() and kind = p_kind and target_id = p_target_id and expires_at is null and not revoked;
        exit;
      end if;
    end;
  end loop;
  return jsonb_build_object('token', r.token, 'expires_at', r.expires_at, 'single_use', r.single_use, 'created', true);
end $$;
revoke all on function qr_issue(text, text, text, integer, boolean) from public, anon;
grant execute on function qr_issue(text, text, text, integer, boolean) to authenticated;
