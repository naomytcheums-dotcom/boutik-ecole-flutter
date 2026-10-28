import '../y_widgets.dart';

/// 204 · Coup de pouce startup : accompagnement des projets étudiants par l'IUT.
class CoupDePouceScreen extends ConsumerWidget {
  const CoupDePouceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionYDataProvider);
    final (title, subtitle, image) = d.startupHero;
    return YRootPage(
      title: 'Coup de pouce startup',
      children: [
        Semantics(
          button: true,
          child: GestureDetector(
            onTap: () => context.openScreen('205'),
            child: YHero(image: image, title: title, subtitle: subtitle, height: 190, topAspect: 684 / 248),
          ),
        ),
        const SizedBox(height: 14),
        YStatsCard(d.startupStats),
        const YTitle('Le parcours', top: 16, bottom: 18),
        YStepper(labels: d.startupSteps, current: 1),
        YTitle(
          'Projets accompagnés',
          top: 0,
          bottom: 6,
          trailing: Semantics(
            button: true,
            child: InkWell(
              onTap: () => context.toast('Tous les projets accompagnés'),
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    Text('Voir tout', style: AppText.label.copyWith(color: AppColors.accent, fontSize: 13)),
                    const SizedBox(width: 6),
                    const AppIcon(AppIcons.arrowRight, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
        YCard(
          children: [
            for (final (photo, name, detail, badge) in d.startupProjects)
              YIconRow(
                leading: YThumb(photo),
                title: name,
                subtitle: detail,
                trailing: YBadge(badge, badge == 'Prototype' ? Tone.warning : Tone.accent),
              ),
          ],
        ),
      ],
    );
  }
}
