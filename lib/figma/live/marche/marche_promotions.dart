import '../form_options.dart' show pickDate;
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../gen.dart' show gToast;
import '../../i18n.dart' show Text;
import '../backend.dart';
import '../promo_state.dart' show marcheAutoPromoProvider, promoDiscountProvider;
import 'marche_data.dart';
import 'marche_widgets.dart';

/// Promotions de la plateforme (réservé à l'administrateur) : Nouvel An, Pâques, fête du travail…
/// L'administrateur choisit le nom, le code, la réduction et la période. Une promotion « automatique » s'applique d'elle-même
/// à chaque commande pendant sa période : le champ du code promo des clients est alors rempli et verrouillé.

final marchePlatformPromosProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final r = await marcheCall('platform_promos', const {});
  if (r.error != null) throw MarcheException(r.error);
  return [for (final x in (r.data as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
});

String _date(Object? v) {
  final d = DateTime.tryParse('$v')?.toLocal();
  if (d == null) return '';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class PromotionsAdminScreen extends ConsumerWidget {
  const PromotionsAdminScreen({super.key});

  void _refresh(WidgetRef ref) {
    ref.invalidate(marchePlatformPromosProvider);
    ref.invalidate(marcheAutoPromoProvider);
    ref.invalidate(promoDiscountProvider);
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final label = TextEditingController(), code = TextEditingController(), value = TextEditingController(), min = TextEditingController();
    var percent = true, auto = true;
    var from = DateTime.now(), to = DateTime.now().add(const Duration(days: 7));
    InputDecoration deco(String l, {String? hint}) => InputDecoration(labelText: l, hintText: hint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)));
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(c).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Nouvelle promotion', style: mst(18, w: FontWeight.w800)),
              const SizedBox(height: 14),
              TextField(controller: label, decoration: deco('Nom', hint: 'Ex. Nouvel An, Pâques, Fête du travail')),
              const SizedBox(height: 12),
              TextField(controller: code, textCapitalization: TextCapitalization.characters, decoration: deco('Code', hint: 'Ex. NOUVELAN (3 à 20 lettres ou chiffres)')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: MDropdown(label: 'Type', value: percent ? 'percent' : 'fixed', items: const {'percent': 'Pourcentage', 'fixed': 'Montant fixe (FCFA)'}, onChanged: (v) => set(() => percent = v == 'percent'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: value, keyboardType: TextInputType.number, decoration: deco(percent ? 'Réduction (%)' : 'Réduction (FCFA)', hint: percent ? '15 ou 20' : '2000'))),
              ]),
              const SizedBox(height: 12),
              TextField(controller: min, keyboardType: TextInputType.number, decoration: deco('Montant minimum du panier (FCFA, facultatif)')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: mButton('Début : ${_date(from.toIso8601String())}', () async {
                    final d = await pickDate(context: c, initialDate: from, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 730)));
                    if (d != null) set(() => from = d);
                  }, dark: false),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: mButton('Fin : ${_date(to.toIso8601String())}', () async {
                    final d = await pickDate(context: c, initialDate: to.isBefore(from) ? from : to, firstDate: from, lastDate: DateTime.now().add(const Duration(days: 1095)));
                    if (d != null) set(() => to = d);
                  }, dark: false),
                ),
              ]),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Appliquer automatiquement', style: mst(13.5, w: FontWeight.w700)),
                subtitle: Text('Le code est rempli et verrouillé dans le panier de chaque client pendant la période.', style: mst(12, c: kGrey)),
                value: auto,
                onChanged: (v) => set(() => auto = v),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: mButton('Annuler', () => Navigator.pop(c, false), dark: false)),
                const SizedBox(width: 12),
                Expanded(child: mButton('Créer', () => Navigator.pop(c, true))),
              ]),
            ]),
          ),
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    int? digits(String s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), ''));
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59);
    final r = await marcheCall('platform_promo_save', {
      'p_label': label.text,
      'p_code': code.text,
      'p_kind': percent ? 'percent' : 'fixed',
      'p_value': digits(value.text),
      'p_starts': start.toUtc().toIso8601String(),
      'p_ends': end.toUtc().toIso8601String(),
      'p_min': digits(min.text) ?? 0,
      'p_auto': auto,
      'p_active': true,
    });
    if (!context.mounted) return;
    gToast(context, r.error != null ? Backend.userMessage('${r.error}') : 'Promotion enregistrée.');
    _refresh(ref);
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, Map<String, dynamic> p) async {
    final r = await marcheCall('platform_promo_toggle', {'p_id': p['id'], 'p_active': p['active'] != true});
    if (!context.mounted) return;
    if (r.error != null) gToast(context, Backend.userMessage('${r.error}'));
    _refresh(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MarchePage(
      title: 'Promotions',
      child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), child: mButton('Nouvelle promotion', () => _create(context, ref), icon: Icons.add)),
        mAsync<List<Map<String, dynamic>>>(
          ref.watch(marchePlatformPromosProvider),
          (l) => l.isEmpty
              ? mNote('Aucune promotion créée.\nCréez-en une pour le Nouvel An, Pâques ou la fête du travail : elle s’applique toute seule pendant sa période.')
              : Column(children: [
                  for (final p in l)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: kLine)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text('${p['label'] ?? p['code']}', style: mst(15, w: FontWeight.w800))),
                          Text(p['kind'] == 'percent' ? '−${p['value']} %' : '−${mFcfa(p['value'])}', style: mst(15, w: FontWeight.w800, c: kViolet)),
                        ]),
                        const SizedBox(height: 4),
                        Text('Code ${p['code']} · du ${_date(p['starts_at'])} au ${_date(p['ends_at'])}${mInt(p['min_amount']) > 0 ? ' · dès ${mFcfa(p['min_amount'])}' : ''}', style: mst(12, c: kGrey)),
                        Text('${p['auto_apply'] == true ? 'Automatique' : 'Sur saisie du code'} · ${mInt(p['used_count'])} utilisation${mInt(p['used_count']) > 1 ? 's' : ''}', style: mst(12, c: kGrey)),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(child: Text(p['active'] == true ? 'Active' : 'Désactivée', style: mst(12.5, w: FontWeight.w700, c: p['active'] == true ? kGreen : kRed))),
                          SizedBox(width: 150, child: mButton(p['active'] == true ? 'Désactiver' : 'Activer', () => _toggle(context, ref, p), dark: false)),
                        ]),
                      ]),
                    ),
                ]),
        ),
      ]),
    );
  }
}
