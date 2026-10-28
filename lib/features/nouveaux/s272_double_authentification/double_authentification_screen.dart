import '../../common/common.dart';

/// 272 · Vérification en 2 étapes (compte administrateur).
class DoubleAuthentificationScreen extends ConsumerStatefulWidget {
  const DoubleAuthentificationScreen({super.key});

  @override
  ConsumerState<DoubleAuthentificationScreen> createState() => _DoubleAuthentificationScreenState();
}

class _DoubleAuthentificationScreenState extends ConsumerState<DoubleAuthentificationScreen> {
  static const _length = 6;
  late final _controller = TextEditingController(text: ref.read(nouveauxDataProvider).twoFactorPrefill);
  bool _trust = true;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _verify() {
    if (_controller.text.length < _length) {
      setState(() => _error = 'Saisissez les $_length chiffres du code.');
      return;
    }
    setState(() => _error = null);
    context.goScreen('117');
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(nouveauxDataProvider);
    return DetailScreen(
      title: 'Vérification en 2 étapes',
      subtitle: 'Compte administrateur · IUT de Douala',
      action: 'Vérifier',
      onAction: _verify,
      children: [
        const HeroMessage(icon: AppIcons.shieldCheck),
        gap12,
        Text('Saisissez le code reçu', style: AppText.h1.copyWith(fontSize: 22, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text('Envoyé par SMS au ${d.twoFactorTarget}', style: AppText.secondary, textAlign: TextAlign.center),
        gap24,
        OtpInput(controller: _controller, length: _length, hasError: _error != null, onChanged: (_) => setState(() => _error = null)),
        if (_error != null) ...[
          gap8,
          Text(_error!, style: AppText.small.copyWith(color: AppColors.error), textAlign: TextAlign.center),
        ],
        gap8,
        Center(
          child: TextLink('Renvoyer le code dans ${d.twoFactorResend}', onTap: () => context.toast('Nouveau code envoyé.')),
        ),
        gap16,
        AppCard(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Autres méthodes', style: AppText.label),
              TextLink('Application d’authentification ›', color: AppColors.textSecondary, onTap: () {}),
              TextLink('Codes de secours (${d.backupCodes}) ›', color: AppColors.textSecondary, onTap: () {}),
            ],
          ),
        ),
        gap12,
        CheckRow(label: 'Faire confiance à cet appareil pendant 30 jours', value: _trust, onChanged: (v) => setState(() => _trust = v)),
      ],
    );
  }
}
