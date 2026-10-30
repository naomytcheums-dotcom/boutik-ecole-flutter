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
