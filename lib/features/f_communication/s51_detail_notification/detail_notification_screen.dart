import '../../common/common.dart';
import '../f_widgets.dart';

/// 51 · Détail d'une notification : commande expédiée, étapes du suivi, récapitulatif.
class DetailNotificationScreen extends ConsumerWidget {
  const DetailNotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionFDataProvider);
    return FScaffold(
      title: 'Notification',
      actions: [
        FButton('Contacter le vendeur', kind: FButtonKind.outline, onPressed: () => context.openScreen('54')),
        FButton('Suivre ma commande', onPressed: () => context.openScreen('46')),
      ],
      children: [
        const SizedBox(height: 2),
        FCard(
          child: FRow(leading: const FTile(AppIcons.truck), title: d.shippedTitle, subtitle: d.shippedWhen),
        ),
        const SizedBox(height: 15),
        Padding(
          // Boîte de texte de la maquette légèrement plus étroite que la page (retour à la ligne identique).
          padding: const EdgeInsets.only(right: 2),
          child: Text(d.shippedText, style: FTxt.paragraph),
        ),
        const SizedBox(height: 14),
        FTimeline(steps: d.shippedSteps, current: d.shippedCurrentStep),
        const SizedBox(height: 36),
        FKvList(
          rows: [('Référence', d.orderRef), ('Point de retrait', d.pickupPoint), ('Montant', fcfa(d.orderAmount))],
        ),
      ],
    );
  }
}
