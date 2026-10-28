import '../u_widgets.dart';

/// 174 · Centre de confiance.
class CentreConfianceScreen extends ConsumerWidget {
  const CentreConfianceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionUDataProvider);
    final light = AppText.small.copyWith(color: Colors.white, fontSize: 12.5);
    return CPage(
      title: 'Centre de confiance',
      tab: NavTab.home,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(colors: [Color(0xFF1B2D5A), Color(0xFF244884)]),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: AppColors.ink, shape: BoxShape.circle),
                    child: const AppIcon(AppIcons.sparkles, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Achetez en confiance', style: AppText.bodyStrong.copyWith(color: Colors.white)),
                        const SizedBox(height: 2),
                        Text('Conseils pour éviter les arnaques et protéger votre compte.', style: light),
                      ],
                    ),
                  ),
                ],
              ),
              gap12,
              for (final t in d.trustTips)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const AppIcon(AppIcons.check, size: 14, color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(child: Text(t, style: light)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const GSectionTitle('Guides'),
        QCard(
          children: [
            for (final g in d.guides)
              QRow(
                icon: g.$1,
                title: g.$2,
                trailing: const AppIcon(AppIcons.chevronRight, size: 18),
                onTap: () => context.openScreen(g.$3),
              ),
          ],
        ),
      ],
    );
  }
}
