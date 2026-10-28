import '../../../core/utils/validators_ad.dart';
import '../ad_widgets.dart';

/// 219 · Nouveau duel (besoin, nombre de propositions, prix, séquestre).
class NouveauDuelScreen extends ConsumerStatefulWidget {
  const NouveauDuelScreen({super.key});

  @override
  ConsumerState<NouveauDuelScreen> createState() => _NouveauDuelScreenState();
}

class _NouveauDuelScreenState extends ConsumerState<NouveauDuelScreen> {
  final _form = GlobalKey<FormState>();
  int _size = 0;
  int? _prize;
  String? _duration;

  static const _counts = [3, 5, 8];

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionADDataProvider);
    final prize = _prize ?? d.duelPrize;
    final total = prize + d.duelBonus * _counts[_size];
    const gap = SizedBox(height: 14);
    return AdPage(
      header: const AdBackHeader('Nouveau duel'),
      actions: [
        PrimaryButton(
          label: 'Lancer le duel',
          height: 54,
          onPressed: () {
            if (_form.currentState?.validate() ?? false) {
              context.toast('Duel envoyé à la modération : ${fcfa(total)} bloqués en séquestre.');
            }
          },
        ),
      ],
      children: [
        AdStepper(labels: d.duelSteps, current: 1),
        const SizedBox(height: 14),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PillTextField(
                label: 'Votre besoin',
                icon: AppIcons.briefcase,
                initialValue: d.duelNeed,
                validator: ValidatorsAD.need,
              ),
              const SizedBox(height: 18),
              Semantics(
                header: true,
                child: Text(
                  'Combien de propositions ?',
                  style: AppText.h3.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 4),
              AdPills(labels: d.duelSizes, selected: _size, expand: true, onSelected: (i) => setState(() => _size = i)),
              const SizedBox(height: 8),
              PillTextField(
                label: 'Prix pour le gagnant',
                icon: AppIcons.trophy,
                initialValue: fcfa(d.duelPrize),
                keyboardType: TextInputType.number,
                validator: ValidatorsAD.prize,
                onChanged: (v) => setState(() => _prize = int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0),
              ),
              gap,
              PillSelectField(
                label: 'Durée du duel',
                icon: AppIcons.clock,
                options: d.duelDurations,
                value: _duration ?? d.duelDurations[1],
                onChanged: (v) => setState(() => _duration = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        AdKvCard(
          title: 'Paiement',
          rows: [
            ('Prix du gagnant', fcfa(prize)),
            ('Prime de participation (chacun)', fcfa(d.duelBonus)),
            ('Total bloqué en séquestre', fcfa(total)),
          ],
        ),
        const SizedBox(height: 18),
        AdNote(d.duelNote, icon: AppIcons.shieldCheck),
      ],
    );
  }
}
