import '../am_widgets.dart';

/// 249 · Créer : choix du type de contenu (publication, reel, live, article) et brouillons.
class CreerScreen extends ConsumerWidget {
  const CreerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionAMDataProvider);
    return AppScaffold(
      tab: NavTab.home,
      header: const ScreenHeader(title: 'Créer', subtitle: 'Que veux-tu partager ?', close: true),
      children: [
        const SizedBox(height: 30),
        for (final o in d.createOptions) ...[
          Semantics(
            button: true,
            label: '${o.$1} : ${o.$2}',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () => context.openScreen(o.$4),
              child: AmCard(
                radius: 32,
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
                child: SizedBox(
                  height: 116,
                  child: Row(
                    children: [
                      SizedBox(width: 96, child: Center(child: ChromeIcon(amIcon(o.$3), size: 64))),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(o.$1, style: AppText.h3.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(o.$2, style: AppText.small),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(color: amSoftGrey, shape: BoxShape.circle),
                        child: const AppIcon(AppIcons.chevronRight, size: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          gap12,
        ],
        gap8,
        AmCard(
          color: const Color(0xB3FFFFFF),
          radius: 24,
          padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
          child: Row(
            children: [
              const AppIcon(AppIcons.pencil, size: 18),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Brouillons', style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w600)),
                    Text('${d.draftsCount} publications non terminées', style: AppText.small.copyWith(fontSize: 11)),
                  ],
                ),
              ),
              AmChip('Reprendre', onTap: () => context.openScreen('250')),
            ],
          ),
        ),
      ],
    );
  }
}
