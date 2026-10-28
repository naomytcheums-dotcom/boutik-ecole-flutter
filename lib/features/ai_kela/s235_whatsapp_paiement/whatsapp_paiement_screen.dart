import '../../common/common.dart';
import '../ai_widgets.dart';

/// Orange Money assombri pour un contraste ≥ 4,5:1 avec le texte blanc (voir docs/questions/AI.md).
const _orangeMoney = Color(0xFFC25500);

/// 235 · WhatsApp : paiement sécurisé du premier jalon par Orange Money.
class WhatsappPaiementScreen extends ConsumerWidget {
  const WhatsappPaiementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionAIDataProvider);
    return AiWhatsAppScaffold(
      messages: d.paymentChat,
      cardBuilder: (context, m) => _PaymentCard(
        amount: fcfa(d.firstMilestoneAmount),
        detail: 'Séquestre · jalon 1 sur ${d.milestonesCount}',
        onPay: () => context.toast('Ouverture d’Orange Money…'),
      ),
    );
  }
}

/// Carte « Paiement sécurisé » : montant, séquestre, bouton Orange Money.
class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.amount, required this.detail, required this.onPay});

  final String amount;
  final String detail;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 48,
            color: const Color(0xFFFFF3E6),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(header: true, child: Text('Paiement sécurisé', style: AppText.bodyStrong)),
                ),
                const AppIcon(AppIcons.lock, size: 20),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Montant', style: AppText.small),
                const SizedBox(height: 2),
                Text(amount, style: AppText.amount.copyWith(fontSize: 22)),
                const SizedBox(height: 2),
                Text(detail, style: AppText.small),
              ],
            ),
          ),
          Semantics(
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPay,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                child: Container(
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: _orangeMoney, borderRadius: BorderRadius.circular(16)),
                  child: Text('Payer avec Orange Money', style: AppText.label.copyWith(color: Colors.white)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
