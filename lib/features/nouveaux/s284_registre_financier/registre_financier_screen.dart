import '../../../figma/live/money_admin.dart' show splitRuleProvider;
import '../../common/common.dart';

/// 284 · Registre financier d'une commande (ventilation après frais et taxes).
class RegistreFinancierScreen extends ConsumerWidget {
  const RegistreFinancierScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(nouveauxDataProvider);
    final rule = ref.watch(splitRuleProvider).value;
    final net = d.ledgerGross - d.ledgerFees - d.ledgerTaxes - d.ledgerRefunds;
    final split = rule == null ? null : splitPayment(net, rule);
    return DetailScreen(
      title: 'Registre financier',
      subtitle: 'Commande ${d.ledgerOrder}',
      action: 'Exporter le registre (CSV)',
      onAction: () => context.toast('Registre exporté (CSV).'),
      children: [
        const HeroMessage(icon: AppIcons.banknote, iconSize: 60),
        gap16,
        KeyValueCard(
          rowGap: 16,
          rows: [
            KV('Montant brut', fcfa(d.ledgerGross)),
            KV('Frais de paiement (1,5 %)', '– ${fcfa(d.ledgerFees)}'),
            KV('Taxes (TVA 19,25 %)', '– ${fcfa(d.ledgerTaxes)}'),
            KV('Remboursements', fcfa(d.ledgerRefunds)),
            KV('Net réparti', fcfa(net), strong: true),
            if (rule != null && split != null) ...[
              KV('Commission plateforme (${rule.platform} %)', fcfa(split.platform)),
              KV('Part département (${rule.institution} %)', fcfa(split.institution)),
              KV('Part étudiants (${rule.beneficiary} %)', fcfa(split.seller)),
            ] else
              KV('Répartition', 'Règle en cours de lecture'),
          ],
        ),
        gap16,
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Répartition configurable', style: AppText.bodyStrong),
              const SizedBox(height: 4),
              Text(
                rule == null
                    ? 'Règle de répartition en cours de lecture · modifiable par l’administrateur global, avec historique.'
                    : '${rule.label} · règle en vigueur, modifiable par l’administrateur global, avec historique.',
                style: AppText.small,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
