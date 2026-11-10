# Authentification et services transverses (10 novembre 2026)

## 1. Mot de passe oublié (écrans 15 et 16)

- Canaux proposés : **E-mail** (lien Supabase Auth, toujours disponible), **SMS** et **WhatsApp** (affichés seulement si les secrets Twilio sont posés ; l'Edge Function `auth-recovery` répond `{email, sms, whatsapp}`).
- SMS / WhatsApp : `supabase/functions/auth-recovery/index.ts`. Code à 6 chiffres, haché (HMAC-SHA256 avec le secret du service), valable 10 min, 5 essais, 3 codes par heure et par numéro, un seul code actif. Réponse identique que le compte existe ou non. Changement du mot de passe par l'API admin. Table `auth_recovery_codes` (RLS sans politique : aucun accès client).
- Connexion par téléphone : si l'identifiant dérivé du numéro échoue (compte créé avec e-mail ET téléphone), l'action `login_phone` retrouve le compte par son numéro et renvoie une session (même message d'erreur générique en cas d'échec).
- Retour `?code=` (PKCE) sur le web : géré par `supabase_flutter` (événement `passwordRecovery`), puis `lib/app.dart` ouvre l'écran 16. Le lien n'est jamais construit vers `localhost` (`Backend.recoveryRedirect()`).
- **À régler par le propriétaire dans Supabase (non modifiable par l'outil)** : Authentication → URL Configuration → *Site URL* `https://boutik-ecole.vercel.app` ; *Redirect URLs* `https://boutik-ecole.vercel.app/**`.

Déploiement : `npx supabase@2.122.0 functions deploy auth-recovery --use-api --no-verify-jwt`.

## 2. Parrainage (240 à 243)

- Les récompenses sont dans **une seule table** : `referral_rules (tier, min_active, bonus_fcfa, share_pct)`. Elle est livrée **vide** : aucun montant n'est inventé. Tant qu'elle est vide, aucune prime n'est créée, l'application affiche « Récompense non définie » et chaque administrateur reçoit une notification (au plus une par jour) quand un filleul devient actif.
- Définir un palier (administrateur connecté) : `select set_referral_rule('<nom>', <filleuls actifs min>, <prime FCFA>, <part des ventes 0 à 0.5>);` — supprimer : `select delete_referral_rule('<nom>');`.
- Conditions de validation (inchangées) : le filleul devient actif à sa première commande payée d'au moins 10 000 FCFA dans les 90 jours ; gains en attente 14 jours ; annulés si la commande est annulée ; 50 primes par mois et par parrain au plus.
- Prévention des abus : pas d'auto-parrainage, pas de personnel, même numéro refusé, code saisi dans les 30 jours, 20 déclarations par code et par 24 h.
- Boutons « Partager via » (240) : WhatsApp, Facebook et SMS ouvrent le service avec le message prérempli ; Instagram et TikTok n'ont pas de lien de partage de texte : le message est copié.

## 3. Certification du compte

- Demande : `submit_certification_request(motif, liens)` — motif de 20 caractères au moins et au moins un justificatif déposé dans le dossier (écran 154). L'ancienne demande directe n'est plus appelable.
- Décision : `decide_certification(utilisateur, statut, motif)` (département ou administrateur) ; refus et retrait exigent un motif ; la personne est notifiée ; trace d'audit.
- Blocage : `can_publish()` ; les annonces ne passent en validation (`pending`) que pour un compte certifié ou le personnel (déclencheur sur `listings`). Dans l'application, `requireCertified` explique et propose la certification (annonces, publication de reels). Navigation, recherche et achats restent ouverts aux visiteurs. Les brouillons restent libres.

## 4. QR codes

- Table `qr_codes` : jeton aléatoire de 192 bits, UNIQUE, rattaché au propriétaire et au contenu ; codes permanents (profil) retrouvés, codes temporaires (borne → téléphone, 5 min, usage unique) révoqués à la création du suivant.
- Scanner réel (caméra) : `mobile_scanner` ; permission caméra Android ajoutée. Lecture validée par `qr_resolve` (expiration, usage unique). « Mon QR personnel » dans le menu du compte.
- Limite : un appareil photo ordinaire ouvre le site (adresse `/?qr=<jeton>`) ; l'ouverture directe du contenu depuis cette adresse n'est pas faite (seul le scanner de l'application agit).

## 5. Export des données (273)

Téléchargement direct d'un fichier JSON (web) ou feuille de partage (mobile) : profil, annonces, commandes, notifications, documents (métadonnées), adresses, gains, parrainages, demandes de certification, QR. Seules les lignes que la sécurité de la base permet au titulaire de lire sont incluses.
