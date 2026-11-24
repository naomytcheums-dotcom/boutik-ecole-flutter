import '../../../figma/live/money_admin.dart' show splitRuleProvider;
import '../../common/common.dart';

/// 260 · Facture avec ventilation selon la règle de répartition en vigueur.
class FactureScreen extends ConsumerWidget {
  const FactureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inv = ref.watch(nouveauxDataProvider).invoice;
    final rule = ref.watch(splitRuleProvider).value;
    final split = rule == null ? null : splitPayment(inv.gross, rule);
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
                if (rule != null && split != null) ...[
                  KV('Commission de la plateforme (${rule.platform} %)', fcfa(split.platform)),
                  KV('Part étudiants / département (${rule.beneficiary} %)', fcfa(split.seller)),
                  KV('Fonds d’innovation (${rule.institution} %)', fcfa(split.institution)),
                ] else
                  KV('Répartition', 'Règle en cours de lecture'),
              ])
                Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: KeyValueRow(kv)),
              gap16,
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(color: const Color(0xFFF1EFF6), borderRadius: BorderRadius.circular(18)),
                child: Row(
                  children: [
                    Expanded(child: Text('Total', style: AppText.h3.copyWith(fontWeight: FontWeight.w500))),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(fcfa(inv.gross + inv.taxes), style: AppText.h1.copyWith(fontWeight: FontWeight.w700)),
                      ),
                    ),
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
