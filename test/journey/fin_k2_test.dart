import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/espace.dart';
import 'package:boutik_ecole/figma/live/marche/marche_data.dart' show shopStatusLabels;
import 'package:boutik_ecole/figma/live/seller_capability.dart';
import 'package:boutik_ecole/figma/live/verification.dart' show myStudentStatusProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/render.dart';

/// Lot K2 : éligibilité vendeur imposée par le serveur ; pause / reprise de la boutique. 390 px de large : un débordement fait échouer le test.
/// Le serveur n'est pas joignable dans ces tests (Backend prêt, sans client) : un appel de pause ou de reprise échoue et l'écran ne doit JAMAIS annoncer un succès.

SellerCapability _cap({bool canSell = true, bool paused = false, String role = 'student', bool phone = true}) => SellerCapability(
      canSell: canSell,
      canPublish: false,
      paused: paused,
      role: role,
      conditions: [
        (key: 'student', label: 'Compte étudiant', ok: role == 'student'),
        (key: 'student_verified', label: 'Statut d’étudiant vérifié (pièce validée ou compte certifié)', ok: canSell),
        (key: 'phone_verified', label: 'Numéro de téléphone vérifié par un code', ok: phone),
        (key: 'not_suspended', label: 'Compte non suspendu', ok: true),
      ],
    );

final _student = demoAccount.copyWith(role: 1, serverId: 's1');
const _pauseOk = 'Boutique en pause : vos annonces sont masquées.';
const _resumeOk = 'Boutique reprise : vos annonces sont de nouveau visibles.';

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

  Future<void> monter(WidgetTester t, Widget page, {List<Override> overrides = const []}) async {
    Backend.ready = true;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final router = GoRouter(initialLocation: '/ici', routes: [
      GoRoute(path: '/ici', builder: (_, _) => page),
      GoRoute(path: '/vendeur/conditions', builder: (_, _) => const Scaffold(body: Center(child: Text('page conditions')))),
    ]);
    await t.pumpWidget(ProviderScope(key: UniqueKey(), overrides: [myStudentStatusProvider.overrideWith((ref) async => null), ...overrides], child: MaterialApp.router(routerConfig: router)));
    await t.pumpAndSettle();
    final c = ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
    c.read(authProvider.notifier).login(_student);
    await t.pumpAndSettle();
  }

  group('capacité vendeur : lecture de la pause', () {
    test('la réponse du serveur porte l’état de pause ; absent = pas en pause', () {
      expect(SellerCapability.fromJson({'can_sell': true, 'role': 'student', 'paused': true, 'conditions': []}).paused, isTrue);
      expect(SellerCapability.fromJson({'can_sell': true, 'role': 'student', 'conditions': []}).paused, isFalse);
      expect(SellerCapability.fromJson({'can_sell': false, 'role': 'client', 'paused': false, 'conditions': []}).canSell, isFalse);
    });

    test('la boutique en pause a son libellé', () {
      expect(shopStatusLabels['paused'], 'En pause');
      expect(shopStatusLabels.keys, containsAll(['draft', 'pending', 'active', 'suspended', 'closed', 'paused']));
    });
  });

  group('pause et reprise de la boutique', () {
    testWidgets('vendeur éligible : carte « Boutique ouverte », confirmation avant la pause, « Annuler » ne fait rien', (t) async {
      await monter(t, const SellerConditionsScreen(), overrides: [sellerCapabilityProvider.overrideWith((ref) async => _cap())]);
      expect(find.text('Vous pouvez vendre'), findsOneWidget);
      expect(find.text('Boutique ouverte'), findsOneWidget);
      expect(find.text('Mettre ma boutique en pause'), findsOneWidget);
      await t.ensureVisible(find.text('Mettre ma boutique en pause'));
      await t.tap(find.text('Mettre ma boutique en pause'));
      await t.pumpAndSettle();
      expect(find.text('Mettre la boutique en pause ?'), findsOneWidget);
      expect(find.textContaining('Vos commandes en cours, vos retraits'), findsOneWidget);
      await t.tap(find.text('Annuler'));
      await t.pumpAndSettle();
      expect(find.text('Mettre la boutique en pause ?'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('pause confirmée mais serveur injoignable : erreur affichée, jamais de faux succès', (t) async {
      await monter(t, const SellerConditionsScreen(), overrides: [sellerCapabilityProvider.overrideWith((ref) async => _cap())]);
      await t.ensureVisible(find.text('Mettre ma boutique en pause'));
      await t.tap(find.text('Mettre ma boutique en pause'));
      await t.pumpAndSettle();
      await t.tap(find.text('Mettre en pause'));
      await t.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text(_pauseOk), findsNothing);
      expect(find.text('Boutique ouverte'), findsOneWidget);
    });

    testWidgets('boutique en pause : état explicite, bouton « Reprendre mes ventes », pas de faux succès sans serveur', (t) async {
      await monter(t, const SellerConditionsScreen(), overrides: [sellerCapabilityProvider.overrideWith((ref) async => _cap(paused: true))]);
      expect(find.text('Votre boutique est en pause'), findsOneWidget);
      expect(find.textContaining('commandes en cours se poursuivent'), findsOneWidget);
      expect(find.text('Mettre ma boutique en pause'), findsNothing);
      await t.ensureVisible(find.text('Reprendre mes ventes'));
      await t.tap(find.text('Reprendre mes ventes'));
      await t.pumpAndSettle();
      expect(find.text('Mettre la boutique en pause ?'), findsNothing, reason: 'la reprise ne demande pas de confirmation');
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text(_resumeOk), findsNothing);
      expect(find.text('Votre boutique est en pause'), findsOneWidget);
    });

    testWidgets('compte non éligible : aucune carte de pause (la pause appartient au vendeur éligible)', (t) async {
      await monter(t, const SellerConditionsScreen(), overrides: [sellerCapabilityProvider.overrideWith((ref) async => _cap(canSell: false, phone: false))]);
      expect(find.text('Vendre sur Boutik-École'), findsOneWidget);
      expect(find.text('Mettre ma boutique en pause'), findsNothing);
      expect(find.text('Reprendre mes ventes'), findsNothing);
    });

    testWidgets('une boutique en pause garde l’accès à l’espace vendeur (commandes en cours, retraits)', (t) async {
      await monter(t, const SellerGate(child: Text('ESPACE VENDEUR')), overrides: [sellerCapabilityProvider.overrideWith((ref) async => _cap(paused: true))]);
      expect(find.text('ESPACE VENDEUR'), findsOneWidget);
    });

    testWidgets('vendeur non éligible : l’espace vendeur reste fermé, les conditions manquantes sont listées', (t) async {
      await monter(t, const SellerGate(child: Text('ESPACE VENDEUR')), overrides: [sellerCapabilityProvider.overrideWith((ref) async => _cap(canSell: false, phone: false))]);
      expect(find.text('ESPACE VENDEUR'), findsNothing);
      expect(find.text('Vérifier mon téléphone'), findsOneWidget);
    });

    testWidgets('Mes rubriques : une boutique en pause est signalée avec un accès à la reprise', (t) async {
      await monter(t, const EspaceScreen(), overrides: [sellerCapabilityProvider.overrideWith((ref) async => _cap(paused: true))]);
      while (t.takeException() != null) {}
      expect(find.text('Boutique en pause'), findsOneWidget);
      expect(find.text('Reprendre mes ventes'), findsOneWidget);
      await t.tap(find.text('Reprendre mes ventes'));
      await t.pumpAndSettle();
      expect(find.text('page conditions'), findsOneWidget);
    });

    testWidgets('Mes rubriques : boutique ouverte, aucun bandeau de pause', (t) async {
      await monter(t, const EspaceScreen(), overrides: [sellerCapabilityProvider.overrideWith((ref) async => _cap())]);
      while (t.takeException() != null) {}
      expect(find.text('Boutique en pause'), findsNothing);
    });
  });
}
