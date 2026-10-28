import '../c_widgets.dart';

/// 25b · Mes collections (listes de favoris).
class MesCollectionsScreen extends ConsumerWidget {
  const MesCollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionCDataProvider);
    void create() => context.toast('Nouvelle collection créée.');
    return CPage(
      title: 'Mes collections',
      tab: NavTab.profile,
      trailing: HeaderIcon(AppIcons.plus, label: 'Créer une collection', onTap: create),
      children: [
        const SearchField(hint: 'Rechercher dans mes listes', showFilter: false),
        GSectionTitle('Mes listes', trailing: TextLink('Gérer →', onTap: () => context.toast('Mode gestion des listes.'))),
        GListCard(
          children: [
            for (final c in d.collections)
              GThumbRow(
                image: c.image,
                title: c.title,
                subtitle: c.detail,
                trailing: const AppIcon(AppIcons.chevronRight, size: 18),
                onTap: () => context.openScreen('25'),
              ),
          ],
        ),
        gap16,
        Material(
          color: Colors.white,
          shape: const StadiumBorder(side: BorderSide(color: AppColors.cardBorder)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: create,
            child: SizedBox(
              height: 46,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppIcon(AppIcons.plus, size: 18),
                  const SizedBox(width: 10),
                  Text('Créer une collection', style: AppText.body.copyWith(fontSize: 15)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
