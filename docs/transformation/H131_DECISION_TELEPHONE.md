# H13.1 — Décision propriétaire : numéro de téléphone en double (lot F)

## Constat (lecture seule sur la production, aucune donnée modifiée)

- Deux profils de production sont marqués `phone_verified = true` avec le **même numéro** (mêmes 9 derniers chiffres).
- Le numéro est écrit sous deux formes : avec préfixe `+` (compte administrateur) et sous forme nationale (compte étudiant). C'est ce qui a permis le doublon : la contrainte `profiles_phone_key` compare le texte exact.
- Comptes créés les 1er et 4 novembre ; domaines gmail ; 0 commande, 0 annonce, 0 message ; l'administrateur n'est dans aucune équipe ; aucun des deux n'est suspendu.
- Leur état « vérifié » ne vient pas d'un code SMS : il vient du marquage global de la migration `20261117990100` (« comptes existants considérés vérifiés »).

## Protections déjà en place

- `profile_set_phone` et `phone_verify_apply` refusent un numéro déjà vérifié sur un autre compte.
- `auth-recovery` (`userByPhone`) renvoie « introuvable » quand deux comptes vérifiés correspondent : ni récupération ni connexion par téléphone pour ce numéro (ambigu, donc sûr).
- Nouveau (migration `20261129900100_h131_garde_telephone_verifie.sql`, **non appliquée en production**) : le déclencheur `profiles_phone_verified_guard` refuse, au niveau base, qu'un numéro vérifié ailleurs soit marqué vérifié sur un autre compte (`Ce numéro est déjà utilisé`, code 23505). Il ne se déclenche que si `phone` ou `phone_verified` change : **les deux comptes existants ne sont pas touchés**.
- Scénario `h131_garde_telephone.mjs` : 12 OK, 0 ECHEC.

## Ce qui reste bloqué (index unique)

L'index unique `profiles_phone_verified_uk` (existe dans les migrations locales, absent en production) ne peut pas être créé tant que le doublon existe. Il ne sera créé qu'après votre décision.

## Options

| Option | Action | Conséquence |
|---|---|---|
| A | Vous confirmez que les deux comptes sont à vous. Vous choisissez le compte qui garde le numéro ; on passe `phone_verified` à `false` sur l'autre (le numéro n'est pas supprimé). | Doublon résolu, index unique créable, récupération par téléphone de nouveau possible pour le compte gardé. Aucun compte supprimé. |
| B | Chaque compte re-vérifie son numéro par SMS. | Une seule vérification peut aboutir. Nécessite le fournisseur SMS configuré. |
| C | On laisse en l'état. | Le déclencheur empêche tout nouveau doublon, mais l'index unique reste absent et la récupération par téléphone reste désactivée pour ce numéro. |

## Ce que je n'ai pas fait

Aucun compte supprimé, aucun numéro modifié, aucune vérification retirée. En attente de votre choix (A, B ou C) et, pour A, du compte à conserver.
