# Questions — Section AA (Borne phygitale : 206–210, 720×1280)

1. **Mise à l'échelle.** La borne est dessinée sur un canevas fixe 720×1280 (`KioskScaffold`), agrandi ou réduit pour remplir l'écran physique. Faut-il prévoir d'autres résolutions de borne (1080×1920) avec une autre disposition ?
2. **FR / EN.** Le sélecteur change la langue de toute l'application ; les textes de la borne sont traduits (fichiers `arb`, clés `kiosk…`). Les noms d'articles, catégories et vendeurs restent en français (contenu publié par les étudiants).
3. **207 — bouton noir rond de la recherche.** La maquette montre un rond noir sans pictogramme au bout du champ de recherche ; reproduit tel quel (étiquette « Que cherchez-vous ? » pour les lecteurs d'écran). Faut-il y mettre un micro (Kéla) ?
4. **207 — Services et Missions.** Les quatre articles de la maquette sont des produits ; les onglets « Services » et « Missions » affichent « Aucun résultat pour le moment. ».
5. **208 — photo.** La « Lampe en bois recyclé » est illustrée par une bétonnière (repris de la maquette, comme en 211/212) ; la galerie reprend les 4 vignettes de la maquette (bétonnière, soudure, maquette, bissap).
6. **208 — « Commander ».** Sur la borne, la commande se poursuit sur le téléphone : « Commander » ouvre le QR (209), comme « Sur mon téléphone ». Faut-il un paiement directement sur la borne ?
7. **209 — QR.** Le QR est généré (paquet `qr`, correction d'erreur élevée, logo au centre) et contient un lien court avec un jeton de session de démonstration. En production, le jeton est émis et signé par le serveur, valable 5 minutes et à usage unique (BACKEND_PLAN.md) : la borne ne signe rien elle-même. Le compte à rebours est réel ; à zéro, le QR s'efface et « Nouveau code » en génère un autre.
8. **209 → 210.** En production, le serveur signale le scan à la borne. En démonstration, toucher le QR simule le scan et ouvre 210.
9. **210 — code-barres.** Le code de suivi est encodé en Code 39 (lisible par une douchette). Faut-il un autre format (Code 128, QR) pour le guichet de retrait ?
10. **210 — retour automatique.** Le compte à rebours de 15 s ramène à l'accueil (206), comme « Terminer ». « Imprimer » affiche « Impression du ticket… » : aucune imprimante n'est pilotée.
11. **206 — état de la borne.** La pastille « Borne prête · réseau OK » est masquée quand l'application est hors connexion (réglage `offline`). Faut-il un écran « Borne hors service » ?
