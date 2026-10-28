import '../../common/common.dart';

/// 255 · Suivi de publication (workflow en 10 étapes).
class SuiviPublicationScreen extends ConsumerWidget {
  const SuiviPublicationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(nouveauxDataProvider);
    final p = d.publicationProduct;
    return DetailScreen(
      title: 'Suivi de publication',
      subtitle: p.title,
      action: 'Voir les contrôles automatiques et réglementaires',
      onAction: () => context.openScreen('256'),
      children: [
        AppCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(width: 60, child: PhotoTile(image: p.image, radius: 14, semanticLabel: p.title)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.title, style: AppText.h3),
                    Text(p.detail, style: AppText.small),
                    const SizedBox(height: 6),
                    StatusBadge(p.stepLabel, tone: BadgeTone.warning),
                  ],
                ),
              ),
            ],
          ),
        ),
        gap16,
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 4),
          child: StepTimeline(
            steps: [
              for (final s in d.publicationSteps)
                TimelineStep(s.title, s.detail, switch (s.progress) {
                  Progress.done => StepStatus.done,
                  Progress.current => StepStatus.current,
                  Progress.upcoming => StepStatus.upcoming,
                }),
            ],
          ),
        ),
      ],
    );
  }
}
