import '../../common/common.dart';

/// 258 · Paiement échoué : choix d'un autre moyen.
class PaiementEchoueScreen extends ConsumerStatefulWidget {
  const PaiementEchoueScreen({super.key});

  @override
  ConsumerState<PaiementEchoueScreen> createState() => _PaiementEchoueScreenState();
}

class _PaiementEchoueScreenState extends ConsumerState<PaiementEchoueScreen> {
  String? _method;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(nouveauxDataProvider);
    final p = d.failedPayment;
    return DetailScreen(
      title: 'Paiement',
      subtitle: 'Commande ${p.orderId}',
      action: 'Réessayer le paiement',
      onAction: () => context.openScreen('257'),
      children: [
        gap16,
        HeroMessage(
          icon: AppIcons.shieldCheck,
          title: 'Le paiement a échoué',
          message: 'Solde insuffisant ou code incorrect. Aucun montant n’a été débité.',
        ),
        gap24,
        KeyValueCard(
          rows: [
            KV('Motif', p.failureReason, color: AppColors.error),
            KV('Montant', fcfa(p.amount)),
            KV('Tentative', p.attempt),
          ],
        ),
        gap24,
        Text('Choisir un autre moyen', style: AppText.bodyStrong),
        gap8,
        for (final m in d.paymentMethods) ...[
          ChoiceRow(
            label: m.label,
            badge: m.badge,
            badgeColor: switch (m.id) {
              'om' => const Color(0xFFB54708),
              'momo' => AppColors.warning,
              _ => AppColors.success,
            },
            badgeBackground: switch (m.id) {
              'om' => const Color(0xFFFFEBDD),
              'momo' => const Color(0xFFFCF3D2),
              _ => AppColors.successSoft,
            },
            selected: _method == m.id,
            onTap: () => setState(() => _method = m.id),
          ),
          gap8,
        ],
      ],
    );
  }
}
