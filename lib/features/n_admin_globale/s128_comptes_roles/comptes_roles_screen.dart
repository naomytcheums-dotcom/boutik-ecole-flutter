import '../../common/common.dart';
import '../../../data/demo/section_n_demo.dart';
import '../n_widgets.dart';

/// 128 · Comptes, rôles et permissions.
class ComptesRolesScreen extends ConsumerStatefulWidget {
  const ComptesRolesScreen({super.key});

  @override
  ConsumerState<ComptesRolesScreen> createState() => _ComptesRolesScreenState();
}

class _ComptesRolesScreenState extends ConsumerState<ComptesRolesScreen> {
  List<bool>? _granted;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionNDataProvider);
    final granted = _granted ??= [for (final p in d.permissions) p.$3];
    return NAdminShell(
      title: 'Comptes, rôles et permissions',
      selected: 1,
      children: [
        OpsSplit(
          flex: (2, 1),
          left: OpsTable(
            columns: const ['Utilisateur', 'Rôle', 'Institution', 'Statut'],
            flex: const [184, 135, 160, 150],
            minWidth: 560,
            rows: [
              for (final a in d.accounts)
                [OpsCell(a.$1, strong: true), OpsCell(a.$2), OpsCell(a.$3), OpsBadge(a.$4, tone: opsToneOf(a.$5))],
            ],
          ),
          right: OpsSettingsCard(
            items: [
              for (final (i, p) in d.permissions.indexed)
                (
                  null,
                  p.$1,
                  p.$2,
                  OpsSwitch(
                    value: granted[i],
                    label: p.$1,
                    onChanged: (v) => setState(() => granted[i] = v),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
