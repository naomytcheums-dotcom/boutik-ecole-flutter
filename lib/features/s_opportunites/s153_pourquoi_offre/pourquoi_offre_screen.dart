import '../s_widgets.dart';

/// 153 · Pourquoi cette offre ? (explication de la compatibilité).
class PourquoiOffreScreen extends ConsumerWidget {
  const PourquoiOffreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionSDataProvider);
    return GPage(
      title: 'Pourquoi cette offre ?',
      actions: [
        GOutlineButton('Ignorer', onPressed: () => ScreenHeader.back(context)),
        PrimaryButton(label: 'Postuler', height: 54, onPressed: () => context.openScreen('159')),
      ],
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: QRow(icon: AppIcons.briefcase, title: d.offerTitle, subtitle: d.offerDetail),
        ),
        gap12,
        AppCard(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              GGauge(percent: d.offerMatch, size: 88),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Compatibilité ${d.offerMatch} %', style: AppText.bodyStrong.copyWith(fontSize: 15)),
                    Text('Votre profil correspond très bien à cette offre.', style: AppText.small.copyWith(fontSize: 11.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
        gap12,
        IProgressCard([for (final c in d.matchCriteria) (c.$1, '${c.$2}%', c.$2 / 100, c.$3)]),
        const GSectionTitle('Points à améliorer'),
        SItemList(d.improvements),
      ],
    );
  }
}
