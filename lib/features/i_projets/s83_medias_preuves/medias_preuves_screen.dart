import '../i_widgets.dart';

/// 83 · Médias et preuves.
class MediasPreuvesScreen extends ConsumerWidget {
  const MediasPreuvesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionIDataProvider);
    return GPage(
      title: 'Médias et preuves',
      actions: [PrimaryButton(label: 'Téléverser', height: 54, onPressed: () => context.openScreen('279'))],
      children: [
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 14,
          childAspectRatio: 108 / 84,
          children: [for (final p in d.mediaGrid) PhotoTile(image: p, radius: 14)],
        ),
        const GSectionTitle('Documents'),
        GListCard(
          children: [
            for (final doc in d.documents)
              IIconRow(
                icon: doc.video ? AppIcons.image : AppIcons.file,
                title: doc.name,
                subtitle: doc.detail,
                trailing: GBadge(doc.status, doc.tone),
                onTap: doc.video ? () => context.openScreen('279') : null,
              ),
          ],
        ),
        gap16,
        const GNote(
          'Les preuves de réalisation sont examinées par le responsable de département.',
          icon: AppIcons.shieldCheck,
        ),
      ],
    );
  }
}
