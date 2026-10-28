import '../../../core/utils/validators.dart';
import '../i_widgets.dart';

/// 80 · Soumettre un projet (étape Idée).
class SoumettreProjetScreen extends ConsumerStatefulWidget {
  const SoumettreProjetScreen({super.key});

  @override
  ConsumerState<SoumettreProjetScreen> createState() => _SoumettreProjetScreenState();
}

class _SoumettreProjetScreenState extends ConsumerState<SoumettreProjetScreen> {
  final _form = GlobalKey<FormState>();
  late final d = ref.read(sectionIDataProvider);
  late String _dept = d.departments.first;
  late String _stage = d.stages.first;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: GPage(
        title: 'Soumettre un projet',
        actions: [
          PrimaryButton(
            label: 'Continuer',
            height: 54,
            onPressed: () {
              if (_form.currentState!.validate()) context.openScreen('81');
            },
          ),
        ],
        children: [
          GStepper(labels: d.submitSteps, current: 0),
          gap12,
          const TextFieldWithError(
            label: 'Titre du projet',
            hint: 'Ex. Serre intelligente',
            prefixIcon: AppIcons.lightbulb,
            validator: Validators.title,
          ),
          gap16,
          SelectField(
            label: 'Département',
            icon: AppIcons.graduationCap,
            options: d.departments,
            value: _dept,
            onChanged: (v) => setState(() => _dept = v),
          ),
          gap16,
          SelectField(
            label: 'Stade d’avancement',
            icon: AppIcons.layers,
            options: d.stages,
            value: _stage,
            onChanged: (v) => setState(() => _stage = v),
          ),
          gap16,
          TextFieldWithError(
            label: 'Description',
            hint: 'Problème résolu, solution, impact attendu…',
            maxLines: 4,
            validator: (v) => (v ?? '').trim().length < 20 ? 'Décrivez le projet en 20 caractères au moins.' : null,
          ),
          gap16,
          AppCard(
            onTap: () => context.openScreen('81'),
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: const IIconRow(
              icon: AppIcons.users,
              title: 'Ajouter des membres',
              subtitle: 'Invitez votre équipe sur Boutik-École',
              trailing: AppIcon(AppIcons.chevronRight, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
