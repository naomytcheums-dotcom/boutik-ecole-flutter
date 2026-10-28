import '../../common/common.dart';

/// 259 · Reçu de paiement.
class RecuScreen extends ConsumerWidget {
  const RecuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(nouveauxDataProvider).receipt;
    return DetailScreen(
      title: 'Reçu',
      subtitle: 'Commande ${r.orderId}',
      action: 'Télécharger le reçu',
      onAction: () => context.toast('Reçu ${r.receiptNo} téléchargé.'),
      secondaryAction: 'Voir la facture',
      onSecondaryAction: () => context.openScreen('260'),
      children: [
        const HeroMessage(icon: AppIcons.circleCheck, title: 'Paiement reçu'),
        gap8,
        Text(fcfa(r.amount), style: AppText.display.copyWith(fontSize: 34), textAlign: TextAlign.center),
        gap16,
        KeyValueCard(
          rowGap: 18,
          rows: [
            KV('Reçu n°', r.receiptNo),
            KV('Date', r.date),
            KV('Moyen', r.method),
            KV('Référence', r.reference),
            KV('Vendeur', r.seller),
            KV('Retrait', r.pickup),
          ],
          footer: Column(
            children: [
              const Divider(height: 24),
              KeyValueRow(KV('Total payé', fcfa(r.amount), strong: true)),
            ],
          ),
        ),
      ],
    );
  }
}
