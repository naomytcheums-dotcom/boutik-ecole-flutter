import '../../../core/utils/validators.dart';
import '../i_widgets.dart';

/// 84 · Nouvelle campagne de financement (étape Objectif).
class NouvelleCampagneScreen extends ConsumerStatefulWidget {
  const NouvelleCampagneScreen({super.key});

  @override
  ConsumerState<NouvelleCampagneScreen> createState() => _NouvelleCampagneScreenState();
}

class _NouvelleCampagneScreenState extends ConsumerState<NouvelleCampagneScreen> {
  final _form = GlobalKey<FormState>();
  late final d = ref.read(sectionIDataProvider);
  late String _type = d.campaignTypes.first;
  late String _project = d.campaignProjects.first;
  late String _duration = d.campaignDurations.first;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: GPage(
        title: 'Nouvelle campagne',
        actions: [
          GOutlineButton('Brouillon', onPressed: () => context.toast('Brouillon enregistré.')),
          PrimaryButton(
            label: 'Continuer',
            height: 54,
            onPressed: () {
              if (_form.currentState!.validate()) context.openScreen('84b');
            },
          ),
        ],
        children: [
          GStepper(labels: d.campaignSteps, current: 1),
          gap12,
          SelectField(
            label: 'Type de campagne',
            icon: AppIcons.layers,
            options: d.campaignTypes,
            value: _type,
            onChanged: (v) => setState(() => _type = v),
          ),
          gap16,
          SelectField(
            label: 'Projet concerné',
            icon: AppIcons.lightbulb,
            options: d.campaignProjects,
            value: _project,
            onChanged: (v) => setState(() => _project = v),
          ),
          gap16,
          TextFieldWithError(
            label: 'Objectif à atteindre (FCFA)',
            initialValue: d.campaignGoal,
            prefixIcon: AppIcons.banknote,
            keyboardType: TextInputType.number,
            validator: Validators.priceFcfa,
          ),
          gap16,
          SelectField(
            label: 'Durée',
            icon: AppIcons.calendar,
            options: d.campaignDurations,
            value: _duration,
            onChanged: (v) => setState(() => _duration = v),
          ),
          gap16,
          const TextFieldWithError(
            label: 'Présentation de la campagne',
            hint: 'Expliquez le projet, l’usage des fonds et l’impact…',
            maxLines: 4,
          ),
          gap16,
          AppCard(
            onTap: () => context.toast('Ajout de contreparties.'),
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: const IIconRow(
              icon: AppIcons.gift,
              title: 'Ajouter des contreparties',
              subtitle: 'Précommandes, remerciements, accès anticipé…',
              trailing: AppIcon(AppIcons.chevronRight, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
