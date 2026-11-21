# Tests sur le serveur réel (Supabase)

Contrairement à `supabase/tests/marketplace_pglite` (base embarquée) et aux tests Flutter (faux serveur local), ces scripts interrogent
**le vrai projet Supabase** avec les comptes de test `test-<rôle>@boutik-ecole.test` (visitor, client, student, company, other, dept, direction, finance, support, admin).

```bash
export LIVE_PASSWORD='...'            # mot de passe des comptes de test : jamais écrit dans le dépôt
node supabase/tests/live/live_writes.mjs   # écritures, isolation entre comptes, lives, offres : affiche OK / ECHEC
node supabase/tests/live/live_matrix.mjs   # 218 fonctions de lecture x 10 comptes -> live_matrix.json
```

- Les écritures sont limitées aux comptes de test et marquées « [TEST ECRITURE] ».
- Aucun paiement, aucun SMS, aucune action sur un compte réel.
- Un échec ici signifie qu'une fonctionnalité ne marche pas **en production**, quel que soit le résultat des tests locaux.
- Ces scripts ne remplacent pas un essai sur téléphone : ils ne voient ni l'interface ni les notifications reçues.
