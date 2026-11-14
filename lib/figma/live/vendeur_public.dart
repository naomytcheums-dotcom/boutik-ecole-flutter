import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'backend.dart';
import 'marche/marche_widgets.dart' show MarcheLink;
import 'produits_liste.dart';
import 'store.dart' show selectedProductProvider;

/// Profil public (écran 24), réputation (38) et confiance (172) du vendeur du produit choisi : chiffres calculés par le serveur
/// (migration 20261105000900) sur ses annonces, ses ventes payées et les avis de ses annonces. Aucun badge inventé.

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

class SellerPublic extends Notifier<Map<String, dynamic>?> {
  @override
  Map<String, dynamic>? build() {
    final (name, id) = ref.watch(selectedProductProvider.select((p) => (p.seller, p.sellerId)));
    if (!Backend.ready) return null;
    Future.microtask(() async {
      final r = await Backend.rpc('seller_public', (id ?? '').isNotEmpty ? {'p_id': id} : {'p_name': name});
      if (!ref.mounted) return;
      state = r.error != null || r.data is! Map ? {'found': false, 'error': true} : Map<String, dynamic>.from(r.data as Map);
    });
    return null;
  }
}

final sellerPublicProvider = NotifierProvider<SellerPublic, Map<String, dynamic>?>(SellerPublic.new);

int _i(Object? v) => ((v as num?) ?? 0).toInt();

Widget _note(double w, String t) => Container(width: w, height: 140, alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(t, textAlign: TextAlign.center, style: _st(13, c: _grey).copyWith(height: 1.5)));

Widget? _gate(Map<String, dynamic>? d, double w, String seller) {
  if (d == null) return _note(w, 'Chargement…');
  if (d['found'] != true) {
    if (d['ambiguous'] == true) return _note(w, 'Plusieurs vendeurs portent ce nom. Ouvrez la boutique depuis un de ses produits.');
    return _note(w, d['error'] == true ? 'Ce profil ne peut pas être chargé pour le moment.' : 'Aucun profil public trouvé pour « $seller ».');
  }
  return null;
}

String _since(Object? iso) {
  final d = DateTime.tryParse('${iso ?? ''}');
  return d == null ? '' : 'Membre depuis ${d.year}';
}

Widget _tile(String l, String v) => Expanded(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFECE8F2))), child: Column(children: [Text(v, style: _st(20, w: FontWeight.w800)), const SizedBox(height: 2), Text(l, style: _st(11, c: _grey))])));

/// 24 : identité, compteurs et produits du vendeur.
class SellerProfileBlock extends ConsumerWidget {
  const SellerProfileBlock({super.key, this.width = 342});
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seller = ref.watch(selectedProductProvider.select((p) => p.seller));
    final d = ref.watch(sellerPublicProvider);
    final g = _gate(d, width, seller);
    if (g != null) return SizedBox(width: width, child: g);
    final fallbackId = '${d!['id'] ?? ''}';
    final sellerId = ref.watch(selectedProductProvider.select((p) => p.sellerId)) ?? fallbackId;
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${d['name']}', style: _st(20, w: FontWeight.w800)),
        const SizedBox(height: 4),
        Text([if ('${d['department']}'.isNotEmpty) '${d['department']}', if ('${d['institution']}'.isNotEmpty) '${d['institution']}', _since(d['since'])].where((e) => e.isNotEmpty).join(' · '), style: _st(12.5, c: _grey)),
        const SizedBox(height: 16),
        Row(children: [_tile('Produits', '${_i(d['products'])}'), const SizedBox(width: 10), _tile('Services', '${_i(d['services'])}'), const SizedBox(width: 10), _tile('Ventes', '${_i(d['sales'])}')]),
        if ('${d['shop_slug'] ?? ''}'.isNotEmpty) ...[const SizedBox(height: 14), SizedBox(width: width, height: 48, child: MarcheLink('Voir sa boutique : ${d['shop_name']}', '/marche/boutique/${d['shop_slug']}'))],
        const SizedBox(height: 22),
        Text('Ses produits', style: _st(16, w: FontWeight.w700)),
        const SizedBox(height: 10),
        ProductCards(width: width, rows: 2, filter: (p) => sellerId.isNotEmpty && (p.sellerId ?? '').isNotEmpty ? p.sellerId == sellerId : p.seller == '${d['name']}', emptyText: 'Aucun produit publié par ce vendeur pour le moment.'),
      ]),
    );
  }
}

/// 38 : note moyenne et répartition des avis reçus.
class SellerReputationBlock extends ConsumerWidget {
  const SellerReputationBlock({super.key, this.width = 342});
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seller = ref.watch(selectedProductProvider.select((p) => p.seller));
    final d = ref.watch(sellerPublicProvider);
    final g = _gate(d, width, seller);
    if (g != null) return SizedBox(width: width, child: g);
    final n = _i(d!['rating_count']);
    final stars = Map<String, dynamic>.from((d['stars'] as Map?) ?? const {});
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${d['name']}', style: _st(20, w: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(_since(d['since']), style: _st(12.5, c: _grey)),
        const SizedBox(height: 18),
        if (n == 0)
          Text('Aucun avis reçu pour le moment.', style: _st(13.5, c: _grey))
        else ...[
          Text('${d['rating_avg']} / 5', style: _st(30, w: FontWeight.w800)),
          Text('$n avis', style: _st(12.5, c: _grey)),
          const SizedBox(height: 14),
          for (var s = 5; s >= 1; s--)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                SizedBox(width: 60, child: Text('$s étoile${s > 1 ? 's' : ''}', style: _st(12))),
                Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(minHeight: 7, value: _i(stars['$s']) / n, backgroundColor: const Color(0xFFF2EFF6), color: const Color(0xFFF5A524)))),
                SizedBox(width: 28, child: Text('${_i(stars['$s'])}', textAlign: TextAlign.right, style: _st(11.5, c: _grey))),
              ]),
            ),
        ],
        const SizedBox(height: 22),
        Text(d['verified'] == true ? 'Identité du vendeur vérifiée.' : 'Identité du vendeur non encore vérifiée.', style: _st(12.5, w: FontWeight.w600, c: d['verified'] == true ? const Color(0xFF0F7A52) : _grey)),
      ]),
    );
  }
}

/// 172 : ce qui est réellement établi sur le vendeur.
class SellerTrustBlock extends ConsumerWidget {
  const SellerTrustBlock({super.key, this.width = 342});
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seller = ref.watch(selectedProductProvider.select((p) => p.seller));
    final d = ref.watch(sellerPublicProvider);
    final g = _gate(d, width, seller);
    if (g != null) return SizedBox(width: width, child: g);
    final n = _i(d!['rating_count']);
    Widget row(IconData icon, String t, String sub, bool ok) => Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(children: [Icon(icon, size: 24, color: ok ? const Color(0xFF1F9D6B) : const Color(0xFFB9B4C7)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: _st(13.5, w: FontWeight.w600)), Text(sub, style: _st(11.5, c: _grey))]))]));
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${d['name']}', style: _st(20, w: FontWeight.w800)),
        const SizedBox(height: 14),
        row(Icons.verified_user_rounded, 'Identité vérifiée', d['verified'] == true ? 'Vérifiée par l’administration' : 'Pas encore vérifiée', d['verified'] == true),
        row(Icons.shopping_bag_rounded, 'Ventes réalisées', '${_i(d['sales'])} commande${_i(d['sales']) > 1 ? 's' : ''} payée${_i(d['sales']) > 1 ? 's' : ''}', _i(d['sales']) > 0),
        row(Icons.star_rounded, 'Avis clients', n == 0 ? 'Aucun avis pour le moment' : '${d['rating_avg']} / 5 · $n avis', n > 0),
        const SizedBox(height: 10),
        Text('Ces éléments sont calculés sur l’activité réelle du vendeur.', style: _st(11.5, c: _grey)),
      ]),
    );
  }
}

/// 212 : vérification d'un certificat par son code, auprès du serveur (fonction publique verify_certificate).
class CertificateChecker extends ConsumerStatefulWidget {
  const CertificateChecker({super.key, this.width = 342});
  final double width;

  @override
  ConsumerState<CertificateChecker> createState() => _CertificateCheckerState();
}

class _CertificateCheckerState extends ConsumerState<CertificateChecker> {
  final _code = TextEditingController();
  Map<String, dynamic>? _res;
  bool _busy = false;

  Future<void> _check() async {
    if (_code.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final r = await Backend.rpc('verify_certificate', {'p_code': _code.text.trim()});
    if (!mounted) return;
    setState(() {
      _busy = false;
      _res = r.error != null || r.data is! Map ? {'error': true} : Map<String, dynamic>.from(r.data as Map);
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _res;
    return SizedBox(
      width: widget.width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Entrez le code du certificat', style: _st(15, w: FontWeight.w700)),
        const SizedBox(height: 10),
        TextField(controller: _code, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(hintText: 'Ex. BE-CERT-0021', border: OutlineInputBorder()), onSubmitted: (_) => _check()),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _busy ? null : _check,
          child: Container(width: widget.width, height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(24)), child: Text(_busy ? 'Vérification…' : 'Vérifier', style: _st(14, w: FontWeight.w700, c: Colors.white))),
        ),
        const SizedBox(height: 18),
        if (r != null)
          if (r['error'] == true)
            Text('Vérification impossible pour le moment.', style: _st(13, c: _grey))
          else if (r['introuvable'] == true)
            Text('Aucun certificat ne porte ce code.', style: _st(13.5, w: FontWeight.w700, c: const Color(0xFFC0392B)))
          else ...[
            Text(r['valide'] == true ? 'Authentique' : 'Révoqué', style: _st(15, w: FontWeight.w800, c: r['valide'] == true ? const Color(0xFF0F7A52) : const Color(0xFFC0392B))),
            const SizedBox(height: 6),
            Text('${r['objet']}', style: _st(14, w: FontWeight.w700)),
            Text('Titulaire : ${r['titulaire']}', style: _st(12.5, c: _grey)),
            Text('Délivré le ${r['delivre_le']}', style: _st(12.5, c: _grey)),
            if (r['valide'] != true && '${r['motif_revocation'] ?? ''}'.isNotEmpty) Text('Motif : ${r['motif_revocation']}', style: _st(12.5, c: _grey)),
          ],
      ]),
    );
  }
}
