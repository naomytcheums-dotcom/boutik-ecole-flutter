import '../j_widgets.dart';

/// 91 · Rechercher des talents (annuaire filtrable côté entreprise).
class RechercherTalentsScreen extends ConsumerStatefulWidget {
  const RechercherTalentsScreen({super.key});

  @override
  ConsumerState<RechercherTalentsScreen> createState() => _RechercherTalentsScreenState();
}

class _RechercherTalentsScreenState extends ConsumerState<RechercherTalentsScreen> {
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
    final d = ref.watch(sectionJDataProvider);
    final q = _query.trim().toLowerCase();
    final items = d.talents
        .where((t) => _filter == 0 || t.category == d.talentFilters[_filter])
        .where((t) => q.isEmpty || '${t.name} ${t.detail} ${t.category}'.toLowerCase().contains(q))
        .toList();
    final filtered = _filter != 0 || q.isNotEmpty;
    final count = filtered ? items.length : d.talentsFound;
    return JNavPage(
      title: 'Rechercher des talents',
      trailing: HHeaderAction(
        AppIcons.funnel,
        label: 'Filtrer',
        onTap: () => setState(() => _filter = (_filter + 1) % d.talentFilters.length),
      ),
      children: [
        const SizedBox(height: 6),
        _SearchBar(focus: _focus, onChanged: (v) => setState(() => _query = v)),
        const SizedBox(height: 9),
        HChips(labels: d.talentFilters, selected: _filter, onSelected: (i) => setState(() => _filter = i)),
        HCountTitle('$count profil${count > 1 ? 's' : ''} correspond${count > 1 ? 'ent' : ''}'),
        if (items.isEmpty)
          const HEmpty('Aucun profil ne correspond à votre recherche.')
        else
          HListCard(
            children: [
              for (final t in items)
                HRow(
                  leading: JAvatar(t.avatar),
                  title: t.name,
                  subtitle: t.detail,
                  trailing: JBadge(t.status, t.tone),
                  onTap: () => context.openScreen('95b'),
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
                hintText: 'Compétence, filière, équipe…',
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
            label: 'Filtres avancés',
            bordered: false,
            background: Colors.transparent,
            onTap: () => context.toast('Filtres avancés bientôt disponibles.'),
          ),
        ],
      ),
    );
  }
}
