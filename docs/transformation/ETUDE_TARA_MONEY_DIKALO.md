# Étude Tara Money / Dikalo (03/11/2026)

Conclusion : **aucune intégration n'est implémentée, et aucune ne doit l'être tant que la documentation officielle n'est pas obtenue.** Aucune API n'est inventée.

## 1. Ce qui a été établi (recherche web, sources citées)

| Point demandé | Résultat |
|---|---|
| Produit « Taramoney » | un service de paiement Mobile Money utilisé via un tableau de bord marchand ; seul indice : un SDK PHP tiers [consolidis/tara-payment](https://packagist.org/packages/consolidis/tara-payment) (v1.0.0, 10 mars 2026, auteur Loic Tiffa, intitulé « SDK non officiel ») |
| Opérateur | **non vérifié** : aucune page officielle trouvée |
| Lien avec Dikalo | **non vérifié** : Dikalo est présenté comme une messagerie camerounaise ([CIO Mag](https://cio-mag.com/cameroun-dikalo-veut-detroner-whatsapp-en-afrique)) ; aucun résultat ne relie Dikalo à Tara Money ni à un agent de paiement WhatsApp |
| Documentation officielle | **introuvable** |
| API | existence suggérée par le SDK tiers (clé API + identifiant d'entreprise tirés du tableau de bord, initiation d'un paiement Mobile Money, rappel par POST) ; **ni URL de base, ni chemins, ni format d'authentification** ne sont publiés |
| Sandbox / production | **non documentés** |
| Signature des webhooks | **aucune vérification décrite** ; le SDK indique une réponse rapide exigée et **aucune nouvelle tentative** en cas d'échec |
| Remboursements, frais, devises, conditions marchandes | **non documentés** |
| Agent WhatsApp | **non vérifié** |

## 2. Conséquences

- Un webhook sans signature documentée ne peut pas valider un paiement : la règle du projet (paiement validé seulement après vérification fiable) interdit de s'en servir seul. Il faudrait une vérification active auprès du prestataire (interrogation du statut par un appel authentifié) si elle existe.
- Pas de nouvelle tentative côté prestataire : il faut une réconciliation périodique côté Boutik-École.
- WhatsApp : un message ou un clic n'est jamais une preuve de paiement. Il pourrait seulement porter un lien de paiement dont la référence, le montant et le bénéficiaire sont affichés dans l'application.

## 3. Architecture multi-prestataires proposée (à construire côté serveur)

Interface commune `PaymentProvider` (fonctions Edge Supabase) : `createTransaction(reference unique, montant entier, devise, bénéficiaire)`, `verify(reference)`, `parseAndVerifyWebhook(corps, en-têtes)`, `refund(reference, montant)`, `capabilities()`. Les prestataires : `notchpay` (existant, à ranger derrière l'interface sans changer son comportement), `taramoney` (**non implémenté**), futurs.

Table unique `payment_transactions` (référence unique, `provider`, `kind` = commande | abonnement | campagne | événement, `subject_id`, montant, devise, statut, dates de création / confirmation / expiration, `provider_ref`, preuve brute, historique) avec idempotence par `unique(provider, provider_ref)` et par clé d'idempotence client. Les statuts ne changent que dans une fonction serveur après vérification.

Les fonds vendeur, plateforme et campagne sont des lignes distinctes d'un registre ; commission, reversement et remboursement sont des paramètres configurables (jamais codés).

## 4. Ce qui manque pour avancer

1. Contact avec Tara Money / Dikalo : documentation officielle, conditions marchandes, accès sandbox, mécanisme de signature, remboursement, frais, devises.
2. Décision du propriétaire sur le périmètre (achats, campagnes, abonnements).
3. Aucune clé n'est lue ni modifiée par ce lot.
