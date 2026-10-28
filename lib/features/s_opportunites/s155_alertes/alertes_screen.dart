import '../s_widgets.dart';

/// 155 · Alertes.
class AlertesScreen extends ConsumerStatefulWidget {
  const AlertesScreen({super.key});

  @override
  ConsumerState<AlertesScreen> createState() => _AlertesScreenState();
}

class _AlertesScreenState extends ConsumerState<AlertesScreen> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionSDataProvider);
    List<SItem> keep(List<SItem> l) => _filter == 0 ? l : l.where((i) => i.rubric == d.alertFilters[_filter]).toList();
    final today = keep(d.todayAlerts);
    final week = keep(d.weekAlerts);
    return AppScaffold(
      tab: NavTab.home,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      header: GRootHeader(
        'Alertes',
        action: HeaderIcon(AppIcons.settings, label: 'Préférences d’alertes', onTap: () => context.openScreen('156')),
      ),
      children: [
        GTabs(labels: d.alertFilters, selected: _filter, onSelected: (i) => setState(() => _filter = i)),
        if (today.isNotEmpty) ...[const GSectionTitle('Aujourd’hui'), SItemList(today)],
        if (week.isNotEmpty) ...[const GSectionTitle('Cette semaine'), SItemList(week)],
        if (today.isEmpty && week.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text('Aucune alerte.', textAlign: TextAlign.center, style: AppText.secondary),
          ),
      ],
    );
  }
}
