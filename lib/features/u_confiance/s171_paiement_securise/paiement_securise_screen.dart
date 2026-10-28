import '../u_widgets.dart';

/// 171 · Paiement sécurisé : alerte de numéro marchand non reconnu.
class PaiementSecuriseScreen extends ConsumerWidget {
  const PaiementSecuriseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionUDataProvider);
    return GPage(
      title: 'Paiement sécurisé',
      actions: [
        GOutlineButton('Annuler le paiement', onPressed: () => context.openScreen('06')),
        PrimaryButton(label: 'Continuer en sécurité', height: 54, onPressed: () => context.openScreen('257')),
      ],
      children: [
        gap16,
        const Center(child: ChromeIcon(AppIcons.shieldCheck, size: 96, semanticLabel: 'Paiement protégé')),
        gap24,
        Semantics(
          header: true,
          child: Text('Vérifiez avant de payer', textAlign: TextAlign.center, style: AppText.h2),
        ),
        gap8,
        Text(
          'Ce vendeur demande un paiement en dehors de Boutik-École.',
          textAlign: TextAlign.center,
          style: AppText.secondary,
        ),
        gap24,
        const GNote(
          'Ne communiquez jamais votre code secret et ne payez qu’au numéro marchand officiel affiché dans l’application.',
          icon: AppIcons.shieldCheck,
        ),
        gap16,
        KeyValueCard(
          title: 'Comparaison',
          rows: [
            KV('Numéro officiel', d.officialNumber),
            KV('Numéro demandé par le vendeur', d.requestedNumber),
            const KV('Statut', 'Non reconnu'),
          ],
        ),
      ],
    );
  }
}
