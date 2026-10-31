-- Graine de la réplique locale pour les tests : catalogue de la plateforme (repris de 20261029000000_p0_securite.sql, anciennement 20261029_p0_securite.sql).
insert into listings (seller_id, title, department, category, price, stock, description, status) values
 (null,'Lampe en bois recyclé','Génie civil','Maison',25000,100,'Lampe décorative fabriquée à partir de bois de récupération, avec éclairage LED économe.','approved'),
 (null,'Drone éducatif','Génie électrique','Tech',150000,100,'Drone pédagogique programmable, idéal pour l''apprentissage de la robotique.','approved'),
 (null,'Sac à dos design','Design – MMI','Mode',25000,100,'Sac à dos en toile recyclée, dessiné et cousu par les étudiants.','approved'),
 (null,'Pots connectés','Agronomie','Maison',15000,100,'Pots de plantes connectés avec capteur d''humidité.','approved'),
 (null,'Support téléphone','Génie industriel','Tech',8000,100,'Support de téléphone imprimé en 3D, plusieurs coloris.','approved'),
 (null,'Tableau décoratif','Arts – Génie civil','Art',18000,100,'Tableau décoratif peint à la main.','approved'),
 (null,'Ordinateur portable prototype','Informatique','Tech',250000,100,'Prototype d''ordinateur portable conçu et assemblé par les étudiants du département.','approved'),
 (null,'Logo et identité visuelle','MMI','Art',50000,100,'Création d''un logo et d''une identité visuelle complète pour votre projet.','approved'),
 (null,'Cours de soutien en maths','Informatique','Tech',10000,100,'Cours de soutien en mathématiques pour lycéens et étudiants de première année.','approved'),
 (null,'Confiture artisanale','Agronomie','Alimentation',3000,100,'Confiture de fruits locaux préparée au laboratoire de transformation.','approved'),
 (null,'Jus de bissap','Agronomie','Alimentation',1500,100,'Jus de bissap frais, sans conservateur.','approved')
on conflict (title) where seller_id is null do nothing;

-- Bornes de référence (reprises de 20261031000000_missions_…sql) : le dump de schéma ne contient pas les données.
-- Sans effet tant que la table n'existe pas encore sur la réplique (31a non appliquée en production).
do $$ begin
  if to_regclass('public.kiosks') is not null then
    insert into kiosks (id, name, location) values
      ('borne-1', 'Borne 1', 'Hall principal'), ('borne-2', 'Borne 2', 'Bibliothèque'), ('borne-3', 'Borne 3', 'Département MMI'), ('borne-4', 'Borne 4', 'Cafétéria')
    on conflict (id) do nothing;
  end if;
end $$;

-- Données de référence de 20261031000100 (31b), absentes du dump de schéma : établissement et modèles de notification.
do $$ begin
  if to_regclass('public.institution_settings') is not null then
    insert into institution_settings (id, name, acronym, address, email, phone, primary_color, accent_color, font)
    values ('iut-douala', 'IUT de Douala', 'IUT-D', 'Bonabéri, Douala', 'contact@iut-douala.cm', null, '#12253F', '#FBB52B', 'Sans-serif professionnelle')
    on conflict (id) do nothing;
  end if;
  if to_regclass('public.notification_templates') is not null then
    insert into notification_templates (key, label, channels, subject, body) values
      ('order_confirmed', 'Commande confirmée', '{email,sms}', 'Votre commande {{numero}} est confirmée', 'Bonjour {{nom}}, votre commande {{numero}} est confirmée. Retrait : {{point_retrait}}.'),
      ('payment_failed', 'Paiement échoué', '{sms,whatsapp}', null, 'Le paiement de la commande {{numero}} a échoué. Réessayez depuis l''application.'),
      ('order_ready', 'Commande prête au retrait', '{sms,app}', null, 'Votre commande {{numero}} est prête. Code de retrait : {{code}}.'),
      ('quote_received', 'Devis reçu', '{email,app}', 'Nouveau devis pour {{service}}', 'Vous avez reçu un devis de {{montant}} FCFA pour « {{service}} ».')
    on conflict (key) do nothing;
  end if;
end $$;
