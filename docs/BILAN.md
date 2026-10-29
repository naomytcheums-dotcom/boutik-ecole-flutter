# Bilan de l'application Boutik-École (branche `feat/figma-fidele`)

Dernière vérification : 29 octobre 2026. Chiffres mesurés dans le dépôt, pas estimés.

## 1. Ce qui existe

- **315 écrans** générés depuis le fichier Figma (`q3uvJnUobbPfhLbcaj0PzJ`) : 234 mobiles, 70 web (1280), 5 borne (720×1280), 1 tablette, 5 échantillons.
- **Fidélité à Figma** : écart moyen par pixel de 2,5 sur 255 ; 305 écrans sur 314 mesurés sont sous 6. Trois écarts supérieurs à 12 (207, 208, 25) viennent des données qui remplacent les photos de la maquette, pas d'un défaut de dessin. L'écran 125 n'a pas pu être comparé (image de référence invalide).
- **Qualité du code** : `flutter analyze` sans aucun problème ; **339 tests verts** (315 comparaisons d'écrans, parcours de soutenance, 24 tests de logique métier).
- **Navigation** : 954 liens `gOpen`, aucune destination inexistante. Parcours de soutenance de 24 écrans testé de bout en bout.

## 2. Niveau de vie des écrans

| Niveau | Écrans | Détail |
|---|---|---|
| Données liées à un état partagé | 65 | achat, compte, vendeur, validation, finance, audit, talents, projets, hackathons, borne, missions |
| dont logique métier testée | 32 | validations de formulaires, workflows, calculs |
| Interactifs sans données | 210 | champs de saisie, interrupteurs, pastilles à choix, boutons avec retour, cœurs, animations, sons |
| Navigation seule | 30 | liens et menu |
| Totalement statiques | 10 | 34, 38, 81, 85, 86, 172, 225, 226, 281, S1 |

Les écrans « interactifs sans données » réagissent (saisie, bascule, retour tactile, sons) mais ne produisent aucun résultat métier : leurs boutons affichent « Démonstration : … ».

## 3. Parcours complets disponibles

1. **Achat** : fiche produit → panier → livraison → paiement → reçu → commande → suivi → historique → facture.
2. **Recherche et favoris** : recherche et catégories filtrent le catalogue (annonces des vendeurs incluses) ; favoris partagés.
3. **Compte** : connexion, inscription validée, code de vérification, mot de passe oublié, choix du profil, profil.
4. **Vendeur** : création d'annonce validée → envoi en validation → catalogue, stocks, commandes reçues, préparation.
5. **Validation et administration** : validation des annonces et des projets par le département, comptes et rôles (suspension bloquante), journal d'audit alimenté par les actions, commissions (liées aux factures), signalements, supervision des commandes, flux financiers.
6. **Contrôle d'accès par rôle** : 10 rôles, page « Accès réservé » avec changement de compte de démonstration.
7. **Talents et opportunités** : annuaire, projets innovants (soumission, validation), offres et candidatures.
8. **Hackathons** : agenda, inscription d'équipe, coéquipiers, dépôt, jury, classement.
9. **Borne phygitale** : catalogue, code QR signé de 5 minutes à usage unique, ticket.
10. **Missions sur mesure** : brief, devis, séquestre par jalons, preuve, libération, revenus.

## 4. Ce qui reste à faire ou à valider

**Accessibilité par la navigation** : 205 écrans n'ont aucun lien entrant (ils s'ouvrent par adresse `#/s/<numéro>` ou par la liste `/catalogue`). Les menus latéraux des consoles web (départements 108–116, institution 117–126, administration 128–138) sont reliés ; il reste à relier le menu des tableaux de bord de type « D1 » (127, 139–144, 187–190), les rubriques mobiles (cercle, communautés, onboarding…) et plusieurs menus secondaires.

**Écrans non traités par une logique** : institution 117–125, modération 130, litiges 133, transactions 134, sécurité 136, configuration 138, finance 140–144, kiosques 145 et incidents 147, administration des missions 198–200, pack multi-filières et score 202–203, startup 204–205, communautés et événements 100–107, onboarding 175–181, Cercle 244–254 (hors saisie), Kéla 230–236 (hors micro), parrainage 240–243, innovations 216–229.

**Limites techniques connues**
- Toutes les données sont **en mémoire** : elles disparaissent au rechargement. Aucun serveur.
- Le **contrôle d'accès** n'existe que dans l'application : il ne protège rien sans serveur.
- Le code de vérification, les paiements, les SMS, le scan du QR de la borne et la dictée de Kéla sont **simulés**.
- Les images des produits viennent de la maquette : un produit ajouté par un vendeur reçoit une photo par défaut.
- Listes limitées au nombre d'emplacements de la maquette (3 à 5 lignes selon l'écran).
- Aucun test sur appareil Android ou iOS (Android Studio non installé ; iOS exige un Mac). Vérifié uniquement dans le navigateur.
- Les sons sont synthétisés ; leur rendu n'a pas été confirmé à l'oreille.
- Les tests de l'ancienne version (Copilot) sont archivés dans `test_legacy/` et ne sont pas exécutés.

## 5. Partie « hors Figma » (non réalisée)

À construire côté serveur, avec les tests proposés dans le rapport d'audit : droits par rôle appliqués à chaque route, isolation entre institutions, paiements Orange Money et MTN MoMo en mode test, QR signé vérifié côté serveur, journal d'audit immuable, certificats (empreinte, ancrage), sauvegardes et restauration, mode hors connexion de la borne, déploiement et supervision.

## 6. Régénérer ou étendre

- Données Figma : `tool/figma_export/fetch_figma.py` (jeton dans `tool/figma_export/.figma_token`, ignoré par Git), puis `python tool/figma_export/convert.py`.
- Liaisons de données et actions : `tool/figma_export/bindings.json` ; états partagés dans `lib/figma/live/`.
- Comparaison à Figma : `python tool/figma_export/score.py` et `side.py`.
- **Le jeton Figma partagé pendant le travail doit être révoqué** (Figma, Paramètres, Sécurité).
