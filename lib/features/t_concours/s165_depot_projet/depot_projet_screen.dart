import '../../../core/utils/validators.dart';
import '../t_widgets.dart';

/// 165 · Dépôt du projet.
class DepotProjetScreen extends ConsumerStatefulWidget {
  const DepotProjetScreen({super.key});

  @override
  ConsumerState<DepotProjetScreen> createState() => _DepotProjetScreenState();
}

class _DepotProjetScreenState extends ConsumerState<DepotProjetScreen> {
  final _form = GlobalKey<FormState>();
  bool _original = false;
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionTDataProvider);
    return Form(
      key: _form,
      child: GPage(
        title: 'Dépôt du projet',
        actions: [
          GOutlineButton('Enregistrer', onPressed: () => context.toast('Brouillon enregistré.')),
          PrimaryButton(
            label: 'Soumettre',
            height: 54,
            onPressed: () {
              setState(() => _submitted = true);
              if (_form.currentState!.validate() && _original) context.openScreen('166');
            },
          ),
        ],
        children: [
          TextFieldWithError(
            label: 'Titre du projet',
            initialValue: d.projectTitle,
            prefixIcon: AppIcons.lightbulb,
            validator: Validators.title,
          ),
          gap16,
          TextFieldWithError(
            label: 'Lien de démonstration',
            hint: 'https://…',
            prefixIcon: AppIcons.link,
            keyboardType: TextInputType.url,
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.isEmpty) return null;
              final u = Uri.tryParse(t);
              return u != null && u.hasScheme && u.host.isNotEmpty ? null : 'Lien invalide (https://…).';
            },
          ),
          gap16,
          const TextFieldWithError(label: 'Description', hint: 'Problème, solution, impact attendu…', maxLines: 4),
          gap16,
          QCard(
            children: [
              QRow(
                icon: AppIcons.upload,
                title: 'Présentation (PDF)',
                subtitle: 'Pitch deck · 10 Mo max',
                trailing: const AppIcon(AppIcons.chevronRight, size: 18),
                onTap: () => context.openScreen('279'),
              ),
              QRow(
                icon: AppIcons.play,
                title: 'Vidéo de démonstration',
                subtitle: '2 minutes maximum',
                trailing: const AppIcon(AppIcons.chevronRight, size: 18),
                onTap: () => context.openScreen('279'),
              ),
            ],
          ),
          gap8,
          CheckRow(
            label: 'Je certifie que le projet est original.',
            value: _original,
            onChanged: (v) => setState(() => _original = v),
          ),
          if (_submitted && !_original)
            Text('Cochez la certification d’originalité.', style: AppText.small.copyWith(color: AppColors.error)),
          gap8,
          GNote(d.submissionDeadline, icon: AppIcons.clock),
        ],
      ),
    );
  }
}
