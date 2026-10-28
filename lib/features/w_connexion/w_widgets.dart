import '../q_parametres/q_widgets.dart';

export '../../data/demo/section_w_demo.dart';
export '../q_parametres/q_widgets.dart';

/// Carte d'information translucide : pictogramme dans un carré blanc, texte court (182–185).
class WInfoCard extends StatelessWidget {
  const WInfoCard({super.key, required this.icon, required this.text});

  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .55), borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: AppIcon(icon, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppText.small.copyWith(fontSize: 12))),
        ],
      ),
    );
  }
}

/// Carte « squelette » affichée pendant le chargement (182).
class WSkeletonCard extends StatelessWidget {
  const WSkeletonCard({super.key});

  static const _shade = Color(0xFFEDEEF2);

  Widget _bar(double w, double h, Color c) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(h)),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: _shade, borderRadius: BorderRadius.circular(12)),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_bar(170, 10, _shade), const SizedBox(height: 10), _bar(108, 8, const Color(0xFFF3F3F6))],
          ),
        ],
      ),
    );
  }
}

/// Ligne de liste : élément de tête facultatif, titre, sous-titre, élément à droite (183, 185).
class WRow extends StatelessWidget {
  const WRow({super.key, required this.title, required this.subtitle, this.leading, this.trailing, this.onTap});

  final String title;
  final String subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: '$title, $subtitle',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppText.bodyStrong.copyWith(fontSize: 14.5)),
                      const SizedBox(height: 3),
                      Text(subtitle, style: AppText.small.copyWith(fontSize: 12)),
                    ],
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// Réglage à interrupteur dont le titre tient sur une ligne (tronqué comme dans la maquette 184).
class WToggleRow extends StatelessWidget {
  const WToggleRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong),
                Text(subtitle, style: AppText.small),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Toggle(value: value, onChanged: onChanged, label: title),
        ],
      ),
    );
  }
}
