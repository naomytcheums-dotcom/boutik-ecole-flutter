import '../../common/common.dart';
import '../e_widgets.dart';

/// 47 · Annuler la commande : motif, remboursement.
class AnnulerCommandeScreen extends ConsumerStatefulWidget {
  const AnnulerCommandeScreen({super.key});

  @override
  ConsumerState<AnnulerCommandeScreen> createState() => _AnnulerCommandeScreenState();
}

class _AnnulerCommandeScreenState extends ConsumerState<AnnulerCommandeScreen> {
  int _reason = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionEDataProvider);
    return EScaffold(
      title: 'Annuler la commande',
      actions: [
        EButton('Garder', kind: EButtonKind.outline, onPressed: () => ScreenHeader.back(context)),
        EButton(
          'Annuler la commande',
          kind: EButtonKind.danger,
          onPressed: () {
            context.toast('Commande ${d.cancelRef} annulée. Remboursement sous ${d.refundDelay}.');
            context.openScreen('45');
          },
        ),
      ],
      children: [
        const SizedBox(height: 2),
        ECard(
          child: ERow(
            height: 65.5,
            leading: EThumb(d.cancelImage, label: d.cancelProduct),
            title: d.cancelRef,
            titleStyle: ETxt.itemRegular,
            subtitle: '${d.cancelProduct} · ${fcfa(d.cancelAmount)}',
            trailing: const EStatusBadge(EOrderStatus.preparing),
          ),
        ),
        const SizedBox(height: 15.25),
        Semantics(header: true, child: Text('Motif de l’annulation', style: ETxt.section)),
        const SizedBox(height: 10.25),
        for (final (i, r) in d.cancelReasons.indexed)
          ECheckRow(label: r, value: i == _reason, radio: true, onChanged: (_) => setState(() => _reason = i)),
        const SizedBox(height: 8),
        EKvList(
          title: 'Remboursement',
          rows: [('Montant remboursé', fcfa(d.cancelAmount)), ('Délai', d.refundDelay), ('Mode', d.refundMode)],
        ),
        const SizedBox(height: 14),
        const ENote('Une commande déjà préparée peut ne plus être annulable.', icon: AppIcons.info),
      ],
    );
  }
}
