import '../j_widgets.dart';

/// 93b · Détail d’une proposition reçue.
class PropositionScreen extends ConsumerWidget {
  const PropositionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionJDataProvider);
    final p = d.proposals.first;
    final offer = [
      ('Montant', fcfa(p.price)),
      ('Délai', '${p.days} jours'),
      ('Révisions', '${p.revisions} incluses'),
      ('Début possible', d.proposalStart),
    ];
    return HPage(
      title: 'Proposition',
      actions: [
        _OutlineDanger('Refuser', onPressed: () => context.toast('Proposition refusée.')),
        PrimaryButton(
          label: 'Accepter',
          height: 54,
          onPressed: () {
            context.toast('Proposition de ${p.name} acceptée.');
            context.openScreen('98');
          },
        ),
      ],
      children: [
        const SizedBox(height: 6),
        JPersonCard(
          avatar: d.proposalAvatar,
          name: p.name,
          detail: '${d.proposalField} · ${p.rating} ★',
          action: Semantics(
            button: true,
            child: GestureDetector(
              onTap: () => context.openScreen('74'),
              child: SizedBox(
                height: 44,
                child: Center(
                  child: Container(
                    width: 90,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: const ShapeDecoration(color: jLavender, shape: StadiumBorder()),
                    child: Text(
                      'Voir profil',
                      style: AppText.small.copyWith(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        gap12,
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text('Offre', style: AppText.h3.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 6),
              for (final (i, (k, v)) in offer.indexed) ...[
                if (i > 0) const Divider(height: 1, thickness: 1, color: Color(0xFFE9E7EC)),
                SizedBox(
                  height: 33,
                  child: Row(
                    children: [
                      Expanded(child: Text(k, style: AppText.secondary.copyWith(fontSize: 13))),
                      Text(v, style: AppText.label.copyWith(fontSize: 13, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        gap16,
        Text(d.proposalText, style: AppText.body.copyWith(fontSize: 13.5, height: 1.5, color: const Color(0xFF4A4752))),
        const JSectionTitle('Livrables'),
        JMilestones(d.proposalDeliverables),
      ],
    );
  }
}

/// Bouton blanc bordé de rouge (« Refuser »).
class _OutlineDanger extends StatelessWidget {
  const _OutlineDanger(this.label, {required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: Material(
      color: Colors.white,
      shape: const StadiumBorder(side: BorderSide(color: AppColors.error, width: 1.2)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: SizedBox(
          height: 54,
          child: Center(child: Text(label, style: AppText.button.copyWith(color: AppColors.error))),
        ),
      ),
    ),
  );
}
