-- Une ligne de commande à 0 FCFA est refusée (S3 : les services « Sur devis » ont un prix 0 en base ; ils se commandent par devis accepté, jamais par le panier).
-- Retour arrière : drop trigger trg_order_line_price on order_lines ; drop function order_line_price_guard().
create or replace function order_line_price_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(new.unit_price, 0) <= 0 then
    raise exception 'Cette offre se commande sur devis : demandez un devis au prestataire';
  end if;
  return new;
end $$;
revoke execute on function order_line_price_guard() from public, anon, authenticated;
drop trigger if exists trg_order_line_price on order_lines;
create trigger trg_order_line_price before insert on order_lines for each row execute function order_line_price_guard();
