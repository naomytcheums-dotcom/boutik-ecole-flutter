import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gToast;
import 'auth.dart';
import 'backend.dart';
import 'console.dart';
import 'entreprise.dart' show TableRows, dateCourte;
import 'store.dart' show selectedProductProvider;

/// Mes adresses (écran 27) et avis d'un produit (écran 31) : lecture directe des tables protégées par RLS (carnet d'adresses du titulaire,
/// avis publics) ; ajout et suppression d'adresse par les fonctions serveur save_address et delete_address.

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

final addressesProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('addresses', 'id,recipient,phone,city,district,line,landmark', order: 'created_at'));
final productReviewsProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('reviews', 'rating,comment,created_at,listings(title)', order: 'created_at'));

Widget _note(double w, String t, {double h = 140}) => Container(width: w, height: h, alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(t, textAlign: TextAlign.center, style: _st(13, c: _grey).copyWith(height: 1.5)));

String addressLine(Map<String, dynamic> a) => [a['line'], if ('${a['district'] ?? ''}'.isNotEmpty) a['district'], a['city'], if ('${a['landmark'] ?? ''}'.isNotEmpty) 'Repère : ${a['landmark']}'].join(', ');

class AddressBook extends ConsumerWidget {
  const AddressBook({super.key, this.width = 342, this.height = 600});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authProvider.select((a) => a.current == null))) return _note(width, 'Connectez-vous pour gérer vos adresses.');
    final rows = ref.watch(addressesProvider);
    if (rows == null) return _note(width, 'Chargement…');
    return SizedBox(
      width: width,
      height: height,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (ref.read(addressesProvider.notifier).error)
          _note(width, 'Vos adresses ne peuvent pas être chargées pour le moment.')
        else if (rows.isEmpty)
          _note(width, 'Aucune adresse enregistrée.\nAjoutez-en une pour accélérer vos livraisons.')
        else
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: rows.length,
              separatorBuilder: (_, _) => const Divider(height: 22, color: Color(0xFFF2EFF6)),
              itemBuilder: (_, i) {
                final a = rows[i];
                return Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${a['recipient']} · ${a['phone']}', style: _st(13.5, w: FontWeight.w700)), const SizedBox(height: 3), Text(addressLine(a), style: _st(12, c: _grey))])),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: 'Supprimer',
                    onPressed: () async {
                      final r = await Backend.rpc('delete_address', {'p_id': '${a['id']}'});
                      if (!context.mounted) return;
                      if (r.error != null) {
                        gToast(context, 'Suppression impossible : ${r.error}');
                        return;
                      }
                      await ref.read(addressesProvider.notifier).refresh();
                    },
                  ),
                ]);
              },
            ),
          ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => addAddressDialog(context, ref),
          child: Container(width: width, height: 50, alignment: Alignment.center, decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(25)), child: Text('Ajouter une adresse', style: _st(14, w: FontWeight.w700, c: Colors.white))),
        ),
      ]),
    );
  }
}

Future<void> addAddressDialog(BuildContext context, WidgetRef ref) async {
  final c = {for (final k in ['recipient', 'phone', 'city', 'district', 'line', 'landmark']) k: TextEditingController()};
  Widget f(String k, String label) => TextField(controller: c[k], decoration: InputDecoration(labelText: label));
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('Nouvelle adresse'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [f('recipient', 'Destinataire'), f('phone', 'Téléphone'), f('city', 'Ville'), f('district', 'Quartier'), f('line', 'Adresse'), f('landmark', 'Repère (facultatif)')])),
      actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Enregistrer'))],
    ),
  );
  if (ok != true || !context.mounted) return;
  final r = await Backend.rpc('save_address', {'p_id': null, 'p_recipient': c['recipient']!.text, 'p_phone': c['phone']!.text, 'p_city': c['city']!.text, 'p_district': c['district']!.text, 'p_line': c['line']!.text, 'p_landmark': c['landmark']!.text});
  if (!context.mounted) return;
  if (r.error != null) {
    gToast(context, 'Enregistrement impossible : ${r.error}');
    return;
  }
  await ref.read(addressesProvider.notifier).refresh();
}

/// Moyenne, répartition et commentaires des avis du produit choisi.
class ProductReviews extends ConsumerWidget {
  const ProductReviews({super.key, this.width = 342, this.height = 600});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = ref.watch(selectedProductProvider).title;
    final all = ref.watch(productReviewsProvider);
    if (all == null) return _note(width, 'Chargement…');
    final rows = [for (final r in all) if ('${(r['listings'] as Map?)?['title']}' == title) r];
    if (rows.isEmpty) return _note(width, 'Aucun avis pour « $title » pour le moment.\nSeuls les acheteurs d’une commande livrée peuvent en publier.');
    final avg = rows.fold<num>(0, (a, r) => a + (r['rating'] as num)) / rows.length;
    return SizedBox(
      width: width,
      height: height,
      child: ListView(padding: EdgeInsets.zero, children: [
        Text(avg.toStringAsFixed(1), style: _st(34, w: FontWeight.w800)),
        Text('${rows.length} avis', style: _st(12.5, c: _grey)),
        const SizedBox(height: 14),
        for (var s = 5; s >= 1; s--)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              SizedBox(width: 22, child: Text('$s', style: _st(12))),
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(minHeight: 7, value: rows.where((r) => r['rating'] == s).length / rows.length, backgroundColor: const Color(0xFFF2EFF6), color: const Color(0xFFF5A524)))),
              SizedBox(width: 30, child: Text('${rows.where((r) => r['rating'] == s).length}', textAlign: TextAlign.right, style: _st(11.5, c: _grey))),
            ]),
          ),
        const SizedBox(height: 18),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [for (var i = 0; i < 5; i++) Icon(i < (r['rating'] as num) ? Icons.star_rounded : Icons.star_outline_rounded, size: 16, color: const Color(0xFFF5A524)), const SizedBox(width: 8), Text(dateCourte(r['created_at']), style: _st(11, c: _grey))]),
              if ('${r['comment'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${r['comment']}', style: _st(13).copyWith(height: 1.5))),
            ]),
          ),
      ]),
    );
  }
}
