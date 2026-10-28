import '../q_widgets.dart';

/// 148 (1/2) · Paramètres du compte.
class ParametresScreen extends ConsumerWidget {
  const ParametresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionQDataProvider);
    final demo = ref.watch(demoModeProvider);
    final language = ref.watch(appSettingsProvider).locale.languageCode == 'en' ? 'English' : 'Français';
    return CPage(
      title: 'Paramètres',
      tab: NavTab.profile,
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            children: [
              CircleAvatar(radius: 36, backgroundImage: AssetImage(d.userAvatar)),
              gap8,
              Text(d.userName, style: AppText.h3.copyWith(fontWeight: FontWeight.w600)),
              Text(d.userMail, style: AppText.small.copyWith(fontSize: 11.5)),
            ],
          ),
        ),
        gap12,
        QCard(
          children: [
            for (final s in d.settings)
              QRow(
                icon: s.$1,
                title: s.$2,
                trailing: s.$3.isEmpty
                    ? const AppIcon(AppIcons.chevronRight, size: 18)
                    : Text(language, style: AppText.small.copyWith(fontSize: 12.5)),
                onTap: () => context.openScreen(s.$4),
              ),
          ],
        ),
        gap12,
        QDangerButton('Se déconnecter', icon: AppIcons.logOut, onTap: () => context.goScreen('11')),
        if (demo) ...[
          gap16,
          Semantics(
            label: 'Données de démonstration : les chiffres affichés sont fictifs',
            excludeSemantics: true,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppIcon(AppIcons.info, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text('Données de démonstration', style: AppText.small.copyWith(fontSize: 11)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
