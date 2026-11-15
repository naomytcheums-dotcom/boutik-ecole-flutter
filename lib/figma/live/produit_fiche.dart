import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../nav.dart' show gOpen, gTab;
import 'backend.dart';
import 'entreprise.dart' show dateCourte;
import 'lots.dart' show verifyCertificateDialog;
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart' show MarchePage, mButton, mNote;
import 'seller.dart' show platformSeller;
import 'share.dart' show siteUrl;
import 'store.dart';

/// Fiche produit unique : les écrans 05, 32, 33, 34 et 35 ouvrent, une fois connecté au serveur, la fiche de la marketplace
/// (/marche/produit/:id : photos et vidéo de l'annonce, stock réel, avis, favori, partage, signalement), jamais un produit de démonstration.

/// Lien partageable d'un produit : le routeur lit directement la fiche (hors connexion, il ouvre la page d'accueil du site).
String productShareLink(String id) => '$siteUrl/#/marche/produit/$id';

/// « Mouanga Yannick » → « Mouanga Y. » (même abréviation que le serveur).
String shortPersonName(String full) {
  final parts = full.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return '';
  return parts.length == 1 ? parts.first : '${parts.first} ${parts[1][0].toUpperCase()}.';
}

/// Identifiant de l'annonce approuvée qui porte ce titre ; null si elle n'existe plus ou si la lecture échoue.
Future<String?> listingIdByTitle(String title) async {
  if (!Backend.ready || title.trim().isEmpty) return null;
  final r = await Backend.rows('listings', 'id', eq: {'title': title, 'status': 'approved'}, limit: 1);
  if (r.error != null || r.rows.isEmpty) return null;
  return '${r.rows.first['id']}';
}

/// Produit retenu pour les écrans qui lisent la sélection (31, 38, 39, 170, 172, 211) quand on vient de la fiche marketplace.
LiveProduct liveProductFromDetail(Map<String, dynamic> d, String id) {
  final card = Map<String, dynamic>.from((d['card'] as Map?) ?? const {});
  final seller = d['seller'] is Map ? Map<String, dynamic>.from(d['seller'] as Map) : null;
  final price = mInt(card['flash_price'] ?? card['price']);
  return LiveProduct(
    '${card['title'] ?? ''}',
    '${d['department'] ?? ''}',
    price,
    seller == null ? platformSeller : shortPersonName('${seller['name'] ?? ''}'),
    '${d['description'] ?? ''}',
    mImageUrl(card['image']),
    sellerId: '${d['seller_id'] ?? ''}'.isEmpty ? null : '${d['seller_id']}',
    stock: card['stock'] == null ? null : mInt(card['stock']),
    id: id,
  );
}

/// Informations complémentaires de la fiche : annonce d'exemple, matériaux recyclés, certificat lié au produit.
final marcheProductExtrasProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final r = await marcheCall('product_extras', {'p_id': id});
  return r.error != null || r.data is! Map ? const <String, dynamic>{} : Map<String, dynamic>.from(r.data as Map);
}, retry: (_, _) => null);

/// Prestataire ou vendeur : nom abrégé, photo, filière. Clé `listing:id` ou `seller:id`.
final providerCardProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, key) async {
  final i = key.indexOf(':');
  if (i < 0 || !Backend.ready) return null;
  final id = key.substring(i + 1);
  if (id.isEmpty) return null;
  final r = await Backend.rpc('provider_card', key.startsWith('listing:') ? {'p_listing': id} : {'p_seller': id});
  if (r.error != null || r.data is! Map) return null;
  final m = Map<String, dynamic>.from(r.data as Map);
  return m['found'] == true ? m : null;
}, retry: (_, _) => null);

/// Écrans 05, 32, 33, 34 et 35 en mode connecté : redirige vers la fiche du produit choisi ; sans produit choisi, le dit.
class ProductRedirect extends ConsumerStatefulWidget {
  const ProductRedirect({super.key});

  @override
  ConsumerState<ProductRedirect> createState() => _ProductRedirectState();
}

class _ProductRedirectState extends ConsumerState<ProductRedirect> {
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _go());
  }

  Future<void> _go() async {
    if (!mounted) return;
    final notifier = ref.read(selectedProductProvider.notifier);
    final p = ref.read(selectedProductProvider);
    if (!notifier.chosen) return setState(() => _message = 'Aucun produit n’est choisi. Ouvrez un produit depuis le catalogue pour voir sa fiche.');
    var id = p.id;
    if (id == null || id.isEmpty) id = await listingIdByTitle(p.title);
    if (!mounted) return;
    if (id == null) return setState(() => _message = 'Ce produit n’est plus disponible.');
    GoRouter.maybeOf(context)?.pushReplacement('/marche/produit/$id');
  }

  @override
  Widget build(BuildContext context) => MarchePage(
        title: 'Produit',
        child: _message == null
            ? const Center(child: CircularProgressIndicator())
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                mNote(_message!),
                mButton('Voir le catalogue', () => gTab(context, '04')),
              ]),
      );
}

/// Écran 211 : passeport du produit choisi. Le certificat n'est montré que s'il est réellement lié à l'annonce.
class ProductPassport extends ConsumerWidget {
  const ProductPassport({super.key, this.width = 342});
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(selectedProductProvider);
    if (!ref.read(selectedProductProvider.notifier).chosen) {
      return SizedBox(width: width, child: mNote('Aucun produit n’est choisi. Ouvrez la fiche d’un produit puis touchez « Passeport du produit ».'));
    }
    final async = ref.watch(_passportProvider((p.title, p.id ?? '')));
    return SizedBox(
      width: width,
      child: async.when(
        loading: () => mNote('Chargement…'),
        error: (_, _) => mNote('Le passeport de ce produit ne peut pas être chargé pour le moment.'),
        data: (x) {
          if (x == null) return mNote('Ce produit n’est plus disponible.');
          final cert = x['certificate'] is Map ? Map<String, dynamic>.from(x['certificate'] as Map) : null;
          Widget row(String l, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 110, child: Text(l, style: mst(12.5, c: kGrey))), Expanded(child: Text(v, style: mst(12.5, w: FontWeight.w600)))]));
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.title, style: mst(22, w: FontWeight.w700)),
            const SizedBox(height: 18),
            Text('Origine', style: mst(15, w: FontWeight.w700)),
            const SizedBox(height: 6),
            if (p.department.isNotEmpty) row('Département', p.department),
            if (p.seller.isNotEmpty) row('Créateur', p.seller),
            if (x['recycled'] == true) row('Matériaux', x['recycled_kg'] == null ? 'Recyclés' : 'Recyclés (${x['recycled_kg']} kg)'),
            const SizedBox(height: 14),
            Text('Certificat', style: mst(15, w: FontWeight.w700)),
            const SizedBox(height: 6),
            if (cert == null)
              Text('Aucun certificat n’est lié à ce produit pour le moment.', style: mst(13, c: kGrey).copyWith(height: 1.5))
            else ...[
              row('Identifiant', '${cert['code']}'),
              row('Délivré le', '${cert['delivre_le']}'),
              row('État', cert['valide'] == true ? 'Authentique' : 'Révoqué'),
              const SizedBox(height: 12),
              mButton('Voir le certificat', () => verifyCertificateDialog(context, ref, code: '${cert['code']}'), width: width),
            ],
          ]);
        },
      ),
    );
  }
}

final _passportProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, (String, String)>((ref, key) async {
  var id = key.$2;
  if (id.isEmpty) id = await listingIdByTitle(key.$1) ?? '';
  if (id.isEmpty) return null;
  final r = await marcheCall('product_extras', {'p_id': id});
  if (r.error != null || r.data is! Map) throw StateError('product_extras');
  final m = Map<String, dynamic>.from(r.data as Map);
  return m['found'] == true ? m : null;
}, retry: (_, _) => null);

/// Ouvre un écran du manifeste (31, 38, 39, 170, 172, 211) pour le produit de la fiche.
void openForProduct(BuildContext context, WidgetRef ref, LiveProduct p, String screen, {bool seller = false}) {
  ref.read(selectedProductProvider.notifier).choose(p);
  final sid = p.sellerId ?? '';
  if (seller && sid.isNotEmpty) ref.read(sellerFocusProvider.notifier).set(sid);
  gOpen(context, screen);
}

/// Date courte d'un avis (« 12 oct. 2026 »).
String reviewDate(Object? iso) => dateCourte(iso);
