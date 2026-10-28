import '../i_widgets.dart';

/// 82 · Journal du projet.
class JournalProjetScreen extends ConsumerWidget {
  const JournalProjetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionIDataProvider);
    return GPage(
      title: 'Journal du projet',
      actions: [PrimaryButton(label: 'Ajouter une étape', height: 54, onPressed: () => context.toast('Nouvelle étape ajoutée.'))],
      children: [
        IMilestones(d.journal),
        gap8,
        Row(
          children: [
            for (final (i, p) in d.journalPhotos.indexed) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: PhotoTile(image: p, aspectRatio: 108 / 84, radius: 14, onTap: () => context.openScreen('83'))),
            ],
          ],
        ),
      ],
    );
  }
}
