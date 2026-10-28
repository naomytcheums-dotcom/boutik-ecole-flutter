import '../x_widgets.dart';

/// 188 · Recherche de talents et d'équipes (web) : recherche, filtres et vignettes de profils.
class RechercheTalentsScreen extends ConsumerStatefulWidget {
  const RechercheTalentsScreen({super.key});

  @override
  ConsumerState<RechercheTalentsScreen> createState() => _RechercheTalentsScreenState();
}

class _RechercheTalentsScreenState extends ConsumerState<RechercheTalentsScreen> {
  int _filter = 0;
  String _query = '';
  final _favorites = <String>{};

  bool _matches(XTalent t) {
    final byFilter = switch (_filter) {
      0 => true,
      4 => t.team,
      5 => t.available,
      _ => t.filter == _filter,
    };
    final q = _query.trim().toLowerCase();
    final byQuery = q.isEmpty || '${t.name} ${t.program} ${t.skills}'.toLowerCase().contains(q);
    return byFilter && byQuery;
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionXDataProvider);
    final results = d.talents.where(_matches).toList();
    return XCompanyShell(
      title: 'Recherche de talents et d’équipes',
      selected: 2,
      children: [
        OpsSearchRow(
          buttonWidth: 272,
          search: OpsSearchBar(
            hint: 'Compétence, filière, nom…',
            onChanged: (v) => setState(() => _query = v),
            onFilter: () => context.toast('Filtres avancés (démonstration).'),
          ),
          button: OpsBigButton(
            label: 'Enregistrer la recherche',
            icon: AppIcons.info,
            dark: false,
            onTap: () => context.toast('Recherche enregistrée.'),
          ),
        ),
        const SizedBox(height: 8),
        OpsFilterChips(labels: d.talentFilters, selected: _filter, onSelected: (i) => setState(() => _filter = i)),
        const SizedBox(height: 12),
        if (results.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Text(
              'Aucun talent ne correspond à ces critères.',
              style: AppText.secondary,
              textAlign: TextAlign.center,
            ),
          )
        else
          ResponsiveGrid(
            columns: 4,
            spacing: 14,
            minItemWidth: 200,
            children: [
              for (final t in results)
                _TalentTile(
                  talent: t,
                  favorite: _favorites.contains(t.name),
                  onFavorite: () => setState(() {
                    if (!_favorites.remove(t.name)) _favorites.add(t.name);
                  }),
                ),
            ],
          ),
      ],
    );
  }
}

class _TalentTile extends StatelessWidget {
  const _TalentTile({required this.talent, required this.favorite, required this.onFavorite});

  final XTalent talent;
  final bool favorite;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Profil de ${talent.name}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.openScreen('74'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PhotoTile(
              image: talent.image,
              aspectRatio: 1.45,
              radius: 18,
              favorite: favorite,
              onFavorite: onFavorite,
              semanticLabel: talent.name,
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(talent.name, style: AppText.body.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(talent.program, style: AppText.body.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(talent.skills, style: AppText.small.copyWith(color: AppColors.accent)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
