import '../i_widgets.dart';

/// 78 · Projets innovants.
class ProjetsInnovantsScreen extends ConsumerStatefulWidget {
  const ProjetsInnovantsScreen({super.key});

  @override
  ConsumerState<ProjetsInnovantsScreen> createState() => _ProjetsInnovantsScreenState();
}

class _ProjetsInnovantsScreenState extends ConsumerState<ProjetsInnovantsScreen> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionIDataProvider);
    final items = [
      for (final (i, p) in d.projects.indexed)
        if (_filter == 0 || d.projectRubrics[i] == d.projectFilters[_filter]) p,
    ];
    return CPage(
      title: 'Projets innovants',
      trailing: cIcon(context, AppIcons.search, 'Rechercher', '21'),
      children: [
        GTabs(labels: d.projectFilters, selected: _filter, onSelected: (i) => setState(() => _filter = i)),
        gap8,
        IHeroBanner(
          image: d.featuredImage,
          title: d.featuredTitle,
          subtitle: d.featuredDetail,
          onTap: () => context.openScreen('79'),
        ),
        GSectionTitle('Projets à découvrir', trailing: TextLink('Voir tout →', onTap: () => setState(() => _filter = 0))),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Aucun projet dans cette catégorie.', textAlign: TextAlign.center, style: AppText.secondary),
          )
        else
          GListCard(
            children: [
              for (final p in items)
                GThumbRow(
                  image: p.image,
                  title: p.title,
                  subtitle: '${p.department} · ${p.progress} %',
                  trailing: GBadge(p.status, p.tone),
                  onTap: () => context.openScreen('79'),
                ),
            ],
          ),
      ],
    );
  }
}
