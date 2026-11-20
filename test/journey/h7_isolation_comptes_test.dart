import 'dart:convert';

import 'package:boutik_ecole/app.dart';
import 'package:boutik_ecole/data/repositories/repositories.dart' show CartLine, cartProvider;
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/drafts.dart';
import 'package:boutik_ecole/figma/live/notifs.dart' show notifsProvider;
import 'package:boutik_ecole/figma/live/promo_state.dart' show promoCodeProvider;
import 'package:boutik_ecole/figma/live/seller.dart' show Listing;
import 'package:boutik_ecole/figma/live/store.dart' as store;
import 'package:boutik_ecole/main.dart' show AppRoot;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/render.dart';

/// H7 · ISOLATION DES COMPTES : après déconnexion puis connexion d'un AUTRE compte sur le même appareil, aucun état privé du premier
/// (panier, favoris, commandes, notifications, brouillons, formulaires, code promo, packs, annonces vendeur en mémoire, seuil de stock,
/// préférences du compte) n'est visible ; un compte neuf démarre vide ; et le premier compte retrouve ce qui lui appartient (panier enregistré
/// pour lui seul).
const _uidA = '11111111-1111-4111-8111-111111111111';
const _uidB = '22222222-2222-4222-8222-222222222222';
const _uidNeuf = '33333333-3333-4333-8333-333333333333';

Map<String, dynamic> _session(String uid, String email) {
  final exp = DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000;
  String b64(Map m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return {
    'access_token': '${b64({'alg': 'HS256', 'typ': 'JWT'})}.${b64({'sub': uid, 'role': 'authenticated', 'exp': exp})}.signature',
    'token_type': 'bearer',
    'expires_in': 7200,
    'expires_at': exp,
    'refresh_token': 'refresh-$uid',
    'user': {'id': uid, 'aud': 'authenticated', 'role': 'authenticated', 'email': email, 'app_metadata': <String, dynamic>{}, 'user_metadata': <String, dynamic>{}, 'created_at': '2026-01-01T00:00:00Z'},
  };
}

Account _compte(String uid, String email, {int role = 0}) => Account(name: 'Titulaire ${uid.substring(0, 2)}', phone: '690000000', email: email, password: '', role: role, verified: false, institution: '', department: '', city: '', serverId: uid);

void main() {
  late FakeSupabase srv;
  setUpAll(() async {
    await loadAppFonts();
    srv = await FakeSupabase.start();
    await srv.initSupabase();
  });
  tearDownAll(() => srv.close());

  setUp(() async {
    GScreen.mockupFrame = false;
    GAnim.enabled = false;
    srv.unknownIsError = false;
    srv.rpc.clear();
    srv.tables.clear();
    srv.calls.clear();
    SharedPreferences.setMockInitialValues({});
    final auth = Supabase.instance.client.auth;
    await auth.recoverSession(jsonEncode(_session(_uidA, 'a@example.test')));
    store.extraProducts = const [];
    Listing.lowStock = 30;
    Backend.promoCode = '';
    Backend.packLines.clear();
    Drafts.values = {};
  });
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = true;
  });

  /// Démonte l'application et laisse passer ses minuteries (rafraîchissements périodiques).
  Future<void> fermer(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 60));
  }

  ProviderContainer containerOf(WidgetTester t) => ProviderScope.containerOf(t.element(find.byType(BoutikEcoleApp)));

  /// Ouvre l'application avec le compte A déjà connecté (session restaurée), comme au démarrage réel.
  Future<void> ouvrir(WidgetTester t, Account a) async {
    t.view.physicalSize = const Size(390, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(AppRoot(remembered: a, firstRun: false));
    await settleReal(t);
  }

  /// Déconnexion réelle (même code que le bouton « Se déconnecter ») puis session du compte suivant ouverte sur le serveur.
  Future<ProviderContainer> basculer(WidgetTester t, {required String uid, required String email, required Account compte}) async {
    containerOf(t).read(authProvider.notifier).logout();
    await settleReal(t);
    expect(Supabase.instance.client.auth.currentUser, isNull, reason: 'la session de A doit être fermée');
    await Supabase.instance.client.auth.recoverSession(jsonEncode(_session(uid, email)));
    final c = containerOf(t);
    expect(c.read(authProvider).current, isNull, reason: 'après déconnexion, plus aucun compte dans le nouvel arbre de providers');
    c.read(authProvider.notifier).login(compte);
    await settleReal(t, rounds: 8);
    return c;
  }

  testWidgets('A se déconnecte, B se connecte : aucun état privé de A n’est visible', (t) async {
    final a = _compte(_uidA, 'a@example.test');
    final b = _compte(_uidB, 'b@example.test');
    // données privées de A côté serveur : B ne les reçoit jamais (le serveur filtre) ; le client ne doit rien en garder
    srv.tables['favorites'] = [
      {'listing_id': 'l1', 'listings': {'title': 'Produit privé de A'}},
    ];
    srv.tables['notifications'] = [
      {'id': 'n1', 'kind': 'order', 'title': 'Notification privée de A', 'body': 'corps de A', 'created_at': '2026-11-01T10:00:00Z', 'read_at': null, 'data': <String, dynamic>{}},
    ];
    srv.tables['orders'] = [
      {'number': '#BE-A-0001', 'subtotal': 5000, 'fee': 0, 'method': 'Orange Money', 'reference': 'R', 'status': 0, 'paid': true, 'created_at': '2026-11-01T10:00:00Z', 'order_lines': [{'title': 'Produit privé de A', 'qty': 1, 'unit_price': 5000, 'fulfillment': 0}]},
    ];
    await ouvrir(t, a);
    var c = containerOf(t);
    // état privé de A : lu sur le serveur…
    c.read(store.favoritesProvider);
    c.read(store.ordersProvider);
    c.read(notifsProvider);
    await settleReal(t, rounds: 8);
    expect(c.read(store.favoritesProvider), contains('Produit privé de A'), reason: 'préalable : A voit ses favoris');
    expect(c.read(store.ordersProvider).map((o) => o.id), contains('#BE-A-0001'), reason: 'préalable : A voit sa commande');
    expect(c.read(notifsProvider).map((n) => n.title), contains('Notification privée de A'), reason: 'préalable : A voit sa notification');
    // … et saisi sur l'appareil
    c.read(cartProvider.notifier).add(const CartLine('Article du panier de A', 'Département : X', 7000, 'placeholder'));
    c.read(promoCodeProvider.notifier).set('PROMO-DE-A');
    c.read(formProvider.notifier).put('np_title', 'Brouillon de A');
    await Drafts.save('np', {'np_title': 'Brouillon de A'});
    Listing.lowStock = 3;
    Backend.packLines['Pack de A'] = 'pack-a';
    store.extraProducts = const [store.LiveProduct('Annonce de A', 'Dept', 1000, 'A', 'd', 'placeholder', sellerId: _uidA)];
    await settleReal(t);
    expect(Backend.promoCode, 'PROMO-DE-A');

    // le serveur ne renvoie plus rien à B
    srv.tables.clear();
    c = await basculer(t, uid: _uidB, email: 'b@example.test', compte: b);
    c.read(cartProvider);
    c.read(store.favoritesProvider);
    c.read(store.ordersProvider);
    c.read(notifsProvider);
    await settleReal(t, rounds: 8);

    expect(c.read(cartProvider), isEmpty, reason: 'panier de A visible par B');
    expect(c.read(store.favoritesProvider), isEmpty, reason: 'favoris de A visibles par B');
    expect(c.read(store.ordersProvider), isEmpty, reason: 'commandes de A visibles par B');
    expect(c.read(notifsProvider), isEmpty, reason: 'notifications de A visibles par B');
    expect(c.read(formProvider).containsKey('np_title'), isFalse, reason: 'formulaire de A visible par B');
    expect(c.read(promoCodeProvider), isEmpty);
    expect(Backend.promoCode, isEmpty, reason: 'le code promo de A serait envoyé avec la commande de B');
    expect(Backend.packLines, isEmpty);
    expect(Drafts.values, isEmpty, reason: 'brouillon de A visible par B');
    expect((await SharedPreferences.getInstance()).getKeys().where((k) => k.startsWith('boutik.draft.')), isEmpty);
    expect(Listing.lowStock, 30, reason: 'seuil de stock du vendeur A repris par B');
    expect(store.extraProducts, isEmpty, reason: 'annonces en mémoire de A');
    expect(store.platformProducts.any((p) => p.title == 'Annonce de A'), isFalse);

    // aucune trace à l'écran : accueil, panier, commandes et favoris de B
    for (final id in ['06', '45', '25b']) {
      final ctx = t.element(find.byType(Scaffold).first);
      GoRouter.of(ctx).go('/s/$id');
      await settleReal(t);
      expect(find.textContaining('privé de A'), findsNothing, reason: 'écran $id');
      expect(find.textContaining('PROMO-DE-A'), findsNothing, reason: 'écran $id');
      expect(find.textContaining('Article du panier de A'), findsNothing, reason: 'écran $id');
    }
    await fermer(t);
  });

  testWidgets('compte neuf après un autre compte : tout démarre vide, zéros réels seulement', (t) async {
    final a = _compte(_uidA, 'a@example.test');
    final neuf = _compte(_uidNeuf, 'neuf@example.test');
    srv.tables['favorites'] = [
      {'listing_id': 'l1', 'listings': {'title': 'Produit privé de A'}},
    ];
    await ouvrir(t, a);
    var c = containerOf(t);
    c.read(store.favoritesProvider);
    await settleReal(t, rounds: 8);
    c.read(cartProvider.notifier).add(const CartLine('Article du panier de A', '', 7000, 'placeholder'));
    srv.tables.clear();
    c = await basculer(t, uid: _uidNeuf, email: 'neuf@example.test', compte: neuf);
    expect(c.read(cartProvider), isEmpty);
    expect(c.read(store.favoritesProvider), isEmpty);
    expect(c.read(store.ordersProvider), isEmpty);
    expect(c.read(notifsProvider), isEmpty);
    expect(c.read(formProvider), isEmpty);
    expect(c.read(authProvider).current?.serverId, _uidNeuf);
    expect(c.read(profileAccountProvider).serverId, _uidNeuf);
    await fermer(t);
  });

  testWidgets('A retrouve son panier enregistré pour lui seul ; le panier de B ne lui est pas montré', (t) async {
    final a = _compte(_uidA, 'a@example.test');
    final b = _compte(_uidB, 'b@example.test');
    await ouvrir(t, a);
    var c = containerOf(t);
    c.read(cartProvider);
    await settleReal(t);
    c.read(cartProvider.notifier).add(const CartLine('Article de A', '', 1000, 'placeholder'));
    await settleReal(t);
    c = await basculer(t, uid: _uidB, email: 'b@example.test', compte: b);
    c.read(cartProvider);
    await settleReal(t);
    expect(c.read(cartProvider), isEmpty);
    c.read(cartProvider.notifier).add(const CartLine('Article de B', '', 2000, 'placeholder'));
    await settleReal(t);
    c = await basculer(t, uid: _uidA, email: 'a@example.test', compte: a);
    c.read(cartProvider);
    await settleReal(t);
    final titres = c.read(cartProvider).map((l) => l.title).toList();
    expect(titres, ['Article de A'], reason: 'chaque compte ne voit que son panier');
    await fermer(t);
  });

  testWidgets('session expirée puis autre compte : les brouillons du premier ne sont pas repris', (t) async {
    final a = _compte(_uidA, 'a@example.test');
    final b = _compte(_uidB, 'b@example.test');
    await ouvrir(t, a);
    var c = containerOf(t);
    await Drafts.adoptOwner(_uidA);
    await Drafts.save('np', {'np_title': 'Brouillon de A'});
    // la session de A expire sans déconnexion demandée, puis B ouvre la sienne sur le même appareil
    appSessionExpired?.call();
    await settleReal(t);
    await Supabase.instance.client.auth.recoverSession(jsonEncode(_session(_uidB, 'b@example.test')));
    c = containerOf(t);
    c.read(authProvider.notifier).login(b);
    await settleReal(t, rounds: 8);
    expect(Drafts.values, isEmpty, reason: 'brouillon de A visible par B');
    expect(c.read(formProvider).containsKey('np_title'), isFalse);
    await fermer(t);
  });
}
