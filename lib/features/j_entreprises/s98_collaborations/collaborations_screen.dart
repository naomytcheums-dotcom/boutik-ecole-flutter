import '../j_widgets.dart';

/// 98 · Collaborations (contrats avec les talents).
class CollaborationsScreen extends ConsumerWidget {
  const CollaborationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionJDataProvider);
    return JRootPage(
      title: 'Collaborations',
      children: [
        const SizedBox(height: 4),
        GKpiGrid(d.contractKpis, valueSize: 23),
        gap12,
        JItemList(d.contracts, onTap: (c) => context.toast('Contrat « ${c.title} » : ${c.detail}.')),
        const JSectionTitle('Suivi du contrat actif'),
        IProgressCard([for (final p in d.contractProgress) (p.$1, '${p.$2}%', p.$2 / 100, p.$3)]),
      ],
    );
  }
}
