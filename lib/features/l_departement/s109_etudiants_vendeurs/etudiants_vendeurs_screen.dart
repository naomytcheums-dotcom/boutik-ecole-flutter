import '../l_widgets.dart';

/// 109 · Étudiants et vendeurs du département.
class EtudiantsVendeursScreen extends ConsumerStatefulWidget {
  const EtudiantsVendeursScreen({super.key});

  @override
  ConsumerState<EtudiantsVendeursScreen> createState() => _EtudiantsVendeursScreenState();
}

class _EtudiantsVendeursScreenState extends ConsumerState<EtudiantsVendeursScreen> {
  int _tab = 0;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionLDataProvider);
    final items = d.people.where((p) {
      final tabOk = switch (_tab) {
        1 => p.$3 == 'Vendeur',
        2 => p.$3 == 'Étudiant',
        3 => p.$6 == 'En attente',
        _ => true,
      };
      return tabOk && p.$1.toLowerCase().contains(_query.toLowerCase());
    }).toList();
    return LDepartmentShell(
      title: 'Étudiants et vendeurs',
      selected: 1,
      children: [
        OpsSearchRow(
          search: OpsSearchBar(
            hint: 'Rechercher un étudiant ou un vendeur…',
            onChanged: (v) => setState(() => _query = v),
            onFilter: () => context.toast('Filtres avancés (démonstration).'),
          ),
          button: OpsBigButton(
            label: 'Exporter la liste',
            icon: AppIcons.download,
            dark: false,
            onTap: () => context.toast('Liste exportée (démonstration).'),
          ),
        ),
        gap16,
        OpsFilterChips(labels: d.peopleTabs, selected: _tab, onSelected: (i) => setState(() => _tab = i)),
        gap16,
        OpsTable(
          columns: const ['Nom', 'Filière', 'Rôle', 'Annonces', 'Ventes (FCFA)', 'Statut'],
          flex: const [3, 3, 2, 2, 2, 2],
          rows: [
            for (final p in items)
              [
                OpsCell(p.$1, strong: true),
                OpsCell(p.$2),
                OpsCell(p.$3),
                OpsCell('${p.$4}'),
                OpsCell(p.$5 == 0 ? '—' : fcfa(p.$5, withUnit: false)),
                lBadge(p.$6, p.$7),
              ],
          ],
        ),
      ],
    );
  }
}
