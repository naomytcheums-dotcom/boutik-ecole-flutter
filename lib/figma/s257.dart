import 'package:flutter/material.dart';

import 'common.dart';
import 'fx.dart';

/// 257 · Paiement en attente de confirmation (nœud Figma 184:174) — reproduction fidèle.
class F257 extends StatelessWidget {
  const F257({super.key});

  @override
  Widget build(BuildContext context) {
    const a = 'assets/figma/s257';
    final soft = [fxShadow(0, 6, 18, const Color(0x0F403366))];
    return FxScreen(w: 390, h: 844, children: [
      ...fxChrome(onBack: () => Navigator.of(context).maybePop()),
      fxText('Paiement', 0, 76, 17, ink, weight: 500, w: 390, align: TextAlign.center),
      fxText('Commande #BE-2026-0142', 0, 100, 12, grey, w: 390, align: TextAlign.center),
      fxText('En attente de confirmation', 67, 300, 20, ink, weight: 600),
      fxText(
        'Validez le paiement sur votre téléphone avec votre code Orange Money. Cela peut prendre jusqu’à 2 minutes.',
        48, 336, 12, grey, w: 294, lh: 18, align: TextAlign.center,
      ),
      fxBox(24, 410, 342, 150, color: Colors.white, radius: 28, shadow: soft),
      for (final r in const [
        ['Moyen', 'Orange Money', 430.0, 256.0],
        ['Montant', '330 000 FCFA', 462.0, 258.0],
        ['Référence', 'OM-7F3A-2210', 494.0, 250.0],
        ['Délai restant', '01:48', 526.0, 311.0],
      ]) ...[
        fxText(r[0] as String, 44, r[2] as double, 12, grey),
        fxText(r[1] as String, r[3] as double, r[2] as double, 12.5, ink, weight: 600),
      ],
      fxBox(24, 580, 342, 70, color: hex(0xFFFFFF, .6), radius: 24, border: Colors.white),
      fxImg('$a/icon_lock.svg', 39, 606, 18, 18),
      fxText('Ne fermez pas la page. Aucun montant n’est débité tant que vous n’avez pas validé.', 70, 596, 11,
          const Color(0xFF5B5963), w: 270, lh: 16),
      fxBox(24, 680, 342, 52, color: ink, radius: 26, shadow: [fxShadow(0, 8, 18, const Color(0x38403366))]),
      fxText('Vérifier le statut', 0, 698, 13, Colors.white, weight: 600, w: 390, align: TextAlign.center),
      fxBox(24, 744, 342, 48, color: hex(0xFFFFFF, .75), radius: 24, border: Colors.white),
      fxText('Changer de moyen de paiement', 0, 760, 13, ink, weight: 600, w: 390, align: TextAlign.center),
      fxTap(24, 680, 342, 52, () => fxOpen(context, '259')),
      fxTap(24, 744, 342, 48, () => fxOpen(context, '258')),
      // Icône horloge chrome (104×104 à 143,178)
      Positioned(
        left: 143,
        top: 178,
        width: 104,
        height: 104,
        child: DecoratedBox(
          decoration: const BoxDecoration(boxShadow: [
            BoxShadow(offset: Offset(0, 8), blurRadius: 12, color: Color(0x4D262640)),
          ]),
          child: Stack(children: [
            Positioned(left: 104 * .0208, top: 104 * .0208, width: 99.667, height: 99.667, child: Image.asset('$a/clock1.png', fit: BoxFit.fill)),
            Positioned(left: 104 * .4375, top: 104 * .1875, width: 30.335, height: 47.668, child: Image.asset('$a/clock2.png', fit: BoxFit.fill)),
          ]),
        ),
      ),
    ]);
  }
}
