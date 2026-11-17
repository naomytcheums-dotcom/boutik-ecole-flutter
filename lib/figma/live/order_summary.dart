import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/demo/section_a_demo.dart' show CartLine;
import '../../data/repositories/repositories.dart' show cartProvider;
import '../gen.dart';
import '../nav.dart';
import 'auth.dart' show gSelfInstitution, kSalesTermsVersion, requireLogin;
import 'backend.dart';
import 'store.dart';

/// Récapitulatif de commande (écrans 42 et 43) : une seule source de vérité, celle du panier, du mode de livraison
/// et du moyen de paiement choisis. Remplace les montants et lignes figés de la maquette (D-011).

/// Image d'une ligne : celle du produit quand c'est un fichier de l'application, sinon l'image de repli (produit inconnu du catalogue).
String lineImage(CartLine l, String fallback) => l.image.startsWith('assets/') ? l.image : fallback;

/// Libellé des frais : « Gratuit » quand le mode de livraison n'en comporte pas (même formulation que le panier 06).
String feeLabel(int fee) => fee == 0 ? 'Gratuit' : fcfa(fee);

/// Mode de livraison retenu (07) : intitulé et précision.
({String title, String detail}) deliveryChoice(bool home) =>
    home ? (title: 'Livraison à domicile', detail: 'À l’adresse du carnet') : (title: 'Retrait sur campus', detail: gSelfInstitution.trim().isEmpty ? 'Sur votre campus' : gSelfInstitution.trim());

/// Moyen de paiement retenu (08).
String payMethodLabel(int method) => method == 0 ? 'Orange Money' : (method == 2 ? 'Paiement à la livraison' : 'Mobile Money');

/// Référence à indiquer au paiement : celle de la commande à payer ; tant qu'aucune commande n'est à payer, aucune référence n'est inventée.
String orderReferenceLabel(List<Order> orders) {
  final o = payableOrder(orders);
  return o == null ? 'Attribuée à la validation' : o.id.replaceFirst('#', '');
}

/// Montant à payer : celui de la commande impayée la plus récente, sinon le total du panier courant.
int amountToPay(List<Order> orders, Totals totals) => payableOrder(orders)?.total ?? totals.total;

/// Numéro marchand du paiement manuel, défini par l'administrateur (fonction payment_instructions) ; null tant qu'il n'est pas communiqué.
final paymentInstructionsProvider = FutureProvider.autoDispose<({String? number, String? operator})>((ref) async {
  if (!Backend.ready) return (number: null, operator: null);
  final r = await Backend.rpc('payment_instructions', const {});
  final d = r.data;
  if (r.error != null || d is! Map) return (number: null, operator: null);
  String? s(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
  return (number: s(d['merchant_number']), operator: s(d['operator']));
}, retry: (_, _) => null);

/// Case « J'accepte les conditions de vente » du récapitulatif (42) : cochée par le client, jamais par défaut.
class _OrderTerms extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool v) => state = v;
}

final orderTermsProvider = NotifierProvider<_OrderTerms, bool>(_OrderTerms.new);

/// Case à cocher des conditions de vente.
class OrderTermsCheck extends ConsumerWidget {
  const OrderTermsCheck({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(orderTermsProvider);
    return Semantics(
      checked: on,
      label: 'J’accepte les conditions de vente et la politique de retour',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => ref.read(orderTermsProvider.notifier).set(!on),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(color: on ? const Color(0xFF111015) : Colors.white, border: on ? null : Border.all(color: const Color(0xFFB8B3C4), width: 1.5), borderRadius: BorderRadius.circular(6)),
              child: on ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: gText('J’accepte les conditions de vente et la politique de retour.', 12.5, const Color(0xFF4A4854), lh: 18, wrap: true, maxLines: 2)),
          ]),
        ),
      ),
    );
  }
}

/// « Confirmer la commande » (42) : exige la case des conditions, enregistre l'acceptation sur le compte connecté, puis ouvre le paiement (08).
Future<void> confirmOrderSummary(WidgetRef ref, BuildContext context) async {
  if (!ref.read(orderTermsProvider)) {
    gToast(context, 'Cochez l’acceptation des conditions de vente pour continuer.');
    return;
  }
  if (Backend.ready && GAnim.enabled) {
    if (!await requireLogin(context, ref, 'confirmer votre commande') || !context.mounted) return;
    final err = await Backend.acceptTerms(kSalesTermsVersion);
    if (err != null) {
      if (context.mounted) gToast(context, err);
      return;
    }
  }
  if (context.mounted) gOpen(context, '08');
}

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
      SizedBox(width: 96, child: gText(fcfa(line.price * line.qty), 13, const Color(0xFF111015), weight: 700, wrap: true, align: TextAlign.right)),
    ]);
  }
}

/// Mode de livraison et adresse réels de la commande : l'adresse figée à la commande (livraison à domicile), sinon le point de retrait.
String orderDeliveryText(Order o) {
  if (o.home) return 'Livraison à domicile\n${o.address.isEmpty ? 'Adresse non disponible' : o.address}';
  return 'Retrait sur campus\n${gSelfInstitution.trim().isEmpty ? 'Votre campus' : gSelfInstitution.trim()}';
}

/// « Total 25 000 FCFA · remise −2 000 FCFA (code) · livraison 3 000 FCFA » : montants de la commande.
String orderAmountLine(Order o) {
  final parts = [
    'Total ${fcfa(o.total)}',
    if (o.discount > 0) 'remise −${fcfa(o.discount)}${o.promoCode.isNotEmpty ? ' (${o.promoCode})' : ''}',
    if (o.fee > 0) 'livraison ${fcfa(o.fee)}',
  ];
  return parts.join(' · ');
}

/// Pastille d'état de la commande affichée (En attente de paiement, En cours, Livrée, Annulée), à largeur du texte, alignée à droite.
class OrderBadge extends ConsumerWidget {
  const OrderBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = ref.watch(viewedOrderProvider).badge;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(color: badgeFill(b), borderRadius: BorderRadius.circular(14)),
        child: gText(b, 11.924, badgeInk(b), weight: 600),
      ),
    );
  }
}

/// Étapes de suivi d'une commande, dans l'ordre de `statusLabel` (store.dart) : un seul statut, lu sur la commande affichée.
final orderSteps = [for (var i = 0; i < 4; i++) statusLabel(i)];

/// Libellé de l'étape i de la commande : connecté, la troisième étape est celle déclarée « prête » par le vendeur (jamais « expédiée » pour un retrait sur campus).
String orderStepLabel(Order o, int i) => i == 2 && Backend.ready ? (o.home ? 'Prête à livrer' : 'Prête à retirer') : statusLabel(i);

/// Libellé court du statut d'une commande, identique sur 09, 29, 46 et 47.
String orderStatusLabel(Order o) => o.cancelled ? 'Annulée' : (o.awaitingPayment ? 'En attente de paiement' : orderStepLabel(o, o.status.clamp(0, 3)));

/// Chronologie de la commande affichée : étapes terminées, étape en cours, étapes à venir (D-083).
class OrderTimeline extends ConsumerWidget {
  const OrderTimeline({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = ref.watch(viewedOrderProvider);
    final current = o.step;
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
          Positioned(left: 32, top: 62.0 * i - 1, width: 305, child: gText((i == 0 && current < 0) ? (o.cancelled ? 'Commande annulée' : 'En attente de paiement') : orderStepLabel(o, i), 13.5, const Color(0xFF111015), weight: 600, wrap: true)),
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
