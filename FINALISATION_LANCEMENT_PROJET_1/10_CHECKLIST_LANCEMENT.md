# 10 — Checklist de lancement (phase 8)

## A. Web
- [x] Migrations 20261101000000 à …0300 en production, vérifiées (0 écart, données intactes)
- [x] Site déployé, version servie identique au build, 15/15 tests en ligne
- [x] Compte administrateur réel
- [ ] **Propriétaire** : définir le mot de passe administrateur (« Mot de passe oublié ») et activer la double authentification
- [ ] **Propriétaire** : saisir les stocks réels des 11 produits (écran 62) ; décider le sort de « Logo » et « Cours de maths » (services ou produits)
- [ ] Appliquer 20261101000400 (parrainage) et …0500 (notifications), **autorisation requise**
- [ ] Nettoyer les 46 comptes `zz-test`, **autorisation requise**
- [ ] Paiement : test sandbox avec un vrai événement, puis clés en direct, **autorisation requise**
- [ ] Livraison à domicile : activer seulement si une équipe logistique existe (réglage administrateur)
- [ ] Pages légales et de confidentialité
- [ ] Pousser la branche `feat/figma-fidele` sur GitHub (11 commits locaux), **autorisation requise**

## B. Android
- [x] Chaîne d'outils installée (`flutter doctor` vert)
- [ ] Compiler l'APK après un redémarrage de Windows (au moins 6 Go libres)
- [ ] Clé de téléversement et signature release
- [ ] Test sur appareil réel, puis fiche Google Play (compte développeur : 25 USD)

## C. iOS
- [ ] Mac avec Xcode, compte Apple Developer (99 USD par an)
- [ ] Compilation, signature, TestFlight, fiche App Store
