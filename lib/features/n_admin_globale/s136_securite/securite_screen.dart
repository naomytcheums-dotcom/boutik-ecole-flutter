import '../../common/common.dart';
import '../../../data/demo/section_n_demo.dart';
import '../n_widgets.dart';

/// 136 · Sécurité et accès (règles + sessions actives).
class SecuriteScreen extends ConsumerStatefulWidget {
  const SecuriteScreen({super.key});

  @override
  ConsumerState<SecuriteScreen> createState() => _SecuriteScreenState();
}

class _SecuriteScreenState extends ConsumerState<SecuriteScreen> {
  List<bool>? _on;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionNDataProvider);
    final on = _on ??= [for (final r in d.securityRules) r.$3];
    return NAdminShell(
      title: 'Sécurité et accès',
      selected: 9,
      children: [
        OpsSplit(
          left: OpsSettingsCard(
            items: [
              for (final (i, r) in d.securityRules.indexed)
                (null, r.$1, r.$2, OpsSwitch(value: on[i], label: r.$1, onChanged: (v) => setState(() => on[i] = v))),
            ],
          ),
          right: OpsTable(
            columns: const ['Utilisateur', 'Appareil', 'Dernière activité'],
            flex: const [163, 154, 150],
            minWidth: 420,
            rows: [
              for (final s in d.sessions) [OpsCell(s.$1, strong: true), OpsCell(s.$2), OpsCell(s.$3)],
            ],
          ),
        ),
      ],
    );
  }
}
