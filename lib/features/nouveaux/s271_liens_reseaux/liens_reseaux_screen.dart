import '../../common/common.dart';

/// 271 · Mes liens et réseaux (icônes affichées sur le profil).
class LiensReseauxScreen extends ConsumerStatefulWidget {
  const LiensReseauxScreen({super.key});

  @override
  ConsumerState<LiensReseauxScreen> createState() => _LiensReseauxScreenState();
}

class _LiensReseauxScreenState extends ConsumerState<LiensReseauxScreen> {
  late final Map<String, bool> _enabled = {
    for (final l in ref.read(nouveauxDataProvider).socialLinks) l.network: l.enabled,
  };

  static const _brand = <String, (Color, Color)>{
    'LinkedIn': (Color(0xFF0A66C2), Colors.white),
    'X': (Color(0xFF111015), Colors.white),
    'Instagram': (Color(0xFFD62976), Colors.white),
    'GitHub': (Color(0xFF24292F), Colors.white),
    'Facebook': (Color(0xFF1877F2), Colors.white),
    'YouTube': (Colors.white, Color(0xFFE62117)),
    'TikTok': (Color(0xFF111015), Colors.white),
    'WhatsApp': (Color(0xFF25D366), Colors.white),
  };

  @override
  Widget build(BuildContext context) {
    final links = ref.watch(nouveauxDataProvider).socialLinks;
    final visible = _enabled.values.where((v) => v).length;
    return DetailScreen(
      title: 'Mes liens et réseaux',
      subtitle: 'Icônes affichées sur votre profil',
      action: 'Enregistrer',
      onAction: () => context.toast('Liens enregistrés.'),
      children: [
        for (final l in links) ...[
          AppCard(
            padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
            radius: 20,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _brand[l.network]!.$1,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  alignment: Alignment.center,
                  child: Text(l.asset, style: AppText.label.copyWith(color: _brand[l.network]!.$2, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.network, style: AppText.bodyStrong),
                      Text(l.handle.isEmpty ? 'Ajouter un lien' : l.handle, style: AppText.small),
                    ],
                  ),
                ),
                Toggle(
                  value: _enabled[l.network]!,
                  label: 'Afficher ${l.network}',
                  onChanged: (v) => setState(() => _enabled[l.network] = v),
                ),
              ],
            ),
          ),
          gap8,
        ],
        Semantics(
          button: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => context.toast('Ajout d’un lien personnalisé.'),
            child: CustomPaint(
              painter: _DashedBorder(),
              child: Container(
                height: 48,
                alignment: Alignment.center,
                child: Text(
                  '+  Ajouter un autre lien (portfolio, site, Drive…)',
                  style: AppText.body.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ),
        gap12,
        Text('Aperçu sur mon profil : $visible icônes visibles + Portfolio', style: AppText.small),
      ],
    );
  }
}

class _DashedBorder extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(24)));
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
