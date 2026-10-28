import '../h_widgets.dart';

/// 70 · Talents étudiants (annuaire filtrable).
class TalentsEtudiantsScreen extends ConsumerStatefulWidget {
  const TalentsEtudiantsScreen({super.key});

  @override
  ConsumerState<TalentsEtudiantsScreen> createState() => _TalentsEtudiantsScreenState();
}

class _TalentsEtudiantsScreenState extends ConsumerState<TalentsEtudiantsScreen> {
  final _focus = FocusNode();
  int _filter = 0;
  String _query = '';

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionHDataProvider);
    final q = _query.trim().toLowerCase();
    final items = d.talents
        .where((t) => _filter == 0 || t.category == d.talentFilters[_filter])
        .where((t) => q.isEmpty || '${t.name} ${t.field} ${t.skills}'.toLowerCase().contains(q))
        .toList();
    final filtered = _filter != 0 || q.isNotEmpty;
    return AppScaffold(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      header: HHeader(
        'Talents étudiants',
        trailing: HHeaderAction(AppIcons.search, label: 'Rechercher', onTap: _focus.requestFocus),
      ),
      children: [
        const SizedBox(height: 6),
        _SearchBar(focus: _focus, onChanged: (v) => setState(() => _query = v)),
        const SizedBox(height: 9),
        HChips(labels: d.talentFilters, selected: _filter, onSelected: (i) => setState(() => _filter = i)),
        HCountTitle(
          filtered
              ? '${items.length} talent${items.length > 1 ? 's' : ''} trouvé${items.length > 1 ? 's' : ''}'
              : '${d.talentsAvailable} talents disponibles',
        ),
        if (items.isEmpty)
          const HEmpty('Aucun talent ne correspond à votre recherche.')
        else
          HListCard(
            children: [
              for (final t in items)
                HRow(
                  leading: ClipOval(child: Image.asset(t.avatar, width: 50, height: 50, fit: BoxFit.cover)),
                  title: t.name,
                  subtitle: '${t.field} · ${t.skills}',
                  trailing: t.available
                      ? const HBadge('Disponible', HBadgeKind.success)
                      : const HBadge('Occupée', HBadgeKind.pending),
                  onTap: () => context.openScreen('74'),
                ),
            ],
          ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.focus, required this.onChanged});

  final FocusNode focus;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.only(left: 16, right: 4),
      decoration: ShapeDecoration(color: Colors.white.withValues(alpha: .7), shape: const StadiumBorder()),
      child: Row(
        children: [
          const AppIcon(AppIcons.search, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              focusNode: focus,
              onChanged: onChanged,
              style: AppText.body,
              decoration: InputDecoration(
                hintText: 'Rechercher un talent…',
                hintStyle: AppText.secondary.copyWith(fontSize: 14),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          RoundIconButton(
            icon: AppIcons.slidersHorizontal,
            label: 'Filtres',
            bordered: false,
            background: Colors.transparent,
            onTap: () => context.toast('Filtres avancés bientôt disponibles.'),
          ),
        ],
      ),
    );
  }
}
