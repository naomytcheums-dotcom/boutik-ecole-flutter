import '../../common/common.dart';

/// 278 · Fiche projet : liens et propriété intellectuelle.
class FicheProjetPiScreen extends ConsumerWidget {
  const FicheProjetPiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(nouveauxDataProvider);
    return DetailScreen(
      title: 'Lampe en bois recyclé',
      subtitle: 'Fiche projet · liens et propriété intellectuelle',
      action: 'Enregistrer les informations',
      onAction: () => context.toast('Informations enregistrées.'),
      children: [
        const HeroMessage(icon: AppIcons.link, iconSize: 60),
        gap16,
        AppCard(
          padding: const EdgeInsets.fromLTRB(20, 18, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Liens du projet', style: AppText.h3.copyWith(fontWeight: FontWeight.w600)),
              gap8,
              for (final l in d.projectLinks)
                InkWell(
                  onTap: () => context.toast('Ouverture de ${l.value}'),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.label, style: AppText.bodyStrong),
                              Text(l.value, style: AppText.small, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        const AppIcon(AppIcons.arrowUpRight, size: 16, color: AppColors.accent),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        gap16,
        KeyValueCard(
          title: 'Propriété intellectuelle',
          rowGap: 12,
          rows: [for (final v in d.projectIp) kvOf(v)],
        ),
      ],
    );
  }
}
