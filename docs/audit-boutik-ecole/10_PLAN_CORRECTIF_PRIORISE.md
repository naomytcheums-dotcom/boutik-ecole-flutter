# 10 — Plan correctif priorisé

Ordre fondé sur les dépendances : on sécurise d'abord ce qui est exposé, puis on crée la source de vérité serveur, puis on raccorde les écrans. Aucune de ces actions n'a été entreprise pendant l'audit.

## Étape 0 — Immédiat (avant tout usage réel, ≈ 1 jour)
**État au 29/10/2026 : 0.2 et 0.3 faits ; 0.1 fait en partie (comptes neutralisés, environnements non séparés) ; 0.5 en partie ; 0.4 et 0.6 restent à faire.**

| # | Action | Anomalies | Critère d'acceptation | Test |
|---|---|---|---|---|
| 0.1 | Séparer les environnements : projet Supabase « démo » distinct de la production ; supprimer ou désactiver les 8 comptes de démonstration de la production ; changer les mots de passe | AN-002 | connexion avec le mot de passe de démonstration (visible dans `auth.dart`) refusée en production | tentative de connexion |
| 0.2 | Corriger la politique `profiles` : interdire la modification de `role`/`suspended` (trigger ou privilèges de colonnes) | AN-001 | un utilisateur standard ne peut pas passer `role='admin'` | test REST à deux comptes |
| 0.3 | Retirer l'INSERT direct sur `orders`/`order_lines` ; créer une fonction serveur `create_order` qui recalcule les prix | AN-003 | commande avec faux montant impossible | test d'API |
| 0.4 | Interdire au vendeur de modifier `listings.status` | AN-004 | refus pour un étudiant | test REST |
| 0.5 | Restreindre l'écriture de `orders.reference` au serveur ; comparer montant/devise au retour Notch Pay ; ajouter le webhook signé | AN-005 | rejeu de référence refusé | test de contrat |
| 0.6 | Réactiver « Confirm email » (ou brancher la vérification SMS réelle) | AN-011 | inscription impossible sans code | test d'inscription |

## Étape 1 — Source de vérité serveur (≈ 2 à 3 semaines)
1.1 Auth : Supabase Auth seul, suppression de `Account.password` et de la validation locale (AN-006). 1.2 Dépôts de données (repositories) lisant/écrivant `listings`, `orders`, `favorites`, `missions`, `hackathon_teams`, `kiosk_sessions` ; états de chargement/erreur ; fin des `catch (_) {}` (AN-007, AN-010). 1.3 Numérotation et stock transactionnels côté serveur (AN-008, AN-009). 1.4 RLS par rôle pour chaque table utilisée par un écran d'administration (AN-013). 1.5 Journal d'audit alimenté par des triggers, non par le client (AN-022).
**Critères** : créer une annonce sur l'appareil A, la valider sur B, la voir sur C après rechargement ; aucune donnée métier perdue au rechargement.

## Étape 2 — Parcours principaux de bout en bout
2.1 Paiement vérifié en sandbox puis en production (AN-014). 2.2 Parcours vendeur complet avec commandes reçues alimentées par les commandes clients (réunir `ordersProvider` et `sellerOrdersProvider`). 2.3 Tableaux de bord calculés par vues SQL (AN-012). 2.4 Retirer les 192 actions « Démonstration » par ordre d'importance métier (AN-016), relier les 222 écrans orphelins (AN-015).

## Étape 3 — Qualité et exploitation
3.1 Tests : suite de non-régression décrite dans `08` (AN-001 à AN-005 en premier). 3.2 Performance : chargement différé, compression, budget de poids (AN-018). 3.3 Responsive : versions web adaptatives pour les consoles ; test clavier mobile (AN-019, AN-020). 3.4 Accessibilité : zones tactiles ≥ 44 px, contrastes, sémantique (AN-021). 3.5 Suppression ou archivage de `lib/features` (AN-027). 3.6 CSP et restriction CORS (AN-028, AN-030).

## Étape 4 — Fonctionnalités annexes
Canal WhatsApp (AN-024), messagerie persistée et temps réel (AN-025), compilation Android/iOS et tests sur appareils, notifications.

## Dépendances
0.x → 1.x → 2.x ; 1.1 avant 1.4 ; 1.2 avant 2.2/2.3 ; 0.3 avant 2.1.
