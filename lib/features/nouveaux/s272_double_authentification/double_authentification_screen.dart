import 'package:flutter/services.dart';

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
  final _focus = FocusNode();
  bool _trust = true;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
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
        Semantics(
          label: 'Code de vérification à $_length chiffres',
          textField: true,
          child: GestureDetector(
            onTap: () => _focus.requestFocus(),
            child: Stack(
              children: [
                Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    keyboardType: TextInputType.number,
                    maxLength: _length,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() => _error = null),
                  ),
                ),
                ValueListenableBuilder(
                  valueListenable: _controller,
                  builder: (context, v, _) => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var i = 0; i < _length; i++)
                        Container(
                          width: 46,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _error != null ? AppColors.error : (i < v.text.length ? AppColors.ink : AppColors.cardBorder),
                              width: i < v.text.length ? 1.6 : 1,
                            ),
                          ),
                          child: Text(i < v.text.length ? v.text[i] : '', style: AppText.h1.copyWith(fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
