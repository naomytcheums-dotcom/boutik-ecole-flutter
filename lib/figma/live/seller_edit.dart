import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../gen.dart';
import '../nav.dart';
import 'auth.dart';
import 'backend.dart';
import 'seller.dart';
import 'store.dart';

/// Modification d'une annonce du vendeur (écran 60) : titre, prix, stock, description, photos, suppression, soumission.
/// Tout est enregistré sur le serveur ; la propriété et les transitions de statut sont contrôlées par la base (RLS + déclencheurs).

/// Annonce ouverte depuis « Mon catalogue » (titre).
final selectedListingProvider = NotifierProvider<StrV, String>(StrV.new);

final currentListingProvider = Provider<Listing?>((ref) {
  final all = ref.watch(listingsProvider);
  final t = ref.watch(selectedListingProvider);
  for (final l in all) {
    if (l.title == t) return l;
  }
  return all.isEmpty ? null : all.first;
});

const _ink = Color(0xFF111015);
const _mute = Color(0xFF66636E);

TextStyle _t(double s, FontWeight w, Color c) => TextStyle(inherit: false, fontFamily: 'PlusJakartaSans', fontSize: s, fontWeight: w, color: c, textBaseline: TextBaseline.alphabetic);

Widget _live(double x, double y, double w, double h, Widget Function(Listing l) build) => gP(
      x, y, w, h,
      Consumer(builder: (context, ref, _) {
        final l = ref.watch(currentListingProvider);
        return l == null ? const SizedBox.shrink() : build(l);
      }),
      show: !demoContent,
    );

Widget listingTitleLive() => _live(24, 388, 345, 28, (l) => Text(l.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _t(22, FontWeight.w800, _ink)));

Widget listingPriceLive() => _live(24, 420, 345, 19, (l) => Text('${fcfa(l.price)} · ${l.category}', style: _t(13, FontWeight.w400, _mute)));

Widget listingDescLive() => _live(24, 493, 345, 60, (l) => Text(l.description.isEmpty ? 'Aucune description.' : l.description, maxLines: 3, overflow: TextOverflow.ellipsis, style: _t(13, FontWeight.w400, l.description.isEmpty ? const Color(0xFF9A98A3) : const Color(0xFF4A4854)).copyWith(height: 1.55)));

Widget listingStockLive() => _live(250, 560, 100, 16, (l) => Align(alignment: Alignment.centerRight, child: Text('${l.stock} unité${l.stock > 1 ? 's' : ''}', style: _t(12.5, FontWeight.w600, _ink))));

Widget listingStatusLive() => _live(230, 628, 120, 16, (l) => Align(alignment: Alignment.centerRight, child: Text(l.label, style: _t(12.5, FontWeight.w600, _ink))));

/// Note de refus du département, visible du vendeur.
Widget listingNoteLive() => _live(24, 656, 342, 20, (l) => l.rejected && l.note.isNotEmpty ? Text('Motif du refus : ${l.note}', maxLines: 1, overflow: TextOverflow.ellipsis, style: _t(12, FontWeight.w600, const Color(0xFFD64545))) : const SizedBox.shrink());

Widget listingHeroLive() => _live(
      24, 174, 342, 200,
      (l) => ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: l.images.isEmpty
            ? Container(
                color: const Color(0xFFEDE9F6),
                alignment: Alignment.center,
                child: Text('Aucune photo\nTouchez « Modifier » pour en ajouter', textAlign: TextAlign.center, style: _t(13, FontWeight.w500, _mute).copyWith(height: 1.5)),
              )
            : Image.network(Backend.listingImageUrl(l.images.first), fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: const Color(0xFFEDE9F6), alignment: Alignment.center, child: Text('Photo indisponible', style: _t(13, FontWeight.w500, _mute)))),
      ),
    );

/// « Publier » : soumet l'annonce au département (brouillon ou refusée → en validation).
Future<void> submitCurrentListing(WidgetRef ref, BuildContext context) async {
  final l = ref.read(currentListingProvider);
  if (l == null) return gToast(context, 'Aucune annonce sélectionnée.');
  if (l.status == 'approved') return gToast(context, 'Cette annonce est déjà publiée.');
  if (l.status == 'pending') return gToast(context, 'Cette annonce est déjà en validation.');
  if (!Backend.ready) return gToast(context, 'La publication nécessite la connexion au serveur.');
  final err = await ref.read(listingsProvider.notifier).submit(l.title);
  if (!context.mounted) return;
  if (err != null) return gAlert(context, 'Annonce non soumise', err);
  gToast(context, 'Annonce envoyée en validation au département');
}

/// Dialogue « Modifier » : champs de l'annonce, photos (ajout / suppression), suppression de l'annonce.
Future<void> editListingDialog(BuildContext context, WidgetRef ref) async {
  final l0 = ref.read(currentListingProvider);
  if (l0 == null) return gToast(context, 'Aucune annonce sélectionnée.');
  if (!Backend.ready) return gToast(context, 'La modification nécessite la connexion au serveur.');
  final title = TextEditingController(text: l0.title);
  final price = TextEditingController(text: '${l0.price}');
  final stock = TextEditingController(text: '${l0.stock}');
  final desc = TextEditingController(text: l0.description);
  String? error;
  var busy = false;
  var images = [...l0.images];
  var gone = false;
  const st = TextStyle(inherit: false, fontFamily: 'PlusJakartaSans', fontSize: 13.5, color: _ink, textBaseline: TextBaseline.alphabetic);
  InputDecoration deco(String h) => InputDecoration(hintText: h, hintStyle: st.copyWith(color: const Color(0xFF9A98A3)), isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)));

  await gDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        Future<void> addPhoto() async {
          if (images.length >= 8) return set(() => error = '8 photos maximum.');
          try {
            final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
            if (x == null) return;
            final name = x.name.toLowerCase();
            final mime = x.mimeType ?? (name.endsWith('.png') ? 'image/png' : (name.endsWith('.webp') ? 'image/webp' : 'image/jpeg'));
            if (!['image/jpeg', 'image/png', 'image/webp'].contains(mime)) return set(() => error = 'Format accepté : JPEG, PNG ou WebP.');
            final bytes = await x.readAsBytes();
            if (bytes.length > 5 * 1024 * 1024) return set(() => error = 'Photo trop lourde (5 Mo maximum).');
            set(() {
              busy = true;
              error = null;
            });
            final r = await ref.read(listingsProvider.notifier).addImage(l0.title, bytes, x.name, mime);
            set(() {
              busy = false;
              if (r.error != null) {
                error = r.error;
              } else {
                images = r.images;
              }
            });
          } catch (_) {
            set(() => error = 'Impossible d’ajouter cette photo.');
          }
        }

        Future<void> save() async {
          final p = int.tryParse(price.text.replaceAll(RegExp(r'[\s ]'), ''));
          final s = int.tryParse(stock.text.trim());
          if (title.text.trim().length < 3) return set(() => error = 'Le titre doit comporter au moins 3 caractères.');
          if (p == null || p < 500) return set(() => error = 'Le prix doit être d’au moins 500 FCFA.');
          if (s == null || s < 0) return set(() => error = 'Le stock doit être un nombre entier positif.');
          set(() {
            busy = true;
            error = null;
          });
          final err = await ref.read(listingsProvider.notifier).edit(l0.title, title2: title.text.trim(), price: p, stock: s, description: desc.text.trim());
          if (err != null) return set(() {
                busy = false;
                error = err;
              });
          ref.read(selectedListingProvider.notifier).set(title.text.trim());
          if (ctx.mounted) Navigator.of(ctx).pop();
        }

        Future<void> remove() async {
          final ok = await gDialog<bool>(
            context: ctx,
            builder: (c2) => AlertDialog(
              backgroundColor: Colors.white,
              title: Text('Supprimer cette annonce ?', style: st.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
              content: Text('Elle ne sera plus visible des acheteurs. Les commandes déjà passées ne sont pas affectées.', style: st),
              actions: [
                TextButton(onPressed: () => Navigator.of(c2).pop(false), child: Text('Annuler', style: st)),
                TextButton(onPressed: () => Navigator.of(c2).pop(true), child: Text('Supprimer', style: st.copyWith(color: const Color(0xFFD64545), fontWeight: FontWeight.w700))),
              ],
            ),
          );
          if (ok != true) return;
          set(() => busy = true);
          final err = await ref.read(listingsProvider.notifier).remove(l0.title);
          if (err != null) return set(() {
                busy = false;
                error = err;
              });
          gone = true;
          if (ctx.mounted) Navigator.of(ctx).pop();
        }

        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text('Modifier l’annonce', style: st.copyWith(fontSize: 17, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 340,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Titre', style: st.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(controller: title, style: st, maxLength: 80, decoration: deco('Titre de l’annonce')),
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Prix (FCFA)', style: st.copyWith(fontWeight: FontWeight.w600)), const SizedBox(height: 6), TextField(controller: price, style: st, keyboardType: TextInputType.number, decoration: deco('25000'))])),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Stock', style: st.copyWith(fontWeight: FontWeight.w600)), const SizedBox(height: 6), TextField(controller: stock, style: st, keyboardType: TextInputType.number, decoration: deco('30'))])),
                ]),
                const SizedBox(height: 12),
                Text('Description', style: st.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(controller: desc, style: st, maxLines: 3, maxLength: 2000, decoration: deco('Décrivez votre produit')),
                const SizedBox(height: 8),
                Text('Photos (${images.length}/8)', style: st.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final path in images)
                    Stack(clipBehavior: Clip.none, children: [
                      ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(Backend.listingImageUrl(path), width: 72, height: 72, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(width: 72, height: 72, color: const Color(0xFFEDE9F6)))),
                      Positioned(
                        right: -6,
                        top: -6,
                        child: GestureDetector(
                          onTap: busy ? null : () async {
                            set(() => busy = true);
                            final r = await ref.read(listingsProvider.notifier).removeImage(l0.title, path);
                            set(() {
                              busy = false;
                              if (r.error != null) {
                                error = r.error;
                              } else {
                                images = r.images;
                              }
                            });
                          },
                          child: Container(width: 22, height: 22, alignment: Alignment.center, decoration: const BoxDecoration(color: _ink, shape: BoxShape.circle), child: const Text('×', style: TextStyle(color: Colors.white, fontSize: 15, height: 1))),
                        ),
                      ),
                    ]),
                  GestureDetector(
                    onTap: busy ? null : addPhoto,
                    child: Container(width: 72, height: 72, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFFF1EEFB), borderRadius: BorderRadius.circular(12)), child: Text('+', style: st.copyWith(fontSize: 26, color: const Color(0xFF5A3FE0)))),
                  ),
                ]),
                if (error != null) ...[const SizedBox(height: 10), Text(error!, style: st.copyWith(color: const Color(0xFFD64545), fontSize: 12.5, fontWeight: FontWeight.w600))],
                const SizedBox(height: 10),
                GestureDetector(onTap: busy ? null : remove, child: Text('Supprimer l’annonce', style: st.copyWith(color: const Color(0xFFD64545), fontSize: 12.5, fontWeight: FontWeight.w600))),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: busy ? null : () => Navigator.of(ctx).pop(), child: Text('Fermer', style: st)),
            TextButton(onPressed: busy ? null : save, child: Text(busy ? 'Patientez…' : 'Enregistrer', style: st.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF5A3FE0)))),
          ],
        );
      },
    ),
  );
  if (gone && context.mounted) {
    gToast(context, 'Annonce supprimée');
    gOpen(context, '61');
  } else if (context.mounted) {
    await ref.read(listingsProvider.notifier).refresh();
  }
}

/// Ouvre l'annonce de la ligne tapée dans « Mon catalogue » (écran 61).
void openListingRow(WidgetRef ref, BuildContext context, int index) {
  final l = ref.read(visibleListingsProvider);
  if (index >= l.length) return;
  ref.read(selectedListingProvider.notifier).set(l[index].title);
  gOpen(context, '60');
}
