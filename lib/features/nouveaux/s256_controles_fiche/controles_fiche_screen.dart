import '../../common/common.dart';

/// 256 · Contrôles de la fiche (étapes 2 et 5 du workflow).
class ControlesFicheScreen extends ConsumerWidget {
  const ControlesFicheScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(nouveauxDataProvider);
    final regPassed = d.regulatoryChecks.where((c) => c.state == CheckState.passed).length;
    return DetailScreen(
      title: 'Contrôles de la fiche',
      subtitle: 'Étapes 2 et 5 du workflow',
      secondaryAction: 'Retour au suivi',
      onSecondaryAction: () => ScreenHeader.back(context),
      children: [
        _GroupTitle('Contrôles automatiques', '${d.autoChecksTotal} / ${d.autoChecksTotal} réussis', BadgeTone.success),
        gap12,
        _ChecksCard(d.autoChecks, passedLabel: 'Réussi'),
        gap24,
        _GroupTitle('Contrôles réglementaires', '$regPassed / ${d.regulatoryChecks.length}', BadgeTone.warning),
        gap12,
        _ChecksCard(d.regulatoryChecks, passedLabel: 'Validé'),
        gap16,
        Text('Aucune publication n’est possible tant que l’étape 5 n’est pas validée.', style: AppText.small),
      ],
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.title, this.badge, this.tone);

  final String title;
  final String badge;
  final BadgeTone tone;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Semantics(header: true, child: Text(title, style: AppText.h3))),
      StatusBadge(badge, tone: tone),
    ],
  );
}

class _ChecksCard extends StatelessWidget {
  const _ChecksCard(this.items, {required this.passedLabel});

  final List<CheckItem> items;
  final String passedLabel;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        children: [
          for (final c in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  if (c.state == CheckState.passed)
                    Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: const AppIcon(AppIcons.check, size: 14, color: Colors.white),
                    )
                  else
                    const StatusDot(Color(0xFFE2DFEA), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      c.label,
                      style: AppText.body.copyWith(
                        fontSize: 14,
                        color: c.state == CheckState.passed ? AppColors.ink : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    switch (c.state) {
                      CheckState.passed => passedLabel,
                      CheckState.pending => 'En attente',
                      CheckState.failed => 'Échec',
                    },
                    style: AppText.small.copyWith(
                      fontSize: 12,
                      color: switch (c.state) {
                        CheckState.passed => AppColors.success,
                        CheckState.pending => AppColors.warning,
                        CheckState.failed => AppColors.error,
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
