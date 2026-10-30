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
