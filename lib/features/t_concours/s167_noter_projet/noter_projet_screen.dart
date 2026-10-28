import '../t_widgets.dart';

/// 167 · Noter un projet (jury).
class NoterProjetScreen extends ConsumerStatefulWidget {
  const NoterProjetScreen({super.key});

  @override
  ConsumerState<NoterProjetScreen> createState() => _NoterProjetScreenState();
}

class _NoterProjetScreenState extends ConsumerState<NoterProjetScreen> {
  late final _scores = [for (final c in ref.read(sectionTDataProvider).criteria) c.$2.toDouble()];

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionTDataProvider);
    final total = _scores.fold<double>(0, (s, v) => s + v).round();
    return GPage(
      title: 'Noter : ${d.evaluated.$1}',
      actions: [
        GOutlineButton('Enregistrer', onPressed: () => context.toast('Note enregistrée (brouillon).')),
        PrimaryButton(
          label: 'Valider la note',
          height: 54,
          onPressed: () => context.toast('Note validée : $total / 40.'),
        ),
      ],
      children: [
        AppCard(
          padding: const EdgeInsets.all(10),
          child: GThumbRow(image: d.evaluated.$3, title: d.evaluated.$1, subtitle: d.evaluated.$2),
        ),
        gap12,
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Column(
            children: [
              for (final (i, c) in d.criteria.indexed) ...[
                Row(
                  children: [
                    Expanded(child: Text(c.$1, style: AppText.body.copyWith(fontSize: 13.5))),
                    Text('${_scores[i].round()} / 10', style: AppText.small.copyWith(color: AppColors.ink)),
                    const SizedBox(width: 8),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Color(c.$3),
                    inactiveTrackColor: const Color(0xFFE9E6F2),
                    thumbColor: Color(c.$3),
                    trackHeight: 5,
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                  ),
                  child: Slider(
                    value: _scores[i],
                    max: 10,
                    divisions: 10,
                    label: '${_scores[i].round()}',
                    semanticFormatterCallback: (v) => '${c.$1} : ${v.round()} sur 10',
                    onChanged: (v) => setState(() => _scores[i] = v),
                  ),
                ),
              ],
            ],
          ),
        ),
        gap12,
        KeyValueCard(
          title: 'Synthèse',
          rowGap: 14,
          rows: [KV('Note totale', '$total / 40'), KV('Rang provisoire', d.provisionalRank)],
        ),
        gap12,
        const TextFieldWithError(label: 'Commentaire du jury', hint: 'Points forts et axes d’amélioration…', maxLines: 3),
      ],
    );
  }
}
