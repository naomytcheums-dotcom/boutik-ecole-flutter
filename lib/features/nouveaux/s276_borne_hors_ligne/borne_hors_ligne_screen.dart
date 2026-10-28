import '../../common/common.dart';

/// 276 · Borne de l'IUT hors connexion (mode secours).
class BorneHorsLigneScreen extends ConsumerWidget {
  const BorneHorsLigneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(nouveauxDataProvider);
    return DetailScreen(
      title: 'Borne de l’IUT',
      subtitle: d.offlineKiosk,
      action: 'Parcourir le catalogue hors ligne',
      onAction: () => context.openScreen('206'),
      children: [
        const HeroMessage(
          icon: AppIcons.wifiOff,
          title: 'Connexion momentanément indisponible',
          message: 'Le catalogue est consultable hors ligne.',
        ),
        gap24,
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Disponible hors ligne', style: AppText.h3),
              gap8,
              for (final f in d.offlineFeatures)
                Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• $f', style: AppText.body)),
              gap8,
              Text('Paiements et commandes : reprise dès le retour du réseau.', style: AppText.small),
            ],
          ),
        ),
        gap16,
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Besoin d’aide ?', style: AppText.h3),
              const SizedBox(height: 6),
              Text(d.helpDesk, style: AppText.small),
            ],
          ),
        ),
        gap24,
        Semantics(
          liveRegion: true,
          child: Text(
            'Reconnexion automatique…',
            textAlign: TextAlign.center,
            style: AppText.label.copyWith(color: AppColors.accent),
          ),
        ),
      ],
    );
  }
}
