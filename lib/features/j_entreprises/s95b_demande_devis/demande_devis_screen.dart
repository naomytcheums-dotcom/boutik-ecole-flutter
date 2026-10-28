import '../../../core/utils/validators_j.dart';
import '../j_widgets.dart';

/// 95b · Demande de devis adressée à un talent ou une équipe.
class DemandeDevisScreen extends ConsumerStatefulWidget {
  const DemandeDevisScreen({super.key});

  @override
  ConsumerState<DemandeDevisScreen> createState() => _DemandeDevisScreenState();
}

class _DemandeDevisScreenState extends ConsumerState<DemandeDevisScreen> {
  final _form = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionJDataProvider);
    return Form(
      key: _form,
      child: HPage(
        title: 'Demande de devis',
        actions: [
          PrimaryButton(
            label: 'Envoyer la demande',
            height: 54,
            onPressed: () {
              if (_form.currentState!.validate()) {
                context.toast('Demande envoyée à ${d.quoteTeam}.');
                context.openScreen('95');
              }
            },
          ),
        ],
        children: [
          const SizedBox(height: 6),
          JPersonCard(avatar: d.quoteTeamAvatar, name: d.quoteTeam, detail: d.quoteTeamDetail),
          const SizedBox(height: 15),
          JTextField(
            label: 'Objet',
            initialValue: d.quoteObject,
            icon: AppIcons.tag,
            validator: (v) => ValidatorsJ.heading(v, 'L’objet'),
          ),
          const SizedBox(height: 15),
          const JTextField(
            label: 'Description du besoin',
            hint: 'Spécifications, quantité, contraintes…',
            maxLines: 3,
            validator: ValidatorsJ.description,
          ),
          const SizedBox(height: 15),
          JTextField(
            label: 'Quantité',
            initialValue: d.quoteQuantity,
            icon: AppIcons.package2,
            validator: ValidatorsJ.quantity,
          ),
          const SizedBox(height: 15),
          JTextField(
            label: 'Budget maximal',
            initialValue: fcfa(d.quoteBudget),
            icon: AppIcons.wallet,
            keyboardType: TextInputType.number,
            validator: ValidatorsJ.budget,
          ),
          const SizedBox(height: 15),
          JTextField(
            label: 'Date de livraison',
            initialValue: d.quoteDate,
            icon: AppIcons.calendar,
            validator: ValidatorsJ.date,
          ),
        ],
      ),
    );
  }
}
