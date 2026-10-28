import '../common/common.dart';

export '../../core/utils/validators.dart';
export '../common/common.dart';

/// Gabarit des écrans d'authentification : en-tête « flèche + titre », pas de menu bas,
/// bouton principal en bas de contenu (comme dans les maquettes 11–18c).
class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key, this.title, required this.children, this.formKey, this.showBack = true});

  final String? title;
  final List<Widget> children;
  final GlobalKey<FormState>? formKey;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final list = AppScaffold(
      showNav: false,
      header: title == null ? null : TitleHeader(title!, showBack: showBack),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: children,
    );
    return formKey == null ? list : Form(key: formKey, child: list);
  }
}

/// Lien « Texte · Action » centré (« Déjà un compte ? Se connecter »).
class InlineLink extends StatelessWidget {
  const InlineLink(this.prefix, this.action, {super.key, required this.onTap});

  final String prefix;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(prefix, style: AppText.small),
        TextLink(action, onTap: onTap),
      ],
    );
  }
}
