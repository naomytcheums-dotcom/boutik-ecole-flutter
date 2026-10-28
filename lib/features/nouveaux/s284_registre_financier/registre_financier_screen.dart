import '../../common/common.dart';

/// 284 · Registre financier d'une commande (ventilation après frais et taxes).
class RegistreFinancierScreen extends ConsumerWidget {
  const RegistreFinancierScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(nouveauxDataProvider);
    final net = d.ledgerGross - d.ledgerFees - d.ledgerTaxes - d.ledgerRefunds;
    final platform = (net * 10) ~/ 100;
    final department = (net * 20) ~/ 100;
    final students = net - platform - department;
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
            KV('Commission plateforme (10 %)', fcfa(platform)),
            KV('Part département (20 %)', fcfa(department)),
            KV('Part étudiants (70 %)', fcfa(students)),
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
                '70 / 20 / 10 par défaut · modifiable par l’administrateur global, avec historique.',
                style: AppText.small,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
