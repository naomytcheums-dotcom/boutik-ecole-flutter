# Procédure de secours : double authentification (2FA) perdue

Applicable à une personne qui ne peut plus produire le code de son application d'authentification (téléphone perdu, volé, réinitialisé).

## 1. La personne a encore un code de secours (cas normal)

1. À la connexion, dans la fenêtre « Vérification en 2 étapes », elle touche **Code de secours** (ou « Utiliser un code de secours » à l'ouverture de l'application).
2. Elle saisit l'un des 8 codes créés lors de l'activation (format `A1B2C3-D4E5F6`). Chaque code ne sert qu'une fois.
3. Le serveur consomme le code, **désactive la 2FA du compte** et notifie la personne. Elle doit réactiver la 2FA depuis « Vérification en 2 étapes » et créer de nouveaux codes.
4. Cinq codes faux en 15 minutes verrouillent la fonction pendant 15 minutes.

Les codes se créent (ou se recréent, ce qui invalide les anciens) depuis « Vérification en 2 étapes » quand la 2FA est active.

## 2. La personne n'a plus de code de secours (support)

L'équipe (administrateur ou support) retire la 2FA **après avoir vérifié l'identité hors de l'application** :

- demande de la personne par le canal d'aide habituel ;
- vérification : pièce d'identité ou carte d'étudiant en cours de validité, comparée au profil ; appel vidéo si le doute subsiste ; adresse e-mail du compte confirmée par un message de retour ;
- jamais sur la seule base d'un message reçu (e-mail, WhatsApp, réseau social).

Puis : menu du compte → **Réinitialiser une double authentification** → e-mail du compte + description de la vérification effectuée (10 caractères au moins).

Règles appliquées par le serveur (`admin_mfa_reset`) :

- réservé à l'administrateur et au support (le support ne peut pas agir sur un compte de l'équipe : seul l'administrateur le peut) ;
- un équipier qui a lui-même la 2FA doit être connecté en niveau aal2 pour utiliser la fonction ;
- impossible sur son propre compte ;
- l'action est inscrite au journal d'audit (niveau « Critique ») et la personne reçoit une notification lui demandant de réactiver la 2FA et, si elle n'est pas à l'origine de la demande, de changer son mot de passe.

## 3. Compte d'administrateur verrouillé

Un administrateur qui a perdu son téléphone et ses codes est réinitialisé par un autre administrateur (même fonction). S'il est le seul administrateur : retirer le facteur depuis le tableau de bord Supabase (Authentication → Users → facteurs MFA) avec les droits du propriétaire du projet.
