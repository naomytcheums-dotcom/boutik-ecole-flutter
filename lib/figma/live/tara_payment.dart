import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../gen.dart' show gAlert, gToast;
import '../i18n.dart' show Text;
import 'auth.dart';
import 'marche/marche_data.dart';

/// Paiement Mobile Money (MTN / Orange) via Tara Money. La transaction est créée côté serveur (le montant vient toujours de la base) ;
/// la confirmation vient uniquement du fournisseur (webhook) : l'application attend et vérifie, elle ne confirme jamais elle-même.

/// Numéro camerounais au format attendu « 2376XXXXXXXX » (accepte 6XXXXXXXX, +237…, espaces) ; null si invalide.
String? taraPhone(String raw) {
  var d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.length == 9 && d.startsWith('6')) d = '237$d';
  return RegExp(r'^2376\d{8}$').hasMatch(d) ? d : null;
}

/// Réseau conseillé d'après le préfixe : 650-654, 67x, 68x → MTN ; 655-659, 69x → Orange (indicatif, modifiable par la personne).
String guessNetwork(String phone) {
  final n = phone.length >= 6 ? phone.substring(3, 6) : '';
  if (RegExp(r'^(67\d|68\d|65[0-4])$').hasMatch(n)) return 'MTN';
  return 'ORANGE';
}

Future<String> _status(String reference) async {
  final r = await marcheCall('my_payments', const {});
  if (r.error != null) return 'unknown';
  for (final x in (r.data as List? ?? const [])) {
    if (x is Map && '${x['reference']}' == reference) return '${x['status']}';
  }
  return 'unknown';
}

/// Demande le réseau et le numéro, lance le débit puis attend la confirmation du fournisseur. Renvoie vrai si le paiement est confirmé.
Future<bool> payWithTara(BuildContext context, WidgetRef ref, {required String reference, required int amount, required String label}) async {
  final phoneCtl = TextEditingController(text: ref.read(authProvider).current?.phone ?? '');
  var network = guessNetwork(taraPhone(phoneCtl.text) ?? '');
  final go = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setS) => AlertDialog(
        title: Text('Payer $label'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${amount.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ')} FCFA par Mobile Money', style: mst(14, w: FontWeight.w800)),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'MTN', label: Text('MTN MoMo')), ButtonSegment(value: 'ORANGE', label: Text('Orange Money'))],
            selected: {network},
            onSelectionChanged: (s) => setS(() => network = s.first),
          ),
          const SizedBox(height: 12),
          TextField(controller: phoneCtl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Numéro Mobile Money', hintText: '6XXXXXXXX'), onChanged: (v) => setS(() { final p = taraPhone(v); if (p != null) network = guessNetwork(p); })),
          const SizedBox(height: 8),
          Text('Vous validerez le paiement sur votre téléphone avec votre code secret.', style: mst(12, c: kGrey)),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Annuler')), TextButton(onPressed: () => Navigator.pop(c, true), child: Text('Payer'))],
      ),
    ),
  );
  final phone = taraPhone(phoneCtl.text);
  phoneCtl.dispose();
  if (go != true || !context.mounted) return false;
  if (phone == null) {
    gAlert(context, 'Numéro invalide', 'Saisissez un numéro camerounais : 6XXXXXXXX.');
    return false;
  }
  try {
    final r = await Supabase.instance.client.functions.invoke('tara-pay', body: {'reference': reference, 'network': network, 'phone': phone});
    final d = r.data;
    if (d is Map && '${d['status']}' == 'confirmed') return true;
  } on FunctionException catch (e) {
    final d = e.details;
    if (context.mounted) gAlert(context, 'Paiement non démarré', d is Map && d['message'] != null ? '${d['message']}' : 'Le paiement n’a pas pu démarrer (code ${e.status}). Réessayez ou demandez l’activation à l’administrateur.');
    return false;
  } catch (_) {
    if (context.mounted) gAlert(context, 'Paiement non démarré', 'Le service de paiement ne répond pas. Réessayez dans un instant ou demandez l’activation à l’administrateur.');
    return false;
  }
  if (!context.mounted) return false;
  // attente de la confirmation du fournisseur (au plus 2 minutes 30)
  var cancelled = false;
  final waiting = showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (c) => AlertDialog(
      title: Text('Validez sur votre téléphone'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 14),
        Text('Un message de ${network == 'MTN' ? 'MTN MoMo' : 'Orange Money'} vous demande de confirmer le paiement avec votre code secret.', textAlign: TextAlign.center),
      ]),
      actions: [TextButton(onPressed: () { cancelled = true; Navigator.pop(c); }, child: Text('Fermer'))],
    ),
  );
  var result = 'pending';
  for (var i = 0; i < 38 && !cancelled && context.mounted; i++) {
    await Future<void>.delayed(const Duration(seconds: 4));
    result = await _status(reference);
    if (result == 'confirmed' || result == 'failed' || result == 'cancelled') break;
  }
  if (context.mounted && !cancelled) Navigator.of(context, rootNavigator: true).pop();
  await waiting;
  if (!context.mounted) return result == 'confirmed';
  await gAlert(context, result == 'confirmed' ? 'Paiement confirmé' : (result == 'failed' || result == 'cancelled') ? 'Paiement non abouti' : 'Paiement en attente', result == 'confirmed' ? 'Merci ! Votre paiement est enregistré.' : (result == 'failed' || result == 'cancelled') ? 'Le paiement n’a pas abouti. Vous pouvez réessayer.' : 'Le forfait s’activera dès la confirmation du paiement.');
  return result == 'confirmed';
}
