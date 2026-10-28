import '../y_widgets.dart';

/// 192 · Votre devis : suivi de validation du brief et devis proposé.
class VotreDevisScreen extends ConsumerWidget {
  const VotreDevisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionYDataProvider);
    final (title, number, status) = d.brief;
    return GPage(
      title: 'Votre devis',
      actions: [
        YOutlineButton('Poser une question', onPressed: () => context.openScreen('196')),
        PrimaryButton(label: 'Accepter le devis', onPressed: () => context.openScreen('193')),
      ],
      children: [
        YCard(
          children: [
            YIconRow(icon: AppIcons.briefcase, title: title, subtitle: number, trailing: YBadge(status, Tone.success)),
          ],
        ),
        const YTitle('Étapes de validation', top: 14, bottom: 16),
        YVTimeline(steps: [for (final (t, dt, s) in d.validationSteps) YVStep(t, dt, s)]),
        const SizedBox(height: 30),
        YKvCard(
          title: 'Devis',
          rows: [
            ('Livrables', d.quoteDeliverables),
            ('Délai', d.quoteDelay),
            ('Équipe', d.quoteTeam),
            ('Total', fcfa(d.quoteTotal)),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (final (i, p) in d.quotePhotos.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    p,
                    height: 76,
                    fit: BoxFit.cover,
                    semanticLabel: 'Réalisation de l’équipe ${i + 1}',
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
