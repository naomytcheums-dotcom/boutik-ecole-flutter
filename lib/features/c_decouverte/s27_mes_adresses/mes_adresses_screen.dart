import '../c_widgets.dart';

/// 27 · Mes adresses.
class MesAdressesScreen extends ConsumerWidget {
  const MesAdressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionCDataProvider);
    final body = AppText.body.copyWith(fontSize: 13.5, color: const Color(0xFF4A4752));
    return CPage(
      title: 'Mes adresses',
      tab: NavTab.profile,
      trailing: cIcon(context, AppIcons.search, 'Rechercher', '21'),
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 18, 12, 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppIcon(AppIcons.mapPin, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Adresse par défaut', style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w600)),
                    gap12,
                    Text(d.defaultAddress.$1, style: body),
                    gap12,
                    Text(d.defaultAddress.$2, style: body),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: 'Modifier l’adresse par défaut',
                child: GestureDetector(
                  onTap: () => context.openScreen('43'),
                  child: const SizedBox(height: 44, child: Center(child: GBadge('Modifier', Tone.neutral))),
                ),
              ),
            ],
          ),
        ),
        GSectionTitle('Mes adresses', trailing: TextLink('Voir tout →', onTap: () {})),
        for (final a in d.addresses) ...[
          AppCard(
            onTap: () => context.openScreen('43'),
            padding: const EdgeInsets.fromLTRB(16, 18, 12, 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIcon(a.$4 ? AppIcons.mapPin : AppIcons.briefcase, size: 20),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.$1, style: AppText.label.copyWith(fontSize: 13.5)),
                      const SizedBox(height: 8),
                      Text(a.$2, style: AppText.small.copyWith(color: AppColors.accent)),
                      const SizedBox(height: 6),
                      Text(a.$3, style: AppText.small.copyWith(color: AppColors.accent)),
                    ],
                  ),
                ),
                if (a.$4) const GBadge('Principale', Tone.warning) else const AppIcon(AppIcons.chevronRight, size: 16),
              ],
            ),
          ),
          gap16,
        ],
        AppCard(
          onTap: () => context.openScreen('43'),
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppIcon(AppIcons.plus, size: 18),
              const SizedBox(width: 12),
              Text('Ajouter une adresse', style: AppText.body.copyWith(fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}
