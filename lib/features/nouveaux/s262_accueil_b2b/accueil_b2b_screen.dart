import '../../common/common.dart';
import 'web_blocks.dart';

/// 262 · Accueil B2B (portail entreprises, web 1280).
class AccueilB2bScreen extends ConsumerWidget {
  const AccueilB2bScreen({super.key});

  static final nav = adminNav([
    ('Accueil B2B', AppIcons.layoutGrid, '262'),
    ('Besoins publiés', AppIcons.fileText, '188'),
    ('Recherche de talents', AppIcons.userCheck, '189'),
    ('Propositions', AppIcons.userCheck, '190'),
    ('Devis', AppIcons.fileText, '95'),
    ('Collaborations', AppIcons.userCheck, '285'),
  ]);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(nouveauxDataProvider);
    final talents = ref.watch(catalogRepositoryProvider).talents();
    return WebShell(
      title: 'Accueil B2B',
      subtitle: 'Trouvez des talents, publiez un besoin, lancez un défi.',
      navItems: nav,
      selected: 0,
      children: [
        TwoColumns(
          flex: (13, 10),
          left: Container(
            height: 290,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            decoration: BoxDecoration(gradient: AppColors.sunGradient, borderRadius: BorderRadius.circular(28)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: ShapeDecoration(color: Colors.white, shape: const StadiumBorder()),
                  child: Text('Analytique · données en direct', style: AppText.small.copyWith(color: AppColors.ink)),
                ),
                const Spacer(),
                Text(
                  'Trouvez les bons talents\nde l’IUT de Douala.',
                  style: AppText.display.copyWith(fontWeight: FontWeight.w400, fontSize: 34),
                ),
              ],
            ),
          ),
          right: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DarkCard(
                onTap: () => context.openScreen('188'),
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Publier un besoin', style: AppText.h1.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                    gap8,
                    Text('Décrivez votre projet, les équipes vous répondent.', style: AppText.body.copyWith(color: Colors.white)),
                  ],
                ),
              ),
              gap16,
              AppCard(
                padding: const EdgeInsets.fromLTRB(28, 22, 28, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lancer un défi d’innovation', style: AppText.h2.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text('Plusieurs équipes proposent une solution.', style: AppText.secondary),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => context.openScreen('168'),
                        child: const StatusBadge('Ouvrir', tone: BadgeTone.accent),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        gap16,
        KpiGrid(d.b2bKpis),
        gap24,
        Text('Talents recommandés', style: AppText.h3.copyWith(fontWeight: FontWeight.w600)),
        gap12,
        ResponsiveGrid(
          columns: 3,
          minItemWidth: 240,
          children: [
            for (final t in talents)
              AppCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(width: 56, child: PhotoTile(image: t.image, radius: 16, semanticLabel: t.name)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.name, style: AppText.h3.copyWith(fontWeight: FontWeight.w600)),
                              Text(t.speciality, style: AppText.secondary),
                            ],
                          ),
                        ),
                      ],
                    ),
                    gap16,
                    Row(
                      children: [
                        StatusBadge('Compatibilité ${t.match} %', tone: BadgeTone.success),
                        const Spacer(),
                        PrimaryButton(label: 'Voir le profil', expand: false, height: 40, onPressed: () => context.openScreen('72')),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
        gap24,
        WebTable(
          title: 'Défis ouverts',
          columns: const ['Défi', 'Équipes', 'Échéance', 'Statut'],
          flex: const [5, 2, 2, 2],
          rows: [
            for (final c in d.openChallenges) [Cell(c.$1, strong: true), Cell(c.$2), Cell(c.$3), Cell(c.$4)],
          ],
        ),
      ],
    );
  }
}
