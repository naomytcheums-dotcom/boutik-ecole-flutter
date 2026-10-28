import '../../l_departement/l_widgets.dart' show lBadge;
import '../u_widgets.dart';

/// 213 · Registre des certificats (web, administration).
class RegistreCertificatsScreen extends ConsumerWidget {
  const RegistreCertificatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionUDataProvider);
    return WebShell(
      title: 'Registre des certificats',
      subtitle: 'Vue d’ensemble · mise à jour aujourd’hui',
      navItems: uAdminNav,
      selected: 7,
      accountName: d.adminName,
      accountSubtitle: d.adminSubtitle,
      children: [
        UKpiBars(d.registryKpis),
        gap16,
        OpsCard(
          child: Column(
            children: [
              OpsTable(
                columns: const ['Identifiant', 'Élément', 'Département', 'Émis le', 'Empreinte', 'Statut'],
                flex: const [3, 6, 3, 3, 4, 2],
                rowHeight: 64,
                rows: [
                  for (final c in d.certificates)
                    [
                      Semantics(
                        button: true,
                        child: GestureDetector(
                          onTap: () => context.openScreen('212'),
                          child: OpsCell(c.$1, strong: true),
                        ),
                      ),
                      OpsCell(c.$2),
                      OpsCell(c.$3),
                      OpsCell(c.$4),
                      OpsCell(c.$5),
                      lBadge(c.$6, c.$7),
                    ],
                ],
              ),
              const SizedBox(height: 110),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 250,
                    child: OpsBigButton(
                      label: 'Émettre un certificat',
                      icon: AppIcons.plus,
                      height: 40,
                      onTap: () => context.toast('Nouveau certificat : choisissez un projet validé.'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
