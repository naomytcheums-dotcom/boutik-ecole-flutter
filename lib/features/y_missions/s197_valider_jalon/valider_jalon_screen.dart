import '../y_widgets.dart';

/// 197 · Valider le jalon : le client examine la preuve et libère le paiement du jalon.
class ValiderJalonScreen extends ConsumerStatefulWidget {
  const ValiderJalonScreen({super.key});

  @override
  ConsumerState<ValiderJalonScreen> createState() => _ValiderJalonScreenState();
}

class _ValiderJalonScreenState extends ConsumerState<ValiderJalonScreen> {
  bool _released = false;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionYDataProvider);
    final (title, subtitle) = d.reviewTitle;
    final split = splitPayment(d.reviewAmount);
    return GPage(
      title: 'Valider le jalon ${d.reviewMilestone}',
      actions: [
        YOutlineButton(
          'Demander une correction',
          onPressed: () => context.toast('Demande de correction envoyée : le paiement reste bloqué.'),
        ),
        PrimaryButton(
          label: _released ? 'Paiement libéré' : 'Valider et libérer',
          onPressed: _released
              ? null
              : () {
                  setState(() => _released = true);
                  context.toast('Jalon ${d.reviewMilestone} validé : ${fcfa(d.reviewAmount)} libérés.');
                },
        ),
      ],
      children: [
        YHero(image: d.reviewHero, title: title, subtitle: subtitle),
        const SizedBox(height: 14),
        Row(
          children: [
            for (final (i, p) in d.quotePhotos.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(p, height: 84, fit: BoxFit.cover, semanticLabel: 'Preuve ${i + 1}'),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        YKvCard(
          title: 'Libération du paiement',
          rows: [
            ('Jalon', '${d.reviewMilestone} sur ${d.reviewMilestoneCount}'),
            ('Montant à libérer', fcfa(d.reviewAmount)),
            ('Part étudiants (70 %)', fcfa(split.seller)),
            ('Fonds innovation (20 %)', fcfa(split.institution)),
            ('Plateforme (10 %)', fcfa(split.platform)),
          ],
        ),
        const SizedBox(height: 14),
        const YNote(
          'Vous pouvez demander une correction : le paiement reste bloqué tant que vous n’avez pas validé.',
          icon: AppIcons.shieldCheck,
        ),
      ],
    );
  }
}
