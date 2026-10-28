import '../s_widgets.dart';

/// 157 · Résumé de Kéla (vue entreprise).
class ResumeKelaScreen extends ConsumerWidget {
  const ResumeKelaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionSDataProvider);
    return AppScaffold(
      tab: NavTab.kela,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      header: GRootHeader(
        'Résumé de Kéla',
        subtitle: d.companyName,
        action: HeaderIcon(AppIcons.bell, label: 'Alertes', onTap: () => context.openScreen('155')),
      ),
      children: [
        SAiCard(
          title: 'Résumé de la semaine par Kéla',
          avatar: d.kelaAvatar,
          text: d.summaryText,
          bullets: d.summaryBullets,
        ),
        gap12,
        GKpiGrid([for (final k in d.summaryKpis) GKpi(k.$1, k.$2, k.$3, delta: k.$4.isEmpty ? null : k.$4, deltaTone: k.$5)]),
        GSectionTitle('À examiner en priorité', trailing: TextLink('Voir tout →', onTap: () => context.openScreen('158'))),
        GListCard(
          children: [
            for (final p in d.priority)
              GThumbRow(
                image: p.$3,
                title: p.$1,
                subtitle: p.$2,
                trailing: GBadge(p.$4, Tone.success),
                onTap: () => context.openScreen('190'),
              ),
          ],
        ),
      ],
    );
  }
}
