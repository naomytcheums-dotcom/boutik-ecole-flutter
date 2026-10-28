import '../k_widgets.dart';

/// 106 · Économie circulaire (produits recyclés, réparables, réutilisables).
class EconomieCirculaireScreen extends ConsumerStatefulWidget {
  const EconomieCirculaireScreen({super.key});

  @override
  ConsumerState<EconomieCirculaireScreen> createState() => _EconomieCirculaireScreenState();
}

class _EconomieCirculaireScreenState extends ConsumerState<EconomieCirculaireScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionKDataProvider);
    return CPage(
      title: 'Économie circulaire',
      trailing: cIcon(context, AppIcons.search, 'Rechercher', '21'),
      children: [
        GTabs(labels: d.circularTabs, selected: _tab, onSelected: (i) => setState(() => _tab = i)),
        gap8,
        IHeroBanner(
          image: d.circularImage,
          title: 'Seconde vie, premier choix',
          subtitle: 'Des créations à partir de matériaux récupérés',
          height: 150,
        ),
        gap16,
        CGrid(d.circular),
        gap16,
        GestureDetector(
          onTap: () => context.openScreen('107'),
          child: const GNote(
            'Chaque achat évite des déchets : retrouvez l’impact dans « Mon impact ».',
            icon: AppIcons.leaf,
          ),
        ),
      ],
    );
  }
}
