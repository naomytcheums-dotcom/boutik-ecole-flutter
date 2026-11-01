import 'dart:io';

import 'package:boutik_ecole/figma/g/g_40.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/admin.dart';
import 'package:boutik_ecole/figma/live/audit.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/render.dart';

/// Lot 2 (phase 4) : champs de saisie qui n'étaient reliés à rien.

const _admin = Account(name: 'Admin', phone: '677000007', email: 'a@b.cm', password: '', role: 3, staff: 'Admin global');
const _client = Account(name: 'Client', phone: '677000008', email: 'c@b.cm', password: '', role: 0);

void main() {
  setUpAll(loadAppFonts);
  tearDown(() => Backend.ready = false);

  group('recherche d’en-tête du back-office (63 écrans)', () {
    test('pages autorisées au rôle uniquement', () {
      final admin = backofficeMatches(_admin, 'journal').map((s) => s.id);
      expect(admin, containsAll(['126', '137']));
      final client = backofficeMatches(_client, 'journal').map((s) => s.id).toList();
      expect(client, isNot(contains('126')), reason: 'un client ne découvre pas les pages réservées');
      expect(client, isNot(contains('137')));
      expect(client, contains('82'), reason: 'Journal du projet est ouvert à tous');
      expect(backofficeMatches(_admin, 'j'), isEmpty, reason: 'au moins 2 caractères');
      expect(backofficeMatches(_admin, 'JOURNAL d’audit').map((s) => s.id), contains('126'), reason: 'casse et accents ignorés');
    });

    test('le générateur produit la même liaison que les écrans modifiés', () {
      final src = File('tool/figma_export/convert.py').readAsStringSync();
      expect(src, contains("backofficeSearch(context, ref, v)"));
      final g = File('lib/figma/g/g_108.dart').readAsStringSync();
      expect(g, contains("inter: true, onSubmitted: (v) { backofficeSearch(context, ref, v); }))"));
    });
  });

  group('journaux d’audit 126 et 137', () {
    test('la recherche filtre réellement ; sans serveur, les exemples de la maquette', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(institutionAuditProvider), isNotEmpty);
      c.read(auditQueryProvider.notifier).set('Carine');
      expect(c.read(globalAuditProvider).map((e) => e.target), ['Carine Mbarga']);
      c.read(auditQueryProvider.notifier).set('introuvable-xyz');
      expect(c.read(globalAuditProvider), isEmpty);
    });

    test('avec le serveur, aucune entrée fictive n’est présentée comme le journal réel', () {
      Backend.ready = true;
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(institutionAuditProvider), isEmpty);
      expect(c.read(globalAuditProvider), isEmpty);
    });
  });

  group('40 « Demande de devis »', () {
    Future<void> pump(WidgetTester tester, ProviderContainer c) async {
      GAnim.enabled = false;
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const MaterialApp(home: Scaffold(body: G_40()))));
      await tester.pump();
    }

    testWidgets('hors serveur : maquette et lien du prototype 40 → 06, sans aucun message de succès', (tester) async {
      GAnim.enabled = false;
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(initialLocation: '/s/40', routes: [
        GoRoute(path: '/s/:id', builder: (_, s) => s.pathParameters['id'] == '40' ? const Scaffold(body: G_40()) : Text('écran ${s.pathParameters['id']}')),
      ]);
      await tester.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: router)));
      await tester.pump();
      expect(find.text('Site vitrine pour mon association'), findsOneWidget);
      await tester.tap(find.text('Envoyer la demande'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('écran 06'), findsOneWidget);
      expect(find.textContaining('Demande envoyée'), findsNothing);
    });

    testWidgets('connecté : aucune valeur d’exemple pré-remplie ; la saisie est enregistrée dans le formulaire', (tester) async {
      Backend.ready = true;
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await pump(tester, c);
      expect(find.text('Site vitrine pour mon association'), findsNothing);
      expect(find.text('50 000 – 80 000 FCFA'), findsNothing);
      await tester.enterText(find.byType(EditableText).at(1), 'Refonte du site de notre association étudiante');
      expect(c.read(formProvider)['q_desc'], 'Refonte du site de notre association étudiante');
    });
  });
}
