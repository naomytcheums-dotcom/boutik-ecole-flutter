import '../../common/common.dart';
import '../s262_accueil_b2b/web_blocks.dart';

/// 267 · Boutik-École Network (portail du réseau des établissements).
class ReseauScreen extends ConsumerWidget {
  const ReseauScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(nouveauxDataProvider);
    return WebShell(
      title: 'Boutik-École Network',
      subtitle: 'Portail du réseau des établissements.',
      navItems: adminNav([
        ('Réseau', AppIcons.globe, '267'),
        ('Établissements', AppIcons.userCheck, '128'),
        ('Catalogue national', AppIcons.fileText, '270'),
        ('Défis intercampus', AppIcons.chartColumn, '168'),
      ]),
      selected: 0,
      children: [
        TwoColumns(
          flex: (7, 8),
          left: AppCard(
            padding: const EdgeInsets.all(24),
            child: AspectRatio(
              aspectRatio: 350 / 445,
              child: Image.asset(Photos.mapCameroon, fit: BoxFit.contain, semanticLabel: 'Carte des établissements du réseau au Cameroun'),
            ),
          ),
          right: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final i in d.institutions) ...[
                AppCard(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(i.title, style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(i.detail, style: AppText.small),
                          ],
                        ),
                      ),
                      StatusBadge(i.status, tone: toneToBadge(i.tone)),
                    ],
                  ),
                ),
                gap12,
              ],
              KpiGrid(d.networkKpis),
              gap24,
              Text('Chaque établissement choisit les contenus qu’il partage dans le catalogue national.', style: AppText.small),
            ],
          ),
        ),
      ],
    );
  }
}
