import '../aa_widgets.dart';

/// 207 · Explorer sur la borne : recherche, filtres par type, grille d'articles (photo puis texte dessous).
class ExplorerBorneScreen extends ConsumerStatefulWidget {
  const ExplorerBorneScreen({super.key});

  @override
  ConsumerState<ExplorerBorneScreen> createState() => _ExplorerBorneScreenState();
}

class _ExplorerBorneScreenState extends ConsumerState<ExplorerBorneScreen> {
  static const _kinds = [null, 'Produits', 'Services', 'Missions'];
  int _tab = 0;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(sectionAADataProvider).products;
    final q = _query.trim().toLowerCase();
    final items = [
      for (final p in all)
        if ((_kinds[_tab] == null || p.kind == _kinds[_tab]) && (q.isEmpty || p.name.toLowerCase().contains(q))) p,
    ];
    return AAPage(
      navIndex: 1,
      builder: (context, l, lang) {
        final tabs = [l.kioskTabAll, l.kioskTabProducts, l.kioskTabServices, l.kioskTabMissions];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 36),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KioskScaffold.padding),
              child: _KioskSearch(hint: l.kioskSearchHint, onChanged: (v) => setState(() => _query = v)),
            ),
            const SizedBox(height: 26),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: KioskScaffold.padding),
                itemCount: tabs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (_, i) =>
                    KioskPill(label: tabs[i], selected: i == _tab, onTap: () => setState(() => _tab = i)),
              ),
            ),
            const SizedBox(height: 28),
            Expanded(
              child: items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: Text(
                        l.kioskEmpty,
                        textAlign: TextAlign.center,
                        style: AppText.body.copyWith(fontSize: 22, color: AppColors.textSecondary),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(KioskScaffold.padding, 0, KioskScaffold.padding, 24),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 24,
                        mainAxisExtent: 356,
                      ),
                      itemCount: items.length,
                      itemBuilder: (_, i) => _KioskProductTile(
                        product: items[i],
                        boosted: l.kioskBoosted,
                        lang: lang,
                        onTap: () {
                          ref.read(kioskSelectionProvider.notifier).select(items[i].id);
                          context.openScreen('208');
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _KioskSearch extends StatelessWidget {
  const _KioskSearch({required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      padding: const EdgeInsets.only(left: 32, right: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .7),
        borderRadius: BorderRadius.circular(41),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 20, offset: Offset(0, 6))],
      ),
      child: Row(
        children: [
          const AppIcon(AppIcons.search, size: 28, color: AppColors.ink),
          const SizedBox(width: 20),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              style: AppText.body.copyWith(fontSize: 23),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: AppText.body.copyWith(fontSize: 23, color: AppColors.textSecondary),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: hint,
            child: Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(color: AppColors.ink, shape: BoxShape.circle),
            ),
          ),
        ],
      ),
    );
  }
}

class _KioskProductTile extends StatelessWidget {
  const _KioskProductTile({required this.product, required this.boosted, required this.lang, required this.onTap});

  final KioskProduct product;
  final String boosted;
  final String lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final price = fcfaLocalized(product.price, lang);
    return Semantics(
      button: true,
      label: '${product.name}, ${product.category}, $price',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 230,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset(product.image, fit: BoxFit.cover),
                  ),
                  if (product.boosted) Positioned(left: 14, top: 14, child: KioskBoostBadge(boosted)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 114,
              padding: const EdgeInsets.fromLTRB(22, 14, 18, 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body.copyWith(fontSize: 20.5, fontWeight: FontWeight.w500),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.category,
                          style: AppText.small.copyWith(fontSize: 15, color: AppColors.textSecondary),
                        ),
                      ),
                      const KioskStars(size: 17, gap: 6),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    price,
                    style: AppText.body.copyWith(fontSize: 21, fontWeight: FontWeight.w700, color: AppColors.accent),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
