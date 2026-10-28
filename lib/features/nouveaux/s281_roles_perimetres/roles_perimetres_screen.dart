import '../../common/common.dart';

/// 281 · Rôles et périmètres (matrice lire / écrire / valider).
/// Affichage seulement : l'application réelle des droits se fait côté serveur (docs/BACKEND_PLAN.md).
class RolesPerimetresScreen extends ConsumerWidget {
  const RolesPerimetresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(nouveauxDataProvider).roleMatrix;
    Widget cell(bool v, String right, String role) => Expanded(
      child: Semantics(
        label: '$role : $right ${v ? 'autorisé' : 'non autorisé'}',
        excludeSemantics: true,
        child: Center(
          child: v
              ? const StatusDot(AppColors.ink, size: 9)
              : Text('–', style: AppText.small),
        ),
      ),
    );
    return DetailScreen(
      title: 'Rôles et périmètres',
      subtitle: 'Institution : IUT de Douala',
      children: [
        const HeroMessage(icon: AppIcons.users, iconSize: 60),
        gap16,
        AppCard(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(flex: 5, child: Text('Rôle', style: AppText.small)),
                  for (final h in ['Lire', 'Écrire', 'Valider'])
                    Expanded(child: Center(child: Text(h, style: AppText.small))),
                ],
              ),
              for (final r in m)
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 40),
                  child: Row(
                    children: [
                      Expanded(flex: 5, child: Text(r.$1, style: AppText.bodyStrong.copyWith(fontSize: 13))),
                      cell(r.$2, 'lire', r.$1),
                      cell(r.$3, 'écrire', r.$1),
                      cell(r.$4, 'valider', r.$1),
                    ],
                  ),
                ),
            ],
          ),
        ),
        gap16,
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Isolation des institutions', style: AppText.h3.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(
                'Chaque compte voit uniquement les données de son institution. Les actions sensibles sont journalisées.',
                style: AppText.small,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
