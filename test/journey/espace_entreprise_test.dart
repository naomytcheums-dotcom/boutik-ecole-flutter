import 'package:boutik_ecole/figma/g/g_78.dart';
import 'package:boutik_ecole/figma/g/g_85.dart';
import 'package:boutik_ecole/figma/g/g_86.dart';
import 'package:boutik_ecole/figma/g/g_87.dart';
import 'package:boutik_ecole/figma/g/g_91.dart';
import 'package:boutik_ecole/figma/g/g_93.dart';
import 'package:boutik_ecole/figma/g/g_95.dart';
import 'package:boutik_ecole/figma/g/g_96.dart';
import 'package:boutik_ecole/figma/g/g_98.dart';
import 'package:boutik_ecole/figma/g/g_99.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/console.dart';
import 'package:boutik_ecole/figma/live/entreprise.dart';
import 'package:boutik_ecole/figma/live/home_live.dart';
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

class _Talents extends TalentsNotifier {
  _Talents(this.v);
  final List<LiveTalent> v;
  @override
  List<LiveTalent>? build() => v;
}

void main() {
  setUpAll(loadAppFonts);
  setUp(() => GScreen.mockupFrame = false);
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = false;
  });

  Future<void> monter(WidgetTester t, Widget ecran, {required bool connecte, List<Override> overrides = const [], bool login = true}) async {
    Backend.ready = connecte;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: ecran)));
    await t.pumpAndSettle();
    if (connecte && login) {
      ProviderScope.containerOf(t.element(find.byWidget(ecran))).read(authProvider.notifier).login(demoAccount);
      await t.pumpAndSettle();
    }
  }

  test('libellés d’état', () {
    expect(proposalStatus('accepted'), 'Acceptée');
    expect(missionStatus('in_progress'), 'En cours');
    expect(quoteStatus('quoted'), 'Devis reçu');
    expect(dateCourte('2026-10-02T10:00:00Z'), '2 oct. 2026');
  });

  testWidgets('93 connecté : propositions reçues réelles', (t) async {
    await monter(t, const G_93(), connecte: true, overrides: [
      companyProposalsProvider.overrideWith(() => _Rows('company_proposals', [{'author': 'Alice Test', 'amount': 80000, 'delay_days': 7, 'status': 'pending', 'mission': 'Site vitrine'}]))
    ]);
    expect(find.text('Alice Test'), findsOneWidget);
    expect(find.textContaining('7 jours'), findsOneWidget);
    expect(find.text('Reçue'), findsOneWidget);
    expect(find.text('Équipe Team Innov’'), findsNothing);
  });

  testWidgets('93 connecté sans proposition : état vide', (t) async {
    await monter(t, const G_93(), connecte: true, overrides: [companyProposalsProvider.overrideWith(() => _Rows('company_proposals', const []))]);
    expect(find.textContaining('Aucune proposition reçue'), findsOneWidget);
  });

  testWidgets('99 connecté : mes besoins publiés avec le nombre de propositions', (t) async {
    await monter(t, const G_99(), connecte: true, overrides: [
      companyMissionsProvider.overrideWith(() => _Rows('company_missions', [{'title': 'Besoin réel', 'status': 'published', 'created_at': '2026-10-02T10:00:00Z', 'proposals': 3, 'team': ''}]))
    ]);
    expect(find.text('Besoin réel'), findsOneWidget);
    expect(find.textContaining('3 propositions'), findsOneWidget);
    expect(find.text('Charte graphique'), findsNothing);
  });

  testWidgets('98 connecté : seules les collaborations attribuées sont listées', (t) async {
    await monter(t, const G_98(), connecte: true, overrides: [
      companyMissionsProvider.overrideWith(() => _Rows('company_missions', [
            {'title': 'Besoin attribué', 'status': 'assigned', 'team': 'Équipe A', 'deadline': null, 'proposals': 1},
            {'title': 'Besoin ouvert', 'status': 'published', 'team': '', 'deadline': null, 'proposals': 0},
          ]))
    ]);
    expect(find.text('Besoin attribué'), findsOneWidget);
    expect(find.text('Besoin ouvert'), findsNothing);
  });

  testWidgets('95 connecté : demandes de devis réelles', (t) async {
    await monter(t, const G_95(), connecte: true, overrides: [
      quotesListProvider.overrideWith(() => _Rows('table:quote_requests', [{'brief': 'Logo pour ma boutique', 'quote_amount': 65000, 'quote_delay_days': 6, 'status': 'quoted'}]))
    ]);
    expect(find.text('Logo pour ma boutique'), findsOneWidget);
    expect(find.text('Devis reçu'), findsOneWidget);
    expect(find.text('DEV-2026-014 · Borne solaire'), findsNothing);
  });

  testWidgets('96 connecté : défis réels, état vide sinon', (t) async {
    await monter(t, const G_96(), connecte: true, overrides: [contestsListProvider.overrideWith(() => _Rows('table:contests', const []))]);
    expect(find.text('Défi Orange : paiement mobile inclusif'), findsNothing);
    expect(find.textContaining('Aucun défi ouvert'), findsOneWidget);
  });

  testWidgets('91 connecté : talents réels', (t) async {
    await monter(t, const G_91(), connecte: true, overrides: [
      liveTalentsProvider.overrideWith(() => _Talents(const [LiveTalent(id: 'u1', name: 'Alice Test', department: 'Informatique', skills: 'Flutter', avatarUrl: '', certified: false)]))
    ]);
    expect(find.text('Alice Test'), findsOneWidget);
    expect(find.text('Aminata Bello'), findsNothing);
  });

  testWidgets('78 connecté : projets validés réels, aucun projet de maquette', (t) async {
    await monter(t, const G_78(), connecte: true, overrides: [
      projectsCatalogProvider.overrideWith(() => _Rows('table:projects', [{'title': 'Projet réel', 'department': 'Informatique', 'summary': 'Une application', 'status': 'approved'}]))
    ]);
    expect(find.text('Projet réel'), findsOneWidget);
    expect(find.text('Validé'), findsOneWidget);
    expect(find.text('Drone éducatif connecté'), findsNothing);
  });

  testWidgets('87 connecté : certificats réels du registre', (t) async {
    await monter(t, const G_87(), connecte: true, overrides: [
      certificatesProvider.overrideWith(() => _Rows('table:certificates', [{'subject_title': 'Serre intelligente', 'code': 'BE-CERT-0021', 'issued_at': '2026-10-02T10:00:00Z', 'revoked': false}]))
    ]);
    expect(find.text('Serre intelligente'), findsOneWidget);
    expect(find.text('Certifié'), findsOneWidget);
    expect(find.textContaining('BE-CERT-0021'), findsOneWidget);
    expect(find.text('Filtre à sable modulaire'), findsNothing);
  });

  testWidgets('85 connecté sans campagne : état vide, aucun montant de maquette', (t) async {
    await monter(t, const G_85(), connecte: true, overrides: [campaignsProvider.overrideWith(() => _Rows('table:campaigns', const []))]);
    expect(find.textContaining('Aucune campagne pour le moment'), findsOneWidget);
    expect(find.text('Objectif : 2 000 000 FCFA'), findsNothing);
  });

  testWidgets('86 connecté : message honnête, aucun chiffre de maquette', (t) async {
    await monter(t, const G_86(), connecte: true);
    expect(find.textContaining('pas encore collectées en ligne'), findsOneWidget);
    expect(find.text('4,2 %'), findsNothing);
  });

  for (final c in <(String, Widget, String)>[('93', const G_93(), 'Équipe Team Innov’'), ('99', const G_99(), 'Charte graphique'), ('96', const G_96(), 'Défi Orange : paiement mobile inclusif'), ('91', const G_91(), 'Aminata Bello'), ('78', const G_78(), 'Drone éducatif connecté'), ('87', const G_87(), 'Filtre à sable modulaire'), ('86', const G_86(), '4,2 %')]) {
    testWidgets('${c.$1} hors connexion : la démonstration reste affichée', (t) async {
      await monter(t, c.$2, connecte: false);
      expect(find.text(c.$3), findsWidgets);
    });
  }
}
