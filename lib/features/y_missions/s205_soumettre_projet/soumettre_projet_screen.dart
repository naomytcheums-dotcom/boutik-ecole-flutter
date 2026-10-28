import '../../../core/utils/validators_y.dart';
import '../y_widgets.dart';

/// 205 · Soumettre mon projet : formulaire de candidature au coup de pouce startup.
class SoumettreProjetScreen extends ConsumerStatefulWidget {
  const SoumettreProjetScreen({super.key});

  @override
  ConsumerState<SoumettreProjetScreen> createState() => _SoumettreProjetScreenState();
}

class _SoumettreProjetScreenState extends ConsumerState<SoumettreProjetScreen> {
  final _form = GlobalKey<FormState>();
  late final SectionYData _d = ref.read(sectionYDataProvider);
  late final _name = TextEditingController(text: _d.projectName);
  late final _problem = TextEditingController(text: _d.projectProblem);
  late final _funding = TextEditingController(text: fcfa(_d.fundingNeed));
  final _help = <int>{0};
  bool _helpError = false;

  @override
  void dispose() {
    _name.dispose();
    _problem.dispose();
    _funding.dispose();
    super.dispose();
  }

  void _send() {
    final ok = _form.currentState!.validate();
    setState(() => _helpError = _help.isEmpty);
    if (!ok || _help.isEmpty) return;
    context.toast('Projet envoyé à l’IUT : réponse sous 7 jours.');
    context.openScreen('204');
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionYDataProvider);
    return GPage(
      title: 'Soumettre mon projet',
      actions: [
        YOutlineButton('Brouillon', onPressed: () => context.toast('Brouillon enregistré.')),
        PrimaryButton(label: 'Envoyer à l’IUT', onPressed: _send),
      ],
      children: [
        YStepper(labels: d.projectSteps, current: 0),
        const SizedBox(height: 10),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PillTextField(
                label: 'Nom du projet',
                icon: AppIcons.lightbulb,
                controller: _name,
                validator: validateProjectName,
              ),
              const SizedBox(height: 16),
              const YLabel('Problème résolu'),
              YTextArea(controller: _problem, label: 'Problème résolu', validator: validateProjectProblem),
              const YTitle('Aide demandée', top: 20, bottom: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: Row(
                  children: [
                    for (final (i, o) in d.helpOptions.indexed) ...[
                      if (i > 0) const SizedBox(width: 8),
                      _HelpChip(
                        label: o,
                        selected: _help.contains(i),
                        onTap: () => setState(() {
                          _help.contains(i) ? _help.remove(i) : _help.add(i);
                          if (_help.isNotEmpty) _helpError = false;
                        }),
                      ),
                    ],
                  ],
                ),
              ),
              if (_helpError)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Choisissez au moins un type d’aide.',
                    style: AppText.small.copyWith(color: AppColors.error, fontWeight: FontWeight.w600),
                  ),
                ),
              const SizedBox(height: 8),
              PillTextField(
                label: 'Besoin de financement',
                icon: AppIcons.wallet,
                controller: _funding,
                keyboardType: TextInputType.number,
                validator: validateFundingAmount,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        YCard(
          children: [
            YIconRow(
              icon: AppIcons.users,
              title: 'Ajouter des coéquipiers',
              subtitle: 'Compétences complémentaires',
              onTap: () => context.toast('Invitez des étudiants d’autres filières.'),
              trailing: const AppIcon(AppIcons.chevronRight, size: 20),
            ),
          ],
        ),
      ],
    );
  }
}

class _HelpChip extends StatelessWidget {
  const _HelpChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 44,
        child: Center(
          widthFactor: 1,
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: ShapeDecoration(
              color: selected ? AppColors.ink : const Color(0xFFEDEBF3),
              shape: const StadiumBorder(),
            ),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: AppText.secondary.copyWith(
                  fontSize: 13.5,
                  color: selected ? Colors.white : const Color(0xFF4A4752),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
