import '../c_widgets.dart';

/// 30 · Commande reçue (confirmation après livraison).
class CommandeRecueScreen extends ConsumerWidget {
  const CommandeRecueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionCDataProvider);
    return AppScaffold(
      showNav: false,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      header: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
        child: Row(
          children: [HeaderIcon(AppIcons.arrowLeft, label: 'Retour', onTap: () => ScreenHeader.back(context))],
        ),
      ),
      children: [
        gap24,
        const Center(child: ChromeIcon(AppIcons.package, size: 84)),
        const SizedBox(height: 54),
        Semantics(
          header: true,
          child: Text(
            'Commande reçue !',
            textAlign: TextAlign.center,
            style: AppText.h1.copyWith(fontSize: 24, fontWeight: FontWeight.w600),
          ),
        ),
        gap24,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            'Votre commande ${d.detailRef} a bien été reçue. Merci pour votre confiance !',
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(fontSize: 13.5, color: AppColors.accent, height: 1.6),
          ),
        ),
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              PrimaryButton(label: 'Évaluer la commande', height: 56, onPressed: () => context.openScreen('47')),
              gap12,
              GOutlineButton('Voir le détail', onPressed: () => context.openScreen('29')),
            ],
          ),
        ),
        gap24,
        AppCard(
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Un problème ?', style: AppText.label),
              gap8,
              Text(
                'Signalez un souci pour obtenir de l’aide.',
                style: AppText.small.copyWith(fontSize: 10.5, color: AppColors.accent),
              ),
              gap8,
              Material(
                color: Colors.white,
                shape: const StadiumBorder(side: BorderSide(color: Color(0xFFF0EEF3))),
                elevation: 1,
                shadowColor: const Color(0x22000000),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => context.openScreen('48'),
                  child: SizedBox(
                    height: 56,
                    child: Center(
                      child: Text('Contacter le support', style: AppText.secondary.copyWith(color: AppColors.accent)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
