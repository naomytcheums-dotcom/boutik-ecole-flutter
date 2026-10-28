import '../auth_common.dart';

/// 18b · Compléter mon profil (étape 1 sur 2).
class CompleterProfilScreen extends ConsumerStatefulWidget {
  const CompleterProfilScreen({super.key});

  @override
  ConsumerState<CompleterProfilScreen> createState() => _CompleterProfilScreenState();
}

class _CompleterProfilScreenState extends ConsumerState<CompleterProfilScreen> {
  final _form = GlobalKey<FormState>();
  String _institution = 'IUT de Douala';
  String? _department;
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionBDataProvider);
    return AuthScreen(
      title: 'Compléter mon profil',
      formKey: _form,
      children: [
        Row(
          children: [
            Expanded(child: Text('Étape 1 sur 2', style: AppText.small.copyWith(fontSize: 11))),
            Text('50 %', style: AppText.small.copyWith(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 6),
        const ProgressLine(value: .5, height: 4),
        gap16,
        Center(
          child: Semantics(
            button: true,
            label: 'Ajouter une photo',
            child: GestureDetector(
              onTap: () => context.toast('Sélection d’une photo…'),
              child: const Column(children: [ChromeIcon(AppIcons.user, size: 64)]),
            ),
          ),
        ),
        Text('Ajouter une photo', textAlign: TextAlign.center, style: AppText.small.copyWith(fontSize: 11)),
        gap16,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFieldWithError(
                label: 'Prénom',
                initialValue: 'Mariam',
                prefixIcon: AppIcons.user,
                validator: (v) => Validators.required(v, 'Le prénom'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFieldWithError(
                label: 'Nom',
                initialValue: 'Essono',
                prefixIcon: AppIcons.user,
                validator: (v) => Validators.required(v, 'Le nom'),
              ),
            ),
          ],
        ),
        gap16,
        const TextFieldWithError(label: 'Ville', initialValue: 'Douala', prefixIcon: AppIcons.mapPin),
        gap16,
        SelectField(
          label: 'Établissement',
          icon: AppIcons.landmark,
          options: d.institutions,
          value: _institution,
          onChanged: (v) => setState(() => _institution = v),
        ),
        gap16,
        SelectField(
          label: 'Département',
          icon: AppIcons.graduationCap,
          hint: 'Sélectionnez votre département',
          options: d.departments,
          value: _department,
          errorText: _submitted && _department == null ? 'Le département est obligatoire.' : null,
          onChanged: (v) => setState(() => _department = v),
        ),
        gap16,
        TextFieldWithError(
          label: 'Date de naissance',
          hint: 'JJ / MM / AAAA',
          prefixIcon: AppIcons.calendar,
          keyboardType: TextInputType.datetime,
          validator: (v) => RegExp(r'^\d{2}\s?/\s?\d{2}\s?/\s?\d{4}$').hasMatch(v?.trim() ?? '') ? null : 'Format attendu : JJ / MM / AAAA.',
        ),
        gap24,
        PrimaryButton(
          label: 'Continuer',
          trailingIcon: AppIcons.arrowRight,
          onPressed: () {
            setState(() => _submitted = true);
            if (_form.currentState!.validate() && _department != null) context.openScreen('18c');
          },
        ),
      ],
    );
  }
}
