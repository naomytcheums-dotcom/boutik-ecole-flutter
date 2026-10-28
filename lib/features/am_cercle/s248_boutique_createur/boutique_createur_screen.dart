import '../am_widgets.dart';

/// 248 · Boutique du créateur : produits, services, offres et ajout d'article.
class BoutiqueCreateurScreen extends ConsumerStatefulWidget {
  const BoutiqueCreateurScreen({super.key});

  @override
  ConsumerState<BoutiqueCreateurScreen> createState() => _BoutiqueCreateurScreenState();
}

class _BoutiqueCreateurScreenState extends ConsumerState<BoutiqueCreateurScreen> {
  int _tab = 0;
  final _favorites = <String>{};

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionAMDataProvider);
    final items = switch (_tab) {
      1 => d.shopItems.where((i) => i.tag == 'Service').toList(),
      2 => <AmShopItem>[],
      _ => d.shopItems,
    };
    return AppScaffold(
      tab: NavTab.profile,
      padding: EdgeInsets.zero,
      header: ScreenHeader(
        title: d.shopName,
        subtitle: d.shopMeta,
        actions: [AmHeaderButton(AppIcons.shoppingBag, label: 'Panier', onTap: () => context.openScreen('06'))],
      ),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              for (var i = 0; i < d.shopTabs.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _TabPill(d.shopTabs[i], selected: i == _tab, onTap: () => setState(() => _tab = i)),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AddItem(onTap: () => context.openScreen('250')),
              gap16,
              if (items.isEmpty)
                const InfoNote(
                  'Aucune offre de client pour le moment. Les demandes reçues apparaîtront ici.',
                  icon: AppIcons.inbox,
                )
              else
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 12,
                  childAspectRatio: 166 / 224,
                  children: [
                    for (final it in items)
                      _ShopTile(
                        item: it,
                        favorite: _favorites.contains(it.title),
                        onFavorite: () => setState(() {
                          _favorites.contains(it.title) ? _favorites.remove(it.title) : _favorites.add(it.title);
                        }),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill(this.label, {required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          alignment: Alignment.center,
          decoration: ShapeDecoration(color: selected ? AppColors.ink : Colors.white, shape: const StadiumBorder()),
          child: Text(
            label,
            style: AppText.body.copyWith(color: selected ? Colors.white : AppColors.ink, fontSize: 13.5),
          ),
        ),
      ),
    ),
  );
}

class _AddItem extends StatelessWidget {
  const _AddItem({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorder(),
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(color: const Color(0x80F1ECFD), borderRadius: BorderRadius.circular(29)),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: Color(0xFFE7E0FA), shape: BoxShape.circle),
                child: const AppIcon(AppIcons.plus, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ajouter un article', style: AppText.bodyStrong.copyWith(color: amViolet)),
                    Text(
                      'Produit, service ou offre : visible sur ton profil et dans le fil',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.small.copyWith(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DashedBorder extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = amViolet
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.height / 2));
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ShopTile extends StatelessWidget {
  const _ShopTile({required this.item, required this.favorite, required this.onFavorite});

  final AmShopItem item;
  final bool favorite;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => context.openScreen('252'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AmPhoto(
            item.image,
            radius: 22,
            children: [
              Positioned(left: 8, top: 8, child: AmChip(item.tag, tone: Tone.neutral, height: 24, fontSize: 11)),
              Positioned(
                right: 0,
                top: 0,
                child: RoundIconButton(
                  icon: favorite ? AppIcons.heartFilled : AppIcons.heart,
                  label: favorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
                  size: 28,
                  bordered: false,
                  foreground: favorite ? amLive : AppColors.ink,
                  onTap: onFavorite,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(item.title, style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w600)),
        Text(
          item.from ? 'À partir de ${fcfaF(item.price)}' : fcfaF(item.price),
          style: AppText.bodyStrong.copyWith(color: amViolet, fontSize: 13),
        ),
        Text(item.rating, style: AppText.small.copyWith(fontSize: 11)),
      ],
    ),
  );
}
