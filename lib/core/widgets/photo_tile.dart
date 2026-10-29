import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';

/// Carte-photo : l'image seule, arrondie. Le texte se place toujours DESSOUS,
/// sur le fond (règle du design system : aucun texte posé dans la photo).
class PhotoTile extends StatelessWidget {
  const PhotoTile({
    super.key,
    this.image,
    this.aspectRatio = 1,
    this.radius = AppSizes.radiusCard,
    this.favorite,
    this.onFavorite,
    this.onTap,
    this.semanticLabel,
    this.placeholderIcon = 'assets/icons/image.svg',
  });

  final String? image;
  final double aspectRatio;
  final double radius;
  final bool? favorite;
  final VoidCallback? onFavorite;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final String placeholderIcon;

  @override
  Widget build(BuildContext context) {
    // Une photo touchable doit être annoncée par les lecteurs d'écran.
    final label = semanticLabel ?? (onTap != null ? 'Ouvrir la photo' : null);
    final picture = image == null
        ? Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE9E2F6), Color(0xFFF6E3D2)],
              ),
            ),
            alignment: Alignment.center,
            child: AppIcon(placeholderIcon, size: 32, color: AppColors.textSecondary),
          )
        : Image.asset(
            image!,
            fit: BoxFit.cover,
            semanticLabel: label,
            errorBuilder: (_, _, _) => Container(color: AppColors.field),
          );
    return Semantics(
      image: true,
      button: onTap != null,
      container: onTap != null,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                picture,
                if (favorite != null)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: RoundIconButton(
                      icon: 'assets/icons/heart.svg',
                      label: favorite! ? 'Retirer des favoris' : 'Ajouter aux favoris',
                      size: 36,
                      bordered: false,
                      foreground: favorite! ? AppColors.error : AppColors.ink,
                      onTap: onFavorite,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Carte produit : photo puis titre, prix, vendeur sous la photo.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.title,
    required this.price,
    required this.subtitle,
    this.image,
    this.onTap,
    this.favorite = false,
    this.onFavorite,
  });

  final String title;
  final String price;
  final String subtitle;
  final String? image;
  final VoidCallback? onTap;
  final bool favorite;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: '$title, $price',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PhotoTile(
              image: image,
              aspectRatio: 177 / 163,
              favorite: favorite,
              onFavorite: onFavorite,
              semanticLabel: title,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(price, style: AppText.label.copyWith(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppText.small, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
