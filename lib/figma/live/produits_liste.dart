import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../nav.dart';
import 'product_card.dart';
import 'seller.dart' show allProductsProvider;
import 'store.dart';

/// Cartes de produits réels (écrans 102 Vitrine, 106 Économie circulaire…) : les produits publiés sur le serveur, deux par ligne,
/// avec chargement, état vide et ouverture de la fiche. Aucun produit de maquette n'est affiché hors démonstration.

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

/// Produits dont le titre ou la description évoque la récupération ou le recyclage (aucun indicateur dédié n'existe sur le serveur).
bool isRecycled(LiveProduct p) => RegExp(r'recycl|récup|recup|upcycl|seconde vie|réemploi|reemploi', caseSensitive: false).hasMatch('${p.title} ${p.description}');

class ProductCards extends ConsumerWidget {
  const ProductCards({super.key, this.width = 342, this.rows = 2, this.filter, this.height, this.emptyText = 'Aucun produit publié pour le moment.'});
  final double width;

  /// Hauteur du cadre défilant (défaut : 390, ou 590 pour 3 rangées). Les cartes sont plus grandes : le cadre défile au besoin.
  final double? height;
  final int rows;
  final bool Function(LiveProduct)? filter;
  final String emptyText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(allProductsProvider);
    final list = [for (final p in all) if (filter == null || filter!(p)) p].take(rows * 2).toList();
    if (list.isEmpty) {
      return Container(
        width: width,
        height: 200,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(emptyText, textAlign: TextAlign.center, style: _st(13, c: _grey).copyWith(height: 1.5)),
      );
    }
    Widget image(LiveProduct p) {
      Widget neutral() => Image.asset(neutralProductImage, fit: BoxFit.cover);
      if (p.image == 'placeholder' || p.image.isEmpty) return neutral();
      return p.image.startsWith('http') ? Image.network(p.image, fit: BoxFit.cover, errorBuilder: (_, _, _) => neutral()) : Image.asset(p.image, fit: BoxFit.cover);
    }

    // Carte produit unique (photo 4:5, titre, prix, boutique, bouton) : voir product_card.dart.
    Widget card(LiveProduct p) => ProductCardView(
          photo: image(p),
          title: p.title,
          price: fcfa(p.price),
          shop: p.seller,
          extra: p.department.isEmpty ? p.category : p.department,
          onTap: () {
            ref.read(selectedProductProvider.notifier).select(p.title);
            gOpen(context, '05');
          },
        );
    final h = height ?? (rows >= 3 ? 590.0 : 390.0);
    return SizedBox(
      width: width,
      height: h,
      child: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (var r = 0; r < (list.length + 1) ~/ 2; r++) ...[
            if (r > 0) const SizedBox(height: 18),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: card(list[r * 2])),
              const SizedBox(width: 14),
              Expanded(child: r * 2 + 1 < list.length ? card(list[r * 2 + 1]) : const SizedBox.shrink()),
            ]),
          ],
        ]),
      ),
    );
  }
}

/// Compteur de la vitrine : nombre de pièces, de créateurs ou de départements réellement représentés.
class VitrineCount extends ConsumerWidget {
  const VitrineCount({super.key, required this.kind});
  final String kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(allProductsProvider);
    final n = switch (kind) {
      'pieces' => all.length,
      'creators' => {for (final p in all) p.seller}.where((s) => s.isNotEmpty).length,
      _ => {for (final p in all) p.department}.where((s) => s.isNotEmpty).length,
    };
    return Text('$n', textAlign: TextAlign.center, style: _st(20, w: FontWeight.w800));
  }
}

/// Écran dont les indicateurs n'ont pas encore de source de données sur le serveur (impact, parrainage, comparaisons) :
/// hors démonstration, un message honnête remplace les chiffres et listes de la maquette. Aucun chiffre n'est inventé.
class NoSource extends StatelessWidget {
  const NoSource({super.key, required this.what, this.width = 342, this.height = 200});
  final String what;
  final double width, height;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Text('$what\n\nCes indicateurs seront affichés dès que leur source de données sera disponible.', textAlign: TextAlign.center, style: _st(13, c: _grey).copyWith(height: 1.5)),
      );
}
