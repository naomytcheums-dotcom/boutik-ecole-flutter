import '../x_widgets.dart';

/// 190 · Devis et négociations (web) : onglets d'état et tableau des devis.
class DevisNegociationsWebScreen extends ConsumerStatefulWidget {
  const DevisNegociationsWebScreen({super.key});

  @override
  ConsumerState<DevisNegociationsWebScreen> createState() => _DevisNegociationsWebScreenState();
}

class _DevisNegociationsWebScreenState extends ConsumerState<DevisNegociationsWebScreen> {
  int _tab = 0;

  static const _empty = ['Aucun devis en cours.', 'Aucun devis accepté.', 'Aucun devis refusé.'];

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionXDataProvider);
    final rows = d.quotes.where(
      (q) => switch (_tab) {
        1 => q.tone == Tone.success,
        2 => q.tab == 2,
        _ => q.tab != 2,
      },
    );
    return XCompanyShell(
      title: 'Devis et négociations',
      selected: 4,
      children: [
        OpsTabs(
          labels: const ['En cours', 'Acceptés', 'Refusés'],
          selected: _tab,
          onSelected: (i) => setState(() => _tab = i),
        ),
        const SizedBox(height: 18),
        OpsTable(
          columns: const ['Devis', 'Prestataire', 'Montant (FCFA)', 'Mis à jour', 'Statut'],
          flex: const [21, 17, 14, 11, 15],
          emptyLabel: _empty[_tab],
          rows: [
            for (final q in rows)
              [
                OpsCell(q.reference, strong: true),
                OpsCell(q.provider),
                OpsCell(fcfa(q.amount, withUnit: false)),
                OpsCell(q.updated),
                OpsBadge(q.status, tone: xToneOf(q.tone), minWidth: 62),
              ],
          ],
        ),
      ],
    );
  }
}
