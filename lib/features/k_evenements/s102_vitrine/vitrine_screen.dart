import '../k_widgets.dart';

/// 102 · Vitrine (collection mise en avant).
class VitrineScreen extends ConsumerWidget {
  const VitrineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionKDataProvider);
    return GPage(
      title: 'Vitrine',
      trailing: HeaderIcon(AppIcons.share, label: 'Partager', onTap: () => context.openScreen('212')),
      actions: [PrimaryButton(label: 'Voir la collection', height: 54, onPressed: () => context.openScreen('22'))],
      children: [
        IHeroBanner(image: d.showcaseImage, title: d.showcaseTitle, subtitle: d.showcaseDetail, height: 200),
        gap16,
        ICounters(d.showcaseCounters),
        const GSectionTitle('Pièces à l’honneur'),
        CGrid(d.showcase),
      ],
    );
  }
}
