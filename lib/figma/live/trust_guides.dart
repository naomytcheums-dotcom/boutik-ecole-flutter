import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;

import '../nav.dart';
import 'tp_ui.dart';

/// Les quatre guides du Centre de confiance : une page chacun, avec les points à retenir et, au besoin, un accès direct au support.
class _Guide {
  const _Guide(this.title, this.intro, this.steps, {this.action});
  final String title, intro;
  final List<(String, String)> steps;
  final String? action;
}

const _guides = <String, _Guide>{
  'paiement': _Guide(
    'Payer en sécurité par Mobile Money',
    'Votre argent n’est protégé que si le paiement passe par Boutik-École.',
    [
      ('Payez uniquement dans l’application', 'Ne payez jamais en dehors de Boutik-École : un virement direct vers un vendeur n’est ni suivi, ni remboursable.'),
      ('Vérifiez le montant et le vendeur', 'Avant de confirmer sur votre téléphone, relisez le montant en FCFA, le nom de la boutique et la référence de la commande.'),
      ('Ne communiquez jamais votre code secret', 'Orange Money et MTN MoMo ne demandent votre code PIN que sur votre propre téléphone, jamais par message ni par appel.'),
      ('Gardez votre preuve de paiement', 'Chaque commande conserve son reçu dans « Mes commandes ». En cas de problème, ouvrez une réclamation depuis la commande.'),
    ],
  ),
  'annonce': _Guide(
    'Reconnaître une annonce suspecte',
    'Quelques signes permettent d’écarter la plupart des arnaques.',
    [
      ('Un prix trop beau pour être vrai', 'Un prix très inférieur à celui de produits comparables, ou une pression pour acheter vite, doit vous alerter.'),
      ('Un vendeur sans historique', 'Regardez le badge vérifié, la date d’inscription, les avis et les ventes déjà réalisées par la boutique.'),
      ('Des photos ou une description vagues', 'Méfiez-vous des images de catalogue, des textes copiés ou d’une description qui ne précise ni l’état ni le stock.'),
      ('Une demande de sortir de l’application', 'Un vendeur qui propose de continuer par téléphone ou de payer ailleurs doit être signalé.'),
    ],
  ),
  'compte': _Guide(
    'Protéger mon compte',
    'Un compte bien protégé reste le vôtre.',
    [
      ('Choisissez un mot de passe fort', 'Au moins 8 caractères avec une majuscule, un chiffre et un caractère spécial, différent de vos autres comptes.'),
      ('Activez la vérification en 2 étapes', 'Dans Mon compte, « Vérification en 2 étapes » : un code à 6 chiffres, propre à votre compte, est demandé à chaque connexion.'),
      ('Ne partagez jamais vos codes', 'Les codes reçus par SMS, WhatsApp ou e-mail ne doivent être donnés à personne, même à quelqu’un qui se dit de Boutik-École.'),
      ('Déconnectez-vous sur un appareil partagé', 'Sur un téléphone ou un ordinateur qui n’est pas le vôtre, fermez toujours votre session.'),
    ],
  ),
  'signaler': _Guide(
    'Signaler un problème',
    'Chaque signalement est examiné par l’équipe.',
    [
      ('Une annonce ou une publication', 'Utilisez « Signaler » dans le menu de l’annonce ou de la publication et indiquez le motif.'),
      ('Une commande ou un paiement', 'Ouvrez la commande, puis « Réclamation » : décrivez le problème et joignez une capture si possible.'),
      ('Un comportement abusif', 'Bloquez la personne puis signalez-la depuis sa fiche ou depuis la conversation.'),
      ('Un autre problème', 'Contactez le support : la réponse arrive dans l’application.'),
    ],
    action: 'Contacter le support',
  ),
};

Future<void> showTrustGuide(BuildContext context, String id) {
  final g = _guides[id];
  if (g == null) return Future.value();
  return Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (ctx) => TpPage(
      title: g.title,
      children: [
        Text(g.intro, style: tpSt(14, c: tpGrey, h: 1.5)),
        const SizedBox(height: 14),
        for (var i = 0; i < g.steps.length; i++)
          TpCard(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 28, height: 28, alignment: Alignment.center, decoration: const BoxDecoration(color: Color(0xFFEEE9FF), shape: BoxShape.circle), child: Text('${i + 1}', style: tpSt(13, w: FontWeight.w800, c: tpViolet))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g.steps[i].$1, style: tpSt(14, w: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(g.steps[i].$2, style: tpSt(13, c: tpGrey, h: 1.5)),
              ])),
            ]),
          ),
        if (g.action != null) ...[
          const SizedBox(height: 8),
          TpButton(g.action!, () {
            Navigator.of(ctx).pop();
            gOpen(context, '49');
          }),
        ],
      ],
    ),
  ));
}
