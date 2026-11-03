import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/demo/section_a_demo.dart' show CartLine;
import '../../data/repositories/repositories.dart' show cartProvider;
import '../gen.dart';
import 'store.dart';

/// Récapitulatif de commande (écrans 42 et 43) : une seule source de vérité, celle du panier, du mode de livraison
/// et du moyen de paiement choisis. Remplace les montants et lignes figés de la maquette (D-011).

/// Image d'une ligne : celle du produit quand c'est un fichier de l'application, sinon l'image de repli (produit inconnu du catalogue).
String lineImage(CartLine l, String fallback) => l.image.startsWith('assets/') ? l.image : fallback;

/// Libellé des frais : « Gratuit » quand le mode de livraison n'en comporte pas (même formulation que le panier 06).
String feeLabel(int fee) => fee == 0 ? 'Gratuit' : fcfa(fee);

/// Mode de livraison retenu (07) : intitulé et précision.
({String title, String detail}) deliveryChoice(bool home) =>
    home ? (title: 'Livraison à domicile', detail: 'À l’adresse du carnet') : (title: 'Retrait sur campus', detail: 'IUT de Douala – Bâtiment principal');

/// Moyen de paiement retenu (08).
String payMethodLabel(int method) => method == 0 ? 'Orange Money' : 'Mobile Money';

/// Référence à indiquer au paiement : celle de la commande créée ; tant qu'aucune commande n'existe, aucune référence n'est inventée.
String orderReferenceLabel(List<Order> orders) => orders.isEmpty ? 'Attribuée à la validation' : orders.first.id.replaceFirst('#', '');

/// Montant à payer : celui de la dernière commande créée, sinon le total du panier courant.
int amountToPay(List<Order> orders, Totals totals) => orders.isEmpty ? totals.total : orders.first.total;

/// Lignes du panier dans une zone défilante : toutes les lignes sont affichées, quel que soit leur nombre.
class OrderLinesList extends ConsumerWidget {
  const OrderLinesList({super.key, this.width = 322, this.height = 200, this.viewedOrder = false});
  final double width, height;

  /// Vrai : les lignes de la commande affichée (09, 29) ; faux : celles du panier courant (42).
  final bool viewedOrder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = viewedOrder ? ref.watch(viewedOrderProvider).lines : ref.watch(cartProvider);
    if (lines.isEmpty) {
      return SizedBox(width: width, height: height, child: gText(viewedOrder ? 'Aucun article.' : 'Votre panier est vide.', 12.5, const Color(0xFF57545F)));
    }
    return SizedBox(
      width: width,
      height: height,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: lines.length,
        separatorBuilder: (_, _) => const Divider(height: 16, thickness: 1, color: Color(0xFFF2EFF6)),
        itemBuilder: (_, i) => _Row(lines[i]),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.line);
  final CartLine line;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: line.image.startsWith('assets/')
            ? Image.asset(line.image, width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (_, _, _) => const _NoImage())
            : const _NoImage(),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          gText(line.title, 13.5, const Color(0xFF111015), weight: 600, wrap: true, maxLines: 1),
          const SizedBox(height: 4),
          gText('Qté : ${line.qty}', 11.5, const Color(0xFF57545F), wrap: true),
        ]),
      ),
      const SizedBox(width: 8),
      SizedBox(width: 70, child: gText(fcfa(line.price * line.qty).replaceAll(' FCFA', ''), 13.5, const Color(0xFF111015), weight: 700, wrap: true, align: TextAlign.right)),
    ]);
  }
}

/// Étapes de suivi d'une commande, dans l'ordre de `statusLabel` (store.dart) : un seul statut, lu sur la commande affichée.
final orderSteps = [for (var i = 0; i < 4; i++) statusLabel(i)];

/// Libellé court du statut d'une commande, identique sur 09, 29, 46 et 47.
String orderStatusLabel(Order o) => o.cancelled ? 'Annulée' : statusLabel(o.status);

/// Chronologie de la commande affichée : étapes terminées, étape en cours, étapes à venir (D-083).
class OrderTimeline extends ConsumerWidget {
  const OrderTimeline({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = ref.watch(viewedOrderProvider);
    final current = o.status.clamp(0, 3);
    return SizedBox(
      width: 340,
      height: 62.0 * orderSteps.length,
      child: Stack(children: [
        for (var i = 0; i < orderSteps.length; i++) ...[
          if (i < orderSteps.length - 1)
            Positioned(left: 9, top: 22 + 62.0 * i, child: Container(width: 2, height: 40, color: i < current ? const Color(0xFFBFE8D6) : const Color(0xFFE4E8EE))),
          Positioned(
            left: 0,
            top: 62.0 * i,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < current ? const Color(0xFF1F9D6B) : (i == current ? const Color(0xFF111015) : Colors.white),
                border: i > current ? Border.all(color: const Color(0xFFE6E1EE), width: 2) : null,
              ),
              child: i < current ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
            ),
          ),
          Positioned(left: 32, top: 62.0 * i - 1, width: 305, child: gText(orderSteps[i], 13.5, const Color(0xFF111015), weight: 600, wrap: true)),
          Positioned(
            left: 32,
            top: 62.0 * i + 19,
            width: 305,
            child: gText(i == 0 ? o.date : (i < current ? 'Terminé' : (i == current ? 'En cours' : 'À venir')), 11.5, const Color(0xFF57545F), wrap: true),
          ),
        ],
      ]),
    );
  }
}

class _NoImage extends StatelessWidget {
  const _NoImage();
  @override
  Widget build(BuildContext context) => Container(width: 50, height: 50, color: const Color(0xFFF1EEFB), child: const Icon(Icons.image_outlined, size: 22, color: Color(0xFF5A3FE0)));
}
