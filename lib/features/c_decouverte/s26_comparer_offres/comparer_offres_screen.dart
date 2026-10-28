import '../c_widgets.dart';

/// 26 · Comparer des offres.
class ComparerOffresScreen extends ConsumerWidget {
  const ComparerOffresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionCDataProvider);
    Widget side(CTile t) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PhotoTile(image: t.image, aspectRatio: 128 / 132, radius: 16, semanticLabel: t.title),
          gap16,
          Text(t.title, style: AppText.body.copyWith(fontSize: 14)),
          Text(fcfa(t.price), style: AppText.h3),
          Text(t.department, style: AppText.small.copyWith(color: AppColors.accent, fontSize: 12.5)),
        ],
      ),
    );
    Widget dots(List<int> colors) => Row(
      children: [
        for (final c in colors)
          Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle),
          ),
      ],
    );
    Widget text(String s) => Text(s, style: AppText.secondary);
    final rows = <(String, Widget, Widget)>[
      for (final r in d.compareRows.take(2)) (r.$1, text(r.$2), text(r.$3)),
      ('Couleurs', dots(d.compareColorsLeft), dots(d.compareColorsRight)),
      for (final r in d.compareRows.skip(2)) (r.$1, text(r.$2), text(r.$3)),
    ];
    return CPage(
      title: 'Comparer des offres',
      trailing: cIcon(context, AppIcons.search, 'Rechercher', '21'),
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [side(d.compareLeft), const SizedBox(width: 36), side(d.compareRight)],
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 50,
                child: Center(
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 8)],
                    ),
                    alignment: Alignment.center,
                    child: Text('VS', style: AppText.bodyStrong.copyWith(fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
        ),
        gap16,
        AppCard(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
          child: Column(
            children: [
              for (final (i, r) in rows.indexed) ...[
                if (i > 0) const Divider(height: 1),
                SizedBox(
                  height: 54,
                  child: Row(
                    children: [
                      SizedBox(width: 114, child: Text(r.$1, style: AppText.body.copyWith(fontWeight: FontWeight.w500))),
                      Expanded(child: r.$2),
                      Expanded(child: r.$3),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        gap24,
        PrimaryButton(label: 'Voir les détails', onPressed: () => context.openScreen('05')),
      ],
    );
  }
}
