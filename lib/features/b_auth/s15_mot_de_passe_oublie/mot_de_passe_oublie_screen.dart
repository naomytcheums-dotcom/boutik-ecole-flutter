import '../auth_common.dart';

/// 15 · Mot de passe oublié.
class MotDePasseOublieScreen extends StatefulWidget {
  const MotDePasseOublieScreen({super.key});

  @override
  State<MotDePasseOublieScreen> createState() => _MotDePasseOublieScreenState();
}

class _MotDePasseOublieScreenState extends State<MotDePasseOublieScreen> {
  final _form = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return AuthScreen(
      title: 'Mot de passe oublié',
      formKey: _form,
      children: [
        gap16,
        const Center(child: ChromeIcon(AppIcons.keyRound, size: 64)),
        gap16,
        Text('Réinitialiser votre mot de passe', textAlign: TextAlign.center, style: AppText.h2.copyWith(fontWeight: FontWeight.w700)),
        gap12,
        Text(
          'Saisissez votre numéro de téléphone ou votre e-mail. Nous vous enverrons un code pour réinitialiser votre mot de passe.',
          textAlign: TextAlign.center,
          style: AppText.small,
        ),
        const SizedBox(height: 32),
        const TextFieldWithError(
          label: 'Téléphone ou e-mail',
          hint: 'Ex. +237 6 XX XX XX XX',
          prefixIcon: AppIcons.mail,
          validator: Validators.phoneOrEmail,
        ),
        gap24,
        const InfoNote('Pour votre sécurité, le code envoyé\nest valable pendant 10 minutes.'),
        gap24,
        PrimaryButton(
          label: 'Envoyer le code',
          trailingIcon: AppIcons.arrowRight,
          onPressed: () {
            if (_form.currentState!.validate()) context.openScreen('16');
          },
        ),
        gap16,
        Center(child: TextLink('Retour à la connexion', onTap: () => context.goScreen('11'))),
      ],
    );
  }
}
