import '../auth_common.dart';

/// 16 · Nouveau mot de passe (force et critères en direct).
class NouveauMotDePasseScreen extends StatefulWidget {
  const NouveauMotDePasseScreen({super.key});

  @override
  State<NouveauMotDePasseScreen> createState() => _NouveauMotDePasseScreenState();
}

class _NouveauMotDePasseScreenState extends State<NouveauMotDePasseScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController(text: 'Boutik2026');

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Validators.passwordCriteria(_password.text);
    final score = Validators.passwordScore(_password.text);
    final (strength, color) = switch (score) {
      <= 1 => ('Faible', AppColors.error),
      2 => ('Moyen', AppColors.warning),
      _ => ('Fort', AppColors.success),
    };
    return AuthScreen(
      title: 'Nouveau mot de passe',
      formKey: _form,
      children: [
        const Center(child: ChromeIcon(AppIcons.lock, size: 64)),
        gap8,
        Text('Créez un nouveau mot de passe', textAlign: TextAlign.center, style: AppText.h2.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Choisissez un mot de passe fort que vous\nn’utilisez pas ailleurs.', textAlign: TextAlign.center, style: AppText.small),
        gap16,
        PasswordField(
          label: 'Nouveau mot de passe',
          controller: _password,
          onChanged: (_) => setState(() {}),
          validator: (v) => Validators.passwordScore(v ?? '') < 3 ? 'Respectez au moins 3 critères sur 4.' : null,
        ),
        gap16,
        Semantics(
          label: 'Force du mot de passe : $strength',
          excludeSemantics: true,
          child: Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i < score ? color : const Color(0xFFE4E0EA),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        gap8,
        Row(
          children: [
            Expanded(child: Text('Force du mot de passe', style: AppText.small.copyWith(fontSize: 11))),
            Text(strength, style: AppText.small.copyWith(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
        gap12,
        CriterionRow('8 caractères minimum', c.length),
        CriterionRow('Une lettre majuscule', c.upper),
        CriterionRow('Un chiffre', c.digit),
        CriterionRow('Un caractère spécial (! @ # …)', c.special),
        gap16,
        PasswordField(
          label: 'Confirmer le mot de passe',
          validator: (v) => v != _password.text ? 'Les mots de passe ne correspondent pas.' : null,
        ),
        gap24,
        PrimaryButton(
          label: 'Réinitialiser le mot de passe',
          onPressed: () {
            if (_form.currentState!.validate()) {
              context.toast('Mot de passe réinitialisé.');
              context.goScreen('11');
            }
          },
        ),
      ],
    );
  }
}
