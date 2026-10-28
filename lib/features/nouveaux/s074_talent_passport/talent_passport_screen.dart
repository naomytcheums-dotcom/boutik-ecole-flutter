import '../../common/common.dart';

/// 74 · Talent Passport (compétences vérifiées, badges, certificats).
class TalentPassportScreen extends ConsumerWidget {
  const TalentPassportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(nouveauxDataProvider);
    return DetailScreen(
      title: 'Talent Passport',
      subtitle: d.passportOwner,
      action: 'Partager mon passport (QR / PDF)',
      onAction: () => context.openScreen('212'),
      children: [
        Row(
          children: [
            const ChromeIcon(AppIcons.badgeCheck, size: 64),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.passportLevel, style: AppText.h1.copyWith(fontSize: 22, fontWeight: FontWeight.w700)),
                  Text(d.passportNumber, style: AppText.small),
                ],
              ),
            ),
          ],
        ),
        gap16,
        AppCard(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Compétences vérifiées', style: AppText.h3.copyWith(fontWeight: FontWeight.w600)),
              for (final s in d.passportSkills) ...[
                gap12,
                Row(
                  children: [
                    Expanded(child: Text(s.name, style: AppText.body)),
                    Text(s.level, style: AppText.secondary),
                  ],
                ),
                const SizedBox(height: 6),
                ProgressLine(value: s.value),
              ],
            ],
          ),
        ),
        gap16,
        AppCard(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Badges obtenus', style: AppText.h3.copyWith(fontWeight: FontWeight.w600)),
              gap12,
              Row(
                children: [
                  for (final (i, b) in d.passportBadges.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 56),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFFF4F0E8), borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b.label, style: AppText.label.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Text(b.value, style: AppText.label.copyWith(color: AppColors.accent)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        gap16,
        AppCard(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Certificats et recommandations', style: AppText.h3.copyWith(fontWeight: FontWeight.w600)),
              gap8,
              for (final c in d.passportCertificates)
                Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(c, style: AppText.body)),
              Text(d.passportRecommendations, style: AppText.secondary),
            ],
          ),
        ),
      ],
    );
  }
}
