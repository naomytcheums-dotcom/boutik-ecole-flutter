import '../../common/common.dart';
import '../s287_catalogue_tablette/catalogue_shared.dart';

/// 288 · Catalogue du département MMI (web 1280×800) : tableau des fiches.
class CatalogueWebScreen extends ConsumerWidget {
  const CatalogueWebScreen({super.key});

  static const nav = [
    WebNavItem('Tableau de bord', AppIcons.layoutGrid, target: '108'),
    WebNavItem('Catalogue', AppIcons.package, target: '288'),
    WebNavItem('Soumissions', AppIcons.fileText, target: '286'),
    WebNavItem('Commandes', AppIcons.shoppingBag, target: '110'),
    WebNavItem('Équipe et permissions', AppIcons.users, target: '281', section: 'Gestion'),
    WebNavItem('Médiathèque', AppIcons.image, target: '263', section: 'Gestion'),
    WebNavItem('Finances', AppIcons.wallet, target: '139', section: 'Gestion'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(nouveauxDataProvider);
    final items = ref.watch(catalogRepositoryProvider).products();
    return WebShell(
      title: 'Catalogue du département ${d.departmentName}',
      subtitle: '${d.catalogTotal} fiches · filtrer, modifier, publier',
      navItems: nav,
      selected: 1,
      defaultActions: false,
      searchHint: 'Rechercher une fiche…',
      headerActions: [
        PrimaryButton(label: '+ Nouvelle fiche', expand: false, height: 46, onPressed: () => context.openScreen('275')),
      ],
      children: [
        WebTable(
          columns: const ['Fiche', 'Type', 'Prix', 'Statut', 'Mis à jour', 'Actions'],
          flex: const [5, 2, 2, 2, 2, 2],
          rows: [
            for (final p in items)
              [
                Row(
                  children: [
                    SizedBox(width: 32, child: PhotoTile(image: p.image, radius: 6, semanticLabel: p.title)),
                    const SizedBox(width: 12),
                    Expanded(child: Cell(p.title, strong: true)),
                  ],
                ),
                Cell(listingType(p.type)),
                Cell(fcfa(p.price)),
                Builder(builder: (_) {
                  final (s, c) = listingStatus(p.status);
                  return Text(s, style: AppText.label.copyWith(color: c));
                }),
                Cell(p.updated, color: AppColors.textSecondary),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextLink('Modifier', onTap: () => context.openScreen('275')),
                    Text(' · ', style: AppText.small),
                    TextLink('Publier', onTap: () => context.toast('${p.title} publié.')),
                  ],
                ),
              ],
          ],
        ),
      ],
    );
  }
}
