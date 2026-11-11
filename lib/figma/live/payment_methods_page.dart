import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gAlert, gToast;
import 'auth.dart' show authProvider, requireLogin;
import 'backend.dart';
import 'tp_ui.dart';

/// Moyens de paiement : numéros Orange Money et MTN MoMo du compte, avec un moyen par défaut utilisé à la commande.
class PaymentMethodsPage extends ConsumerStatefulWidget {
  const PaymentMethodsPage({super.key});
  @override
  ConsumerState<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

const _names = {'orange_money': 'Orange Money', 'mtn_momo': 'MTN Mobile Money'};

class _PaymentMethodsPageState extends ConsumerState<PaymentMethodsPage> {
  List<Map<String, dynamic>>? _rows;
  bool _error = false;
  String _provider = 'orange_money';
  final _phone = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await Backend.rows('payment_methods', 'id,provider,phone,is_default', order: 'created_at', ascending: true, limit: 20);
    if (!mounted) return;
    setState(() {
      _error = r.error != null;
      _rows = r.rows;
    });
  }

  /// Orange : 655-659 et 69x ; MTN : 650-654, 67x et 68x. Un numéro qui ne correspond pas à l'opérateur choisi est signalé.
  String? _mismatch(String ph) {
    if (ph.length != 9) return null;
    final p3 = int.tryParse(ph.substring(0, 3)) ?? 0;
    final orange = (p3 >= 655 && p3 <= 659) || (p3 >= 690 && p3 <= 699);
    final mtn = (p3 >= 650 && p3 <= 654) || (p3 >= 670 && p3 <= 689);
    if (_provider == 'orange_money' && mtn) return 'Ce numéro ressemble à un numéro MTN.';
    if (_provider == 'mtn_momo' && orange) return 'Ce numéro ressemble à un numéro Orange.';
    return null;
  }

  Future<void> _add() async {
    if (!await requireLogin(context, ref, 'enregistrer un moyen de paiement') || !mounted) return;
    var ph = _phone.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (ph.startsWith('237') && ph.length == 12) ph = ph.substring(3);
    if (!RegExp(r'^6\d{8}$').hasMatch(ph)) return gAlert(context, 'Numéro invalide', 'Saisissez 9 chiffres commençant par 6 (exemple : 6 99 99 99 99).');
    final warn = _mismatch(ph);
    setState(() => _busy = true);
    final r = await Backend.rpc('save_payment_method', {'p_provider': _provider, 'p_phone': ph, 'p_default': false});
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.error != null) return gAlert(context, 'Enregistrement impossible', Backend.userMessage(r.error!));
    _phone.clear();
    gToast(context, warn == null ? 'Moyen de paiement enregistré.' : 'Enregistré. $warn Vérifiez l’opérateur.');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final signed = ref.watch(authProvider.select((a) => a.current != null));
    return TpPage(
      title: 'Moyens de paiement',
      subtitle: 'Mobile Money',
      children: [
        if (!signed)
          const TpEmpty(title: 'Connexion requise', text: 'Connectez-vous pour gérer vos moyens de paiement.', icon: Icons.lock_outline)
        else ...[
          tpSection('Mes moyens', hint: 'Le moyen par défaut est proposé en premier à la commande.'),
          if (_rows == null)
            const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
          else if (_error)
            const TpEmpty(title: 'Lecture impossible', text: 'Vos moyens de paiement ne peuvent pas être chargés pour le moment.', icon: Icons.cloud_off_rounded)
          else if (_rows!.isEmpty)
            tpNote('Aucun moyen de paiement enregistré. Ajoutez votre numéro ci-dessous.')
          else
            for (final m in _rows!)
              TpCard(
                child: Row(children: [
                  Container(width: 42, height: 42, decoration: BoxDecoration(color: m['provider'] == 'orange_money' ? const Color(0xFFFFE6CC) : const Color(0xFFFFF3B0), shape: BoxShape.circle), child: const Icon(Icons.phone_android, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_names['${m['provider']}'] ?? '${m['provider']}', style: tpSt(14, w: FontWeight.w700)),
                    Text('+237 ${m['phone']}', style: tpSt(12.5, c: tpGrey)),
                  ])),
                  if (m['is_default'] == true)
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFDDF5EC), borderRadius: BorderRadius.circular(10)), child: Text('Par défaut', style: tpSt(11, w: FontWeight.w700, c: tpGreen)))
                  else
                    TextButton(onPressed: () async { await Backend.rpc('set_default_payment_method', {'p_id': m['id']}); await _load(); }, child: Text('Par défaut', style: tpSt(12, w: FontWeight.w700, c: tpViolet))),
                  IconButton(tooltip: 'Supprimer', icon: const Icon(Icons.delete_outline, size: 20), onPressed: () async { await Backend.rpc('delete_payment_method', {'p_id': m['id']}); await _load(); }),
                ]),
              ),
          tpSection('Ajouter un numéro'),
          Row(children: [
            for (final e in _names.entries)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _provider = e.key),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: _provider == e.key ? tpInk : const Color(0xB3FFFFFF), borderRadius: BorderRadius.circular(20)), child: Text(e.value, style: tpSt(12.5, w: FontWeight.w700, c: _provider == e.key ? Colors.white : tpInk))),
                ),
              ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 +]')), LengthLimitingTextInputFormatter(16)],
            decoration: InputDecoration(prefixText: '+237  ', hintText: '6XX XX XX XX', filled: true, fillColor: const Color(0xCCFFFFFF), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: tpLine))),
          ),
          const SizedBox(height: 14),
          TpButton('Enregistrer ce numéro', _busy ? null : _add, busy: _busy),
          tpNote('Aucun code secret n’est jamais demandé ici : la confirmation du paiement se fait sur votre téléphone, au moment de la commande.'),
        ],
      ],
    );
  }
}

/// Moyen de paiement par défaut du compte (opérateur et numéro), ou null : proposé en premier à la commande.
final defaultPaymentProvider = FutureProvider.autoDispose<({String provider, String phone})?>((ref) async {
  if (!Backend.ready || ref.watch(authProvider.select((a) => a.current == null))) return null;
  final r = await Backend.rows('payment_methods', 'provider,phone,is_default', order: 'created_at', ascending: true, limit: 20);
  for (final x in r.rows) {
    if (x['is_default'] == true) return (provider: '${x['provider']}', phone: '${x['phone']}');
  }
  return null;
});
