# 05 — Notifications push, e-mail et SMS (phase 3)

## Déjà en production
- Notifications **dans l'application** (table `notifications`). Elles sont produites par les fonctions serveur : commande, préparation, message, annonce validée ou refusée, mission, concours, certificat. Lecture et marquage « lu » sont en place.
- 4 modèles de messages (`notification_templates`, écran 265).

## Ajouté en local (migration `20261101000500`, réplique 12/12, **non appliquée en production**)

| Élément | Règle |
|---|---|
| `notification_preferences` | Par canal (push, e-mail, SMS) et par type. Consentement horodaté. **E-mail et SMS seulement si l'utilisateur les a activés.** Push actif si un appareil est enregistré, désactivable. |
| `device_tokens` | Jetons d'appareil (Android, iOS, web), enregistrés et retirés par leur titulaire |
| `notification_outbox` | File d'envoi alimentée automatiquement à chaque notification. Statuts : en file, envoyé, échec, ignoré. Visible du titulaire, du support et de l'administrateur. |
| Écritures | Uniquement par des fonctions (`set_notification_preference`, `register_device`, `unregister_device`) ; jamais par un visiteur |

**Aucun envoi.** Tant que le répartiteur et les fournisseurs n'existent pas, les lignes restent « en file ». Cela a été vérifié (test N4).

## Reste à faire (décisions du propriétaire requises)

| # | Élément | Dépendance |
|---|---|---|
| 1 | Push : projet **Firebase** (FCM) pour Android et web ; APNs pour iOS | création du projet, clés (`google-services.json`, clé APNs) |
| 2 | E-mail transactionnel (Brevo, Resend, SES…) | choix du fournisseur et coût ; domaine d'envoi vérifié (SPF, DKIM) |
| 3 | SMS (Orange SMS API Cameroun, Twilio…) | choix du fournisseur et coût par SMS ; numéro émetteur |
| 4 | Répartiteur : Edge Function `notify-dispatch` qui lit la file, envoie, retente 3 fois et journalise | fournisseurs 1 à 3 |
| 5 | Écran des préférences (écran 56, « Notifications et confidentialité ») relié à `set_notification_preference` | migration appliquée |
| 6 | Enregistrement de l'appareil au démarrage (`firebase_messaging`) | Firebase |

Matrice des événements (proposée) : commande (payée, prête, livrée) en push et SMS ; message reçu en push ; mission et concours en push et e-mail ; sécurité (mot de passe, connexion) en e-mail, toujours.
