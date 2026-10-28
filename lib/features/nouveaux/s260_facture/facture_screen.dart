import '../../common/common.dart';

/// 260 · Facture avec ventilation 70 / 20 / 10.
class FactureScreen extends ConsumerWidget {
  const FactureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inv = ref.watch(nouveauxDataProvider).invoice;
    final split = splitPayment(inv.gross);
    return DetailScreen(
      title: 'Facture',
      subtitle: inv.number,
      action: 'Télécharger la facture (PDF)',
      onAction: () {
        context.toast('Facture ${inv.number} téléchargée.');
        context.openScreen('44');
      },
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Boutik-École', style: AppText.h2),
                        Text('IUT de Douala · Cameroun', style: AppText.small),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Facture n° ${inv.number}', style: AppText.label),
                      const SizedBox(height: 4),
                      Text(inv.date, style: AppText.small),
                    ],
                  ),
                ],
              ),
              gap16,
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFF1EFF6), borderRadius: BorderRadius.circular(12)),
                child: _line('Désignation', 'Qté', 'Montant', header: true),
              ),
              for (final l in inv.lines)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.cardBorder))),
                  child: _line(l.label, '${l.qty}', fcfa(l.amount, withUnit: false)),
                ),
              gap16,
              Text('Détail du montant', style: AppText.bodyStrong),
              gap8,
              for (final kv in [
                KV('Montant brut', fcfa(inv.gross)),
                KV('Frais de paiement', fcfa(inv.fees)),
                KV('Taxes applicables', fcfa(inv.taxes)),
                KV('Commission de la plateforme (10 %)', fcfa(split.platform)),
                KV('Part étudiants / département (70 %)', fcfa(split.seller)),
                KV('Fonds d’innovation (20 %)', fcfa(split.institution)),
              ])
                Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: KeyValueRow(kv)),
              gap16,
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(color: const Color(0xFFF1EFF6), borderRadius: BorderRadius.circular(18)),
                child: Row(
                  children: [
                    Expanded(child: Text('Total TTC', style: AppText.h3.copyWith(fontWeight: FontWeight.w500))),
                    Text(fcfa(inv.gross + inv.taxes), style: AppText.h1.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              gap16,
              Text('Répartition indicative selon la règle validée par l’établissement.', style: AppText.small.copyWith(fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _line(String a, String b, String c, {bool header = false}) {
    final s = header ? AppText.small : AppText.body;
    final strong = header ? AppText.small : AppText.bodyStrong;
    return Row(
      children: [
        Expanded(flex: 5, child: Text(a, style: s)),
        Expanded(flex: 1, child: Text(b, style: s, textAlign: TextAlign.center)),
        Expanded(flex: 2, child: Text(c, style: strong, textAlign: TextAlign.end)),
      ],
    );
  }
}
