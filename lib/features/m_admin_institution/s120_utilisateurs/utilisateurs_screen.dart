import '../m_widgets.dart';

/// 120 · Utilisateurs et affectations.
class UtilisateursScreen extends ConsumerStatefulWidget {
  const UtilisateursScreen({super.key});

  @override
  ConsumerState<UtilisateursScreen> createState() => _UtilisateursScreenState();
}

class _UtilisateursScreenState extends ConsumerState<UtilisateursScreen> {
  int _tab = 0;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionMDataProvider);
    final items = d.users.where((u) {
      final ok = switch (_tab) {
        1 => u.$2 == 'Étudiant',
        2 => u.$2 == 'Vendeur',
        3 => u.$2 == 'Responsable',
        4 => u.$5 == 'Suspendu',
        _ => true,
      };
      return ok && u.$1.toLowerCase().contains(_query.toLowerCase());
    }).toList();
    return MAdminShell(
      title: 'Utilisateurs et affectations',
      selected: 3,
      children: [
        OpsSearchRow(
          search: OpsSearchBar(
            hint: 'Rechercher un utilisateur…',
            onChanged: (v) => setState(() => _query = v),
            onFilter: () => context.toast('Filtres (démonstration).'),
          ),
          button: OpsBigButton(
            label: 'Inviter un utilisateur',
            icon: AppIcons.plus,
            onTap: () => context.toast('Invitation envoyée.'),
          ),
        ),
        gap16,
        OpsFilterChips(labels: d.userTabs, selected: _tab, onSelected: (i) => setState(() => _tab = i)),
        gap16,
        OpsTable(
          columns: const ['Nom', 'Rôle', 'Département', 'Dernière connexion', 'Statut'],
          flex: const [3, 2, 3, 3, 2],
          emptyLabel: 'Aucun utilisateur.',
          rows: [
            for (final u in items)
              [OpsCell(u.$1, strong: true), OpsCell(u.$2), OpsCell(u.$3), OpsCell(u.$4), lBadge(u.$5, u.$6)],
          ],
        ),
      ],
    );
  }
}
