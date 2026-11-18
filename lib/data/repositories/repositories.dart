import 'dart:async' show unawaited;
import 'dart:convert';

import '../../figma/live/auth.dart' show authProvider;
import '../../figma/live/backend.dart' show Backend;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../demo/catalog_demo.dart';
import '../demo/nouveaux_demo.dart';
import '../demo/section_a_demo.dart';
import '../demo/section_b_demo.dart';
import '../models/models.dart';

export '../demo/section_a_demo.dart' show CartLine, ExploreItem, SectionAData, Totals;
export '../demo/section_b_demo.dart' show SearchResult, SectionBData;

/// Dépôt du catalogue. Implémentation de démonstration : données locales fictives.
/// Pour brancher l'API, fournir une autre implémentation via `overrideWithValue`.
abstract interface class CatalogRepository {
  List<Product> products();
  List<Talent> talents();
}

class DemoCatalogRepository implements CatalogRepository {
  const DemoCatalogRepository();

  @override
  List<Product> products() => demoProducts;

  @override
  List<Talent> talents() => demoTalents;
}

final catalogRepositoryProvider = Provider<CatalogRepository>((_) => const DemoCatalogRepository());

/// Données des écrans de la section « Nouveaux écrans ».
final nouveauxDataProvider = Provider<NouveauxData>((_) => const NouveauxData());

/// Données de la section A (démarrage et parcours d'achat).
final sectionADataProvider = Provider<SectionAData>((_) => const SectionAData());

/// Données de la section B (authentification).
final sectionBDataProvider = Provider<SectionBData>((_) => const SectionBData());

/// Rôle choisi à l'inscription (13).
class RoleNotifier extends Notifier<int> {
  @override
  int build() => 1;

  void set(int v) => state = v;
}

final roleProvider = NotifierProvider<RoleNotifier, int>(RoleNotifier.new);

/// Panier partagé entre la fiche produit (05), le panier (06) et le paiement (08).
/// Connecté au serveur : le panier est enregistré sur l'appareil, séparément pour chaque compte (et pour le visiteur), et survit au rechargement.
class CartNotifier extends Notifier<List<CartLine>> {
  String _owner = '';
  List<CartLine> _last = const [];

  @override
  // Connecté au serveur : le panier démarre vide (les articles d'exemple de la maquette ne sont que pour la démonstration hors connexion).
  List<CartLine> build() {
    if (!Backend.ready) return ref.read(sectionADataProvider).cart;
    final uid = ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
    final carry = _owner.isEmpty && uid.isNotEmpty ? _last : const <CartLine>[]; // le panier du visiteur suit son compte à la connexion
    _owner = uid;
    _last = const [];
    Future.microtask(() => _load(uid, carry));
    return const <CartLine>[];
  }

  static String _key(String uid) => 'boutik.cart.${uid.isEmpty ? 'guest' : uid}';

  Future<void> _load(String uid, List<CartLine> carry) async {
    var saved = <CartLine>[];
    var carried = carry;
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key(uid));
      if (raw != null) {
        final j = jsonDecode(raw);
        if (j is List) saved = [for (final x in j) ?CartLine.fromJson(x)];
      }
      // le panier enregistré du visiteur (même appareil) suit le compte, même si l'application a été rechargée entre-temps (la copie en mémoire et la copie enregistrée sont la même)
      if (uid.isNotEmpty) {
        final guest = p.getString(_key(''));
        if (guest != null) {
          final j = jsonDecode(guest);
          if (j is List) {
            final lines = [for (final x in j) ?CartLine.fromJson(x)];
            if (lines.isNotEmpty) carried = lines;
          }
          await p.remove(_key(''));
        }
      }
      if (carry.isNotEmpty) await p.remove(_key(''));
    } catch (_) {}
    if (!ref.mounted || _owner != uid) return;
    var merged = saved;
    for (final l in [...state, ...carried]) {
      merged = _merge(merged, l);
    }
    if (merged.length == saved.length && merged.isEmpty) return;
    _set(merged, persist: carried.isNotEmpty || state.isNotEmpty);
  }

  static List<CartLine> _merge(List<CartLine> into, CartLine line) {
    final i = into.indexWhere((l) => l.title == line.title);
    if (i < 0) return [...into, line];
    return [for (final (j, l) in into.indexed) j == i ? l.withQty((l.qty + line.qty).clamp(1, maxCartQty)) : l];
  }

  void _set(List<CartLine> v, {bool persist = true}) {
    state = v;
    _last = v;
    if (persist && Backend.ready) unawaited(_save(v));
  }

  Future<void> _save(List<CartLine> v) async {
    try {
      final p = await SharedPreferences.getInstance();
      if (v.isEmpty) {
        await p.remove(_key(_owner));
      } else {
        await p.setString(_key(_owner), jsonEncode([for (final l in v) l.toJson()]));
      }
    } catch (_) {}
  }

  /// Quantité de la ligne [index] (1 à [max], 20 au plus) ; moins de 1 retire la ligne.
  void setQty(int index, int qty, {int max = maxCartQty}) {
    if (qty < 1) return remove(index);
    final q = qty.clamp(1, max.clamp(1, maxCartQty));
    _set([for (final (i, l) in state.indexed) i == index ? l.withQty(q) : l]);
  }

  void remove(int index) => _set([...state]..removeAt(index));

  void add(CartLine line) => _set(_merge(state, line.qty > maxCartQty ? line.withQty(maxCartQty) : line));

  /// Vide le panier (commande passée ou paiement lancé).
  void clear() => _set(const <CartLine>[]);

  /// Remet des lignes dans le panier (nouvel essai de paiement après un échec).
  void restore(List<CartLine> lines) {
    var merged = state;
    for (final l in lines) {
      merged = _merge(merged, l);
    }
    _set(merged);
  }
}

final cartProvider = NotifierProvider<CartNotifier, List<CartLine>>(CartNotifier.new);

/// Mode de livraison choisi (07) : true = retrait sur campus.
class PickupNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool v) => state = v;
}

final pickupProvider = NotifierProvider<PickupNotifier, bool>(PickupNotifier.new);

/// Indique que l'application tourne sur des données de démonstration (affiché dans les paramètres).
final demoModeProvider = Provider<bool>((_) => true);
