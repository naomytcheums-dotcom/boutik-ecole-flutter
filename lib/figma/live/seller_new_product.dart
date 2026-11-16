import 'dart:typed_data';

import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'auth.dart';
import 'backend.dart';

/// Formulaire « Nouveau produit » (58) : photos choisies avant l'enregistrement, remise à zéro à l'ouverture.

/// Photo choisie dans le formulaire, envoyée au stockage une fois l'annonce créée.
class PickedPhoto {
  const PickedPhoto(this.bytes, this.name, this.mime);
  final Uint8List bytes;
  final String name, mime;
}

/// Plafond unique de photos par annonce (base de données, fiche 60 et espace vendeur).
const maxListingPhotos = 8;
const maxPhotoBytes = 5 * 1024 * 1024;

class NewProductPhotos extends Notifier<List<PickedPhoto>> {
  @override
  List<PickedPhoto> build() => const [];
  void set(List<PickedPhoto> v) => state = v;
  void clear() => state = const [];
}

final newProductPhotosProvider = NotifierProvider<NewProductPhotos, List<PickedPhoto>>(NewProductPhotos.new);

const newProductKeys = ['np_title', 'np_price', 'np_cat', 'np_stock', 'np_desc', 'np_sup'];

/// Vide le formulaire (valeurs, erreurs, photos) : sans cela, l'état global gardait la description de l'annonce précédente.
void resetNewProduct(WidgetRef ref) {
  ref.read(formProvider.notifier).clear(newProductKeys);
  ref.read(errorsProvider.notifier).clear();
  ref.read(newProductPhotosProvider.notifier).clear();
}

/// Élément invisible posé dans l'écran : remet le formulaire à zéro à son ouverture.
class NewProductReset extends ConsumerStatefulWidget {
  const NewProductReset({super.key});
  @override
  ConsumerState<NewProductReset> createState() => _NewProductResetState();
}

class _NewProductResetState extends ConsumerState<NewProductReset> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) resetNewProduct(ref);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Libellé sous « Ajouter des photos ».
class NewProductPhotoCount extends ConsumerWidget {
  const NewProductPhotoCount({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(newProductPhotosProvider).length;
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(n == 0 ? 'Jusqu’à $maxListingPhotos photos · JPG, PNG, WebP · 5 Mo max' : '$n photo${n > 1 ? 's' : ''} sur $maxListingPhotos · touchez pour gérer', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(inherit: false, fontFamily: 'PlusJakartaSans', fontSize: 11.5, color: Color(0xFF57545F), textBaseline: TextBaseline.alphabetic)),
    );
  }
}

/// Fenêtre de gestion des photos : aperçu, retrait, ajout (plusieurs à la fois).
Future<void> managePhotos(BuildContext context, WidgetRef ref) async {
  String? error;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
      final photos = ref.read(newProductPhotosProvider);
      Future<void> add() async {
        try {
          final picked = await ImagePicker().pickMultiImage(maxWidth: 1600, imageQuality: 85);
          if (picked.isEmpty) return;
          final next = [...ref.read(newProductPhotosProvider)];
          String? err;
          for (final x in picked) {
            if (next.length >= maxListingPhotos) {
              err = '$maxListingPhotos photos au maximum.';
              break;
            }
            final n = x.name.toLowerCase();
            final mime = x.mimeType ?? (n.endsWith('.png') ? 'image/png' : (n.endsWith('.webp') ? 'image/webp' : 'image/jpeg'));
            if (!const ['image/jpeg', 'image/png', 'image/webp'].contains(mime)) {
              err = 'Format accepté : JPEG, PNG ou WebP.';
              continue;
            }
            final bytes = await x.readAsBytes();
            if (bytes.length > maxPhotoBytes) {
              err = 'Photo trop lourde (5 Mo maximum).';
              continue;
            }
            next.add(PickedPhoto(bytes, x.name, mime));
          }
          ref.read(newProductPhotosProvider.notifier).set(next);
          set(() => error = err);
        } catch (_) {
          set(() => error = 'Impossible d’ajouter cette photo.');
        }
      }

      const st = TextStyle(inherit: false, fontFamily: 'PlusJakartaSans', fontSize: 13.5, color: Color(0xFF111015), textBaseline: TextBaseline.alphabetic);
      return AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Photos du produit (${photos.length}/$maxListingPhotos)', style: st.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('La première photo sert de couverture. Les photos sont envoyées quand vous enregistrez le produit.', style: st.copyWith(fontSize: 12, color: const Color(0xFF57545F))),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (var i = 0; i < photos.length; i++)
                Stack(clipBehavior: Clip.none, children: [
                  ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(photos[i].bytes, width: 72, height: 72, fit: BoxFit.cover)),
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Semantics(
                      button: true,
                      label: 'Retirer la photo ${i + 1}',
                      child: GestureDetector(
                        onTap: () {
                          ref.read(newProductPhotosProvider.notifier).set([...photos]..removeAt(i));
                          set(() => error = null);
                        },
                        child: Container(width: 26, height: 26, alignment: Alignment.center, decoration: const BoxDecoration(color: Color(0xFF111015), shape: BoxShape.circle), child: const Icon(Icons.close, size: 15, color: Colors.white)),
                      ),
                    ),
                  ),
                ]),
              if (photos.length < maxListingPhotos)
                Semantics(button: true, label: 'Ajouter des photos', child: GestureDetector(onTap: add, child: Container(width: 72, height: 72, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFFF1EEFB), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.add_a_photo_outlined, color: Color(0xFF5A3FE0))))),
            ]),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error!, style: st.copyWith(color: const Color(0xFFD64545), fontSize: 12.5, fontWeight: FontWeight.w600))),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Terminé', style: st))],
      );
    }),
  );
}

/// Envoie les photos choisies vers l'annonce créée ; renvoie le nombre de photos qui n'ont pas pu partir.
Future<int> uploadPickedPhotos(String listingId, List<PickedPhoto> photos) async {
  var current = <String>[];
  var failed = 0;
  for (final p in photos) {
    final r = await Backend.addListingImage(listingId, current, p.bytes, p.name, p.mime);
    if (r.error != null) {
      failed++;
    } else {
      current = r.images;
    }
  }
  return failed;
}
