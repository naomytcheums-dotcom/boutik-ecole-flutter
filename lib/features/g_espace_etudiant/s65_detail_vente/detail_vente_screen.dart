import '../g_widgets.dart';

/// 65 · Détail d’une vente (résumé, commission, historique).
class DetailVenteScreen extends ConsumerWidget {
  const DetailVenteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionGDataProvider);
    final commission = d.saleAmount * d.commissionPercent ~/ 100;
    return GPage(
      title: 'Vente ${d.saleRef}',
      actions: [PrimaryButton(label: 'Marquer comme prête', height: 54, onPressed: () => context.toast('Commande marquée prête : le client est averti.'))],
      children: [
        AppCard(
          padding: const EdgeInsets.all(10),
          child: GThumbRow(
            image: d.saleImage,
            title: d.saleProduct,
            subtitle: 'Qté : ${d.saleQty} · ${fcfa(d.saleAmount)}',
            trailing: const GBadge('À préparer', Tone.warning),
          ),
        ),
        gap12,
        KeyValueCard(
          title: 'Résumé de la vente',
          rowGap: 14,
          rows: [
            KV('Acheteur', d.saleBuyer),
            KV('Date', d.saleDate),
            KV('Montant', fcfa(d.saleAmount)),
            KV('Commission (${d.commissionPercent} %)', '– ${fcfa(commission)}'),
            KV('Vous recevez', fcfa(d.saleAmount - commission)),
            KV('Retrait', d.pickupPoint),
          ],
        ),
        const GSectionTitle('Historique des opérations'),
        StepTimeline(
          steps: [
            for (final (i, s) in d.saleHistory.indexed)
              TimelineStep(
                s.title,
                s.detail ?? '',
                i < d.saleCurrentStep ? StepStatus.done : (i == d.saleCurrentStep ? StepStatus.current : StepStatus.upcoming),
              ),
          ],
        ),
      ],
    );
  }
}