import '../auth_common.dart';

/// 20 · Résultats de recherche.
class ResultatsRechercheScreen extends ConsumerStatefulWidget {
  const ResultatsRechercheScreen({super.key});

  @override
  ConsumerState<ResultatsRechercheScreen> createState() => _ResultatsRechercheScreenState();
}

class _ResultatsRechercheScreenState extends ConsumerState<ResultatsRechercheScreen> {
  late final _query = TextEditingController(text: ref.read(sectionBDataProvider).searchQuery);
  int _filter = 0;
  late final Set<String> _favorites = {
    for (final r in ref.read(sectionBDataProvider).searchResults)
      if (r.favorite) r.title,
  };

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionBDataProvider);
    final q = _query.text.trim().toLowerCase();
    final results = q.isEmpty || q == d.searchQuery
        ? d.searchResults
        : d.searchResults.where((r) => r.title.toLowerCase().contains(q) || r.category.toLowerCase().contains(q)).toList();
    final count = q == d.searchQuery ? d.searchCount : results.length;
    return AppScaffold(
      tab: NavTab.search,
      padding: EdgeInsets.zero,
      header: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
        child: Row(
          children: [
            RoundIconButton(
              icon: AppIcons.arrowLeft,
              label: 'Retour',
              bordered: false,
              background: Colors.transparent,
              onTap: () => ScreenHeader.back(context),
            ),
            Expanded(
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: ShapeDecoration(color: Colors.white.withValues(alpha: .7), shape: const StadiumBorder()),
                child: Row(
                  children: [
                    const AppIcon(AppIcons.search, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _query,
                        onChanged: (_) => setState(() {}),
                        style: AppText.body,
                        decoration: const InputDecoration(
                          filled: false,
                          isDense: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            HeaderIcon(AppIcons.slidersHorizontal, label: 'Filtres', onTap: () => context.openScreen('23')),
          ],
        ),
      ),
      children: [
        PillBar(
          labels: const ['Tous', 'Produits', 'Services', 'Talents', 'Projets'],
          selected: _filter,
          onSelected: (i) => setState(() => _filter = i),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        gap16,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Semantics(liveRegion: true, child: Text('$count résultat${count > 1 ? 's' : ''}', style: AppText.h3)),
        ),
        gap12,
        if (results.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Text('Aucun résultat pour « ${_query.text} ».', textAlign: TextAlign.center, style: AppText.secondary),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: LayoutBuilder(
              builder: (context, c) => Wrap(
                spacing: 14,
                runSpacing: 16,
                children: [
                  for (final r in results)
                    SizedBox(
                      width: (c.maxWidth - 14) / 2,
                      child: GestureDetector(
                        onTap: () => context.openScreen('05'),
                        child: Semantics(
                          button: true,
                          label: '${r.title}, ${fcfa(r.price)}',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              PhotoTile(
                                image: r.image,
                                aspectRatio: 158 / 112,
                                radius: 18,
                                favorite: _favorites.contains(r.title),
                                onFavorite: () => setState(
                                  () => _favorites.contains(r.title) ? _favorites.remove(r.title) : _favorites.add(r.title),
                                ),
                              ),
                              gap8,
                              Text(r.title, style: AppText.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(fcfa(r.price), style: AppText.label.copyWith(fontWeight: FontWeight.w500)),
                              Text(r.category, style: AppText.small.copyWith(color: AppColors.accent)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
