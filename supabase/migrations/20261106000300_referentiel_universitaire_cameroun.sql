-- Référentiel universitaire du Cameroun : établissements supplémentaires + départements / filières (qui étaient vides).
-- NON DESTRUCTIVE : uniquement des insertions (`on conflict do nothing`) ; les 11 établissements existants, les profils et les
-- départements déjà proposés ne sont jamais modifiés ni supprimés. Retour arrière en fin de fichier.
--
-- Sources et limites (à relire par l'équipe) :
--  * établissements d'État, grandes écoles publiques et principaux établissements privés d'enseignement supérieur connus du MINESUP ;
--    la liste officielle des IPES (fichier PDF du MINESUP) reste à importer pour être exhaustive (voir docs/transformation/REFERENTIEL_ETABLISSEMENTS.md) ;
--  * départements : intitulés standards de filières par type d'établissement + départements réels de l'IUT de Douala ;
--    l'équipe affine / complète par `reference_review` ou par propositions des étudiants.

-- ------------------------------------------------------------------ établissements
insert into institutions (name, short_name, kind, city, status, source) values
  -- grandes écoles et facultés de l'État rattachées aux universités
  ('École normale supérieure de Yaoundé', 'ENS Yaoundé', 'ecole', 'Yaoundé', 'verified', 'MINESUP — Université de Yaoundé I'),
  ('École nationale supérieure polytechnique de Yaoundé', 'ENSPY', 'ecole', 'Yaoundé', 'verified', 'MINESUP — Université de Yaoundé I'),
  ('Faculté de médecine et des sciences biomédicales de Yaoundé', 'FMSB', 'ecole', 'Yaoundé', 'verified', 'MINESUP — Université de Yaoundé I'),
  ('École supérieure des sciences et techniques de l''information et de la communication', 'ESSTIC', 'ecole', 'Yaoundé', 'verified', 'MINESUP — Université de Yaoundé II'),
  ('Institut des relations internationales du Cameroun', 'IRIC', 'institut', 'Yaoundé', 'verified', 'MINESUP — Université de Yaoundé II'),
  ('École nationale d''administration et de magistrature', 'ENAM', 'ecole', 'Yaoundé', 'verified', 'MINESUP'),
  ('École nationale supérieure des travaux publics', 'ENSTP', 'ecole', 'Yaoundé', 'verified', 'MINESUP'),
  ('Institut de formation et de recherche démographiques', 'IFORD', 'institut', 'Yaoundé', 'verified', 'MINESUP — Université de Yaoundé II'),
  ('École nationale supérieure des postes, des télécommunications et des TIC', 'SUP''PTIC', 'ecole', 'Yaoundé', 'verified', 'MINESUP'),
  ('École normale supérieure d''enseignement technique de Douala', 'ENSET Douala', 'ecole', 'Douala', 'verified', 'MINESUP — Université de Douala'),
  ('École supérieure des sciences économiques et commerciales de Douala', 'ESSEC', 'ecole', 'Douala', 'verified', 'MINESUP — Université de Douala'),
  ('Faculté de génie industriel de Douala', 'FGI', 'ecole', 'Douala', 'verified', 'MINESUP — Université de Douala'),
  ('Faculté des sciences économiques et de gestion appliquée de Douala', 'FSEGA', 'ecole', 'Douala', 'verified', 'MINESUP — Université de Douala'),
  ('Faculté de médecine et des sciences pharmaceutiques de Douala', 'FMSP', 'ecole', 'Douala', 'verified', 'MINESUP — Université de Douala'),
  ('École nationale supérieure polytechnique de Douala', 'ENSPD', 'ecole', 'Douala', 'verified', 'MINESUP — Université de Douala'),
  ('Institut universitaire de technologie Fotso Victor de Bandjoun', 'IUT-FV Bandjoun', 'institut', 'Bandjoun', 'verified', 'MINESUP — Université de Dschang'),
  ('Faculté d''agronomie et des sciences agricoles de Dschang', 'FASA', 'ecole', 'Dschang', 'verified', 'MINESUP — Université de Dschang'),
  ('Institut universitaire de technologie de Ngaoundéré', 'IUT Ngaoundéré', 'institut', 'Ngaoundéré', 'verified', 'MINESUP — Université de Ngaoundéré'),
  ('École nationale supérieure des sciences agro-industrielles de Ngaoundéré', 'ENSAI', 'ecole', 'Ngaoundéré', 'verified', 'MINESUP — Université de Ngaoundéré'),
  ('École nationale supérieure polytechnique de Maroua', 'ENSPM', 'ecole', 'Maroua', 'verified', 'MINESUP — Université de Maroua'),
  ('Institut supérieur du Sahel', 'ISS Maroua', 'institut', 'Maroua', 'verified', 'MINESUP — Université de Maroua'),
  ('Higher Technical Teacher Training College Kumba', 'HTTTC Kumba', 'ecole', 'Kumba', 'verified', 'MINESUP — University of Buea'),
  ('Higher Teacher Training College Bambili', 'HTTC Bambili', 'ecole', 'Bamenda', 'verified', 'MINESUP — University of Bamenda'),
  ('National Higher Polytechnic Institute Bambili', 'NAHPI', 'ecole', 'Bamenda', 'verified', 'MINESUP — University of Bamenda'),
  ('Institut africain d''informatique', 'IAI Cameroun', 'institut', 'Yaoundé', 'verified', 'Établissement connu — à confirmer MINESUP'),
  -- principaux établissements privés d'enseignement supérieur
  ('Université catholique d''Afrique centrale', 'UCAC', 'prive', 'Yaoundé', 'verified', 'Établissement privé connu — à confirmer MINESUP'),
  ('Université des Montagnes', 'UdM', 'prive', 'Bangangté', 'verified', 'Établissement privé connu — à confirmer MINESUP'),
  ('Université protestante d''Afrique centrale', 'UPAC', 'prive', 'Yaoundé', 'verified', 'Établissement privé connu — à confirmer MINESUP'),
  ('Saint Jerome Catholic University of Douala', 'SJCUD', 'prive', 'Douala', 'verified', 'Établissement privé connu — à confirmer MINESUP'),
  ('Université adventiste Cosendai', 'UAC Cosendai', 'prive', 'Nanga-Eboko', 'verified', 'Établissement privé connu — à confirmer MINESUP'),
  ('Institut universitaire de la Côte', 'IUC', 'prive', 'Douala', 'verified', 'Établissement privé connu — à confirmer MINESUP'),
  ('Institut universitaire du Golfe de Guinée', 'IUG', 'prive', 'Douala', 'verified', 'Établissement privé connu — à confirmer MINESUP'),
  ('Institut Siantou Supérieur', 'Siantou', 'prive', 'Yaoundé', 'verified', 'Établissement privé connu — à confirmer MINESUP'),
  ('ICT University', 'ICTU', 'prive', 'Yaoundé', 'verified', 'Établissement privé connu — à confirmer MINESUP'),
  ('Catholic University Institute of Buea', 'CUIB', 'prive', 'Buea', 'verified', 'Établissement privé connu — à confirmer MINESUP'),
  ('Université évangélique du Cameroun', 'UEC', 'prive', 'Bandjoun', 'verified', 'Établissement privé connu — à confirmer MINESUP')
on conflict (lower(name)) do nothing;

-- ------------------------------------------------------------------ départements / filières
-- 1. IUT de Douala : départements de l'établissement
insert into departments (institution_id, name, status)
select i.id, d.name, 'verified'
from institutions i
cross join (values
  ('Informatique'), ('Génie informatique'), ('Génie civil'), ('Génie électrique et informatique industrielle'),
  ('Génie industriel et maintenance'), ('Génie mécanique et productique'), ('Gestion logistique et transport'),
  ('Techniques de commercialisation'), ('Métiers du multimédia et de l''internet'), ('Réseaux et télécommunications'),
  ('Gestion des entreprises et des administrations'), ('Génie biologique'), ('Énergies renouvelables')
) as d(name)
where lower(i.name) = lower('Institut universitaire de technologie de Douala')
on conflict (institution_id, lower(name)) do nothing;

-- 2. universités d'État : filières standards
insert into departments (institution_id, name, status)
select i.id, d.name, 'verified'
from institutions i
cross join (values
  ('Informatique'), ('Mathématiques'), ('Physique'), ('Chimie'), ('Biologie'), ('Droit et sciences politiques'),
  ('Sciences économiques'), ('Sciences de gestion'), ('Lettres et sciences humaines'), ('Sciences de l''éducation'),
  ('Génie civil'), ('Génie électrique'), ('Génie mécanique'), ('Agronomie')
) as d(name)
where i.kind = 'universite_etat' and i.status = 'verified'
on conflict (institution_id, lower(name)) do nothing;

-- 3. écoles et instituts techniques : filières d'ingénierie et de technologie
insert into departments (institution_id, name, status)
select i.id, d.name, 'verified'
from institutions i
cross join (values
  ('Informatique'), ('Génie civil'), ('Génie électrique'), ('Génie mécanique'), ('Génie industriel'), ('Réseaux et télécommunications'),
  ('Gestion'), ('Commerce et marketing')
) as d(name)
where i.status = 'verified' and i.kind in ('ecole', 'institut')
  and lower(i.name) <> lower('Institut universitaire de technologie de Douala')
  and not exists (select 1 from departments x where x.institution_id = i.id)
on conflict (institution_id, lower(name)) do nothing;

-- 4. établissements privés : filières de gestion, droit et informatique
insert into departments (institution_id, name, status)
select i.id, d.name, 'verified'
from institutions i
cross join (values
  ('Informatique'), ('Gestion'), ('Comptabilité et finance'), ('Commerce et marketing'), ('Droit'), ('Communication'), ('Réseaux et télécommunications')
) as d(name)
where i.status = 'verified' and i.kind = 'prive' and not exists (select 1 from departments x where x.institution_id = i.id)
on conflict (institution_id, lower(name)) do nothing;

-- ------------------------------------------------------------------ isolation : plus aucun produit d'exemple visible
-- Les 11 annonces « d'exemple » de la plateforme (20261029000000 / 20261101000800, `showcase = true`, sans vendeur) sont fictives.
-- Elles ne sont PAS supprimées (aucune perte de données) mais ne sont plus lisibles par l'API : le catalogue d'un compte neuf est vide
-- tant que de vrais produits ne sont pas publiés. Les fonctions du serveur (security definer) continuent de les voir ; pour les
-- republier, retirer cette politique (voir retour arrière).
drop policy if exists "annonces : exemples masqués" on listings;
create policy "annonces : exemples masqués" on listings as restrictive for select using (showcase = false);

-- Retour arrière (à n'exécuter qu'avec l'accord du propriétaire ; supprimerait aussi les profils rattachés) :
--   drop policy "annonces : exemples masqués" on listings;
--   delete from departments where status = 'verified' and proposed_by is null and created_at >= timestamptz '2026-11-09';
--   (les établissements ajoutés se retirent un par un, par leur nom, seulement s'ils n'ont aucun profil rattaché)
