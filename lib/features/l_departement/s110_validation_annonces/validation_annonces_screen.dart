import '../l_widgets.dart';

/// 110 · Validation des annonces.
class ValidationAnnoncesScreen extends ConsumerStatefulWidget {
  const ValidationAnnoncesScreen({super.key});

  @override
  ConsumerState<ValidationAnnoncesScreen> createState() => _ValidationAnnoncesScreenState();
}

class _ValidationAnnoncesScreenState extends ConsumerState<ValidationAnnoncesScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionLDataProvider);
    return LDepartmentShell(
      title: 'Validation des annonces',
      selected: 2,
      children: [
        OpsTabs(labels: d.listingTabs, selected: _tab, onSelected: (i) => setState(() => _tab = i)),
        gap16,
        OpsTable(
          columns: const ['Annonce', 'Vendeur', 'Catégorie', 'Prix (FCFA)', 'Soumise', 'Action'],
          flex: const [3, 3, 2, 2, 2, 2],
          emptyLabel: 'Aucune annonce dans cet onglet.',
          rows: [
            if (_tab == 0)
              for (final l in d.listingsToValidate)
                [
                  OpsCell(l.$1, strong: true),
                  OpsCell(l.$2),
                  OpsCell(l.$3),
                  OpsCell(fcfa(l.$4, withUnit: false)),
                  OpsCell(l.$5),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OpsBadge('Examiner', tone: OpsTone.info, onTap: () => context.openScreen('256')),
                  ),
                ],
          ],
        ),
        gap16,
        OpsSplit(
          left: OpsKvCard(title: 'Indicateurs de validation', rows: d.validationIndicators),
          right: const OpsInfoNote('Une annonce refusée doit toujours comporter un motif consultable par l’étudiant.'),
        ),
      ],
    );
  }
}
