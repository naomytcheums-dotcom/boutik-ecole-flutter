import '../l_widgets.dart';

/// 214 · Départements (annuaire des filières par famille).
class DepartementsScreen extends ConsumerStatefulWidget {
  const DepartementsScreen({super.key});

  @override
  ConsumerState<DepartementsScreen> createState() => _DepartementsScreenState();
}

class _DepartementsScreenState extends ConsumerState<DepartementsScreen> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionLDataProvider);
    final families = _filter == 0 ? d.families : d.families.where((f) => f.$2 == d.familyFilters[_filter]).toList();
    return CPage(
      title: 'Départements',
      trailing: cIcon(context, AppIcons.search, 'Rechercher', '21'),
      tab: NavTab.home,
      children: [
        GTabs(labels: d.familyFilters, selected: _filter, onSelected: (i) => setState(() => _filter = i)),
        for (final f in families) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Semantics(header: true, child: Text(f.$1, style: AppText.bodyStrong.copyWith(fontSize: 15))),
          ),
          GListCard(
            children: [
              for (final dep in f.$3)
                GThumbRow(
                  image: dep.$3,
                  title: dep.$1,
                  subtitle: dep.$2,
                  trailing: const AppIcon(AppIcons.chevronRight, size: 18),
                  onTap: () => context.openScreen('215'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
