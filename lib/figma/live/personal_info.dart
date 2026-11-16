import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gAlert, gToast;
import '../nav.dart' show gOpen;
import 'auth.dart' show Account, authProvider, normPhone, parseBirth, validName, validPhone;
import 'backend.dart';
import 'phone_verify.dart';
import 'tp_ui.dart';

String _frDate(String iso) {
  final d = parseBirth(iso);
  if (d == null) return '';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// « Informations personnelles » (Paramètres) : nom, téléphone et date de naissance du compte connecté.
/// L'e-mail est celui de la connexion : il se change par la procédure de sécurité, pas ici. Un téléphone déjà enregistré
/// n'est pas remplacé ici (le serveur le refuse) : il se renseigne seulement s'il est vide.
class PersonalInfoPage extends ConsumerStatefulWidget {
  const PersonalInfoPage({super.key});
  @override
  ConsumerState<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends ConsumerState<PersonalInfoPage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _birth = TextEditingController();
  Account? _loaded;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _birth.dispose();
    super.dispose();
  }

  void _fill(Account a) {
    if (_loaded?.serverId == a.serverId && _loaded != null) return;
    _loaded = a;
    _name.text = a.name;
    _birth.text = _frDate(a.birth);
  }

  Future<void> _save(Account a) async {
    final nameErr = validName(_name.text);
    if (nameErr != null) return gAlert(context, 'Nom invalide', nameErr);
    final hasPhone = normPhone(a.phone).isNotEmpty;
    final newPhone = hasPhone ? '' : normPhone(_phone.text);
    if (!hasPhone && newPhone.isNotEmpty) {
      final e = validPhone(newPhone);
      if (e != null) return gAlert(context, 'Numéro invalide', e);
    }
    final birthText = _birth.text.trim();
    final birth = birthText.isEmpty ? null : parseBirth(birthText);
    if (birthText.isNotEmpty && birth == null) {
      return gAlert(context, 'Date invalide', 'Écrivez la date au format JJ/MM/AAAA, par exemple 07/03/2002.');
    }
    final clearBirth = birthText.isEmpty && a.birth.trim().isNotEmpty;
    final sameBirth = (birth == null ? '' : _frDate(birth.toIso8601String().substring(0, 10))) == _frDate(a.birth);
    if (_name.text.trim() == a.name.trim() && newPhone.isEmpty && sameBirth && !clearBirth) {
      return gToast(context, 'Aucune modification à enregistrer.');
    }
    setState(() => _busy = true);
    final r = await Backend.updatePersonal(a, name: _name.text.trim(), phone: newPhone, birth: birth, clearBirth: clearBirth);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.account != null) {
      ref.read(authProvider.notifier).update(r.account!);
      _loaded = r.account;
      if (r.error == null) _phone.clear();
    }
    if (r.error != null || r.account == null) {
      return gAlert(context, 'Informations non enregistrées', r.error ?? 'Réessayez dans un instant.');
    }
    gToast(context, 'Informations enregistrées');
  }

  @override
  Widget build(BuildContext context) {
    final a = ref.watch(authProvider.select((s) => s.current));
    if (a == null) {
      return const TpPage(
        title: 'Informations personnelles',
        children: [TpEmpty(title: 'Connexion requise', text: 'Connectez-vous pour consulter et modifier vos informations.', icon: Icons.lock_outline)],
      );
    }
    _fill(a);
    final hasPhone = normPhone(a.phone).isNotEmpty;
    return TpPage(
      title: 'Informations personnelles',
      subtitle: 'Visibles par vous seul, sauf votre nom',
      children: [
        TpField('Nom complet', _name, required: true, maxLength: 80),
        if (hasPhone) ...[
          Text('Téléphone', style: tpSt(12.5, w: FontWeight.w600)),
          const SizedBox(height: 6),
          TpCard(margin: const EdgeInsets.only(bottom: 4), child: Row(children: [const Icon(Icons.lock_outline, size: 18, color: tpGrey), const SizedBox(width: 10), Text('+237 ${normPhone(a.phone)}', style: tpSt(14))])),
          tpNote('Ce numéro est enregistré et ne se change pas ici : contactez le support (Aide et support) pour le remplacer.'),
                    const PhoneVerifyCard(),
        ] else ...[
          TpField('Téléphone', _phone, keyboard: TextInputType.phone, formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 +]')), LengthLimitingTextInputFormatter(16)]),
          tpNote('9 chiffres commençant par 6. Une fois enregistré, le numéro ne se modifie plus ici.'),
        ],
        const SizedBox(height: 10),
        Text('Adresse e-mail', style: tpSt(12.5, w: FontWeight.w600)),
        const SizedBox(height: 6),
        TpCard(margin: const EdgeInsets.only(bottom: 4), child: Row(children: [const Icon(Icons.lock_outline, size: 18, color: tpGrey), const SizedBox(width: 10), Expanded(child: Text(a.email.isEmpty ? 'Aucune adresse enregistrée' : a.email, style: tpSt(14)))])),
        tpNote('L’adresse e-mail est celle de votre connexion : elle ne se modifie pas depuis cet écran.'),
        const SizedBox(height: 10),
        TpField('Date de naissance (JJ/MM/AAAA)', _birth, keyboard: TextInputType.datetime, maxLength: 10, formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9/.-]'))]),
        const SizedBox(height: 6),
        TpButton('Enregistrer', _busy ? null : () => _save(a), busy: _busy),
        const SizedBox(height: 14),
        TpButton('Mes données : export et suppression', () => gOpen(context, '273'), dark: false, compact: true),
      ],
    );
  }
}
