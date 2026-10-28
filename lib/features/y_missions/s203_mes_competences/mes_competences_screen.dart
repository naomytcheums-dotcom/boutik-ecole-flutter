import '../y_widgets.dart';

/// 203 · Mes compétences : score de l'étudiant, domaines maîtrisés et explication du score.
class MesCompetencesScreen extends ConsumerWidget {
  const MesCompetencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionYDataProvider);
    return YRootPage(
      title: 'Mes compétences',
      showBack: true,
      children: [
        YStatsCard(d.skillStats),
        const YTitle('Domaines maîtrisés', top: 13, bottom: 14),
        AppCard(
          radius: 26,
          borderColor: null,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            children: [
              for (final (i, (label, value, color)) in d.skills.indexed) ...[
                if (i > 0) const SizedBox(height: 14),
                Semantics(
                  label: '$label : $value sur 100',
                  excludeSemantics: true,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(label, style: AppText.body.copyWith(fontSize: 13.5, color: AppColors.ink)),
                          ),
                          Text('$value', style: AppText.small.copyWith(fontSize: 12.5, color: const Color(0xFF4A4752))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _Bar(value / 100, Color(color)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const YTitle('Pourquoi ce score ?', top: 17, bottom: 17),
        YCard(
          children: [
            for (final (icon, title, detail, points) in d.scoreReasons)
              YIconRow(
                leading: YIconTile(
                  icon,
                  iconColor: icon == AppIcons.starFilled ? const Color(0xFF2F5B8F) : AppColors.ink,
                ),
                title: title,
                subtitle: detail,
                trailing: YBadge(points, Tone.success),
              ),
          ],
        ),
        const SizedBox(height: 14),
        const YNote(
          'Ce score aide l’administrateur à attribuer les besoins aux étudiants les plus qualifiés.',
          icon: AppIcons.sparkle,
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar(this.value, this.color);

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(3),
    child: SizedBox(
      height: 6,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFFEFEDF3)),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value,
            child: ColoredBox(color: color),
          ),
        ],
      ),
    ),
  );
}
