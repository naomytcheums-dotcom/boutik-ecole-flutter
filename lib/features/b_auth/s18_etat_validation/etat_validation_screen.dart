import '../auth_common.dart';

/// 18 · État de validation du compte vendeur.
class EtatValidationScreen extends ConsumerWidget {
  const EtatValidationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionBDataProvider);
    const steps = [('Envoyée', AppIcons.check), ('En vérification', AppIcons.clock), ('Décision', null)];
    return AuthScreen(
      title: 'État de validation',
      children: [
        gap16,
        const Center(child: ChromeIcon(AppIcons.circleDot, size: 64)),
        gap12,
        const Center(child: StatusBadge('En attente', tone: BadgeTone.warning)),
        gap16,
        Text('Demande en cours d’examen', textAlign: TextAlign.center, style: AppText.h2.copyWith(fontWeight: FontWeight.w700)),
        gap12,
        Text(
          'Notre équipe vérifie vos informations.\nVous recevrez une réponse sous 24 à 48 h.',
          textAlign: TextAlign.center,
          style: AppText.small,
        ),
        gap16,
        Semantics(
          label: 'Étape 2 sur 3 : en vérification',
          excludeSemantics: true,
          child: Row(
            children: [
              for (final (i, s) in steps.indexed)
                Expanded(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 36,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Container(height: 2, color: i == 0 ? Colors.transparent : (i <= 1 ? AppColors.ink : AppColors.cardBorder))),
                                Expanded(child: Container(height: 2, color: i == 2 ? Colors.transparent : (i < 1 ? AppColors.ink : AppColors.cardBorder))),
                              ],
                            ),
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i <= 1 ? AppColors.ink : Colors.white,
                                border: i <= 1 ? null : Border.all(color: AppColors.cardBorder),
                              ),
                              alignment: Alignment.center,
                              child: s.$2 == null ? null : AppIcon(s.$2!, size: 16, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      gap8,
                      Text(
                        s.$1,
                        style: AppText.small.copyWith(
                          fontSize: 11,
                          color: i == 0 ? AppColors.accent : (i == 1 ? AppColors.ink : AppColors.textSecondary),
                          fontWeight: i == 1 ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        gap16,
        AppCard(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Résultats possibles', style: AppText.bodyStrong),
              gap8,
              for (final o in d.validationOutcomes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: switch (o.$3) {
                            'success' => AppColors.successSoft,
                            'error' => AppColors.errorSoft,
                            _ => AppColors.accentSoft,
                          },
                        ),
                        alignment: Alignment.center,
                        child: AppIcon(
                          switch (o.$3) {
                            'success' => AppIcons.check,
                            'error' => AppIcons.x,
                            _ => AppIcons.triangleAlert,
                          },
                          size: 16,
                          color: switch (o.$3) {
                            'success' => AppColors.success,
                            'error' => AppColors.error,
                            _ => AppColors.accent,
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(o.$1, style: AppText.label.copyWith(fontWeight: FontWeight.w600)),
                            Text(o.$2, style: AppText.small.copyWith(fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        gap16,
        PrimaryButton(label: 'Retour à l’accueil', onPressed: () => context.goScreen(NavTargets.home)),
        gap12,
        PrimaryButton(label: 'Contacter le support', variant: ButtonVariant.secondary, onPressed: () => context.openScreen('48')),
      ],
    );
  }
}
