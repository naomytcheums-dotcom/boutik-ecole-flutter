import 'package:boutik_ecole/figma/g/g_189.dart';
import 'package:boutik_ecole/figma/g/g_190.dart';
import 'package:boutik_ecole/figma/g/g_66.dart';
import 'package:boutik_ecole/figma/g/g_67.dart';
import 'package:boutik_ecole/figma/g/g_69.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/console.dart';
import 'package:boutik_ecole/figma/live/entreprise.dart';
import 'package:boutik_ecole/figma/live/impact.dart';
import 'package:boutik_ecole/figma/live/profile_data.dart';
import 'package:boutik_ecole/figma/live/vendeur.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

class _Rows extends RpcRows {
  _Rows(super.fn, this.v);
  final List<Map<String, dynamic>>? v;
  @override
  List<Map<String, dynamic>>? build() => v;
}

class _Map extends RpcMap {
  _Map(super.fn, this.v);
  final Map<String, dynamic>? v;
  @override
  Map<String, dynamic>? build() => v;
}

class _Docs extends DocsNotifier {
  _Docs(this.v);
  final List<UserDoc> v;
  @override
  List<UserDoc>? build() => v;
}

const _rev = {
  'total': 100000, 'paid_out': 20000, 'scheduled': 10000, 'available': 70000, 'orders': 3, 'pending_count': 1, 'pending_amount': 15000,
  'months': [{'month': '2026-11', 'amount': 100000}], 'weeks': [{'week': '2026-11-02', 'amount': 60000}],
};

void main() {
  setUpAll(loadAppFonts);
  setUp(() => GScreen.mockupFrame = false);
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = false;
  });

  Future<void> monter(WidgetTester t, Widget ecran, {required bool connecte, bool large = false, List<Override> overrides = const []}) async {
    Backend.ready = connecte;
    GAnim.enabled = false;
    t.view.physicalSize = large ? const Size(1280, 890) : const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: ecran)));
    await t.pumpAndSettle();
    if (connecte) {
      ProviderScope.containerOf(t.element(find.byWidget(ecran))).read(authProvider.notifier).login(demoAccount);
      await t.pumpAndSettle();
    }
  }

  testWidgets('66 connecté : revenus calculés, aucun montant de maquette', (t) async {
    await monter(t, const G_66(), connecte: true, overrides: [sellerRevenueProvider.overrideWith(() => _Map('seller_revenue', _rev))]);
    expect(find.text('Disponible'), findsOneWidget);
    expect(find.text('3 commandes') , findsNothing);
    expect(find.textContaining('sur 3 commandes'), findsOneWidget);
    expect(find.text('Relevé octobre 2026'), findsNothing);
  });

  testWidgets('67 connecté : ventes par semaine réelles', (t) async {
    await monter(t, const G_67(), connecte: true, overrides: [sellerRevenueProvider.overrideWith(() => _Map('seller_revenue', _rev))]);
    expect(find.text('Ventes par semaine'), findsOneWidget);
    expect(find.text('Lampe en bois recyclé'), findsNothing);
    expect(find.text('4 280'), findsNothing);
  });

  testWidgets('69 connecté : justificatifs réels', (t) async {
    await monter(t, const G_69(), connecte: true, overrides: [
      myDocsProvider.overrideWith(() => _Docs([UserDoc(id: '1', kind: 'student_card', name: 'carte.jpg', path: 'p', size: 5, status: 'verified', note: '', createdAt: DateTime(2026, 11, 1))]))
    ]);
    expect(find.text('carte.jpg'), findsOneWidget);
    expect(find.text('Vérifié'), findsOneWidget);
    expect(find.text('IUT-2023-0412'), findsNothing);
  });

  testWidgets('189 connecté : propositions réelles', (t) async {
    await monter(t, const G_189(), connecte: true, large: true, overrides: [
      companyProposalsProvider.overrideWith(() => _Rows('company_proposals', [
            {'author': 'Alice Test', 'mission': 'Logo', 'amount': 90000, 'delay_days': 7, 'status': 'submitted'}
          ]))
    ]);
    expect(find.text('Alice Test'), findsOneWidget);
    expect(find.text('Team Innov’'), findsNothing);
  });

  testWidgets('190 connecté : devis réels', (t) async {
    await monter(t, const G_190(), connecte: true, large: true, overrides: [
      quotesListProvider.overrideWith(() => _Rows('table:quote_requests', [
            {'brief': 'Borne Test', 'status': 'requested', 'quote_amount': null, 'quote_delay_days': null}
          ]))
    ]);
    expect(find.text('Borne Test'), findsOneWidget);
    expect(find.text('DEV-2026-014 · Borne solaire'), findsNothing);
  });

  for (final c in <(String, Widget, String, bool)>[('66', const G_66(), 'Relevé octobre 2026', false), ('67', const G_67(), 'Lampe en bois recyclé', false), ('69', const G_69(), 'Certificat de scolarité', false), ('189', const G_189(), 'Team Innov’', true), ('190', const G_190(), 'DEV-2026-014 · Borne solaire', true)]) {
    testWidgets('${c.$1} hors connexion : la démonstration reste affichée', (t) async {
      await monter(t, c.$2, connecte: false, large: c.$4);
      expect(find.text(c.$3), findsWidgets);
    });
  }
}
