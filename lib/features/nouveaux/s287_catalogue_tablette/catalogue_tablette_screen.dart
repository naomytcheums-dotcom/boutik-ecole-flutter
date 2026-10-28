import '../../common/common.dart';
import 'catalogue_shared.dart';

/// 287 · Catalogue du département MMI (tablette 768) : 3 colonnes.
class CatalogueTabletteScreen extends ConsumerWidget {
  const CatalogueTabletteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(nouveauxDataProvider);
    final filter = ref.watch(catalogFilterProvider);
    final items = filterCatalog(ref.watch(catalogRepositoryProvider).products(), filter).take(6).toList();
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth >= 700 ? 3 : (c.maxWidth >= 480 ? 2 : 1);
              return ListView(
                padding: const EdgeInsets.fromLTRB(40, 40, 40, 32),
                children: [
                  PageIntro('Catalogue du département ${d.departmentName}', subtitle: d.catalogSummary, display: true),
                  gap24,
                  Container(
                    height: 52,
                    padding: const EdgeInsets.only(left: 24, right: 6),
                    decoration: ShapeDecoration(color: Colors.white, shape: const StadiumBorder()),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            style: AppText.body,
                            decoration: InputDecoration(
                              hintText: 'Rechercher une fiche…',
                              hintStyle: AppText.body.copyWith(color: AppColors.textSecondary),
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                          ),
                        ),
                        PrimaryButton(label: '+ Nouvelle fiche', expand: false, height: 40, onPressed: () => context.openScreen('275')),
                      ],
                    ),
                  ),
                  gap16,
                  Wrap(
                    spacing: 16,
                    children: [
                      for (final (i, f) in catalogFilters.indexed)
                        Pill(f, selected: i == filter, onTap: () => ref.read(catalogFilterProvider.notifier).select(i)),
                    ],
                  ),
                  gap16,
                  GridView.count(
                    crossAxisCount: cols,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 20,
                    childAspectRatio: 216 / 330,
                    children: [for (final p in items) _CatalogTile(p)],
                  ),
                  gap16,
                  Text('Mise en page adaptée : $cols colonnes (mobile : 1 colonne, bureau : tableau)', style: AppText.small),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CatalogTile extends StatelessWidget {
  const _CatalogTile(this.p);

  final Product p;

  @override
  Widget build(BuildContext context) {
    final (status, color) = listingStatus(p.status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PhotoTile(image: p.image, aspectRatio: 216 / 210, radius: 20, semanticLabel: p.title),
        gap16,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.title, style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(fcfa(p.price), style: AppText.bodyStrong.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(status, style: AppText.label.copyWith(color: color)),
              Row(
                children: [
                  TextLink('Modifier', color: AppColors.textSecondary, onTap: () => context.openScreen('275')),
                  Text(' · ', style: AppText.small),
                  TextLink('Dupliquer', color: AppColors.textSecondary, onTap: () => context.toast('${p.title} dupliqué.')),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
