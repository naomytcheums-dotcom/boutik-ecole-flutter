import '../c_widgets.dart';

/// 31 · Avis et évaluations.
class AvisEvaluationsScreen extends ConsumerWidget {
  const AvisEvaluationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionCDataProvider);
    return CPage(
      title: 'Avis et évaluations',
      children: [
        gap16,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: Semantics(
                label: 'Note moyenne ${d.ratingAverage} sur 5, ${d.ratingCount} avis',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: d.ratingAverage,
                        children: [
                          TextSpan(
                            text: '/5',
                            style: AppText.h2.copyWith(fontWeight: FontWeight.w400, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      style: AppText.display.copyWith(fontSize: 38, fontWeight: FontWeight.w700),
                    ),
                    gap8,
                    Row(
                      children: [
                        for (var i = 0; i < 5; i++)
                          const AppIcon(AppIcons.starFilled, size: 18, color: Color(0xFFF2B33D)),
                      ],
                    ),
                    gap16,
                    Text('(${d.ratingCount} avis)', style: AppText.small),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 6,
              child: Column(
                children: [
                  for (final (stars, pct) in d.ratingDistribution)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text('$stars', style: AppText.small.copyWith(color: AppColors.ink)),
                          const SizedBox(width: 4),
                          const AppIcon(AppIcons.starFilled, size: 10),
                          const SizedBox(width: 6),
                          Expanded(child: ProgressLine(value: pct / 100, color: const Color(0xFFF6B73C), height: 8)),
                          SizedBox(
                            width: 34,
                            child: Text('$pct%', textAlign: TextAlign.end, style: AppText.small.copyWith(fontSize: 10)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const GSectionTitle('Avis clients'),
        for (final r in d.reviews) ...[
          AppCard(
            padding: const EdgeInsets.fromLTRB(10, 16, 10, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(radius: 20, backgroundImage: AssetImage(r.avatar)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.author, style: AppText.body.copyWith(fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(r.date, style: AppText.small.copyWith(fontSize: 11)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: const ShapeDecoration(color: Color(0xFFFCF3D7), shape: StadiumBorder()),
                      child: Text(
                        r.score,
                        style: AppText.small.copyWith(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                gap16,
                Text(r.text, style: AppText.body.copyWith(fontSize: 13.5, color: const Color(0xFF4A4752), height: 1.5)),
                if (r.photos.isNotEmpty) ...[
                  gap16,
                  Row(
                    children: [
                      for (final p in r.photos)
                        Padding(
                          padding: const EdgeInsets.only(right: 18),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(p, width: 82, height: 54, fit: BoxFit.cover),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          gap16,
        ],
      ],
    );
  }
}
