import '../../common/common.dart';
import '../../../data/demo/section_n_demo.dart';
import '../n_widgets.dart';

/// 138 · Configuration générale (modules activables, intégrations).
class ConfigurationScreen extends ConsumerStatefulWidget {
  const ConfigurationScreen({super.key});

  @override
  ConsumerState<ConfigurationScreen> createState() => _ConfigurationScreenState();
}

class _ConfigurationScreenState extends ConsumerState<ConfigurationScreen> {
  List<bool>? _on;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionNDataProvider);
    final on = _on ??= [for (final m in d.modules) m.$3];
    return NAdminShell(
      title: 'Configuration générale',
      selected: 11,
      children: [
        OpsSplit(
          left: OpsSettingsCard(
            items: [
              for (final (i, m) in d.modules.indexed)
                (null, m.$1, m.$2, OpsSwitch(value: on[i], label: m.$1, onChanged: (v) => setState(() => on[i] = v))),
            ],
          ),
          right: OpsSettingsCard(
            items: [for (final g in d.integrations) (g.$1, g.$2, g.$3, OpsBadge(g.$4, tone: opsToneOf(g.$5)))],
          ),
        ),
        const SizedBox(height: 18),
        OpsInfoNote(d.configNote),
      ],
    );
  }
}
