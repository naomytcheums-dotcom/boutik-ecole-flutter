import '../../n_admin_globale/n_widgets.dart' show NAdminShell;
import '../v_widgets.dart';

/// 181 · Matrice des permissions (web, administration globale).
class MatricePermissionsScreen extends ConsumerWidget {
  const MatricePermissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionVDataProvider);
    return NAdminShell(
      title: 'Matrice des permissions',
      selected: 1,
      children: [
        OpsCard(
          child: OpsTable(
            columns: ['Permission', ...d.matrixRoles],
            flex: const [5, 2, 2, 2, 2, 2, 2],
            minWidth: 760,
            rows: [
              for (final p in d.matrix) [OpsCell(p.$1, strong: true), for (final v in p.$2) OpsCell(v)],
            ],
          ),
        ),
        gap16,
        const OpsInfoNote(
          'Les permissions sont configurables et seront confirmées avec l’IUT avant la mise en production.',
        ),
      ],
    );
  }
}
