import '../../../core/utils/validators_j.dart';
import '../j_widgets.dart';

/// 90 · Publier un besoin (étape « Besoin »).
class PublierBesoinScreen extends ConsumerStatefulWidget {
  const PublierBesoinScreen({super.key});

  @override
  ConsumerState<PublierBesoinScreen> createState() => _PublierBesoinScreenState();
}

class _PublierBesoinScreenState extends ConsumerState<PublierBesoinScreen> {
  final _form = GlobalKey<FormState>();
  late String _category = ref.read(sectionJDataProvider).needCategories.first;
  late String _budget = ref.read(sectionJDataProvider).needBudgets[1];
  String? _file;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionJDataProvider);
    return Form(
      key: _form,
      child: HPage(
        title: 'Publier un besoin',
        actions: [
          GOutlineButton('Brouillon', onPressed: () => context.toast('Brouillon enregistré.')),
          PrimaryButton(
            label: 'Publier',
            height: 54,
            onPressed: () {
              if (_form.currentState!.validate()) {
                context.toast('Besoin publié : les talents peuvent proposer.');
                context.openScreen('93');
              }
            },
          ),
        ],
        children: [
          const SizedBox(height: 4),
          JStepper(labels: d.needSteps, current: 0),
          gap12,
          JTextField(
            label: 'Titre du besoin',
            hint: 'Ex. Application de suivi clients',
            icon: AppIcons.pencil,
            validator: (v) => ValidatorsJ.heading(v, 'Le titre'),
          ),
          const SizedBox(height: 15),
          JSelectField(
            label: 'Catégorie',
            icon: AppIcons.layoutGrid,
            options: d.needCategories,
            value: _category,
            onChanged: (v) => setState(() => _category = v),
          ),
          const SizedBox(height: 15),
          const JTextField(
            label: 'Description',
            hint: 'Contexte, objectifs, contraintes…',
            maxLines: 3,
            validator: ValidatorsJ.description,
          ),
          const SizedBox(height: 15),
          JSelectField(
            label: 'Budget estimé',
            icon: AppIcons.wallet,
            options: d.needBudgets,
            value: _budget,
            onChanged: (v) => setState(() => _budget = v),
          ),
          const SizedBox(height: 15),
          JTextField(
            label: 'Date limite',
            initialValue: d.needDeadline,
            icon: AppIcons.calendar,
            validator: ValidatorsJ.date,
          ),
          const SizedBox(height: 15),
          AppCard(
            onTap: () => setState(() => _file = 'cahier_des_charges.pdf'),
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            child: Row(
              children: [
                const JIconTile(AppIcons.upload),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _file ?? 'Joindre le cahier des charges',
                        style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _file == null ? 'PDF, DOC · 10 Mo max' : 'Fichier joint · toucher pour remplacer',
                        style: AppText.small.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const AppIcon(AppIcons.chevronRight, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
