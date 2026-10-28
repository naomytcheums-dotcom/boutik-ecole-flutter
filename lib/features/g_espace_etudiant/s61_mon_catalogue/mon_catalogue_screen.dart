import '../g_widgets.dart';

/// 61 · Mon catalogue (annonces du vendeur).
class MonCatalogueScreen extends ConsumerStatefulWidget {
  const MonCatalogueScreen({super.key});

  @override
  ConsumerState<MonCatalogueScreen> createState() => _MonCatalogueScreenState();
}

class _MonCatalogueScreenState extends ConsumerState<MonCatalogueScreen> {
  int _tab = 0;
  String _query = '';

  static (String, Tone) _status(GListingStatus s) => switch (s) {
    GListingStatus.published => ('Publié', Tone.success),
    GListingStatus.lowStock => ('Stock bas', Tone.neutral),
    GListingStatus.outOfStock => ('Rupture', Tone.error),
    GListingStatus.draft => ('Brouillon', Tone.neutral),
  };

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionGDataProvider);
    final filter = [null, GListingStatus.published, GListingStatus.draft, GListingStatus.outOfStock][_tab];
    final items = d.catalog
        .where((l) => filter == null || l.status == filter)
        .where((l) => l.title.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    return AppScaffold(
      tab: NavTab.profile,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      header: GRootHeader(
        'Mon catalogue',
        action: HeaderIcon(AppIcons.plus, label: 'Nouvelle annonce', onTap: () => context.openScreen('58')),
      ),
      children: [
        SearchField(hint: 'Rechercher une annonce', onChanged: (v) => setState(() => _query = v)),
        gap8,
        GTabs(
          labels: ['Tous (${d.catalogTotal})', 'Publiés', 'Brouillons', 'Rupture'],
          selected: _tab,
          onSelected: (i) => setState(() => _tab = i),
        ),
        gap8,
        if (items.isEmpty)
          Padding(padding: const EdgeInsets.all(32), child: Text('Aucune annonce.', textAlign: TextAlign.center, style: AppText.secondary))
        else
          GListCard(
            children: [
              for (final l in items)
                GThumbRow(
                  image: l.image,
                  title: l.title,
                  subtitle: '${fcfa(l.price)} · ${l.status == GListingStatus.draft ? 'Brouillon' : '${l.stock} en stock'}',
                  trailing: GBadge(_status(l.status).$1, _status(l.status).$2),
                  onTap: () => context.openScreen('60'),
                ),
            ],
          ),
      ],
    );
  }
}