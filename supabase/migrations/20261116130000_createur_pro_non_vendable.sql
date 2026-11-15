-- createur_pro reste non vendable : la mise en vente d'une offre payante est une décision commerciale du propriétaire (voir 20261116120000).
-- Pour l'ouvrir : update plans set sellable = true where code = 'createur_pro';
update plans set sellable = false where code = 'createur_pro';
