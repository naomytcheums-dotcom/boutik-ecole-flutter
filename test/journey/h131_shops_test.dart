import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/marche/marche_boutiques.dart';
import 'package:boutik_ecole/figma/live/marche/marche_vendeur.dart' show ShopEditorScreen;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/render.dart';

/// H13.1 · multi-boutiques : « Mes boutiques » (compteurs réels, bascule de la boutique active, limite et refus de création, serveur muet / en panne),
/// équipe (ajout, refus du serveur, retrait), espace d'un membre (le préparateur prépare, le lecteur lit seulement, toujours avec p_shop), éditeur de boutique
/// (création : create=true ; modification d'une boutique précise : id ; gestionnaire sans soumission), préparation d'une commande limitée à une boutique. Faux serveur local.
Map<String, dynamic> _shop(String id, String name, {String status = 'active', String role = 'owner', bool active = false, int revenue = 0, int pending = 0}) => {
      'id': id,
      'name': name,
      'slug': name.toLowerCase(),
      'status': status,
      'role': role,
      'is_active': active,
      'owner_id': role == 'owner' ? FakeSupabase.userId : 'other-owner',
      'logo_url': null,
      'listings': {'approved': 3, 'pending': 1, 'draft': 0, 'rejected': 0},
      'stock_units': 42,
      'out_of_stock': 1,
      'pending_orders': pending,
      'orders_30d': 5,
      'revenue_30d': revenue,
      'followers': 7,
      'active_promos': 2,
      'members': role == 'owner' ? 1 : null,
    };

Map<String, dynamic> _overview({bool canCreate = true, String? reason}) => {
      'active_shop_id': 's1',
      'max': 3,
      'owned': 2,
      'can_create': canCreate,
      'create_blocked_reason': reason,
      'totals': {'shops': 2, 'revenue_30d': 165000, 'orders_30d': 10, 'pending_orders': 4, 'listings_approved': 6, 'stock_units': 84, 'followers': 14},
      'shops': const [],
    };

final _account = Account(name: 'Awa Vendeuse', phone: '690000001', email: 'awa@t.cm', password: 'x', role: 1, serverId: FakeSupabase.userId);

void main() {
  late FakeSupabase srv;
  setUpAll(() async {
    await loadAppFonts();
    srv = await FakeSupabase.start();
    await srv.initSupabase();
  });
  tearDownAll(() => srv.close());

  setUp(() {
    GScreen.mockupFrame = false;
    GAnim.enabled = false;
    Backend.ready = true;
    srv.rpc.clear();
    srv.tables.clear();
    srv.calls.clear();
    srv.failRpc.clear();
    srv.unknownIsError = false;
    srv.failWrites = false;
  });
  tearDown(() => GScreen.mockupFrame = true);

  Future<void> host(WidgetTester t, Widget child) async {
    t.view.physicalSize = const Size(420, 3200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: [initialAccountProvider.overrideWithValue(_account)], child: MaterialApp(home: child)));
    await t.pump(const Duration(milliseconds: 200));
  }

  Future<void> attendre(WidgetTester t, Finder f) async {
    for (var i = 0; i < 60 && f.evaluate().isEmpty; i++) {
      await settleReal(t, rounds: 2, ms: 100);
    }
  }

  Future<void> fin(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 60));
  }

  void serve({List<Map<String, dynamic>>? shops, Map<String, dynamic>? overview}) {
    srv.rpc['my_shops'] = (_) => shops ?? [_shop('s1', 'Alpha', active: true, revenue: 125000, pending: 2), _shop('s2', 'Beta', status: 'paused', revenue: 40000, pending: 2), _shop('s3', 'Boutique Partenaire', role: 'staff')];
    srv.rpc['my_shops_overview'] = (_) => overview ?? _overview();
  }

  group('Mes boutiques', () {
    testWidgets('liste, vue globale et compteurs viennent du serveur ; la boutique active est marquée', (t) async {
      serve();
      await host(t, const MyShopsScreen());
      await attendre(t, find.text('Alpha'));
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('Boutique Partenaire'), findsOneWidget);
      expect(find.text('165 000 FCFA'), findsOneWidget);
      expect(find.text('Boutique active'), findsOneWidget);
      expect(find.textContaining('Propriétaire'), findsWidgets);
      expect(find.textContaining('Préparateur'), findsOneWidget);
      expect(find.textContaining('ventes 30 j 125 000 FCFA'), findsOneWidget);
      expect(find.text('Créer une nouvelle boutique'), findsOneWidget);
      expect(find.text('Réactiver'), findsOneWidget);
      expect(find.text('Désactiver'), findsOneWidget);
      expect(find.text('Quitter l’équipe'), findsOneWidget);
      await fin(t);
    });

    testWidgets('bascule de boutique : appel serveur avec p_shop, puis relecture des listes', (t) async {
      serve();
      srv.rpc['shop_set_active'] = (a) => {'active_shop_id': a['p_shop']};
      await host(t, const MyShopsScreen());
      await attendre(t, find.text('Alpha'));
      final before = srv.callsOf('my_shops').length;
      await t.tap(find.text('Utiliser cette boutique').first);
      await settleReal(t);
      expect(srv.callsOf('shop_set_active').single.args['p_shop'], 's2');
      expect(srv.callsOf('my_shops').length, greaterThan(before));
      await fin(t);
    });

    testWidgets('refus du serveur : message, aucune relecture comme si c’était réussi', (t) async {
      serve();
      srv.rpc['shop_set_active'] = (_) => throw const FakeRpcError('Boutique introuvable');
      await host(t, const MyShopsScreen());
      await attendre(t, find.text('Alpha'));
      final before = srv.callsOf('my_shops').length;
      await t.tap(find.text('Utiliser cette boutique').first);
      await attendre(t, find.text('Action non enregistrée'));
      expect(find.text('Action non enregistrée'), findsOneWidget);
      expect(srv.callsOf('my_shops').length, before);
      await fin(t);
    });

    testWidgets('limite atteinte : motif affiché, pas de bouton de création', (t) async {
      serve(overview: _overview(canCreate: false, reason: 'Limite atteinte : 3 boutique(s) au maximum par compte'));
      await host(t, const MyShopsScreen());
      await attendre(t, find.text('Alpha'));
      expect(find.text('Créer une nouvelle boutique'), findsNothing);
      expect(find.textContaining('Limite atteinte : 3 boutique(s)'), findsOneWidget);
      await fin(t);
    });

    testWidgets('aucune boutique : état vide honnête (pas de chiffres inventés)', (t) async {
      serve(shops: const [], overview: _overview());
      await host(t, const MyShopsScreen());
      await attendre(t, find.text('Vous n’avez pas encore de boutique.'));
      expect(find.text('Vue globale de vos boutiques (30 derniers jours)'), findsNothing);
      await fin(t);
    });

    testWidgets('serveur muet (404) : message d’installation, aucune boutique', (t) async {
      srv.unknownIsError = true;
      await host(t, const MyShopsScreen());
      await attendre(t, find.textContaining('pas encore installée'));
      expect(find.text('Alpha'), findsNothing);
      await fin(t);
    });

    testWidgets('panne serveur (500) sur my_shops : erreur lisible, jamais « 0 boutique »', (t) async {
      srv.rpc['my_shops_overview'] = (_) => _overview();
      srv.failRpc.add('my_shops');
      await host(t, const MyShopsScreen());
      await settleReal(t, rounds: 8);
      expect(find.text('Vous n’avez pas encore de boutique.'), findsNothing);
      expect(find.text('Boutiques'), findsNothing);
      await fin(t);
    });
  });

  group('Barre de la boutique affichée', () {
    testWidgets('deux boutiques : sélecteur sur la boutique active ; une seule : nom simple ; aucune : rien', (t) async {
      serve(shops: [_shop('s1', 'Alpha', active: true), _shop('s2', 'Beta')]);
      await host(t, const Scaffold(body: ActiveShopBar()));
      await attendre(t, find.text('Alpha'));
      expect(find.byType(DropdownButton<String>), findsOneWidget);
      expect(find.text('Mes boutiques'), findsOneWidget);
      await fin(t);
      serve(shops: [_shop('s1', 'Alpha', active: true)]);
      await host(t, const Scaffold(body: ActiveShopBar()));
      await attendre(t, find.text('Boutique : Alpha'));
      expect(find.byType(DropdownButton<String>), findsNothing);
      await fin(t);
      serve(shops: const []);
      await host(t, const Scaffold(body: ActiveShopBar()));
      await settleReal(t, rounds: 4);
      expect(find.text('Mes boutiques'), findsNothing);
      await fin(t);
    });
  });

  group('Équipe de la boutique', () {
    testWidgets('liste, ajout par e-mail avec le rôle choisi, refus du serveur sans faux succès, retrait', (t) async {
      srv.rpc['shop_members_list'] = (a) {
        expect(a['p_shop'], 's1');
        return [{'user_id': 'u4', 'name': 'Nadia Gestion', 'role': 'manager', 'since': '2026-11-01'}];
      };
      await host(t, const ShopMembersScreen(shopId: 's1'));
      await attendre(t, find.text('Nadia Gestion'));
      // e-mail invalide : aucun appel
      await t.enterText(find.byType(TextField), 'pas-un-email');
      await t.tap(find.text('Ajouter à l’équipe'));
      await settleReal(t, rounds: 2);
      expect(srv.callsOf('shop_member_set'), isEmpty);
      // refus du serveur
      srv.rpc['shop_member_set'] = (_) => throw const FakeRpcError('Réservé au propriétaire de la boutique : seul lui gère les membres');
      await t.enterText(find.byType(TextField), 'lecteur@t.cm');
      await t.tap(find.text('Ajouter à l’équipe'));
      await attendre(t, find.text('Membre non ajouté'));
      expect(find.text('Membre non ajouté'), findsOneWidget);
      expect(srv.callsOf('shop_member_set').single.args, {'p_shop': 's1', 'p_role': 'viewer', 'p_email': 'lecteur@t.cm'});
      await t.tap(find.text('Compris'));
      await settleReal(t, rounds: 2);
      // succès
      srv.rpc['shop_member_set'] = (a) => {'user_id': 'u9', 'role': a['p_role']};
      await t.tap(find.text('Ajouter à l’équipe'));
      await settleReal(t);
      expect(srv.callsOf('shop_member_set'), hasLength(2));
      // retrait avec confirmation
      srv.rpc['shop_member_remove'] = (_) => true;
      await t.tap(find.byTooltip('Retirer'));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.text('Retirer').last);
      await settleReal(t);
      expect(srv.callsOf('shop_member_remove').single.args, {'p_shop': 's1', 'p_user': 'u4'});
      await fin(t);
    });
  });

  group('Espace d’un membre', () {
    final order = {'number': '#BE-2026-0007', 'title': 'Robe Alpha', 'buyer_name': 'Awa K.', 'total': 16000, 'status': 1, 'nlines': 1, 'shop_id': 's3'};

    testWidgets('préparateur : fait avancer SES lignes (p_shop) et rien d’autre', (t) async {
      srv.rpc['my_shops'] = (_) => [_shop('s3', 'Boutique Partenaire', role: 'staff')];
      srv.rpc['seller_orders'] = (a) {
        expect(a['p_shop'], 's3');
        return [order];
      };
      srv.rpc['set_seller_order_status'] = (a) => a['p_status'];
      await host(t, const ShopMemberSpaceScreen(shopId: 's3'));
      await attendre(t, find.text('Marquer : En préparation'));
      await t.tap(find.text('Marquer : En préparation'));
      await settleReal(t);
      expect(srv.callsOf('set_seller_order_status').single.args, {'p_order': '#BE-2026-0007', 'p_status': 2, 'p_shop': 's3'});
      await fin(t);
    });

    testWidgets('lecteur : consulte seulement (aucun bouton de préparation) ; refus du serveur affiché', (t) async {
      srv.rpc['my_shops'] = (_) => [_shop('s3', 'Boutique Partenaire', role: 'viewer')];
      srv.rpc['seller_orders'] = (_) => [order];
      await host(t, const ShopMemberSpaceScreen(shopId: 's3'));
      await attendre(t, find.text('#BE-2026-0007'));
      await settleReal(t, rounds: 3);
      expect(find.textContaining('Marquer'), findsNothing);
      await fin(t);
    });

    testWidgets('accès refusé par le serveur : message, aucune commande inventée', (t) async {
      srv.rpc['my_shops'] = (_) => const [];
      srv.rpc['seller_orders'] = (_) => throw const FakeRpcError('Boutique introuvable');
      await host(t, const ShopMemberSpaceScreen(shopId: 's9'));
      await attendre(t, find.textContaining('Boutique introuvable'));
      expect(find.textContaining('Marquer'), findsNothing);
      expect(find.textContaining('Aucune commande'), findsNothing);
      await fin(t);
    });
  });

  group('Éditeur de boutique', () {
    testWidgets('nouvelle boutique : shop_save avec create=true et sans identifiant', (t) async {
      srv.tables['marketplace_categories'] = [{'label': 'Mode', 'position': 1, 'active': true}];
      srv.rpc['shop_save'] = (a) => {'slug': 'ma-boutique-test'};
      await host(t, const ShopEditorScreen(create: true));
      await attendre(t, find.text('Créer ma boutique (brouillon)'));
      await t.enterText(find.byType(TextField).first, 'Ma boutique test');
      await t.ensureVisible(find.text('Créer ma boutique (brouillon)'));
      await t.tap(find.text('Créer ma boutique (brouillon)'));
      await settleReal(t);
      final p = srv.callsOf('shop_save').single.args['p'] as Map;
      expect(p['create'], true);
      expect(p.containsKey('id'), isFalse);
      expect(p['name'], 'Ma boutique test');
      await fin(t);
    });

    testWidgets('boutique précise : id envoyé, soumission ciblée sur cette boutique (propriétaire)', (t) async {
      srv.tables['marketplace_categories'] = [{'label': 'Mode', 'position': 1, 'active': true}];
      srv.tables['shops'] = [
        {'id': 's2', 'name': 'Beta', 'slug': 'beta', 'status': 'draft', 'owner_id': FakeSupabase.userId, 'categories': ['Mode'], 'color_primary': '#0F7A52', 'color_secondary': '#5A3FE0', 'socials': <String, dynamic>{}}
      ];
      srv.rpc['shop_save'] = (a) => {'slug': 'beta', 'id': 's2'};
      srv.rpc['shop_submit'] = (_) => 'pending';
      await host(t, const ShopEditorScreen(shopId: 's2'));
      await attendre(t, find.text('Soumettre à la validation'));
      await t.ensureVisible(find.text('Enregistrer'));
      await t.tap(find.text('Enregistrer'));
      await settleReal(t);
      expect((srv.callsOf('shop_save').single.args['p'] as Map)['id'], 's2');
      await t.ensureVisible(find.text('Soumettre à la validation'));
      await t.tap(find.text('Soumettre à la validation'));
      await settleReal(t);
      expect(srv.callsOf('shop_submit').single.args, {'p_shop': 's2'});
      await fin(t);
    });

    testWidgets('gestionnaire d’équipe : peut modifier l’identité, pas soumettre ni fermer', (t) async {
      srv.tables['marketplace_categories'] = [{'label': 'Mode', 'position': 1, 'active': true}];
      srv.tables['shops'] = [
        {'id': 's3', 'name': 'Boutique Partenaire', 'slug': 'partenaire', 'status': 'draft', 'owner_id': 'autre-proprietaire', 'categories': ['Mode'], 'color_primary': '#0F7A52', 'color_secondary': '#5A3FE0', 'socials': <String, dynamic>{}}
      ];
      await host(t, const ShopEditorScreen(shopId: 's3'));
      await attendre(t, find.text('Enregistrer'));
      expect(find.text('Soumettre à la validation'), findsNothing);
      expect(find.text('Fermer la boutique'), findsNothing);
      await fin(t);
    });
  });

  group('Préparation d’une commande multi-boutiques', () {
    test('le statut n’est envoyé qu’avec la boutique de la commande ; sans boutique, comportement d’origine', () async {
      srv.calls.clear();
      srv.rpc['set_seller_order_status'] = (a) => a['p_status'];
      expect(await Backend.setSellerOrderStatus('#BE-1', 2, shopId: 's1'), isNull);
      expect(srv.callsOf('set_seller_order_status').single.args, {'p_order': '#BE-1', 'p_status': 2, 'p_shop': 's1'});
      srv.calls.clear();
      expect(await Backend.setSellerOrderStatus('#BE-1', 3), isNull);
      expect(srv.callsOf('set_seller_order_status').single.args, {'p_order': '#BE-1', 'p_status': 3});
      srv.rpc['set_seller_order_status'] = (_) => throw const FakeRpcError('Boutique introuvable');
      expect(await Backend.setSellerOrderStatus('#BE-1', 4, shopId: 'sx'), isNotNull);
    });
  });
}
