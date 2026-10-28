import '../w_widgets.dart';

/// 182 · Explorer pendant le chargement (réseau lent) : squelettes, filtres utilisables.
class ExplorerChargementScreen extends ConsumerStatefulWidget {
  const ExplorerChargementScreen({super.key});

  @override
  ConsumerState<ExplorerChargementScreen> createState() => _ExplorerChargementScreenState();
}

class _ExplorerChargementScreenState extends ConsumerState<ExplorerChargementScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionWDataProvider);
    return AppScaffold(
      tab: NavTab.home,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      header: const QTitle('Explorer'),
      children: [
        SearchField(onTap: () => context.openScreen('21'), onFilter: () => context.openScreen('21')),
        gap16,
        GTabs(labels: d.exploreTabs, selected: _tab, onSelected: (i) => setState(() => _tab = i)),
        gap16,
        Semantics(
          label: 'Chargement des contenus ${d.exploreTabs[_tab]}',
          liveRegion: true,
          child: ExcludeSemantics(
            child: Column(
              children: [
                for (var i = 0; i < d.skeletonCount; i++) ...[const WSkeletonCard(), const SizedBox(height: 12)],
              ],
            ),
          ),
        ),
        gap8,
        const WInfoCard(
          icon: AppIcons.refreshCw,
          text: 'Chargement en cours… les contenus apparaissent progressivement.',
        ),
      ],
    );
  }
}
