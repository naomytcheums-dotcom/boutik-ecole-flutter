import '../k_widgets.dart';

/// 237 · Impact par territoire (web) : carte, indicateurs, régions actives, focus ville.
class ImpactTerritoireScreen extends ConsumerStatefulWidget {
  const ImpactTerritoireScreen({super.key});

  @override
  ConsumerState<ImpactTerritoireScreen> createState() => _ImpactTerritoireScreenState();
}

class _ImpactTerritoireScreenState extends ConsumerState<ImpactTerritoireScreen> {
  int _tab = 0;

  static const _nav = [
    ('Tableau de bord', AppIcons.layoutGrid, '238'),
    ('Impact territorial', AppIcons.mapPin, '237'),
    ('Étudiants', AppIcons.users, '70'),
    ('Missions', AppIcons.layers, '191'),
    ('Revenus', AppIcons.wallet, '66'),
    ('Statistiques', AppIcons.chartColumn, '67'),
    ('Paramètres', AppIcons.settings, '148-1'),
  ];

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionKDataProvider);
    final maxRegion = d.activeRegions.first.$2;
    Widget sidebar() => Container(
      width: 200,
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 20),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .7), borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.only(left: 4), child: BrandMark(size: 26, withName: true, web: true)),
          const SizedBox(height: 30),
          for (final (i, n) in _nav.indexed)
            Semantics(
              button: true,
              selected: i == 1,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.goScreen(n.$3),
                child: Container(
                  height: 46,
                  margin: const EdgeInsets.only(bottom: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: i == 1 ? const Color(0xFFF6F4F8) : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      AppIcon(n.$2, size: 18),
                      const SizedBox(width: 14),
                      Text(n.$1, style: AppText.body.copyWith(fontWeight: i == 1 ? FontWeight.w600 : FontWeight.w400)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    final right = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final (i, k) in d.territoryKpis.indexed) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppIcon(k.$3, size: 16),
                      const SizedBox(height: 18),
                      Text(k.$1, style: AppText.h2.copyWith(fontWeight: FontWeight.w700)),
                      Text(k.$2, style: AppText.small.copyWith(fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        gap12,
        AppCard(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Régions les plus actives', style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w600)),
              gap12,
              for (final (i, r) in d.activeRegions.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(width: 24, child: Text('${i + 1}', style: AppText.small)),
                      SizedBox(width: 110, child: Text(r.$1, style: AppText.body)),
                      Expanded(child: ProgressLine(value: r.$2 / maxRegion * .95, height: 6)),
                      SizedBox(width: 44, child: Text('${r.$2}', textAlign: TextAlign.end, style: AppText.bodyStrong)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        gap12,
        SizedBox(
          height: 200,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.asset(d.focusImage, width: 150, fit: BoxFit.cover),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.focusCity.$1, style: AppText.h2.copyWith(fontWeight: FontWeight.w600)),
                      Text(d.focusCity.$2, style: AppText.small),
                      const SizedBox(height: 14),
                      Text(d.focusCity.$3, style: AppText.body.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600)),
                      Text(d.focusCity.$4, style: AppText.body),
                      Text(d.focusCity.$5, style: AppText.body),
                      const Spacer(),
                      PrimaryButton(label: 'Voir la région', height: 40, onPressed: () => context.openScreen('238')),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final map = AppCard(
      padding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          Center(
            child: Semantics(
              image: true,
              label: 'Carte du Cameroun colorée selon l’impact par région',
              child: Image.asset(d.territoryMap, height: 560, fit: BoxFit.contain),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Impact', style: AppText.small.copyWith(color: AppColors.ink)),
              const SizedBox(height: 6),
              SizedBox(
                width: 150,
                child: Row(
                  children: [
                    for (final c in const [0xFFE7E0FA, 0xFFCDBEF5, 0xFFA48DEF, 0xFF6A4DF0])
                      Expanded(child: Container(height: 8, color: Color(c))),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 150,
                child: Row(
                  children: [
                    Text('faible', style: AppText.small.copyWith(fontSize: 11)),
                    const Spacer(),
                    Text('fort', style: AppText.small.copyWith(fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Theme(
      data: AppTheme.light(web: true),
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFBF2DC), Color(0xFFF4EEF6), Color(0xFFEDE6F7)],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 1000;
                final content = ListView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  children: [
                    Semantics(
                      header: true,
                      child: Text('Impact par territoire', style: AppText.h1.copyWith(fontWeight: FontWeight.w600)),
                    ),
                    Text('Où les talents de l’IUT créent de la valeur, région par région.', style: AppText.secondary),
                    gap16,
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final (i, t) in d.territoryTabs.indexed)
                          Pill(t, selected: i == _tab, onTap: () => setState(() => _tab = i)),
                        if (wide) const SizedBox(width: 280),
                        Pill(d.territoryMonth),
                      ],
                    ),
                    gap16,
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 56, child: SizedBox(height: 600, child: map)),
                          const SizedBox(width: 18),
                          Expanded(flex: 37, child: right),
                        ],
                      )
                    else ...[
                      SizedBox(height: 460, child: map),
                      gap16,
                      right,
                    ],
                    const SizedBox(height: 8),
                    Text('Données de démonstration', style: AppText.small.copyWith(fontSize: 11)),
                  ],
                );
                return Padding(
                  padding: EdgeInsets.all(wide ? 24 : 0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .45),
                      borderRadius: BorderRadius.circular(wide ? 30 : 0),
                    ),
                    padding: EdgeInsets.all(wide ? 16 : 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (wide) sidebar(),
                        Expanded(child: content),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
