import '../c_widgets.dart';

/// 25 · Mes favoris.
class MesFavorisScreen extends ConsumerStatefulWidget {
  const MesFavorisScreen({super.key});

  @override
  ConsumerState<MesFavorisScreen> createState() => _MesFavorisScreenState();
}

class _MesFavorisScreenState extends ConsumerState<MesFavorisScreen> {
  int _tab = 0;
  final _removed = <String>{};

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionCDataProvider);
    final items = [
      for (final (i, f) in d.favorites.indexed)
        if (!_removed.contains(f.title) && (_tab == 0 || d.favoriteRubrics[i] == d.favoriteTabs[_tab])) f,
    ];
    return CPage(
      title: 'Mes favoris',
      tab: NavTab.profile,
      trailing: cIcon(context, AppIcons.search, 'Rechercher', '21'),
      children: [
        GTabs(labels: d.favoriteTabs, selected: _tab, onSelected: (i) => setState(() => _tab = i)),
        gap12,
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text('Aucun favori ici pour le moment.', textAlign: TextAlign.center, style: AppText.secondary),
          ),
        for (final f in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: InkWell(
              onTap: () => context.openScreen('05'),
              child: Row(
                children: [
                  SizedBox(
                    width: 156,
                    child: PhotoTile(image: f.image, aspectRatio: 156 / 122, radius: 22, semanticLabel: f.title),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                f.title,
                                style: AppText.label.copyWith(fontSize: 13.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            RoundIconButton(
                              icon: AppIcons.heartFilled,
                              label: 'Retirer ${f.title} des favoris',
                              size: 28,
                              bordered: false,
                              background: Colors.transparent,
                              foreground: const Color(0xFFE5394A),
                              onTap: () => setState(() => _removed.add(f.title)),
                            ),
                          ],
                        ),
                        Text(fcfa(f.price), style: AppText.body.copyWith(fontSize: 15)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(f.department, style: AppText.small.copyWith(color: AppColors.accent, fontSize: 13)),
                            ),
                            const AppIcon(AppIcons.chevronRight, size: 16),
                          ],
                        ),
                      ],
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
