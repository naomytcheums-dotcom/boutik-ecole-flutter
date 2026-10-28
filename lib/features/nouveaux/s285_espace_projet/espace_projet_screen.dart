import '../../common/common.dart';

/// 285 · Espace projet d'une mission (contrat, jalons, messagerie).
class EspaceProjetScreen extends ConsumerWidget {
  const EspaceProjetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(nouveauxDataProvider);
    final current = d.milestones.indexWhere((m) => m.tone == Tone.warning) + 1;
    return DetailScreen(
      title: 'Espace projet',
      subtitle: d.missionTitle,
      action: 'Valider le jalon $current',
      onAction: () => context.toast('Jalon $current validé.'),
      children: [
        const HeroMessage(icon: AppIcons.briefcase, iconSize: 60),
        gap16,
        KeyValueCard(
          title: 'Contrat de mission',
          rowGap: 12,
          rows: [for (final v in d.missionContract) kvOf(v)],
          footer: Align(
            alignment: Alignment.centerLeft,
            child: TextLink('Voir le contrat (PDF) ↗', onTap: () => context.toast('Ouverture du contrat.')),
          ),
        ),
        gap16,
        AppCard(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Jalons', style: AppText.h3.copyWith(fontWeight: FontWeight.w600)),
              gap8,
              for (final m in d.milestones)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      StatusDot(toneToColor(m.tone)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(m.title, style: AppText.body)),
                      Text(m.status, style: AppText.label.copyWith(color: toneToColor(m.tone))),
                    ],
                  ),
                ),
            ],
          ),
        ),
        gap16,
        AppCard(
          onTap: () => context.openScreen('51'),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Messagerie du projet · ${d.missionMessages} nouveaux messages', style: AppText.bodyStrong),
              const SizedBox(height: 4),
              Text('Historique des échanges et des versions', style: AppText.small),
            ],
          ),
        ),
      ],
    );
  }
}
