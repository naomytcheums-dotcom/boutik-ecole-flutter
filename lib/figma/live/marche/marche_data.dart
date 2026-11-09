import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth.dart';
import '../backend.dart';

/// Données de la marketplace multi-boutiques (migration 20261107000000). Tout vient du serveur : hors connexion, ou si la fonction
/// serveur n'est pas encore installée, les écrans l'indiquent et n'affichent aucun produit ni boutique inventés.

const kInk = Color(0xFF111015);
const kGrey = Color(0xFF57545F);
const kLine = Color(0xFFECE8F2);
const kViolet = Color(0xFF5A3FE0);
const kRed = Color(0xFFE5484D);
const kGreen = Color(0xFF0F7A52);

TextStyle mst(double size, {FontWeight w = FontWeight.w500, Color c = kInk}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

/// Réponse JSON d'une fonction serveur : (valeur, null) ou (null, message lisible). Hors connexion : message dédié.
Future<({Object? data, String? error})> marcheCall(String fn, Map<String, dynamic> params) async {
  if (!Backend.ready) return (data: null, error: 'offline');
  final r = await Backend.rpc(fn, params);
  if (r.error != null) {
    final low = r.error!.toLowerCase();
    if (low.contains('could not find the function') || low.contains('pgrst202')) return (data: null, error: 'missing');
    return (data: null, error: r.error);
  }
  return (data: r.data, error: null);
}

/// Message affiché à la place d'une liste quand la lecture a échoué.
String marcheErrorText(Object? e) {
  if (e == 'offline') return 'La marketplace est disponible une fois l’application connectée au serveur.';
  if (e == 'missing') return 'La marketplace n’est pas encore installée sur le serveur.';
  return Backend.userMessage('$e');
}

class MarcheException implements Exception {
  MarcheException(this.code);
  final Object? code;
  @override
  String toString() => marcheErrorText(code);
}

Future<List<Map<String, dynamic>>> _list(String fn, Map<String, dynamic> p) async {
  final r = await marcheCall(fn, p);
  if (r.error != null) throw MarcheException(r.error);
  return [for (final x in (r.data as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
}

Future<Map<String, dynamic>> _map(String fn, Map<String, dynamic> p) async {
  final r = await marcheCall(fn, p);
  if (r.error != null) throw MarcheException(r.error);
  return r.data is Map ? Map<String, dynamic>.from(r.data as Map) : <String, dynamic>{};
}

// ------------------------------------------------------------------ filtres de la marketplace

const marcheSorts = {'popular': 'Popularité', 'recent': 'Nouveautés', 'price_asc': 'Prix croissant', 'price_desc': 'Prix décroissant', 'rating': 'Mieux notés'};

class MarcheFilters {
  const MarcheFilters({this.q = '', this.category = '', this.city = '', this.min, this.max, this.sort = 'popular', this.shops = false});
  final String q, category, city, sort;
  final int? min, max;

  /// Vrai : l'onglet « Boutiques » est affiché à la place des produits.
  final bool shops;

  MarcheFilters copy({String? q, String? category, String? city, Object? min = _keep, Object? max = _keep, String? sort, bool? shops}) => MarcheFilters(
        q: q ?? this.q,
        category: category ?? this.category,
        city: city ?? this.city,
        min: identical(min, _keep) ? this.min : min as int?,
        max: identical(max, _keep) ? this.max : max as int?,
        sort: sort ?? this.sort,
        shops: shops ?? this.shops,
      );

  Map<String, dynamic> get productParams => {
        if (q.trim().isNotEmpty) 'p_q': q.trim(),
        if (category.isNotEmpty) 'p_category': category,
        if (city.isNotEmpty) 'p_city': city,
        if (min != null) 'p_min': min,
        if (max != null) 'p_max': max,
        'p_sort': sort,
      };

  bool get active => category.isNotEmpty || city.isNotEmpty || min != null || max != null;
}

const _keep = Object();

class MarcheFiltersNotifier extends Notifier<MarcheFilters> {
  @override
  MarcheFilters build() => const MarcheFilters();
  void set(MarcheFilters f) => state = f;
}

final marcheFiltersProvider = NotifierProvider<MarcheFiltersNotifier, MarcheFilters>(MarcheFiltersNotifier.new);

// ------------------------------------------------------------------ lectures

final marcheProductsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final f = ref.watch(marcheFiltersProvider);
  return _list('marketplace_search', f.productParams);
});

final marcheShopsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final f = ref.watch(marcheFiltersProvider);
  return _list('marketplace_shops', {
    if (f.q.trim().isNotEmpty) 'p_q': f.q.trim(),
    if (f.category.isNotEmpty) 'p_category': f.category,
    if (f.city.isNotEmpty) 'p_city': f.city,
    'p_sort': f.sort == 'recent' || f.sort == 'rating' ? f.sort : 'popular',
  });
});

final marcheTrendingProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => _list('trending_products', const {'p_limit': 10}));
final marcheFlashProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => _list('flash_sales_active', const {}));
final marcheShopProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, slug) => _map('shop_public', {'p_slug': slug}));
final marcheProductProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) => _map('product_detail', {'p_id': id}));
final marcheMyShopProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  return _map('my_shop', const {});
});
final marchePromotionsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) => _map('my_promotions', const {}));
final marcheDashboardProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, days) => _map('shop_dashboard', {'p_days': days}));
final marcheModerationProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) => _map('marketplace_moderation', const {}));
final marcheFollowedProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => _list('my_followed_shops', const {}));

/// Produits choisis pour la comparaison (4 au maximum, identifiants d'annonces).
class CompareNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  /// Renvoie faux si la limite de 4 produits est atteinte.
  bool toggle(String id) {
    if (state.contains(id)) {
      state = [for (final x in state) if (x != id) x];
      return true;
    }
    if (state.length >= 4) return false;
    state = [...state, id];
    return true;
  }

  void clear() => state = const [];
}

final marcheCompareProvider = NotifierProvider<CompareNotifier, List<String>>(CompareNotifier.new);

// ------------------------------------------------------------------ utilitaires d'affichage

int mInt(Object? v) => ((v as num?) ?? 0).toInt();

/// « 25 000 FCFA ».
String mFcfa(Object? v) {
  final n = mInt(v).toString();
  final b = StringBuffer();
  for (var i = 0; i < n.length; i++) {
    if (i > 0 && (n.length - i) % 3 == 0) b.write(' ');
    b.write(n[i]);
  }
  return '$b FCFA';
}

/// Photo publique d'une annonce : URL complète telle qu'enregistrée, ou chemin du compartiment `listing-images`.
String mImageUrl(Object? raw) {
  final s = '${raw ?? ''}';
  if (s.isEmpty) return '';
  return s.startsWith('http') ? s : Backend.listingImageUrl(s);
}

/// Reste avant la fin d'une vente : « 2 j 03 h », « 03:12:45 ».
String mCountdown(DateTime end, DateTime now) {
  final d = end.difference(now);
  if (d.isNegative) return 'Terminée';
  if (d.inHours >= 24) return '${d.inDays} j ${(d.inHours % 24).toString().padLeft(2, '0')} h';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
}

Color mHex(Object? raw, Color fallback) {
  final s = '${raw ?? ''}'.replaceAll('#', '');
  final v = int.tryParse(s, radix: 16);
  return s.length == 6 && v != null ? Color(0xFF000000 | v) : fallback;
}

const shopStatusLabels = {'draft': 'Brouillon', 'pending': 'En validation', 'active': 'Active', 'suspended': 'Suspendue', 'closed': 'Fermée'};
