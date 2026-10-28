import '../s_widgets.dart';

/// 159 · Candidature envoyée.
class CandidatureEnvoyeeScreen extends ConsumerWidget {
  const CandidatureEnvoyeeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionSDataProvider);
    return GPage(
      title: 'Candidature envoyée',
      showBack: false,
      actions: [
        GOutlineButton('Mes candidatures', onPressed: () => context.openScreen('76')),
        PrimaryButton(label: 'Autres offres', height: 54, onPressed: () => context.goScreen('151')),
      ],
      children: [
        gap24,
        const Center(child: ChromeIcon(AppIcons.circleCheck, size: 72)),
        gap16,
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            'Merci pour votre candidature !',
            textAlign: TextAlign.center,
            style: AppText.h2.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        gap8,
        Text(
          'Camlight a bien reçu votre dossier. Vous serez notifié à chaque étape.',
          textAlign: TextAlign.center,
          style: AppText.small.copyWith(fontSize: 12.5),
        ),
        gap16,
        KeyValueCard(title: 'Récapitulatif', rowGap: 14, rows: [for (final s in d.sentSummary) KV(s.$1, s.$2)]),
        gap12,
        SAiCard(title: 'Conseil de l’IA', text: d.sentAdvice),
      ],
    );
  }
}
