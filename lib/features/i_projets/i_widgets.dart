import '../../data/demo/section_i_demo.dart';
import '../c_decouverte/c_widgets.dart';

export '../../data/demo/section_i_demo.dart';
export '../c_decouverte/c_widgets.dart';

/// Bannière photo avec titre et sous-titre posés en bas (78, 79, 84b), comme les maquettes.
class IHeroBanner extends StatelessWidget {
  const IHeroBanner({
    super.key,
    required this.image,
    required this.title,
    required this.subtitle,
    this.height = 170,
    this.onTap,
  });

  final String image;
  final String title;
  final String subtitle;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(image, fit: BoxFit.cover),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0xD91A1630)],
                      stops: [.3, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppText.h2.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: AppText.small.copyWith(color: Colors.white)),
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

/// Carte de compteurs séparés par des filets (79, 84b).
class ICounters extends StatelessWidget {
  const ICounters(this.items, {super.key});

  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          for (final (i, c) in items.indexed) ...[
            if (i > 0) Container(width: 1, height: 40, color: AppColors.cardBorder),
            Expanded(
              child: Semantics(
                label: '${c.$2} : ${c.$1}',
                excludeSemantics: true,
                child: Column(
                  children: [
                    Text(c.$1, style: AppText.h2.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(c.$2, style: AppText.small.copyWith(fontSize: 11.5)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Lignes « libellé · valeur » avec barre de progression colorée (79, 81, 84b).
class IProgressCard extends StatelessWidget {
  const IProgressCard(this.rows, {super.key});

  final List<(String, String, double, int)> rows;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        children: [
          for (final (i, r) in rows.indexed) ...[
            if (i > 0) const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: Text(r.$1, style: AppText.body.copyWith(fontSize: 13.5))),
                Text(r.$2, style: AppText.small.copyWith(color: const Color(0xFF4A4752))),
              ],
            ),
            const SizedBox(height: 6),
            ProgressLine(value: r.$3, color: Color(r.$4), height: 6),
          ],
        ],
      ),
    );
  }
}

/// Frise verticale de jalons (82, 85) : pastille verte cochée, disque noir, cercle blanc.
class IMilestones extends StatelessWidget {
  const IMilestones(this.items, {super.key});

  final List<IMilestone> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (i, m) in items.indexed)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 22,
                  child: Column(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: switch (m.state) {
                            0 => AppColors.success,
                            1 => AppColors.ink,
                            _ => Colors.white,
                          },
                        ),
                        alignment: Alignment.center,
                        child: m.state == 0 ? const AppIcon(AppIcons.check, size: 12, color: Colors.white) : null,
                      ),
                      if (i < items.length - 1) Expanded(child: Container(width: 1.5, color: const Color(0xFFB9E2CF))),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 22),
                    child: Semantics(
                      label: '${m.title}, ${m.detail.isEmpty ? (m.state == 2 ? 'à venir' : '') : m.detail}',
                      excludeSemantics: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.title, style: AppText.body.copyWith(fontSize: 14.5, fontWeight: FontWeight.w500)),
                          if (m.detail.isNotEmpty) Text(m.detail, style: AppText.small.copyWith(fontSize: 11.5)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Ligne avec pictogramme carré gris (83, 87).
class IIconRow extends StatelessWidget {
  const IIconRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final String icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: const Color(0xFFF2F0F5), borderRadius: BorderRadius.circular(10)),
              alignment: Alignment.center,
              child: AppIcon(icon, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.body.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600)),
                  Text(subtitle, style: AppText.small.copyWith(fontSize: 11.5)),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
