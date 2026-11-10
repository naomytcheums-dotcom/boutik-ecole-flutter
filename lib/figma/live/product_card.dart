import 'package:flutter/material.dart';

/// Carte produit unique de l'application (format de la première maquette) : grande photo 4:5 aux coins arrondis, titre, prix,
/// nom de la boutique et bouton d'action. Utilisée partout où un produit est listé (marketplace, vitrine, catalogues) :
/// deux colonnes sur téléphone. Aucun contenu inventé : un champ vide n'est pas affiché.

const kCardInk = Color(0xFF111015);
const kCardGrey = Color(0xFF57545F);
const kCardViolet = Color(0xFF5A3FE0);

TextStyle _cs(double size, {FontWeight w = FontWeight.w500, Color c = kCardInk}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

/// Hauteur du corps de la carte sous la photo (titre 2 lignes, prix, boutique, bouton) : sert à calculer le rapport de la grille.
const double kProductCardBodyHeight = 150;

/// Rapport largeur / hauteur d'une carte de largeur [w] pour une grille.
double productCardAspect(double w) => w / (w * 5 / 4 + kProductCardBodyHeight);

class ProductCardView extends StatelessWidget {
  const ProductCardView({
    super.key,
    required this.photo,
    required this.title,
    required this.price,
    required this.onTap,
    this.oldPrice,
    this.shop = '',
    this.extra = '',
    this.buttonLabel = 'Voir le produit',
    this.priceColor = kCardInk,
    this.overlays = const [],
    this.semanticLabel,
  });

  final Widget photo;
  final String title, price, shop, extra, buttonLabel;
  final String? oldPrice;
  final Color priceColor;
  final VoidCallback onTap;

  /// Pastilles posées sur la photo (remise, épuisé, comparer), déjà positionnées avec [Positioned].
  final List<Widget> overlays;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel ?? '$title, $price',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFECE8F2)), boxShadow: const [BoxShadow(color: Color(0x14403366), blurRadius: 10, offset: Offset(0, 3))]),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AspectRatio(aspectRatio: 4 / 5, child: Stack(fit: StackFit.expand, children: [photo, ...overlays])),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: _cs(12.5, w: FontWeight.w700)),
                const SizedBox(height: 3),
                Row(children: [
                  Flexible(child: Text(price, maxLines: 1, overflow: TextOverflow.ellipsis, style: _cs(13, w: FontWeight.w800, c: priceColor))),
                  if (oldPrice != null && oldPrice!.isNotEmpty) ...[const SizedBox(width: 6), Flexible(child: Text(oldPrice!, maxLines: 1, overflow: TextOverflow.ellipsis, style: _cs(10.5, c: kCardGrey).copyWith(decoration: TextDecoration.lineThrough)))],
                ]),
                if (shop.isNotEmpty) ...[const SizedBox(height: 2), Text(shop, maxLines: 1, overflow: TextOverflow.ellipsis, style: _cs(10.5, w: FontWeight.w600, c: kCardViolet))],
                if (extra.isNotEmpty) Text(extra, maxLines: 1, overflow: TextOverflow.ellipsis, style: _cs(10.5, c: kCardGrey)),
                const SizedBox(height: 8),
                Container(
                  height: 32,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: kCardInk, borderRadius: BorderRadius.circular(16)),
                  child: Text(buttonLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: _cs(11.5, w: FontWeight.w700, c: Colors.white)),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
