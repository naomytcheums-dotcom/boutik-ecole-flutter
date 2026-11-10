# Communautés, cartes produit, cohérence visuelle (10-11 novembre 2026)

## Communautés (migration `20261111000000_communautes_validation.sql`)
- Création : toujours « en attente » ; l'administrateur (ou le support) valide ou refuse avec motif (`community_decide`), file `communities_pending`, notifications au créateur et aux administrateurs.
- Description : 500 MOTS au plus (contrôle SQL + compteur « N / 500 mots » à l'écran, bouton bloqué au-delà).
- Département : liste lue dans `departments` (statut `verified`, référentiel universitaire), jamais en dur.
- Rôles : propriétaire, administrateur, modérateur, **mentor** (nouveau), membre ; onglets Publications / Membres / Mentors ; le propriétaire ou un administrateur change les rôles.
- Publier : seulement dans une communauté validée. Les communautés existantes restent actives.
- Code : `lib/figma/live/communities.dart` (annuaire, écran 103) et `communities_screens.dart` (création, page, validation). Test SQL : `supabase/tests/communautes_pglite` (18 contrôles ; `cd supabase/tests/marketplace_pglite && node replay.mjs all ../communautes_pglite/scenario.mjs`).

## Boutique vitrine
- Produit : 4 photos au plus + 1 vidéo (le serveur autorisait déjà 8 photos : aucune migration), défilement automatique toutes les 3 s (`AutoCarousel`).

## Carte produit unique
- `lib/figma/live/product_card.dart` (`ProductCardView`) : photo 4:5, titre, prix (barré si remise), boutique, bouton ; deux colonnes sur téléphone. Utilisée par la marketplace (`MarcheProductTile`) et par toutes les listes de produits (`ProductCards`).
- Le visuel exact de la maquette jointe à la conversation d'origine n'était pas accessible : mise en page à confirmer par le propriétaire.

## Cohérence visuelle
- Flèche de retour : `Icons.arrow_back` partout (Material) ; l'icône de retour des écrans Figma est déjà une flèche fine.
- Accueil (03) : avatar en doublon avec l'onglet Profil du menu retiré.
- Icône « soleil » (jour/nuit) retirée : bouton des paramètres de notifications (50) remplacé par l'icône Paramètres ; ligne « Mode sombre » retirée (118).
- Plus aucun nombre d'écrans affiché (catalogue des écrans, laboratoire de design, espace).
