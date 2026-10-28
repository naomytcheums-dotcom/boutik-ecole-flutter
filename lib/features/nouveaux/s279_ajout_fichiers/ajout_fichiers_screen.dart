import '../../common/common.dart';

/// 279 · Ajouter des fichiers (contrôles automatiques avant publication).
class AjoutFichiersScreen extends ConsumerWidget {
  const AjoutFichiersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(nouveauxDataProvider);
    return DetailScreen(
      title: 'Ajouter des fichiers',
      subtitle: 'Contrôles automatiques avant publication',
      action: 'Ajouter un fichier',
      onAction: () => context.toast('Sélection d’un fichier…'),
      children: [
        const HeroMessage(icon: AppIcons.paperclip, iconSize: 60),
        gap16,
        KeyValueCard(title: 'Règles de dépôt', rowGap: 12, rows: [for (final v in d.uploadRules) kvOf(v)]),
        gap16,
        for (final f in d.uploads) ...[
          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            radius: 20,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(padding: const EdgeInsets.only(top: 5), child: StatusDot(toneToColor(f.tone))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.title, style: AppText.bodyStrong),
                      const SizedBox(height: 4),
                      Text(f.detail, style: AppText.small.copyWith(color: toneToColor(f.tone), fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Text(f.status, style: AppText.small),
              ],
            ),
          ),
          gap12,
        ],
      ],
    );
  }
}
