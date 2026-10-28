import '../y_web.dart';

const _subColor = Color(0xFF3D4A6B);

/// 199 · Attribuer (web admin) : détail du brief et choix des étudiants qualifiés.
class AttribuerScreen extends ConsumerStatefulWidget {
  const AttribuerScreen({super.key});

  @override
  ConsumerState<AttribuerScreen> createState() => _AttribuerScreenState();
}

class _AttribuerScreenState extends ConsumerState<AttribuerScreen> {
  late final Set<int> _selected = {...ref.read(sectionYDataProvider).preselected};

  void _assign() {
    if (_selected.isEmpty) {
      context.toast('Sélectionnez au moins un étudiant.');
      return;
    }
    context.toast('Mission attribuée à une équipe de ${_selected.length} étudiants.');
    context.openScreen('200');
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionYDataProvider);
    final (client, need) = d.assignBrief;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(client, style: AppText.h3.copyWith(fontSize: 17)),
        const SizedBox(height: 6),
        Text(need, style: AppText.body.copyWith(fontSize: 13.5, color: _subColor)),
        const SizedBox(height: 12),
        for (final (i, (l, v)) in d.assignRows.indexed) ...[
          if (i > 0) const Divider(height: 1, thickness: 1, color: yDivider),
          Semantics(
            label: '$l : $v',
            excludeSemantics: true,
            child: SizedBox(
              height: 34,
              child: Row(
                children: [
                  Expanded(child: Text(l, style: AppText.secondary.copyWith(fontSize: 13))),
                  Text(v, style: AppText.label.copyWith(fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          decoration: BoxDecoration(color: const Color(0xFFEFEDF5), borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const AppIcon(AppIcons.sparkle, size: 18),
                  const SizedBox(width: 10),
                  Text('Suggestion', style: AppText.label.copyWith(fontSize: 13.5)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                d.assignSuggestion,
                style: AppText.small.copyWith(fontSize: 12.5, height: 1.5, color: const Color(0xFF4A4752)),
              ),
            ],
          ),
        ),
      ],
    );
    final button = PrimaryButton(label: 'Attribuer à cette équipe', height: 50, onPressed: _assign);
    final candidates = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text('Étudiants qualifiés', style: AppText.h3.copyWith(fontSize: 16))),
        const SizedBox(height: 16),
        for (final (i, c) in d.candidates.indexed) ...[
          if (i > 0) const SizedBox(height: 14),
          _CandidateCard(
            candidate: c,
            selected: _selected.contains(i),
            onToggle: () => setState(() => _selected.contains(i) ? _selected.remove(i) : _selected.add(i)),
          ),
        ],
      ],
    );
    return YAdminShell(
      title: 'Attribuer : Identité visuelle · $client',
      selected: 2,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            if (c.maxWidth < 900) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [details, const SizedBox(height: 16), button, const SizedBox(height: 24), candidates],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: (c.maxWidth - 32) * .366,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16, top: 0),
                    child: SizedBox(
                      height: 676,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [const SizedBox(height: 176), details, const Spacer(), button],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(child: candidates),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.candidate, required this.selected, required this.onToggle});

  final (String, String, String, int, bool, int) candidate;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final (name, track, rating, works, available, score) = candidate;
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: AppText.h3.copyWith(fontSize: 16)),
        const SizedBox(height: 4),
        Text(track, style: AppText.body.copyWith(fontSize: 13, color: _subColor)),
        const SizedBox(height: 6),
        Text('Note $rating · $works réalisations certifiées', style: AppText.small.copyWith(fontSize: 12.5)),
        const SizedBox(height: 5),
        YWebBadge(available ? 'Disponible' : 'Occupé', tone: available ? Tone.success : Tone.warning),
      ],
    );
    final side = SizedBox(
      width: 187,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Padding(padding: const EdgeInsets.only(right: 43), child: YProgress(score / 100)),
          const SizedBox(height: 8),
          Text('Score $score', style: AppText.label.copyWith(fontSize: 12.5)),
          const Spacer(),
          Align(
            alignment: Alignment.centerRight,
            child: YWebButton(selected ? 'Sélectionné' : 'Choisir', width: 84 + 20, dark: selected, onTap: onToggle),
          ),
        ],
      ),
    );
    return Semantics(
      label: '$name, score $score${selected ? ', sélectionné' : ''}',
      child: YWebCard(
        padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
        child: LayoutBuilder(
          builder: (context, c) => c.maxWidth < 480
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    info,
                    const SizedBox(height: 10),
                    SizedBox(height: 90, child: side),
                  ],
                )
              : SizedBox(
                  height: 92,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(width: 107),
                      Expanded(child: info),
                      side,
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
