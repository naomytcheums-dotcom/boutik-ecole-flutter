# 07 — Sécurité, paiements et administration (phase 5)

## Contrôles de production (lecture seule, 01/11, après les 4 migrations) — `donnees/securite_production_20261101.json`

| Contrôle | Résultat |
|---|---|
| Tables publiques sans RLS | **0** |
| Fonctions SECURITY DEFINER sans `search_path` | **0** |
| Politiques d'écriture « true » (ouvertes à tous) | **0** |
| Fonctions exécutables par un visiteur | 9, toutes en lecture ou en contrôle d'accès : `chat_file_allowed`, `current_role_name`, `is_contest_staff`, `is_mission_participant`, `is_participant`, `listing_rating`, `rls_auto_enable`, `shared_cv`, `verify_certificate` |
| Droits d'écriture techniques accordés au rôle anonyme | 8 tables (`audit_log`, `favorites`, `hackathon_teams`, `kiosk_sessions`, `listings`, `order_lines`, `orders`, `profiles`). **Aucune écriture possible** : toutes les politiques d'écriture exigent un compte (`auth.uid()`), et `orders`, `order_lines` et `audit_log` n'ont aucune politique d'écriture. **Risque faible** ; révocation recommandée par précaution (migration à préparer). |
| Compartiments de fichiers | `chat-files` privé, `project-files` privé, `listing-images` public (photos d'annonces) |
| Appels REST anonymes sur les nouvelles fonctions | **14/14 refusés ou conformes** |
| Comptes | 1 administrateur réel (`naomytcheums@gmail.com`, sans session ouverte), 28 clients, 26 étudiants ; **46 comptes `zz-test` à nettoyer** (procédure prête, autorisation requise) |
| Double authentification | 2 facteurs enregistrés ; parcours MFA testé en production le 31/10 (8/8) |

## Paiements (Notch Pay)
- Fonctions `pay`, `notchpay-webhook` et `notchpay-mcp` déployées le 31/10 ; elles n'ont pas été modifiées aujourd'hui.
- Il n'y a **aucun paiement réel** :
  - 0 commande, 0 événement de paiement ;
  - les écrans de paiement des jalons, de mise en avant (« Propulser ») et de retrait des gains affichent « indisponible ».
- Il reste à faire : test en mode **sandbox** avec un vrai événement, puis passage aux **clés en direct**. Les deux demandent votre autorisation.

## Administration
- Compte administrateur réel créé. Le propriétaire définit son mot de passe avec « Mot de passe oublié ». Aucun mot de passe n'a été affiché ni conservé.
- Le département et l'administrateur gèrent les produits de la plateforme, les concours et la livraison. Les actions sensibles sont journalisées.
