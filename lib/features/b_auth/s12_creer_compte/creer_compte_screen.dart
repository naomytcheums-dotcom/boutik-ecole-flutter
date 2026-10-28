import '../auth_common.dart';

/// 12 · Créer un compte.
class CreerCompteScreen extends ConsumerStatefulWidget {
  const CreerCompteScreen({super.key});

  @override
  ConsumerState<CreerCompteScreen> createState() => _CreerCompteScreenState();
}

class _CreerCompteScreenState extends ConsumerState<CreerCompteScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _accepted = false;
  bool _showTermsError = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final ok = _form.currentState!.validate();
    setState(() => _showTermsError = !_accepted);
    if (ok && _accepted) context.openScreen('14');
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreen(
      title: 'Créer un compte',
      formKey: _form,
      children: [
        Text('Rejoignez la marketplace de l’IUT de Douala', style: AppText.small),
        gap16,
        TextFieldWithError(
          label: 'Nom complet',
          hint: 'Ex. Mariam Essono',
          prefixIcon: AppIcons.user,
          validator: (v) => Validators.required(v, 'Le nom'),
        ),
        gap16,
        const TextFieldWithError(
          label: 'Téléphone',
          hint: '+237 6 XX XX XX XX',
          prefixIcon: AppIcons.smartphone,
          keyboardType: TextInputType.phone,
          validator: Validators.phoneCm,
        ),
        gap16,
        const TextFieldWithError(
          label: 'E-mail',
          hint: 'exemple@mail.com',
          prefixIcon: AppIcons.mail,
          keyboardType: TextInputType.emailAddress,
          validator: Validators.email,
        ),
        gap16,
        PasswordField(label: 'Mot de passe', hint: '8 caractères minimum', controller: _password, validator: Validators.password),
        gap16,
        PasswordField(
          label: 'Confirmer le mot de passe',
          hint: 'Confirmez votre mot de passe',
          validator: (v) => v != _password.text ? 'Les mots de passe ne correspondent pas.' : null,
        ),
        gap12,
        CheckRow(
          label: 'J’accepte les Conditions d’utilisation et la Politique de confidentialité.',
          value: _accepted,
          onChanged: (v) => setState(() {
            _accepted = v;
            _showTermsError = false;
          }),
        ),
        if (_showTermsError)
          Text('Vous devez accepter les conditions pour continuer.', style: AppText.small.copyWith(color: AppColors.error)),
        gap16,
        PrimaryButton(label: 'Créer mon compte', trailingIcon: AppIcons.arrowRight, onPressed: _submit),
        gap8,
        InlineLink('Déjà un compte ? ', 'Se connecter', onTap: () => context.openScreen('11')),
      ],
    );
  }
}
