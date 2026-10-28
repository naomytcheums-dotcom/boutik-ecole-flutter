import '../auth_common.dart';

/// 13 · Choix du profil (rôle).
class ChoixProfilScreen extends ConsumerWidget {
  const ChoixProfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roles = ref.watch(sectionBDataProvider).roles;
    final selected = ref.watch(roleProvider);
    return AuthScreen(
      title: 'Choix du profil',
      children: [
        Text('Quel est votre profil ?', style: AppText.h2.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Choisissez le rôle qui vous correspond.\nVous pourrez le modifier plus tard.', style: AppText.small),
        gap16,
        for (final (i, r) in roles.indexed) ...[
          Semantics(
            inMutuallyExclusiveGroup: true,
            checked: i == selected,
            button: true,
            label: '${r.$1}. ${r.$2}',
            excludeSemantics: true,
            child: AppCard(
              onTap: () => ref.read(roleProvider.notifier).set(i),
              color: i == selected ? const Color(0xFFFFFAEE) : Colors.white,
              borderColor: i == selected ? const Color(0xFFF2C24B) : AppColors.cardBorder,
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: i == selected ? const Color(0xFFFBE8B7) : const Color(0xFFF1EFF6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: AppIcon(r.$3, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.$1, style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text(r.$2, style: AppText.small.copyWith(fontSize: 11)),
                      ],
                    ),
                  ),
                  if (i == selected)
                    const StatusBadge('Sélectionné', tone: BadgeTone.dark)
                  else
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.textSecondary)),
                    ),
                ],
              ),
            ),
          ),
          gap12,
        ],
        gap8,
        PrimaryButton(
          label: 'Continuer',
          trailingIcon: AppIcons.arrowRight,
          onPressed: () => selected == 1 ? context.openScreen('18b') : context.goScreen(selected == 2 ? '262' : NavTargets.home),
        ),
      ],
    );
  }
}
