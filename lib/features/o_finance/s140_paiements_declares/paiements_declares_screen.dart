import '../o_widgets.dart';

/// 140 · Paiements déclarés (vérification manuelle).
class PaiementsDeclaresScreen extends ConsumerStatefulWidget {
  const PaiementsDeclaresScreen({super.key});

  @override
  ConsumerState<PaiementsDeclaresScreen> createState() => _PaiementsDeclaresScreenState();
}

class _PaiementsDeclaresScreenState extends ConsumerState<PaiementsDeclaresScreen> {
  int _tab = 0;
  final _verified = <String>{};

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionODataProvider);
    (String, Tone) status(dynamic p) => _verified.contains(p.$1) ? ('Vérifié', Tone.success) : (p.$6 as String, p.$7 as Tone);
    final items = d.declared.where((p) {
      final s = status(p).$1;
      return switch (_tab) {
        1 => s == 'Vérifié',
        2 => s == 'Rejeté',
        _ => true,
      };
    }).toList();
    return OFinanceShell(
      title: 'Paiements déclarés',
      selected: 1,
      children: [
        OpsTabs(labels: d.paymentTabs, selected: _tab, onSelected: (i) => setState(() => _tab = i)),
        gap16,
        OpsTable(
          columns: const ['Référence', 'Commande', 'Moyen', 'Montant (FCFA)', 'Déclaré', 'Statut'],
          flex: const [2, 3, 2, 2, 2, 2],
          emptyLabel: 'Aucun paiement dans cet onglet.',
          rows: [
            for (final p in items)
              [
                OpsCell(p.$1, strong: true),
                OpsCell(p.$2),
                OpsCell(p.$3),
                OpsCell(fcfa(p.$4, withUnit: false)),
                OpsCell(p.$5),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OpsBadge(
                    status(p).$1,
                    tone: opsToneOf(status(p).$2),
                    onTap: status(p).$1 == 'À vérifier' ? () => setState(() => _verified.add(p.$1)) : null,
                  ),
                ),
              ],
          ],
        ),
        gap16,
        const OpsInfoNote(
          'Les paiements déclarés sont vérifiés manuellement tant que l’intégration automatique n’est pas confirmée.',
        ),
      ],
    );
  }
}
