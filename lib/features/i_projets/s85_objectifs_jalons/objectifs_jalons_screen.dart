import '../i_widgets.dart';

/// 85 · Objectifs et jalons de la campagne.
class ObjectifsJalonsScreen extends ConsumerWidget {
  const ObjectifsJalonsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionIDataProvider);
    return AppScaffold(
      showNav: false,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      header: const CHeader('Objectifs et jalons'),
      children: [
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              GGauge(percent: d.collected * 100 ~/ d.goal),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Objectif : ${fcfa(d.goal)}', style: AppText.h3.copyWith(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('${fcfa(d.collected)} collectés', style: AppText.small),
                  ],
                ),
              ),
            ],
          ),
        ),
        const GSectionTitle('Jalons financiers'),
        IMilestones(d.fundingMilestones),
        gap8,
        KeyValueCard(
          title: 'Utilisation des fonds',
          rowGap: 14,
          rows: [for (final f in d.fundsUse) KV(f.$1, '${f.$2} %')],
        ),
      ],
    );
  }
}

