import '../c_widgets.dart';

/// 21 · Recherche avancée.
class RechercheAvanceeScreen extends ConsumerStatefulWidget {
  const RechercheAvanceeScreen({super.key});

  @override
  ConsumerState<RechercheAvanceeScreen> createState() => _RechercheAvanceeScreenState();
}

class _RechercheAvanceeScreenState extends ConsumerState<RechercheAvanceeScreen> {
  late final d = ref.read(sectionCDataProvider);
  int _tab = 0;
  late String _dept = d.departments.first;
  late String _budget = d.budgets.first;
  late String _cat = d.categories.first;
  bool _available = true;
  bool _verified = false;

  void _reset() => setState(() {
    _tab = 0;
    _dept = d.departments.first;
    _budget = d.budgets.first;
    _cat = d.categories.first;
    _available = true;
    _verified = false;
  });

  @override
  Widget build(BuildContext context) {
    return GPage(
      title: 'Recherche avancée',
      trailing: cIcon(context, AppIcons.slidersHorizontal, 'Filtres', '23'),
      actions: [
        GOutlineButton('Réinitialiser', onPressed: _reset),
        PrimaryButton(label: 'Rechercher', height: 54, onPressed: () => context.openScreen('20')),
      ],
      children: [
        const SearchField(hint: 'Mot-clé, nom, compétence…', showFilter: false),
        gap8,
        Row(
          children: [
            for (final (i, t) in d.searchTabs.indexed)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == _tab,
                  child: InkWell(
                    onTap: () => setState(() => _tab = i),
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: i == _tab ? AppColors.accent : AppColors.cardBorder, width: i == _tab ? 2 : 1),
                        ),
                      ),
                      child: Text(
                        t,
                        style: AppText.small.copyWith(
                          color: i == _tab ? AppColors.ink : AppColors.textSecondary,
                          fontWeight: i == _tab ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        gap12,
        SelectField(
          label: 'Département',
          icon: AppIcons.landmark,
          options: d.departments,
          value: _dept,
          onChanged: (v) => setState(() => _dept = v),
        ),
        gap16,
        SelectField(
          label: 'Budget',
          icon: AppIcons.wallet,
          options: d.budgets,
          value: _budget,
          onChanged: (v) => setState(() => _budget = v),
        ),
        gap16,
        SelectField(
          label: 'Catégorie',
          icon: AppIcons.layoutGrid,
          options: d.categories,
          value: _cat,
          onChanged: (v) => setState(() => _cat = v),
        ),
        gap16,
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          child: Column(
            children: [
              ToggleRow(
                title: 'Disponible uniquement',
                subtitle: 'En stock ou sur commande',
                value: _available,
                onChanged: (v) => setState(() => _available = v),
              ),
              const Divider(height: 1),
              ToggleRow(
                title: 'Vendeurs vérifiés',
                subtitle: 'Badge de confiance',
                value: _verified,
                onChanged: (v) => setState(() => _verified = v),
              ),
            ],
          ),
        ),
        const GSectionTitle('Recherches récentes'),
        GListCard(
          children: [
            for (final r in d.recentSearches)
              ListRow(
                title: r,
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: const Color(0xFFF2F0F5), borderRadius: BorderRadius.circular(10)),
                  alignment: Alignment.center,
                  child: const AppIcon(AppIcons.clock, size: 18),
                ),
                onTap: () => context.openScreen('20'),
              ),
          ],
        ),
      ],
    );
  }
}
