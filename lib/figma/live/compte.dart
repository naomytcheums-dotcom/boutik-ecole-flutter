import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gToast;
import 'geo_stub.dart' if (dart.library.js_interop) 'geo_web.dart';
import 'auth.dart';
import 'backend.dart';
import 'console.dart';
import 'delivery.dart' show transientAddressProvider;
import 'entreprise.dart' show TableRows, dateCourte;
import 'store.dart' show selectedProductProvider;

/// Mes adresses (écran 27) et avis d'un produit (écran 31) : lecture directe des tables protégées par RLS (carnet d'adresses du titulaire,
/// avis publics) ; ajout et suppression d'adresse par les fonctions serveur save_address et delete_address.

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

final addressesProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('addresses', 'id,recipient,phone,city,district,line,landmark', order: 'created_at'));

/// Avis publics d'une annonce (lecture ouverte aux visiteurs par la fonction serveur `product_reviews`, filtrée par titre côté serveur).
final productReviewsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, title) async {
  final r = await Backend.rpc('product_reviews', {'p_title': title});
  if (r.error != null || r.data is! List) throw StateError('product_reviews');
  return [for (final x in r.data as List) Map<String, dynamic>.from(x as Map)];
}, retry: (_, _) => null);

Widget _note(double w, String t, {double h = 140}) => Container(width: w, height: h, alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(t, textAlign: TextAlign.center, style: _st(13, c: _grey).copyWith(height: 1.5)));

String addressLine(Map<String, dynamic> a) => [a['line'], if ('${a['district'] ?? ''}'.isNotEmpty) a['district'], a['city'], if ('${a['landmark'] ?? ''}'.isNotEmpty && !'${a['landmark']}'.startsWith('GPS')) 'Repère : ${a['landmark']}'].join(', ');

class AddressBook extends ConsumerWidget {
  const AddressBook({super.key, this.width = 342, this.height = 600});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authProvider.select((a) => a.current == null))) return _note(width, 'Connectez-vous pour gérer vos adresses.');
    final temp = ref.watch(transientAddressProvider);
    final all = ref.watch(addressesProvider);
    final rows = all == null ? null : [for (final a in all) if ('${a['id']}' != temp) a];
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

/// Fenêtre « Nouvelle adresse » : la position réelle de l'appareil remplit ville, quartier et rue ; le nom et le téléphone viennent du profil.
/// Tout reste modifiable à la main si la personne le souhaite.
Future<void> addAddressDialog(BuildContext context, WidgetRef ref) async {
  final me = ref.read(authProvider).current;
  final c = {
    'recipient': TextEditingController(text: me?.name ?? ''),
    'phone': TextEditingController(text: me?.phone ?? ''),
    'city': TextEditingController(),
    'district': TextEditingController(),
    'line': TextEditingController(),
  };
  GeoPlace? place;
  var gen = 0; // change quand la position détectée remplit le quartier : le champ est recréé avec la nouvelle valeur
  String status = 'search';
  var started = false;
  Future<void> locate(StateSetter set) async {
    set(() => status = 'search');
    final r = await detectPlace();
    place = r.place;
    if (r.place != null) {
      final p = r.place!;
      if (p.city.isNotEmpty) c['city']!.text = p.city;
      if (p.district.isNotEmpty) c['district']!.text = p.district;
      if (p.line.isNotEmpty) c['line']!.text = p.line;
    }
    set(() {
      gen++;
      status = r.status;
    });
  }

  Widget district() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Autocomplete<String>(
          key: ValueKey('district$gen'),
          initialValue: TextEditingValue(text: c['district']!.text),
          optionsBuilder: (v) async {
            final city = c['city']!.text.trim();
            if (city.length < 2) return const <String>[];
            final r = await Backend.rpc('suggest_districts', {'p_city': city, 'p_q': v.text, 'p_limit': 8});
            if (r.error != null || r.data is! List) return const <String>[];
            return [for (final x in r.data as List) '${(x as Map)['name']}'];
          },
          onSelected: (v) => c['district']!.text = v,
          fieldViewBuilder: (ctx, ctrl, focus, submit) => TextField(
            controller: ctrl,
            focusNode: focus,
            style: _st(14),
            onChanged: (v) => c['district']!.text = v,
            decoration: InputDecoration(
              labelText: 'Quartier',
              labelStyle: _st(13, c: _grey),
              helperText: 'Pas dans la liste ? Saisissez-le : il sera proposé aux prochains clients.',
              helperMaxLines: 2,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
        ),
      );

  Widget f(String k, String label, {TextInputType? kb}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c[k],
          keyboardType: kb,
          style: _st(14),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: _st(13, c: _grey),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
      );

  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => StatefulBuilder(builder: (d, set) {
      if (!started) {
        started = true;
        locate(set);
      }
      final msg = switch (status) {
        'search' => 'Recherche de votre position…',
        'ok' => place == null ? '' : 'Position détectée automatiquement. Corrigez-la si besoin.',
        'denied' => 'Localisation refusée : autorisez-la dans votre navigateur ou saisissez l’adresse.',
        'unsupported' => 'La localisation n’est pas disponible sur cet appareil : saisissez l’adresse.',
        _ => 'Position introuvable : activez le GPS ou saisissez l’adresse.',
      };
      return Dialog(
        backgroundColor: const Color(0xFFF4EFF8),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Nouvelle adresse', style: _st(20, w: FontWeight.w800)),
              const SizedBox(height: 12),
              Row(children: [
                Icon(status == 'ok' ? Icons.my_location : Icons.location_searching, size: 18, color: status == 'ok' ? const Color(0xFF2E9E5B) : _grey),
                const SizedBox(width: 8),
                Expanded(child: Text(msg, style: _st(12, c: _grey).copyWith(height: 1.4))),
              ]),
              const SizedBox(height: 14),
              f('recipient', 'Nom du destinataire'),
              f('phone', 'Téléphone', kb: TextInputType.phone),
              f('city', 'Ville'),
              district(),
              f('line', 'Adresse'),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: status == 'search' ? null : () => locate(set),
                  icon: const Icon(Icons.my_location, size: 18),
                  label: Text('Utiliser ma position actuelle', style: _st(13, w: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(d, false), child: Text('Annuler', style: _st(13.5, c: _grey))),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _ink, shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14)),
                  onPressed: () => Navigator.pop(d, true),
                  child: Text('Enregistrer', style: _st(13.5, w: FontWeight.w700, c: Colors.white)),
                ),
              ]),
            ]),
          ),
        ),
      );
    }),
  );
  if (ok != true || !context.mounted) return;
  if (c['city']!.text.trim().isEmpty || c['line']!.text.trim().isEmpty) {
    gToast(context, 'Indiquez au moins la ville et l’adresse.');
    return;
  }
  final gps = place == null ? '' : 'GPS ${place!.lat.toStringAsFixed(6)},${place!.lon.toStringAsFixed(6)}';
  final r = await Backend.rpc('save_address', {'p_id': null, 'p_recipient': c['recipient']!.text, 'p_phone': c['phone']!.text, 'p_city': c['city']!.text, 'p_district': c['district']!.text, 'p_line': c['line']!.text, 'p_landmark': gps});
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
    final async = ref.watch(productReviewsProvider(title));
    if (async.isLoading && !async.hasValue) return _note(width, 'Chargement…');
    if (async.hasError && !async.hasValue) return _note(width, 'Les avis ne peuvent pas être chargés pour le moment.');
    final rows = async.value ?? const <Map<String, dynamic>>[];
    if (rows.isEmpty) return _note(width, 'Aucun avis pour « $title » pour le moment.\nSeuls les acheteurs d’une commande payée, dont l’article a été préparé, peuvent en publier.');
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
