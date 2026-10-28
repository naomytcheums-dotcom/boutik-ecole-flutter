import '../../common/common.dart';

/// 257 · Paiement en attente de confirmation.
class PaiementAttenteScreen extends ConsumerWidget {
  const PaiementAttenteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(nouveauxDataProvider).pendingPayment;
    return DetailScreen(
      title: 'Paiement',
      subtitle: 'Commande ${p.orderId}',
      action: 'Vérifier le statut',
      onAction: () => context.openScreen('259'),
      secondaryAction: 'Changer de moyen de paiement',
      onSecondaryAction: () => context.openScreen('258'),
      children: [
        gap24,
        HeroMessage(
          icon: AppIcons.clock,
          title: 'En attente de confirmation',
          message:
              'Validez le paiement sur votre téléphone avec votre code ${p.method}. Cela peut prendre jusqu’à 2 minutes.',
        ),
        gap24,
        KeyValueCard(
          rows: [
            KV('Moyen', p.method),
            KV('Montant', fcfa(p.amount)),
            KV('Référence', p.reference),
            KV('Délai restant', p.remaining),
          ],
        ),
        gap16,
        const InfoNote('Ne fermez pas la page. Aucun montant n’est débité tant que vous n’avez pas validé.'),
      ],
    );
  }
}
