import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter/services.dart';

import '../gen.dart' show gAlert, gToast;
import 'backend.dart';
import 'tp_ui.dart';

/// Carte « Vérifier mon numéro » : le numéro enregistré n'a aucun pouvoir (connexion par téléphone, récupération du mot de passe,
/// SMS et WhatsApp) tant que le code reçu par SMS n'a pas été saisi. Sans connexion au serveur ou numéro déjà vérifié : rien n'est affiché.
class PhoneVerifyCard extends StatefulWidget {
  const PhoneVerifyCard({super.key});
  @override
  State<PhoneVerifyCard> createState() => _PhoneVerifyCardState();
}

class _PhoneVerifyCardState extends State<PhoneVerifyCard> {
  final _code = TextEditingController();
  bool? _verified;
  bool _sent = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!Backend.ready) return;
    final v = await Backend.phoneVerified();
    if (mounted) setState(() => _verified = v);
  }

  Future<void> _request() async {
    setState(() => _busy = true);
    final e = await Backend.phoneVerifyRequest();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _sent = e == null;
    });
    if (e != null) {
      gAlert(context, 'Code non envoyé', e);
    } else {
      gToast(context, 'Code envoyé par SMS');
    }
  }

  Future<void> _confirm() async {
    if (_code.text.trim().length != 6) return gToast(context, 'Saisissez les 6 chiffres reçus.');
    setState(() => _busy = true);
    final e = await Backend.phoneVerifyConfirm(_code.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    if (e != null) return gAlert(context, 'Numéro non vérifié', e);
    setState(() => _verified = true);
    gToast(context, 'Numéro vérifié');
  }

  @override
  Widget build(BuildContext context) {
    if (!Backend.ready || _verified == null) return const SizedBox.shrink();
    if (_verified == true) {
      return TpCard(margin: const EdgeInsets.only(bottom: 8), child: Row(children: [const Icon(Icons.verified_outlined, size: 18, color: tpGrey), const SizedBox(width: 10), Expanded(child: Text('Numéro vérifié', style: tpSt(13.5, w: FontWeight.w600)))]));
    }
    return TpCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Numéro à vérifier', style: tpSt(14, w: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Tant qu’il n’est pas vérifié, ce numéro ne sert ni à la connexion par téléphone, ni à la récupération du mot de passe, ni aux notifications SMS et WhatsApp.', style: tpSt(12.5, c: tpGrey)),
        const SizedBox(height: 10),
        if (!_sent)
          TpButton('Recevoir un code par SMS', _busy ? null : _request, busy: _busy, compact: true)
        else ...[
          TpField('Code à 6 chiffres', _code, keyboard: TextInputType.number, maxLength: 6, formatters: [FilteringTextInputFormatter.digitsOnly]),
          const SizedBox(height: 6),
          TpButton('Vérifier', _busy ? null : _confirm, busy: _busy, compact: true),
          const SizedBox(height: 6),
          TpButton('Renvoyer le code', _busy ? null : _request, dark: false, compact: true),
        ],
      ]),
    );
  }
}
