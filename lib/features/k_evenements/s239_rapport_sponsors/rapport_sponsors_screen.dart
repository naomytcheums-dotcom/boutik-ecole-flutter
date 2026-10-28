import '../k_widgets.dart';

/// 239 · Rapport sponsors (web, espace partenaire).
class RapportSponsorsScreen extends ConsumerWidget {
  const RapportSponsorsScreen({super.key});

  static const nav = [
    WebNavItem('Carte d’impact', AppIcons.globe, target: '237'),
    WebNavItem('Indicateurs', AppIcons.chartColumn, target: '238'),
    WebNavItem('Étudiants', AppIcons.users, target: '70'),
    WebNavItem('Revenus redistribués', AppIcons.wallet, target: '284'),
    WebNavItem('Rapports sponsors', AppIcons.fileText, target: '239', section: 'Gestion'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionKDataProvider);
    const orange = Color(0xFFB45F06);
    return WebShell(
      title: 'Rapport sponsors · T3 2026',
      subtitle: 'Vue d’ensemble · mise à jour aujourd’hui',
      navItems: nav,
      selected: 4,
      accountName: 'Partenaire',
      accountSubtitle: 'Impact et partenaires',
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
          child: Wrap(
            spacing: 40,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${d.sponsorName} a contribué à', style: AppText.secondary),
                    const SizedBox(height: 6),
                    Text(fcfa(d.sponsorAmount), style: AppText.display.copyWith(fontSize: 30, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text('en sponsoring du concours et de 4 projets étudiants', style: AppText.secondary),
                  ],
                ),
              ),
              for (final k in d.sponsorKpis)
                SizedBox(
                  width: 120,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(k.$1, style: AppText.display.copyWith(fontSize: 30, color: orange, fontWeight: FontWeight.w600)),
                      Text(k.$2, style: AppText.secondary),
                    ],
                  ),
                ),
            ],
          ),
        ),
        gap16,
        WebTable(
          columns: const ['Projet sponsorisé', 'Département', 'Montant (FCFA)', 'Étudiants', 'Résultat', 'Statut'],
          flex: const [5, 3, 3, 2, 4, 2],
          rows: [
            for (final s in d.sponsored)
              [
                Cell(s.$1, strong: true),
                Cell(s.$2),
                Cell(fcfa(s.$3, withUnit: false)),
                Cell(s.$4),
                Cell(s.$5),
                Align(
                  alignment: Alignment.centerLeft,
                  child: GBadge(s.$6, s.$6 == 'Terminé' ? Tone.success : Tone.accent),
                ),
              ],
          ],
        ),
      ],
    );
  }
}
