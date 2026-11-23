# 04 — Actions « Démonstration » et comportements simulés

## 1. Les 192 actions historiques

Aucune occurrence `Démonstration :` ne subsiste dans le code (vérifié le 31/10, inchangé). Leur devenir est détaillé dans
`AUDIT_REPRISE_20261031/03_AUDIT_ACTIONS_DEMONSTRATION.md`.

**Correction de cet audit** : la méthode du 31/10 classait « serveur » toute fonction qui atteignait Supabase, même de façon indirecte.
Or le journal d'audit (`auditProvider.log` → `log_audit`) écrit sur le serveur. Des actions **purement locales** qui journalisaient leur
geste ont donc été comptées comme réelles :
- `submitBrief`, `acceptQuote`, `payNextMilestone`, `submitProof`, `releaseMilestone`, `askCorrection` (missions 191 à 197) ;
- `submitRegistration`, `submitDeposit`, `validateJury`, `toggleInvite` (concours 160 à 167).

Ces dix actions sont **corrigées le 01/11** quand le serveur est joignable (rapport 02, C5 et C6).

## 2. État des 22 actions ou flux simulés recensés le 31/10, et des 10 découverts le 01/11

| Élément | Avant | Après (local, `6364a6d`) | Statut |
|---|---|---|---|
| Mot de passe oublié et réinitialisation (15, 16) | simulés | réels (Supabase Auth) | **corrigé** (à vérifier après déploiement) |
| Administration des comptes (128) | simulée | réelle (RPC `admin_set_account`) | **corrigé**, migration à appliquer |
| Signalements du support (131, 170) | fictifs | réels (lecture), statut par RPC | **corrigé**, migration à appliquer pour le statut |
| Classement des hackathons | équipes fictives | sans équipe fictive | **corrigé** |
| Code SMS de l'écran 14 | faux envoi | renvoi du lien e-mail réel | **corrigé** |
| 64 « Signaler un souci » | faux signalement | conversation de commande réelle | **corrigé** |
| 164 « Message au mentor » | faux envoi | explication | **honnête** (fonction absente) |
| 165 et 195 « Brouillon » | faux enregistrement | brouillon réel sur l'appareil | **corrigé** |
| 167 « Enregistrer » (jury) | faux brouillon | message exact | **honnête** |
| 192 « Poser une question », 194 « Message à l'équipe » | faux envois | messagerie de mission réelle | **corrigé** |
| 210 « Ticket » | fausse impression | explication | **honnête** (matériel absent) |
| Missions 191 à 197 (6 actions) | simulées (séquestre fictif) | serveur ou explication | **corrigé** (actions) ; **affichage encore fictif** |
| Concours (4 actions) | simulés | engagement réel ou explication | **corrigé** (actions) ; **affichage encore fictif** |
| Jeton QR de la borne (208-210) | calculé dans le navigateur | inchangé | **reste à faire** (P2) |
| 7 actions en attente d'un service (`unavailableAction`) | honnêtes | inchangées | en attente des paiements ou du streaming |

## 3. Contrôle automatique « plus de faux succès »

Liste des boutons dont le gestionnaire se limite à un `gToast` (même méthode que le 31/10, `donnees/messages_seuls_ecrans_apres.csv`) :
- avant : 12 boutons, dont **9 formulés comme un succès** ;
- la relecture du 01/11 en a trouvé **deux autres trompeurs**, que le motif ne classait pas en « succès » : 110 « Export … en cours de
  préparation » et 161 « Lien du concours copié ». Ils sont **corrigés** (`04a0dbd`) ;
- après : **2 boutons, 0 formulé comme un succès** : 164 « Discussion d'équipe : bientôt disponible » et le message exact de 167.
  110 et 161 appellent désormais l'action réelle.

## 4. Ce qui dépend d'une validation humaine ou de vous

- Statut et retrait d'un signalement, rôles et suspensions : action d'un modérateur ou d'un administrateur **réel** (comptes à créer
  par vous).
- Demandes de certification : décision de l'administration.
- Suppression de compte (273) : demande enregistrée, traitement manuel par l'équipe.
