import '../auth_common.dart';

/// 14 · Vérification du compte (code SMS à 6 chiffres).
class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  final _code = TextEditingController(text: '482');
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _verify() {
    if (_code.text.length < 6) {
      setState(() => _error = 'Saisissez les 6 chiffres du code.');
      return;
    }
    context.openScreen('13');
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionBDataProvider);
    return AuthScreen(
      title: 'Vérification',
      children: [
        const SizedBox(height: 120),
        Text('Vérification du compte', textAlign: TextAlign.center, style: AppText.h2.copyWith(fontWeight: FontWeight.w700)),
        gap16,
        Text('Entrez le code à 6 chiffres envoyé au\n${d.otpTarget}', textAlign: TextAlign.center, style: AppText.small),
        gap24,
        OtpInput(controller: _code, hasError: _error != null, onChanged: (_) => setState(() => _error = null)),
        if (_error != null) ...[
          gap8,
          Text(_error!, textAlign: TextAlign.center, style: AppText.small.copyWith(color: AppColors.error)),
        ],
        gap24,
        Text('Vous n’avez pas reçu le code ?', textAlign: TextAlign.center, style: AppText.small),
        Center(child: TextLink('Renvoyer dans ${d.otpResend}', onTap: () => context.toast('Nouveau code envoyé.'))),
        gap16,
        PrimaryButton(label: 'Vérifier', trailingIcon: AppIcons.arrowRight, onPressed: _verify),
        gap8,
        Center(child: TextLink('Modifier le numéro', color: AppColors.ink, onTap: () => ScreenHeader.back(context))),
        gap16,
        const InfoNote('Ne partagez jamais ce code.\nIl est valable pendant 10 minutes.', icon: AppIcons.shieldCheck),
      ],
    );
  }
}

