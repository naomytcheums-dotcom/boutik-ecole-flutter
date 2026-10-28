import '../c_widgets.dart';

/// 22 · Catalogue de produits.
class CatalogueProduitsScreen extends ConsumerStatefulWidget {
  const CatalogueProduitsScreen({super.key});

  @override
  ConsumerState<CatalogueProduitsScreen> createState() => _CatalogueProduitsScreenState();
}

class _CatalogueProduitsScreenState extends ConsumerState<CatalogueProduitsScreen> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionCDataProvider);
    final rubric = d.catalogFilters[_filter];
    final items = [
      for (final (i, t) in d.catalog.indexed)
        if (_filter == 0 || d.catalogRubrics[i] == rubric) t,
    ];
    return CPage(
      title: 'Catalogue de produits',
      trailing: cIcon(context, AppIcons.search, 'Rechercher', '21'),
      children: [
        GTabs(labels: d.catalogFilters, selected: _filter, onSelected: (i) => setState(() => _filter = i)),
        gap8,
        CCountRow(_filter == 0 ? '${d.catalogCount} produits' : '${items.length} produit${items.length > 1 ? 's' : ''}'),
        gap12,
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text('Aucun produit dans cette rubrique.', textAlign: TextAlign.center, style: AppText.secondary),
          )
        else
          CGrid(items),
      ],
    );
  }
}
