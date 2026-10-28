import '../o_widgets.dart';

/// 141 · Journal financier et rapprochement.
class JournalFinancierScreen extends ConsumerWidget {
  const JournalFinancierScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionODataProvider);
    final credits = d.journal.fold(0, (s, l) => s + l.$4);
    final debits = d.journal.fold(0, (s, l) => s + l.$3);
    final pending = d.journal.where((l) => !l.$5).length;
    return OFinanceShell(
      title: 'Journal financier',
      selected: 2,
      children: [
        OpsSplit(
          flex: (3, 2),
          left: OpsTable(
            columns: const ['Date', 'Libellé', 'Débit', 'Crédit', 'Rapproché'],
            flex: const [2, 4, 2, 2, 2],
            minWidth: 520,
            rows: [
              for (final l in d.journal)
                [
                  OpsCell(l.$1, strong: true),
                  OpsCell(l.$2),
                  OpsCell(l.$3 == 0 ? '—' : fcfa(l.$3, withUnit: false)),
                  OpsCell(l.$4 == 0 ? '—' : fcfa(l.$4, withUnit: false)),
                  lBadge(l.$5 ? 'Oui' : 'Non', l.$5 ? Tone.success : Tone.neutral),
                ],
            ],
          ),
          right: OpsKvCard(
            title: 'Synthèse',
            rows: [
              ('Total crédits', fcfa(credits)),
              ('Total débits', fcfa(debits)),
              ('Solde', fcfa(credits - debits)),
              ('Lignes à rapprocher', '$pending'),
            ],
          ),
        ),
      ],
    );
  }
}
