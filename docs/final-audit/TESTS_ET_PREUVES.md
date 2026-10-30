# Tests et preuves (30/10/2026)

## Commandes exécutées
| Commande | Résultat |
|---|---|
| `flutter analyze lib test` | 2 infos (sans erreur) |
| `flutter test` | 348 tests réussis (315 goldens, parcours, logique, identité, rubriques) |
| `python supabase/tests/webhook_e2e.py` | 19/19 (webhook simulé localement) |
| `flutter build web --release` | réussi |
| Tests REST sur la base réelle (comptes jetables, supprimés ensuite) | profil/certification : 18/18 ; favoris : 9/9 ; paiement sandbox : voir NOTCHPAY.md |
| Transaction SQL annulée | approbation et révocation par un valideur, retour arrière et auto-certification refusés, journal écrit |

## Scénarios « deux comptes » (A et B)
Profil A modifié → B inchangé ; A ne voit ni ne modifie le profil de B ; A ne peut ni s'attribuer le badge ni le rôle admin ; favoris isolés et persistants après reconnexion. **Réalisés au niveau API/base**, pas dans l'interface.

## Non exécuté (cause)
- **Playwright / tests E2E navigateur : non réalisés.** L'outil de navigation disponible rend mal le canvas Flutter (captures expirées) ; aucune suite Playwright n'a été écrite.
- Tests responsive (375→1440 px), erreurs réseau, sessions expirées, doubles clics : non réalisés.
- Aucun test écran par écran du comportement (les goldens ne vérifient que le rendu).
- Paiement : Orange Money, sous-paiement avec le vrai fournisseur, webhook réel : non réalisés.

## Captures
Aucune capture de parcours utilisateur archivée (limite ci-dessus).

## Complément du 30/10/2026 (soir)
| Domaine | Commande / script | Résultat |
|---|---|---|
| Annonces vendeur (phase 1) | `supabase/tests/listings_stock_rest.py 1` (base réelle, comptes jetables) | 17/17 : propriété forcée, statut forcé, transitions refusées, validations, doublon |
| Annonces, stock, images (phase 2) | `listings_stock_rest.py 2` + test de suppression d'image refait séparément | 23/23 ; le test de suppression par un autre compte (200, aucune ligne supprimée, fichier toujours présent) remplace un contrôle initial faible |
| Messagerie et notifications | `supabase/tests/messaging_rest.py 1/2/3` | phase 2 : 25/26 — l'échec était un vrai défaut (premier message non compté comme non lu), corrigé par `20261030e` et prouvé en phase 3 (4/4) |
| Favoris | `supabase/tests/favorites_rest.py` | 9/9 |
| Serveur MCP | `python supabase/tests/mcp_e2e.py` ; client officiel `@modelcontextprotocol/inspector` sur la fonction déployée | 26/26 ; `tools/list` et `tools/call` réussis sur l'URL déployée (avec la clé publique Supabase) |
| Tests Flutter | `flutter test` | 355 réussis |

Particularité : l'approbation d'une annonce par un valideur et le passage « payé » d'une commande ont été effectués **en SQL par le propriétaire de la base** (étapes de mise en place des scénarios), car aucun compte valideur ou service ne doit être créé en production. Les comptes, annonces, commandes et conversations de test ont été supprimés après chaque série.

## Complément du 30/10/2026 (nuit)
| Domaine | Résultat |
|---|---|
| `flutter test` | 364 réussis (dont mode invité, messagerie, édition du profil) |
| `conversations_list_rest.py` (base réelle) | 8/8 : nom de l'interlocuteur visible des seuls participants, non-lus, anonyme refusé, `listing_contact` |
| Site déployé | empreinte identique au build (`f1a46344…`) ; contient `my_conversations` et la fenêtre « Un compte est nécessaire » |
| URL MCP publique | **401** `Missing authorization header` : « Verify JWT » encore actif sur `notchpay-mcp` |

## Complément du 31/10/2026
| Domaine | Résultat |
|---|---|
| `flutter test` | 372 réussis |
| Rôle fixé à la création (REST) | 6/6 |
| Pièces jointes, vocaux, conversation de commande (REST, base réelle) | 29/29 |
| Photos et modification d'annonce (REST) | 8/8 |
| Commandes reçues par le vendeur (REST) | 15/15 — le contrôle « mise à jour directe de order_lines refusée » est faible (erreur serveur sans filtre WHERE) |
| Nettoyage | comptes, annonces, commandes, conversations et fichiers de test supprimés après chaque série |

## Complément du 30/10/2026 (lots 2 à 5) — tests réellement exécutés
| Domaine | Commande | Résultat |
|---|---|---|
| Avis, réclamations, signalements (REST, base réelle) | `supabase/tests/feedback_rest.py 1/2/3` | 30/30 (le seul échec initial était un défaut du test : méthode HTTP) |
| Services et devis (REST, base réelle) | `supabase/tests/quotes_rest.py 1/2` | 30/30 (le contrôle « le public ne voit aucune demande » est satisfait par un refus d'accès 401, test ajusté) |
| Engagements (REST, base réelle) | `python supabase/tests/engagements_rest.py` | 18/18 |
| Flutter | `flutter test` | 380 réussis (dont tableau de bord vendeur sans commande, accès à la demande de devis, notes, engagements hors connexion) |
| Navigateur réel (Chromium, site déployé) — visiteur | `e2e/tests/visiteur.spec.ts` | 12/12 (lot 1) |
| Navigateur réel — avis, réclamation, réponse du vendeur, notification, note moyenne, signalement | `e2e/tests/avis.spec.ts` avec trois comptes jetables connectés par le vrai écran de connexion | 9/9 au total, **en plusieurs exécutions** : l'état des comptes se consomme (un avis ou une réclamation ne se redépose pas) ; une série fraîche exige de relancer la préparation (`feedback_rest.py 1`, approbation et paiement en SQL, `2`). Les derniers tests rejoués sur le dernier déploiement ont tous réussi. |
| Navigateur réel — services, demande de devis, réponse du prestataire, acceptation | `e2e/tests/devis.spec.ts` | **4/5 constatés** : liste des services, fiche, réponse du prestataire et acceptation ont réussi ; le test « envoi de la demande » n'a jamais été vu réussi de bout en bout (la demande a bien été créée côté serveur, mais un échec réseau (DNS) a interrompu le test, et la reprise a confirmé que le doublon est refusé avec un message clair). Une série fraîche reste à rejouer. |

### Défauts réels trouvés par ces tests navigateur et corrigés
1. **Tableau de bord vendeur (écran 57) : écran gris pour tout compte vendeur sans commande** (erreur d'index évaluée même quand l'élément est masqué). Corrigé (`orderIdAt`), test unitaire ajouté. Jamais vu avant car les tests précédents ne passaient pas par le navigateur avec un vrai compte vendeur.
2. **« Mes commandes » d'un compte réel affichait l'historique fictif** de la maquette et ignorait les commandes du serveur : les commandes du compte sont maintenant lues sur le serveur (état de préparation, paiement, annulation), l'historique fictif n'est plus mêlé aux comptes réels.
3. **Le message de confirmation (toast) recouvrait le bouton du bas pendant 1,8 s** et absorbait le clic (signalement impossible juste après le choix d'un motif). Les messages sont maintenant posés au-dessus de la barre d'actions.
4. **Montant de devis saisi en double (« 7000070000 »)** : le serveur répondait par une erreur technique de dépassement d'entier ; la saisie est maintenant bornée avec un message clair.
5. La demande de devis (95b) renvoyait « Page introuvable » aux comptes non-entreprise : accès ouvert à tout compte connecté (décision métier documentée, test ajouté).
6. La fiche produit n'offrait aucun moyen de signaler l'annonce (écran 170 sans entrée) : lien « Signaler » ajouté ; l'écran affiche le prix et le vendeur de l'annonce signalée.

### Liens et parcours
`tool/audit/nav_graph.py` : 315 écrans ; **225 atteignables par liens explicites** (95 au début du lot 5) ; 90 listés dans `RESTE_A_FAIRE.md`. Les liens ajoutés sont des zones tactiles posées sur des libellés existants (aucune mise en page modifiée) ; l'outil `tool/audit/apply_journeys.py` est idempotent. **Ces liens n'ont pas été tous parcourus un à un dans un navigateur** : seuls ceux des tests ci-dessus l'ont été.

## Reprise du 30/10/2026 (soir) — tests réellement exécutés
| Domaine | Commande | Résultat |
|---|---|---|
| Flutter | `flutter test` | **394 réussis** (382 constatés à la reprise + 12 nouveaux : liens et routeur, menu du compte par rôle, engagements, préférences) ; 315 goldens inchangés |
| Navigateur réel — parcours par rôle (spec de Claude) | `tests/parcours.spec.ts` | 5/5 avant le déploiement, 5/5 après |
| Navigateur réel — engagements réversibles et préférences | `tests/engagements.spec.ts` | **5/5** : inscription puis désinscription (statut `cancelled` lu sur le serveur, libellé du bouton mis à jour) ; candidature 153 → 159 → 76 → retrait (`cancelled`) ; canaux enregistrés (`channel_prefs.email = true`) et relus après rechargement ; « Paramètres » du menu s'ouvre ; question au vendeur exigée puis traitée par le serveur |
| Navigateur réel — visiteur | `tests/visiteur.spec.ts` | 12/12 |
| Navigateur réel — devis | `tests/devis.spec.ts` | **non exécuté** : comptes de l'état précédent supprimés ; une série neuve exige l'approbation d'un service par le propriétaire de la base |
| REST | — | aucune migration ajoutée, aucun nouveau test REST |

### Défauts trouvés pendant la reprise et corrigés
1. **Liens « Écran introuvable »** : une vingtaine d'appels utilisaient `p3`/`a3` (identifiants réels `P3`/`A3`) ou `148_1`/`147_2`/`146_1` (identifiants réels `148-1`…), dont l'entrée « Paramètres » du menu du compte. Le routeur résout désormais ces formes ; un test parcourt chaque lien de chaque écran.
2. `nav_graph.py` ignorait les identifiants à lettre (`L1`, `P3`…) : 12 écrans étaient comptés orphelins à tort.
3. Écrans 180/181 (gestion des rôles) ouverts à tout visiteur : réservés à l'administration.

## 2ᵉ reprise (30/10/2026, nuit) — tests réellement exécutés
| Domaine | Commande | Résultat |
|---|---|---|
| Flutter | `flutter test` | **401 réussis**, 315 goldens inchangés |
| REST, base isolée (Docker) | `lots_rest.py` · `quotes_rest.py 1/2` · `engagements_rest.py` · `favorites_rest.py` | 77/77 · 30/30 · 18/18 · 9/9 |
| MCP / webhook (vraies fonctions, dépendances simulées) | `mcp_e2e.py` · `webhook_e2e.py` | 27/27 · 19/19 |
| Nettoyage des comptes de test (base isolée) | `maintenance/cleanup_test_accounts.sql` | dry-run correct (22 comptes) ; garde-fou déclenché comme prévu |
| Navigateur, base isolée (build `--dart-define`) | `lots`, `devis`, `engagements`, `parcours`, `visiteur` | **34/34** |
| Navigateur, production | toutes les specs | **24/24** exécutés ; 21 ignorés (base isolée ou état préparé requis) |

Défauts réels trouvés par ces tests et corrigés : texte des lignes de dialogue absent de l'arbre d'accessibilité (`ListView`), retour du réseau qui laissait
l'écran 150-3 affiché (pile de navigation mal lue), écran 47 décalé de 704 px (golden), annulation serveur non reflétée (`cancelled_at`), 3 défauts SQL de la nouvelle migration.
