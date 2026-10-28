import 'package:flutter/services.dart';

import '../../common/common.dart';
import '../e_widgets.dart';

/// 43 · Instructions de paiement (paiement marchand Orange Money).
class InstructionsPaiementScreen extends ConsumerWidget {
  const InstructionsPaiementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionEDataProvider);
    final total = d.summaryLines.fold(0, (s, l) => s + l.price * l.qty) + d.deliveryFee;
    return EScaffold(
      title: 'Instructions de paiement',
      actions: [
        EButton(
          'Copier la référence',
          kind: EButtonKind.outline,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: d.reference));
            if (context.mounted) context.toast('Référence ${d.reference} copiée.');
          },
        ),
        EButton('J’ai payé', onPressed: () => context.openScreen('44')),
      ],
      children: [
        const SizedBox(height: 2),
        EKvList(
          title: 'Détails du paiement',
          rows: [
            ('Moyen de paiement', d.paymentMethod),
            ('Numéro marchand', d.merchantNumber),
            ('Référence à indiquer', d.reference),
            ('Montant à payer', fcfa(total)),
          ],
        ),
        const SizedBox(height: 13.5),
        ETimeline(steps: d.paymentSteps, current: d.paymentCurrentStep),
        const SizedBox(height: 36),
        ENote(d.paymentCheckDelay, icon: AppIcons.clock),
      ],
    );
  }
}
