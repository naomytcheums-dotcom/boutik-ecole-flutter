import '../l_widgets.dart';

/// 111 · Validation des projets.
class ValidationProjetsScreen extends ConsumerStatefulWidget {
  const ValidationProjetsScreen({super.key});

  @override
  ConsumerState<ValidationProjetsScreen> createState() => _ValidationProjetsScreenState();
}

class _ValidationProjetsScreenState extends ConsumerState<ValidationProjetsScreen> {
  final _decisions = <String, (String, Tone)>{};

  Future<void> _decide(String project) async {
    final choice = await showDialog<(String, Tone)>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text(project),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(c, ('Validé', Tone.success)), child: const Text('Valider')),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(c, ('À corriger', Tone.error)),
            child: const Text('Demander une correction'),
          ),
        ],
      ),
    );
    if (choice != null) setState(() => _decisions[project] = choice);
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionLDataProvider);
    return LDepartmentShell(
      title: 'Validation des projets',
      selected: 3,
      children: [
        OpsKpiRow(lKpis(d.projectKpis)),
        gap16,
        OpsTable(
          columns: const ['Projet', 'Équipe', 'Stade', 'Avancement', 'Décision'],
          flex: const [3, 2, 2, 2, 2],
          rows: [
            for (final p in d.projects)
              [
                OpsCell(p.$1, strong: true),
                OpsCell(p.$2),
                OpsCell(p.$3),
                OpsCell('${p.$4} %'),
                Builder(
                  builder: (_) {
                    final (label, tone) = _decisions[p.$1] ?? (p.$5, p.$6);
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: OpsBadge(
                        label,
                        tone: opsToneOf(tone),
                        onTap: label == 'À valider' ? () => _decide(p.$1) : null,
                      ),
                    );
                  },
                ),
              ],
          ],
        ),
      ],
    );
  }
}
