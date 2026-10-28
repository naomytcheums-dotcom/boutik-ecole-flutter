import '../../common/common.dart';
import '../s262_accueil_b2b/web_blocks.dart';

/// 266 · État technique (disponibilité des services, sauvegardes, restauration).
class EtatTechniqueScreen extends ConsumerWidget {
  const EtatTechniqueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(nouveauxDataProvider);
    return WebShell(
      title: 'État technique',
      subtitle: 'Disponibilité des services et sauvegardes.',
      navItems: adminNav([
        ('Tableau de bord', AppIcons.layoutGrid, '127'),
        ('État technique', AppIcons.server, '266'),
        ('Sauvegardes', AppIcons.hardDrive, null),
        ('Journal', AppIcons.fileText, '137'),
      ]),
      selected: 1,
      children: [
        KpiGrid(d.uptime),
        gap16,
        TwoColumns(
          flex: (3, 2),
          left: WebTable(
            title: 'Sauvegardes',
            columns: const ['Sauvegarde', 'Date', 'Taille', 'Test de restauration'],
            flex: const [3, 2, 2, 2],
            rows: [for (final b in d.backups) [Cell(b.$1, strong: true), Cell(b.$2), Cell(b.$3), Cell(b.$4)]],
          ),
          right: WebPanel(
            title: 'Restaurer une sauvegarde',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Choisir un point de restauration, vérifier puis confirmer. L’action est journalisée.', style: AppText.secondary),
                const SizedBox(height: 32),
                PrimaryButton(
                  label: 'Lancer la restauration',
                  expand: false,
                  height: 44,
                  onPressed: () => context.toast('Restauration simulée (démonstration).'),
                ),
              ],
            ),
          ),
        ),
        gap24,
        Text(d.platformVersion, style: AppText.small),
      ],
    );
  }
}
