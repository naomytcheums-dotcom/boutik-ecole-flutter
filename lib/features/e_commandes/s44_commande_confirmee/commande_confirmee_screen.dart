import '../../common/common.dart';
import '../e_widgets.dart';

/// 44 · Commande confirmée.
class CommandeConfirmeeScreen extends ConsumerWidget {
  const CommandeConfirmeeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionEDataProvider);
    final total = d.summaryLines.fold(0, (s, l) => s + l.price * l.qty) + d.deliveryFee;
    return EScaffold(
      title: 'Commande confirmée',
      showBack: false,
      actions: [
        EButton('Accueil', kind: EButtonKind.outline, onPressed: () => context.goScreen(NavTargets.home)),
        EButton('Suivre ma commande', onPressed: () => context.openScreen('09')),
      ],
      children: [
        const SizedBox(height: 11),
        const Center(child: ChromeIcon(AppIcons.shoppingBag, size: 104, semanticLabel: 'Commande validée')),
        const SizedBox(height: 27.5),
        Semantics(
          header: true,
          child: Text(
            'Merci pour votre commande !',
            textAlign: TextAlign.center,
            style: AppText.h2.copyWith(fontSize: 19, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 7),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Text(
            'Votre commande a bien été enregistrée. Un reçu vous a été envoyé par e-mail.',
            textAlign: TextAlign.center,
            style: AppText.secondary.copyWith(height: 1.42),
          ),
        ),
        const SizedBox(height: 32.5),
        EKvList(
          title: 'Récapitulatif',
          rows: [
            ('Référence', '#${d.reference}'),
            ('Date', d.orderDate),
            ('Montant', fcfa(total)),
            ('Retrait', d.pickupPoint),
          ],
        ),
        const SizedBox(height: 14.5),
        const ENote('Vous serez notifié dès que votre commande sera prête à être retirée.', icon: AppIcons.bell),
      ],
    );
  }
}
