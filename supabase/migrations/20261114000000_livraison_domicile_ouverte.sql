-- La livraison à domicile est proposée par défaut (les clients la demandent) ; l'administrateur peut toujours régler ville et frais.
alter table institution_settings alter column home_delivery_enabled set default true;
update institution_settings set home_delivery_enabled = true;
