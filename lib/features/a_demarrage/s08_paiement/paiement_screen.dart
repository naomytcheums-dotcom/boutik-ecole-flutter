import '../../common/common.dart';

/// 08 · Paiement (Orange Money / Mobile Money).
class PaiementScreen extends ConsumerStatefulWidget {
  const PaiementScreen({super.key});

  @override
  ConsumerState<PaiementScreen> createState() => _PaiementScreenState();
}

class _PaiementScreenState extends ConsumerState<PaiementScreen> {
  int _method = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionADataProvider);
    final cart = ref.watch(cartProvider);
    final fee = d.deliveryFee;
    final methods = [
      ('Orange Money', d.orangeAccount, AppColors.ink, 'OM'),
      ('Mobile Money (autre)', 'MTN Money, Wave, etc.', const Color(0xFFFFCB05), 'MoMo'),
    ];
    return AppScaffold(
      tab: NavTab.home,
      header: const TitleHeader('Paiement'),
      bottomBar: PrimaryButton(label: 'Payer maintenant', icon: AppIcons.lock, onPressed: () => context.openScreen('257')),
      children: [
        Text('Moyen de paiement', style: AppText.h3),
        gap12,
        for (final (i, m) in methods.indexed) ...[
          Semantics(
            inMutuallyExclusiveGroup: true,
            checked: i == _method,
            button: true,
            label: m.$1,
            excludeSemantics: true,
            child: AppCard(
              onTap: () => setState(() => _method = i),
              color: i == _method ? const Color(0xFFF2F6FC) : Colors.white,
              borderColor: i == _method ? const Color(0xFFB9CCEB) : AppColors.cardBorder,
              padding: const EdgeInsets.fromLTRB(64, 16, 16, 16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: m.$3, borderRadius: BorderRadius.circular(10)),
                    alignment: Alignment.center,
                    child: Text(
                      m.$4,
                      style: AppText.label.copyWith(color: i == 0 ? const Color(0xFFFF7900) : AppColors.ink, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.$1, style: AppText.body),
                        const SizedBox(height: 4),
                        Text(m.$2, style: AppText.small.copyWith(color: i == 0 ? AppColors.accent : AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: i == _method ? AppColors.accent : AppColors.ink, width: 1.4),
                    ),
                    alignment: Alignment.center,
                    child: i == _method
                        ? Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle))
                        : null,
                  ),
                ],
              ),
            ),
          ),
          gap12,
        ],
        AppCard(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            children: [
              Align(alignment: Alignment.centerLeft, child: Text('Récapitulatif', style: AppText.h3)),
              gap16,
              KeyValueRow(KV('Articles (${cart.count})', fcfa(cart.subtotal), color: AppColors.accent)),
              gap16,
              KeyValueRow(KV('Livraison', fcfa(fee), color: AppColors.accent)),
              const Divider(height: 32),
              Row(
                children: [
                  Expanded(child: Text('Total', style: AppText.h3)),
                  Text(fcfa(cart.subtotal + fee), style: AppText.h2.copyWith(color: AppColors.accent, fontWeight: FontWeight.w800)),
                ],
              ),
            ],
          ),
        ),
        gap16,
        const InfoNote('Vos informations sont protégées et ne sont jamais partagées.', title: 'Paiement sécurisé'),
      ],
    );
  }
}
