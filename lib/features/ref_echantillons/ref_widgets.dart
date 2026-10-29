import '../common/common.dart';

/// Composants partagés des échantillons de référence (Kéla, profils, vitrine).

const refStar = Color(0xFFF5A524);
const refLive = Color(0xFFF0335A);
const refVerified = Color(0xFF3B82F6);
const refChip = Color(0xFFF1EFEC);

/// Bouton rond « verre nacré » (liseré irisé) des en-têtes Kéla.
class RefGlassButton extends StatelessWidget {
  const RefGlassButton({super.key, this.icon, this.text, required this.label, this.onTap, this.size = 44});

  final String? icon;
  final String? text;
  final String label;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(1.4),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Color(0xFFF7E3D6), Color(0xFFBFD0F5)],
            ),
            boxShadow: [BoxShadow(color: Color(0x143A2A50), blurRadius: 12, offset: Offset(0, 3))],
          ),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFBFAF9), Color(0xFFF1EDEE)],
              ),
            ),
            alignment: Alignment.center,
            child: text != null
                ? Text(text!, style: AppText.label.copyWith(fontSize: 12, fontWeight: FontWeight.w700))
                : AppIcon(icon!, size: 20),
          ),
        ),
      ),
    );
  }
}

/// Interrupteur noir (activé) / gris (désactivé).
class RefSwitch extends StatelessWidget {
  const RefSwitch({super.key, required this.value, required this.onChanged, required this.label});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: SizedBox(
          width: 48,
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 44,
              height: 26,
              padding: const EdgeInsets.all(3),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(
                color: value ? AppColors.ink : const Color(0xFFE4E1E8),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cadre en pointillés violets (« Connecter un autre outil », « Ajouter un autre lien »).
class RefDashedAddCard extends StatelessWidget {
  const RefDashedAddCard({super.key, required this.title, required this.subtitle, this.onTap});

  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: CustomPaint(
          painter: const _DashedRRectPainter(color: Color(0xFF8B74F0), radius: 24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: const AppIcon(AppIcons.plus, size: 16, color: AppColors.accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppText.body.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppText.small.copyWith(fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
        d += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) => old.color != color || old.radius != radius;
}

/// Ligne d'outil connecté : logo, nom, détail et action à droite.
class RefToolRow extends StatelessWidget {
  const RefToolRow({
    super.key,
    required this.name,
    required this.detail,
    required this.trailing,
    this.logo,
    this.initials,
    this.tint,
    this.detailColor,
    this.logoSize = 40,
  });

  final double logoSize;
  final String name;
  final String detail;
  final Widget trailing;
  final String? logo;
  final String? initials;
  final Color? tint;
  final Color? detailColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        RefToolLogo(image: logo, initials: initials, tint: tint, size: logoSize, radius: logoSize / 4),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: AppText.body.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 1),
              Text(
                detail,
                style: AppText.small.copyWith(fontSize: 11.5, color: detailColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        trailing,
      ],
    );
  }
}

/// Avatar cerclé de noir avec l'étiquette « EN DIRECT » (profils P1, P2).
class RefLiveAvatar extends StatelessWidget {
  const RefLiveAvatar({super.key, this.photo, this.size = 112, this.live = true});

  final String? photo;
  final double size;
  final bool live;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size + 8,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Container(
            width: size,
            height: size,
            padding: const EdgeInsets.all(5),
            decoration: const BoxDecoration(color: AppColors.ink, shape: BoxShape.circle),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: ClipOval(
                child: photo == null
                    ? const ColoredBox(color: Colors.white)
                    : Image.asset(photo!, fit: BoxFit.cover, semanticLabel: 'Photo de profil'),
              ),
            ),
          ),
          if (live) const Positioned(bottom: 10, child: RefLiveTag('EN DIRECT', fontSize: 10)),
        ],
      ),
    );
  }
}

/// Pastilles grises de statistiques (« 2 695 Abonnés »…).
class RefStatPills extends StatelessWidget {
  const RefStatPills(this.labels, {super.key});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final l in labels)
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: const Color(0xFFF2F1EF), borderRadius: BorderRadius.circular(16)),
            child: Center(
              widthFactor: 1,
              child: Text(l, style: AppText.body.copyWith(fontSize: 13, fontWeight: FontWeight.w500)),
            ),
          ),
      ],
    );
  }
}

/// Nom + pastille vérifiée, hashtags (profils P1, P2).
class RefProfileIdentity extends StatelessWidget {
  const RefProfileIdentity({super.key, required this.name, required this.tags, this.nameSize = 24});

  final String name;
  final List<String> tags;
  final double nameSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Semantics(
              header: true,
              child: Text(
                name,
                style: AppText.h1.copyWith(fontSize: nameSize, fontWeight: FontWeight.w500, letterSpacing: -0.3),
              ),
            ),
            const SizedBox(width: 8),
            const RefVerifiedDot(size: 18),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          tags.join('  '),
          style: AppText.body.copyWith(fontSize: nameSize * 0.56, color: const Color(0xFF6B6870)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// En-tête des échantillons : logo, bouton « verre » à gauche, titre centré, action à droite.
class RefHeader extends StatelessWidget {
  const RefHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon = AppIcons.arrowLeft,
    this.leadingLabel = 'Retour',
    this.onLeading,
    this.trailing,
    this.titleTrailing,
    this.brand = true,
    this.titleSize = 18,
  });

  final String title;
  final String? subtitle;
  final String leadingIcon;
  final String leadingLabel;
  final VoidCallback? onLeading;
  final Widget? trailing;
  final Widget? titleTrailing;
  final bool brand;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (brand) const BrandMark(size: 26) else const SizedBox(height: 26),
          const SizedBox(height: 4),
          Row(
            children: [
              const SizedBox(width: 8),
              RefGlassButton(
                icon: leadingIcon,
                label: leadingLabel,
                onTap: onLeading ?? () => ScreenHeader.back(context),
              ),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: AppText.h3.copyWith(fontSize: titleSize, fontWeight: FontWeight.w500),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (titleTrailing != null) ...[const SizedBox(width: 10), titleTrailing!],
                        ],
                      ),
                      if (subtitle != null) Text(subtitle!, style: AppText.secondary.copyWith(fontSize: 12.5)),
                    ],
                  ),
                ),
              ),
              trailing ?? const SizedBox(width: 44),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
    );
  }
}

/// Note en étoiles (pleines jusqu'à [value]).
class RefStars extends StatelessWidget {
  const RefStars({super.key, this.value = 5, this.size = 14, this.spacing = 2});

  final int value;
  final double size;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$value étoiles sur 5',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 5; i++)
            Padding(
              padding: EdgeInsets.only(right: i < 4 ? spacing : 0),
              child: AppIcon(
                i < value ? AppIcons.starFilled : AppIcons.star,
                size: size,
                color: i < value ? refStar : AppColors.cardBorder,
              ),
            ),
        ],
      ),
    );
  }
}

/// Pastille bleue « compte vérifié ».
class RefVerifiedDot extends StatelessWidget {
  const RefVerifiedDot({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Compte vérifié',
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(color: refVerified, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: AppIcon(AppIcons.check, size: size * 0.62, color: Colors.white),
      ),
    );
  }
}

/// Étiquette rose « EN DIRECT » / « LIVE ».
class RefLiveTag extends StatelessWidget {
  const RefLiveTag(this.label, {super.key, this.color = refLive, this.fontSize = 9});

  final String label;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: AppText.small.copyWith(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
      ),
    );
  }
}

/// Logo d'un réseau ou outil : image (asset) ou initiales sur fond teinté.
class RefToolLogo extends StatelessWidget {
  const RefToolLogo({super.key, this.image, this.initials, this.tint, this.size = 36, this.radius = 9});

  final String? image;
  final String? initials;
  final Color? tint;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final color = tint ?? AppColors.accent;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: image != null
            ? Image.asset(image!, fit: BoxFit.cover)
            : ColoredBox(
                color: Color.alphaBlend(color.withValues(alpha: 0.12), Colors.white),
                child: Center(
                  child: Text(
                    initials ?? '',
                    style: AppText.label.copyWith(color: color, fontSize: size * 0.36, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
      ),
    );
  }
}

/// Barres d'onde vocale.
class RefWaveform extends StatelessWidget {
  const RefWaveform({super.key, required this.heights, this.color, this.gradient, this.barWidth = 4, this.gap = 6});

  final List<double> heights;
  final Color? color;
  final Gradient? gradient;
  final double barWidth;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < heights.length; i++)
            Container(
              width: barWidth,
              height: heights[i],
              margin: EdgeInsets.only(right: i < heights.length - 1 ? gap : 0),
              decoration: BoxDecoration(
                color: gradient == null ? color : null,
                gradient: gradient,
                borderRadius: BorderRadius.circular(barWidth),
              ),
            ),
        ],
      ),
    );
  }
}

/// Puce grise arrondie (« Découvrir → », « Visiter »…).
class RefChipButton extends StatelessWidget {
  const RefChipButton(
    this.label, {
    super.key,
    this.trailing,
    this.leading,
    this.onTap,
    this.height = 32,
    this.color = refChip,
    this.foreground = AppColors.ink,
    this.fontSize = 13,
    this.padding = 16,
    this.leadingColor,
  });

  final Color? leadingColor;
  final String label;
  final String? trailing;
  final String? leading;
  final VoidCallback? onTap;
  final double height;
  final Color color;
  final Color foreground;
  final double fontSize;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        color: color,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap ?? () {},
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: height),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: padding),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null) ...[
                    AppIcon(leading!, size: 16, color: leadingColor ?? foreground),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: AppText.body.copyWith(fontSize: fontSize, fontWeight: FontWeight.w600, color: foreground),
                  ),
                  if (trailing != null) ...[const SizedBox(width: 10), AppIcon(trailing!, size: 16, color: foreground)],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Grand bouton pilule (noir ou blanc) des barres d'action basses.
class RefPillButton extends StatelessWidget {
  const RefPillButton({
    super.key,
    required this.label,
    this.icon,
    this.dark = true,
    this.onTap,
    this.height = 44,
    this.fontSize = 14,
  });

  final String label;
  final String? icon;
  final bool dark;
  final VoidCallback? onTap;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : AppColors.ink;
    return Semantics(
      button: true,
      child: Material(
        color: dark ? AppColors.ink : Colors.white,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: SizedBox(
            height: height,
            child: Row(
              mainAxisAlignment: icon == null ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  const SizedBox(width: 16),
                  AppIcon(icon!, size: 18, color: fg),
                  const SizedBox(width: 12),
                ],
                Text(
                  label,
                  style: AppText.body.copyWith(fontSize: fontSize, fontWeight: FontWeight.w600, color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Carte blanche arrondie à ombre douce des échantillons.
class RefCard extends StatelessWidget {
  const RefCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.color = Colors.white,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [BoxShadow(color: Color(0x0A2A1F3D), blurRadius: 16, offset: Offset(0, 3))],
      ),
      child: Material(
        color: color,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Sélecteur horizontal de puces (« Tout », « Vidéos »…), la puce active est noire.
class RefPillRow extends StatelessWidget {
  const RefPillRow({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.height = 36,
    this.padding = 22,
    this.fontSize = 14,
    this.gap = 8,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  final double height;
  final double padding;
  final double fontSize;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: EdgeInsets.only(right: gap),
              child: Semantics(
                button: true,
                selected: i == selected,
                child: GestureDetector(
                  onTap: () => onSelected(i),
                  child: Container(
                    height: height,
                    padding: EdgeInsets.symmetric(horizontal: padding),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == selected ? AppColors.ink : Colors.white,
                      borderRadius: BorderRadius.circular(height / 2),
                    ),
                    child: Text(
                      labels[i],
                      style: AppText.body.copyWith(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w500,
                        color: i == selected ? Colors.white : AppColors.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Image d'asset arrondie (photos des maquettes).
class RefPhoto extends StatelessWidget {
  const RefPhoto(
    this.image, {
    super.key,
    this.width,
    this.height,
    this.radius = 20,
    this.alignment = Alignment.center,
    this.semanticLabel,
  });

  final String image;
  final double? width;
  final double? height;
  final double radius;
  final Alignment alignment;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        image,
        width: width,
        height: height,
        fit: BoxFit.cover,
        alignment: alignment,
        semanticLabel: semanticLabel,
        excludeFromSemantics: semanticLabel == null,
      ),
    );
  }
}
