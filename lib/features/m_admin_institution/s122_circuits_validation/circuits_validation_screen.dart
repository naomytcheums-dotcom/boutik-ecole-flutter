import '../m_widgets.dart';

/// 122 · Circuits de validation.
class CircuitsValidationScreen extends ConsumerStatefulWidget {
  const CircuitsValidationScreen({super.key});

  @override
  ConsumerState<CircuitsValidationScreen> createState() => _CircuitsValidationScreenState();
}

class _CircuitsValidationScreenState extends ConsumerState<CircuitsValidationScreen> {
  int _tab = 0;
  late final _rules = [for (final r in ref.read(sectionMDataProvider).circuitRules) r.$3];

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionMDataProvider);
    return MAdminShell(
      title: 'Circuits de validation',
      selected: 5,
      children: [
        OpsTabs(labels: d.circuitTabs, selected: _tab, onSelected: (i) => setState(() => _tab = i)),
        gap16,
        OpsSplit(
          left: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: IMilestones([for (final s in d.circuitSteps) IMilestone(s.$1, s.$2, s.$3)]),
          ),
          right: OpsSettingsCard(
            items: [
              for (final (i, r) in d.circuitRules.indexed)
                (
                  null,
                  r.$1,
                  r.$2,
                  OpsSwitch(value: _rules[i], label: r.$1, onChanged: (v) => setState(() => _rules[i] = v)),
                ),
            ],
          ),
        ),
        gap16,
        const OpsInfoNote(
          'Les délais et seuils sont des paramètres configurables, à confirmer avec l’IUT avant mise en production.',
        ),
      ],
    );
  }
}
