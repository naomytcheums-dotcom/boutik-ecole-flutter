import 'dart:convert';

import 'package:boutik_ecole/data/demo/section_a_demo.dart' show CartLine;
import 'package:boutik_ecole/data/repositories/repositories.dart' show cartProvider;
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/access.dart';
import 'package:boutik_ecole/figma/live/account_menu.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/client_space.dart';
import 'package:boutik_ecole/figma/live/espace.dart';
import 'package:boutik_ecole/figma/live/seller_capability.dart';
import 'package:boutik_ecole/figma/live/verification.dart' show myStudentStatusProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/render.dart';

/// Lot H5 : un seul parcours public -> inscription/connexion -> espace personnel -> achat ; capacité vendeur (écrans 57 à 69 et écran des conditions) ;
/// gardes d'authentification côté client ; retour à l'écran d'origine ; espace personnel. 390 px de large : un débordement fait échouer le test.

SellerCapability _cap({bool student = true, bool verified = true, bool phone = true, bool active = true, String role = 'student'}) => SellerCapability(
      canSell: student && verified && phone && active,
      canPublish: false,
      role: role,
      conditions: [
        (key: 'student', label: 'Compte étudiant', ok: student),
        (key: 'student_verified', label: 'Statut d’étudiant vérifié (pièce validée ou compte certifié)', ok: verified),
        (key: 'phone_verified', label: 'Numéro de téléphone vérifié par un code', ok: phone),
        (key: 'not_suspended', label: 'Compte non suspendu', ok: active),
      ],
    );

final _client = demoAccount.copyWith(role: 0, serverId: 'c1');
final _student = demoAccount.copyWith(role: 1, serverId: 's1');

void main() {
  setUpAll(loadAppFonts);
  setUp(() {
    GScreen.mockupFrame = false;
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = false;
  });

  Future<ProviderContainer> monter(WidgetTester t, Widget Function(BuildContext, WidgetRef) page, {Account? account, bool serveur = true, bool ignoreInkWarning = false, List<Override> overrides = const []}) async {
    Backend.ready = serveur;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    Widget ecran(String texte) => Scaffold(body: Center(child: Text(texte)));
    final router = GoRouter(initialLocation: '/ici?x=1', routes: [
      GoRoute(path: '/ici', builder: (_, _) => Consumer(builder: (c, ref, _) => page(c, ref))),
      GoRoute(
        path: '/s/:id',
        builder: (_, s) => Consumer(
          builder: (c, ref, _) => Scaffold(
            body: Column(children: [
              Text('ecran ${s.pathParameters['id']}'),
              TextButton(onPressed: () => finishAuthFlow(ref, c), child: const Text('Terminer')),
            ]),
          ),
        ),
      ),
      GoRoute(path: '/parametres/informations', builder: (_, _) => ecran('page informations')),
      GoRoute(path: '/aide/contact', builder: (_, _) => ecran('page support')),
      GoRoute(path: '/vendeur/conditions', builder: (_, _) => ecran('page conditions')),
    ]);
    await t.pumpWidget(ProviderScope(key: UniqueKey(), overrides: [myStudentStatusProvider.overrideWith((ref) async => null), ...overrides], child: MaterialApp.router(routerConfig: router)));
    await t.pumpAndSettle();
    final c = ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
    if (account != null) {
      c.read(authProvider.notifier).login(account);
      await t.pumpAndSettle();
    }
    // « Mes rubriques » (écran existant) pose un ListTile dans un cadre coloré : avertissement de débogage sans rapport avec ces tests
    if (ignoreInkWarning) {
      while (t.takeException() != null) {}
    }
    return c;
  }

  group('capacité vendeur : écrans vendeur et conditions', () {
    testWidgets('un client voit les conditions (jamais l’espace vendeur) et le compte reste le même', (t) async {
      await monter(t, (_, _) => const SellerGate(child: Text('ESPACE VENDEUR')), account: _client, overrides: [
        sellerCapabilityProvider.overrideWith((ref) async => _cap(student: false, verified: false, phone: true, role: 'client')),
      ]);
      expect(find.text('ESPACE VENDEUR'), findsNothing);
      expect(find.text('Vendre sur Boutik-École'), findsOneWidget);
      expect(find.textContaining('Vous gardez le même compte'), findsOneWidget);
      expect(find.text('Compte étudiant'), findsOneWidget);
      expect(find.text('Vérifier mon téléphone'), findsNothing, reason: 'conditions déjà remplies ou hors sujet pour un client');
      expect(find.text('Vérifier mon statut d’étudiant'), findsNothing, reason: 'un client n’est pas invité à vérifier un statut d’étudiant');
    });

    testWidgets('un étudiant dont le téléphone n’est pas vérifié : condition manquante et démarche pour la remplir', (t) async {
      await monter(t, (_, _) => const SellerGate(child: Text('ESPACE VENDEUR')), account: _student, overrides: [
        sellerCapabilityProvider.overrideWith((ref) async => _cap(phone: false)),
      ]);
      expect(find.text('ESPACE VENDEUR'), findsNothing);
      expect(find.text('Vérifier mon téléphone'), findsOneWidget);
      await t.tap(find.text('Vérifier mon téléphone'));
      await t.pumpAndSettle();
      expect(find.text('page informations'), findsOneWidget);
    });

    testWidgets('étudiant sans statut vérifié : démarche de vérification proposée', (t) async {
      await monter(t, (_, _) => const SellerGate(child: Text('ESPACE VENDEUR')), account: _student, overrides: [
        sellerCapabilityProvider.overrideWith((ref) async => _cap(verified: false)),
      ]);
      expect(find.text('Vérifier mon statut d’étudiant'), findsOneWidget);
      expect(find.text('ESPACE VENDEUR'), findsNothing);
    });

    testWidgets('compte suspendu : condition expliquée, contact du support', (t) async {
      await monter(t, (_, _) => const SellerGate(child: Text('ESPACE VENDEUR')), account: _student, overrides: [
        sellerCapabilityProvider.overrideWith((ref) async => _cap(active: false)),
      ]);
      expect(find.text('Contacter le support'), findsOneWidget);
      await t.tap(find.text('Contacter le support'));
      await t.pumpAndSettle();
      expect(find.text('page support'), findsOneWidget);
    });

    testWidgets('capacité réunie : l’espace vendeur s’ouvre', (t) async {
      await monter(t, (_, _) => const SellerGate(child: Text('ESPACE VENDEUR')), account: _student, overrides: [
        sellerCapabilityProvider.overrideWith((ref) async => _cap()),
      ]);
      expect(find.text('ESPACE VENDEUR'), findsOneWidget);
    });

    testWidgets('lecture de la capacité en échec : aucun accès accordé, bouton Réessayer', (t) async {
      await monter(t, (_, _) => const SellerGate(child: Text('ESPACE VENDEUR')), account: _student, overrides: [
        sellerCapabilityProvider.overrideWith((ref) async => throw Exception('réseau')),
      ]);
      expect(find.text('ESPACE VENDEUR'), findsNothing);
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('non connecté : invitation à se connecter, jamais l’espace vendeur', (t) async {
      await monter(t, (_, _) => const SellerGate(child: Text('ESPACE VENDEUR')));
      expect(find.text('ESPACE VENDEUR'), findsNothing);
      expect(find.text('Connexion requise'), findsOneWidget);
    });

    testWidgets('hors connexion au serveur (aperçu) : l’écran reste ouvert', (t) async {
      await monter(t, (_, _) => const SellerGate(child: Text('ESPACE VENDEUR')), serveur: false);
      expect(find.text('ESPACE VENDEUR'), findsOneWidget);
    });

    testWidgets('AccessGuard : écrans 57 à 69 conditionnés par la capacité, quel que soit le rôle', (t) async {
      for (final id in ['57', '58', '63', '69']) {
        await monter(t, (_, _) => AccessGuard(id: id, child: const Text('ECRAN')), account: _client, overrides: [
          sellerCapabilityProvider.overrideWith((ref) async => _cap(student: false, role: 'client')),
        ]);
        expect(find.text('ECRAN'), findsNothing, reason: id);
        expect(find.text('Vendre sur Boutik-École'), findsOneWidget, reason: id);
      }
      await monter(t, (_, _) => const AccessGuard(id: '58', child: Text('ECRAN')), account: _student, overrides: [sellerCapabilityProvider.overrideWith((ref) async => _cap())]);
      expect(find.text('ECRAN'), findsOneWidget);
      expect(isSellerScreenId('57'), isTrue);
      expect(isSellerScreenId('69'), isTrue);
      expect(isSellerScreenId('56'), isFalse);
      expect(isSellerScreenId('70'), isFalse);
      expect(isSellerScreenId('57b'), isFalse);
    });
  });

  group('gardes d’authentification côté client', () {
    testWidgets('le parcours personnel exige un compte : « Connexion requise » pour une personne non connectée', (t) async {
      for (final id in ['45', '25', '27', '09', '50', '52', '261', '148-1']) {
        await monter(t, (_, _) => AccessGuard(id: id, child: const Text('ECRAN')));
        expect(find.text('ECRAN'), findsNothing, reason: id);
        expect(find.text('Connexion requise'), findsOneWidget, reason: id);
        expect(find.text('Se connecter'), findsOneWidget, reason: id);
      }
    });

    testWidgets('connecté, ces écrans s’ouvrent ; les écrans publics restent ouverts à tous', (t) async {
      await monter(t, (_, _) => const AccessGuard(id: '45', child: Text('ECRAN')), account: _client);
      expect(find.text('ECRAN'), findsOneWidget);
      await monter(t, (_, _) => const AccessGuard(id: '03', child: Text('ACCUEIL')));
      expect(find.text('ACCUEIL'), findsOneWidget);
      await monter(t, (_, _) => const AccessGuard(id: '05', child: Text('PRODUIT')));
      expect(find.text('PRODUIT'), findsOneWidget);
    });

    testWidgets('aperçu hors serveur : aucun blocage', (t) async {
      await monter(t, (_, _) => const AccessGuard(id: '45', child: Text('ECRAN')), serveur: false);
      expect(find.text('ECRAN'), findsOneWidget);
    });
  });

  group('retour à l’écran d’origine', () {
    testWidgets('« Se connecter » mémorise l’écran d’origine ; la fin du parcours y ramène (même après un remplacement de la pile)', (t) async {
      late BuildContext ctx;
      final c = await monter(t, (context, ref) {
        ctx = context;
        return Scaffold(body: Center(child: TextButton(onPressed: () => requireLogin(context, ref, 'tester'), child: const Text('Agir'))));
      });
      await t.tap(find.text('Agir'));
      await t.pumpAndSettle();
      expect(find.text('Un compte est nécessaire'), findsOneWidget);
      await t.tap(find.text('Créer un compte'));
      await t.pumpAndSettle();
      expect(find.text('ecran 12'), findsOneWidget);
      expect(c.read(returnToProvider)?.location, '/ici?x=1');
      // l'inscription remplace la pile (13, 18b…) : la pile ne contient plus l'écran d'origine
      GoRouter.of(ctx).go('/s/18b');
      await t.pumpAndSettle();
      expect(find.text('ecran 18b'), findsOneWidget);
      await t.tap(find.text('Terminer'));
      await t.pumpAndSettle();
      expect(find.text('Agir'), findsOneWidget, reason: 'retour à l’écran qui demandait la connexion');
      expect(c.read(returnToProvider), isNull);
    });

    testWidgets('« Plus tard » n’en garde aucune trace ; sans origine, retour à l’accueil du rôle', (t) async {
      final c = await monter(t, (context, ref) => Scaffold(body: Center(child: TextButton(onPressed: () => requireLogin(context, ref, 'tester'), child: const Text('Agir')))));
      c.read(returnToProvider.notifier).set((location: '/ancien', at: DateTime.now()));
      await t.tap(find.text('Agir'));
      await t.pumpAndSettle();
      await t.tap(find.text('Plus tard'));
      await t.pumpAndSettle();
      expect(c.read(returnToProvider), isNull);
      expect(find.text('Agir'), findsOneWidget);
    });

    test('adresses du parcours de compte : jamais une destination de retour', () {
      expect(isAuthLocation('/s/11'), isTrue);
      expect(isAuthLocation('/s/12?x=1'), isTrue);
      expect(isAuthLocation('/s/18b'), isTrue);
      expect(isAuthLocation('/s/45'), isFalse);
      expect(isAuthLocation('/marche/produit/abc'), isFalse);
      expect(returnToLifetime, const Duration(minutes: 30));
    });

    testWidgets('destination périmée (plus de 30 min) : oubliée', (t) async {
      late WidgetRef r;
      final c = await monter(t, (context, ref) {
        r = ref;
        return const Scaffold(body: Text('x'));
      });
      c.read(returnToProvider.notifier).set((location: '/s/45', at: DateTime.now().subtract(const Duration(minutes: 31))));
      expect(takeReturnTo(r), isNull);
      c.read(returnToProvider.notifier).set((location: '/s/45', at: DateTime.now()));
      expect(takeReturnTo(r), '/s/45');
      c.read(returnToProvider.notifier).set((location: '/s/11', at: DateTime.now()));
      expect(takeReturnTo(r), isNull);
    });
  });

  group('panier du visiteur conservé à la connexion', () {
    test('le panier enregistré du visiteur est repris par le compte, une seule fois', () async {
      Backend.ready = true;
      addTearDown(() => Backend.ready = false);
      SharedPreferences.setMockInitialValues({
        'boutik.cart.guest': jsonEncode([const CartLine('Lampe', 'GI', 5000, 'x', qty: 2).toJson()]),
      });
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(cartProvider);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      c.read(authProvider.notifier).login(_client);
      c.read(cartProvider);
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      final cart = c.read(cartProvider);
      expect(cart.length, 1);
      expect(cart.first.title, 'Lampe');
      expect(cart.first.qty, 2);
      final p = await SharedPreferences.getInstance();
      expect(p.getString('boutik.cart.guest'), isNull, reason: 'le panier du visiteur a été transféré');
      expect(p.getString('boutik.cart.c1'), isNotNull);
    });
  });

  group('menus sans « deux espaces »', () {
    test('personne non connectée : invitation à se connecter, aucun écran personnel', () {
      final l = accountMenuLabels('visitor');
      expect(l, containsAll(['Se connecter', 'Créer un compte', 'Marketplace']));
      for (final x in ['Mes commandes', 'Mes favoris', 'Mes adresses', 'Mes avis', 'Messages', 'Notifications', 'Mon espace', 'Paramètres', 'Mes litiges']) {
        expect(l, isNot(contains(x)), reason: x);
      }
      expect(roleNames['visitor'], 'Non connecté');
    });

    test('client : espace personnel complet et « Devenir vendeur » ; pas d’outils vendeur', () {
      final l = accountMenuLabels('client');
      expect(l, containsAll(['Mes commandes', 'Mes favoris', 'Mes adresses', 'Mes avis', 'Mes litiges', 'Mes réclamations', 'Informations personnelles', 'Mon espace', 'Devenir vendeur (conditions)']));
      expect(l, isNot(contains('Tableau de bord')));
      expect(l, isNot(contains('Se connecter')));
      expect(l.where((x) => x.contains('client')).toList(), isEmpty, reason: 'plus de libellé « client » dans le menu');
    });

    test('étudiant : outils vendeur seulement avec la capacité, sinon « Devenir vendeur »', () {
      final sans = accountMenuLabels('student', cap: _cap(phone: false));
      expect(sans, contains('Devenir vendeur (conditions)'));
      for (final x in ['Tableau de bord', 'Mes annonces', 'Commandes reçues', 'Stocks', 'Revenus', 'Statistiques', 'Publier un service', 'Conformité du compte']) {
        expect(sans, isNot(contains(x)), reason: x);
      }
      expect(sans, containsAll(['Mes documents', 'Mon CV vivant']), reason: 'les outils d’étudiant restent');
      final avec = accountMenuLabels('student', cap: _cap());
      expect(avec, containsAll(['Tableau de bord', 'Mes annonces', 'Commandes reçues', 'Stocks', 'Revenus']));
      expect(avec, isNot(contains('Devenir vendeur (conditions)')));
      expect(accountMenuLabels('student'), contains('Tableau de bord'), reason: 'capacité inconnue (aperçu) : rien n’est caché');
    });

    test('les autres rôles ne reçoivent ni outils vendeur ni invitation à devenir vendeur', () {
      for (final r in ['company', 'dept', 'direction', 'finance', 'support', 'admin']) {
        final l = accountMenuLabels(r, cap: _cap(student: false, role: r));
        expect(l, isNot(contains('Devenir vendeur (conditions)')), reason: r);
        expect(l, isNot(contains('Mes annonces')), reason: r);
      }
    });

    testWidgets('Mes rubriques : invitation à se connecter, libellé « Non connecté », rubrique « Espace vendeur »', (t) async {
      await monter(t, (_, _) => const EspaceScreen(), serveur: false, ignoreInkWarning: true);
      expect(find.textContaining('Non connecté'), findsOneWidget);
      expect(find.text('Un seul compte pour tout'), findsOneWidget);
      expect(find.text('Se connecter'), findsOneWidget);
      expect(find.text('Créer un compte'), findsOneWidget);
      expect(rubriques.any((r) => r.titre == 'Espace vendeur'), isTrue);
      expect(rubriques.any((r) => r.titre.contains('étudiant-vendeur')), isFalse);
    });

    testWidgets('Mes rubriques : un étudiant sans capacité voit « Devenir vendeur », pas les écrans 57 à 69', (t) async {
      await monter(t, (_, _) => const EspaceScreen(), account: _student, ignoreInkWarning: true, overrides: [sellerCapabilityProvider.overrideWith((ref) async => _cap(verified: false))]);
      expect(find.text('Devenir vendeur'), findsOneWidget);
      final data = rubriquesPour(_student, sellerOk: false);
      expect(data.values.expand((x) => x).any((e) => isSellerScreenId(e.$1)), isFalse);
      expect(rubriquesPour(_student).values.expand((x) => x).any((e) => isSellerScreenId(e.$1)), isTrue);
    });
  });

  group('espace personnel : mes avis', () {
    testWidgets('avis publiés : note, commentaire, commande ; retrait avec confirmation', (t) async {
      final avis = [
        {'kind': 'product', 'id': 'r1', 'title': 'Lampe en bois', 'rating': 4, 'comment': 'Très belle finition', 'created_at': '2026-11-10T10:00:00Z', 'order_number': '#BE-2026-0142'},
        {'kind': 'shop', 'id': 's1', 'title': 'Atelier Awa', 'rating': 5, 'comment': null, 'created_at': '2026-11-11T10:00:00Z', 'order_number': null},
      ];
      await monter(t, (_, _) => const MyReviewsScreen(), account: _client, overrides: [myReviewsProvider.overrideWith((ref) async => avis)]);
      expect(find.text('Lampe en bois'), findsOneWidget);
      expect(find.text('Très belle finition'), findsOneWidget);
      expect(find.textContaining('#BE-2026-0142'), findsOneWidget);
      expect(find.text('Atelier Awa'), findsOneWidget);
      expect(find.text('Retirer'), findsNWidgets(2));
      await t.tap(find.text('Retirer').first);
      await t.pumpAndSettle();
      expect(find.text('Retirer cet avis ?'), findsOneWidget);
      await t.tap(find.text('Garder'));
      await t.pumpAndSettle();
      expect(find.text('Retirer cet avis ?'), findsNothing);
    });

    testWidgets('aucun avis : état vide explicite ; lecture en échec : message et pas de liste inventée', (t) async {
      await monter(t, (_, _) => const MyReviewsScreen(), account: _client, overrides: [myReviewsProvider.overrideWith((ref) async => <Map<String, dynamic>>[])]);
      expect(find.textContaining('Vous n’avez publié aucun avis'), findsOneWidget);
      await monter(t, (_, _) => const MyReviewsScreen(), account: _client, overrides: [myReviewsProvider.overrideWith((ref) async => throw Exception('hors ligne'))]);
      expect(find.textContaining('Vous n’avez publié aucun avis'), findsNothing);
    });

    testWidgets('non connecté : invitation à se connecter', (t) async {
      await monter(t, (_, _) => const MyReviewsScreen());
      expect(find.text('Connexion requise'), findsOneWidget);
    });
  });
}
