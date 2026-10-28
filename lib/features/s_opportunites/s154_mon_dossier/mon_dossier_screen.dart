import '../s_widgets.dart';

/// 154 · Mon dossier (complétude et checklist).
class MonDossierScreen extends ConsumerWidget {
  const MonDossierScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionSDataProvider);
    final missing = d.checklist.where((c) => c.tone != Tone.success).length;
    return GPage(
      title: 'Mon dossier',
      actions: [PrimaryButton(label: 'Compléter mon dossier', height: 54, onPressed: () => context.openScreen('18c'))],
      children: [
        AppCard(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              GGauge(percent: d.dossierPercent, size: 92),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dossier complet à ${d.dossierPercent} %', style: AppText.bodyStrong.copyWith(fontSize: 15)),
                    Text(
                      'Encore $missing éléments pour postuler partout.',
                      style: AppText.small.copyWith(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const GSectionTitle('Checklist'),
        SItemList(d.checklist),
        gap12,
        SAiCard(title: 'Conseil de l’IA', text: d.dossierAdvice),
      ],
    );
  }
}
