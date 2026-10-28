import '../auth_common.dart';

/// 11 · Connexion (« Bon retour ! »).
class ConnexionScreen extends ConsumerStatefulWidget {
  const ConnexionScreen({super.key});

  @override
  ConsumerState<ConnexionScreen> createState() => _ConnexionScreenState();
}

class _ConnexionScreenState extends ConsumerState<ConnexionScreen> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _password = TextEditingController();
  int _mode = 0;

  @override
  void dispose() {
    _id.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) context.goScreen(NavTargets.home);
  }

  @override
  Widget build(BuildContext context) {
    final phone = _mode == 0;
    return AuthScreen(
      formKey: _form,
      children: [
        gap24,
        const Center(child: BrandMark(size: 64)),
        gap16,
        Text('Bon retour !', textAlign: TextAlign.center, style: AppText.h1.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('Connectez-vous pour accéder à votre espace', textAlign: TextAlign.center, style: AppText.secondary),
        gap16,
        SegmentedChoice(
          labels: const ['Téléphone', 'E-mail'],
          selected: _mode,
          onSelected: (i) => setState(() {
            _mode = i;
            _id.clear();
          }),
        ),
        gap24,
        TextFieldWithError(
          key: ValueKey(_mode),
          label: phone ? 'Numéro de téléphone' : 'Adresse e-mail',
          hint: phone ? '+237  6 XX XX XX XX' : 'exemple@mail.com',
          controller: _id,
          prefixIcon: phone ? AppIcons.smartphone : AppIcons.mail,
          keyboardType: phone ? TextInputType.phone : TextInputType.emailAddress,
          validator: phone ? Validators.phoneCm : Validators.email,
        ),
        gap16,
        PasswordField(label: 'Mot de passe', hint: '••••••••', controller: _password, validator: Validators.password),
        Align(
          alignment: Alignment.centerRight,
          child: TextLink('Mot de passe oublié ?', onTap: () => context.openScreen('15')),
        ),
        gap8,
        PrimaryButton(label: 'Se connecter', trailingIcon: AppIcons.arrowRight, onPressed: _submit),
        gap16,
        Text('ou', textAlign: TextAlign.center, style: AppText.small),
        gap16,
        PrimaryButton(label: 'Créer un compte', variant: ButtonVariant.secondary, onPressed: () => context.openScreen('12')),
        gap24,
        Text(
          'En continuant, vous acceptez nos Conditions d’utilisation et notre Politique de confidentialité.',
          textAlign: TextAlign.center,
          style: AppText.small.copyWith(fontSize: 11),
        ),
        Center(child: TextLink('Lire les conditions', onTap: () => context.openScreen('17'))),
      ],
    );
  }
}
