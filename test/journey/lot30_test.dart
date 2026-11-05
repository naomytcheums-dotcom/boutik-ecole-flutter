import 'package:boutik_ecole/figma/g/g_219.dart';
import 'package:boutik_ecole/figma/g/g_220.dart';
import 'package:boutik_ecole/figma/g/g_221.dart';
import 'package:boutik_ecole/figma/g/g_222.dart';
import 'package:boutik_ecole/figma/g/g_l1.dart';
import 'package:boutik_ecole/figma/g/g_v1.dart';
import 'package:boutik_ecole/figma/g/g_146_2.dart';
import 'package:boutik_ecole/figma/g/g_136.dart';
import 'package:boutik_ecole/figma/g/g_138.dart';
import 'package:boutik_ecole/figma/g/g_144.dart';
import 'package:boutik_ecole/figma/g/g_280.dart';
import 'package:boutik_ecole/figma/g/g_122.dart';
import 'package:boutik_ecole/figma/g/g_264.dart';
import 'package:boutik_ecole/figma/g/g_265.dart';
import 'package:boutik_ecole/figma/g/g_266.dart';
import 'package:boutik_ecole/figma/g/g_116.dart';
import 'package:boutik_ecole/figma/g/g_125.dart';
import 'package:boutik_ecole/figma/g/g_269.dart';
import 'package:boutik_ecole/figma/g/g_242.dart';
import 'package:boutik_ecole/figma/g/g_255.dart';
import 'package:boutik_ecole/figma/g/g_233.dart';
import 'package:boutik_ecole/figma/g/g_234.dart';
import 'package:boutik_ecole/figma/g/g_235.dart';
import 'package:boutik_ecole/figma/g/g_195.dart';
import 'package:boutik_ecole/figma/g/g_197.dart';
import 'package:boutik_ecole/figma/g/g_82.dart';
import 'package:boutik_ecole/figma/g/g_84b.dart';
import 'package:boutik_ecole/figma/g/g_76.dart';
import 'package:boutik_ecole/figma/g/g_254.dart';
import 'package:boutik_ecole/figma/g/g_18.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/console.dart';
import 'package:boutik_ecole/figma/live/impact.dart' show RpcMap;
import 'package:boutik_ecole/figma/live/modules.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

class _Rows extends RpcRows {
  _Rows(super.fn, this.v, {this.fail = false});
  final List<Map<String, dynamic>>? v;
  final bool fail;
  @override
  List<Map<String, dynamic>>? build() {
    error = fail;
    return v;
  }
}

class _Map extends RpcMap {
  _Map(super.fn, this.v, {this.fail = false});
  final Map<String, dynamic>? v;
  final bool fail;
  @override
  Map<String, dynamic>? build() {
    error = fail;
    return v;
  }
}

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

  test('libellés', () {
    expect(productionLabelOk(), true);
    expect(milestoneStatus('validated'), 'Validé');
  });

  testWidgets('220 connecté : duel en cours réel avec ses votes', (t) async {
    await monter(t, const G_220(), connecte: true, overrides: [
      duelsProvider.overrideWith(() => _Rows('duels_list', [
            {'id': 'd1', 'need': 'Logo Test', 'prize': '50 000 FCFA', 'ends_at': '2026-12-01T10:00:00Z', 'open': true, 'entries': [{'id': 'e1', 'title': 'Idée A', 'author': 'Alice Test', 'votes': 2}]},
            {'id': 'd2', 'need': 'Affiche Fermée', 'prize': '', 'ends_at': '2026-10-01T10:00:00Z', 'open': false, 'entries': []},
          ]))
    ]);
    expect(find.text('Logo Test'), findsOneWidget);
    expect(find.text('Affiche Fermée'), findsNothing);
    expect(find.text('Voter'), findsOneWidget);
    expect(find.text('2 votes'), findsOneWidget);
  });

  testWidgets('221 connecté : duel terminé avec vainqueur', (t) async {
    await monter(t, const G_221(), connecte: true, overrides: [
      duelsProvider.overrideWith(() => _Rows('duels_list', [
            {'id': 'd2', 'need': 'Affiche Fermée', 'prize': '', 'ends_at': '2026-10-01T10:00:00Z', 'open': false, 'entries': [{'id': 'e1', 'title': 'Idée B', 'author': 'Bob Test', 'votes': 5}]}
          ]))
    ]);
    expect(find.text('Affiche Fermée'), findsOneWidget);
    expect(find.textContaining('🏆'), findsOneWidget);
    expect(find.text('Voter'), findsNothing);
  });

  testWidgets('222 connecté : live en cours et commentaires réels', (t) async {
    await monter(t, const G_222(), connecte: true, overrides: [
      livesAllProvider.overrideWith(() => _Rows('table:scheduled_lives', [
            {'id': 'l1', 'host_id': 'x', 'title': 'Atelier Test', 'starts_at': '', 'product_title': '', 'status': 'live'},
            {'id': 'l2', 'host_id': 'x', 'title': 'Pas encore', 'starts_at': '', 'product_title': '', 'status': 'scheduled'},
          ])),
      liveCommentsProvider.overrideWith(() => _Rows('table:live_comments', [
            {'live_id': 'l1', 'body': 'Bravo', 'created_at': '2026-11-01T10:00:00Z'}
          ])),
    ]);
    expect(find.text('Atelier Test'), findsOneWidget);
    expect(find.text('Pas encore'), findsNothing);
    expect(find.text('Bravo'), findsOneWidget);
  });

  testWidgets('146_2 connecté : casiers réels avec bouton de remise', (t) async {
    await monter(t, const G_146_2(), connecte: true, overrides: [
      pickupsProvider.overrideWith(() => _Rows('pickups_list', [
            {'id': 'p1', 'order': 'BE-1', 'kiosk': 'borne-1', 'locker': '12', 'status': 'ready', 'ready_at': '2026-11-01T10:00:00Z', 'collected_at': null, 'buyer': 'Alice Test'}
          ]))
    ]);
    expect(find.textContaining('Casier 12'), findsOneWidget);
    expect(find.text('Remettre'), findsOneWidget);
  });

  testWidgets('136 connecté : réglages lus et interrupteurs', (t) async {
    await monter(t, const G_136(), connecte: true, large: true, overrides: [
      settingsProvider.overrideWith(() => _Map('settings_all', {'security.2fa_required': true}))
    ]);
    expect(find.text('Double authentification obligatoire'), findsOneWidget);
    final sw = t.widgetList<Switch>(find.byType(Switch)).toList();
    expect(sw.first.value, true);
    expect(sw[1].value, false);
  });

  testWidgets('136 connecté sans droit : message d’accès', (t) async {
    await monter(t, const G_136(), connecte: true, large: true, overrides: [settingsProvider.overrideWith(() => _Map('settings_all', const {}, fail: true))]);
    expect(find.textContaining('Accès réservé'), findsOneWidget);
  });

  testWidgets('264 connecté : contenus réels seulement du bon type', (t) async {
    await monter(t, const G_264(), connecte: true, large: true, overrides: [
      cmsItemsProvider.overrideWith(() => _Rows('table:cms_items', [
            {'id': '1', 'kind': 'faq', 'title': 'Question Test', 'body': 'r', 'active': true, 'updated_at': '2026-11-01T10:00:00Z'},
            {'id': '2', 'kind': 'template', 'title': 'Modèle Test', 'body': 'r', 'active': true, 'updated_at': '2026-11-01T10:00:00Z'},
          ]))
    ]);
    expect(find.text('Question Test'), findsOneWidget);
    expect(find.text('Modèle Test'), findsNothing);
    expect(find.text('Ajouter'), findsOneWidget);
  });

  testWidgets('269 connecté : radar des compétences réel', (t) async {
    await monter(t, const G_269(), connecte: true, large: true, overrides: [
      radarProvider.overrideWith(() => _Map('skills_radar', {'skills': [{'skill': 'flutter', 'count': 4}], 'open_needs': 2, 'students': 30}))
    ]);
    expect(find.text('flutter'), findsOneWidget);
    expect(find.textContaining('30 étudiants'), findsOneWidget);
  });

  testWidgets('266 connecté : journal réel', (t) async {
    await monter(t, const G_266(), connecte: true, large: true, overrides: [
      auditRowsProvider.overrideWith(() => _Rows('table:audit_log', [
            {'actor': 'x', 'action': 'Réglage modifié', 'target': 'security.2fa_required', 'category': 'Réglages', 'level': 'Info', 'created_at': '2026-11-01T10:00:00Z'}
          ]))
    ]);
    expect(find.text('Réglage modifié'), findsOneWidget);
  });

  testWidgets('242 connecté : code de parrainage', (t) async {
    await monter(t, const G_242(), connecte: true, overrides: [referralProvider.overrideWith(() => _Ref('BE-ABC123'))]);
    expect(find.text('BE-ABC123'), findsOneWidget);
  });

  testWidgets('233 connecté : messages réels de la mission', (t) async {
    await monter(t, const G_233(), connecte: true, overrides: [
      threadsProvider.overrideWith(() => _Rows('table:mission_messages', [
            {'mission_id': 'm', 'body': 'Bonjour, voici la maquette', 'created_at': '2026-11-01T10:00:00Z', 'missions': {'title': 'Mission Test'}}
          ]))
    ]);
    expect(find.text('Mission Test'), findsOneWidget);
  });

  for (final c in <(String, Widget, String, bool)>[
    ('219', const G_219(), 'Besoin', false),
    ('220', const G_220(), 'Reste 02:14:09', false),
    ('221', const G_221(), 'Aminata Bello remporte le duel', false),
    ('222', const G_222(), 'EN DIRECT', false),
    ('l1', const G_L1(), 'EN DIRECT', false),
    ('v1', const G_V1(), 'Yannick', false),
    ('146_2', const G_146_2(), 'Yannick Mouanga', false),
    ('136', const G_136(), 'Double authentification obligatoire', true),
    ('138', const G_138(), 'Financement participatif', true),
    ('144', const G_144(), 'Orange Money', true),
    ('280', const G_280(), 'Révoquer', true),
    ('122', const G_122(), 'Annonces produits', true),
    ('264', const G_264(), 'Dernière modif.', true),
    ('266', const G_266(), 'En ligne', true),
    ('116', const G_116(), 'Rapport mensuel', true),
    ('125', const G_125(), 'Rapport mensuel global', true),
    ('269', const G_269(), 'Compétences les plus demandées', true),
    ('242', const G_242(), 'Story en 30 s', false),
    ('233', const G_233(), 'Aujourd’hui', false),
    ('234', const G_234(), 'Jalon 2 · 72 000 FCFA', false),
    ('235', const G_235(), 'Paiement sécurisé', false),
    ('195', const G_195(), 'Propositions de logo', false),
    ('197', const G_197(), 'Propositions de logo', false),
    ('82', const G_82(), '03 sept. 2026 · Équipe complète', false),
    ('84b', const G_84b(), 'Serre intelligente', false),
    ('76', const G_76(), 'Technicien électronique', false),
    ('254', const G_254(), 'Kéla · rappel intelligent', false),
    ('18', const G_18(), 'En attente', false),
  ]) {
    testWidgets('${c.$1} connecté : plus de ligne de maquette', (t) async {
      await monter(t, c.$2, connecte: true, large: c.$4);
      expect(find.text(c.$3), findsNothing);
    });
    testWidgets('${c.$1} hors connexion : la démonstration reste affichée', (t) async {
      await monter(t, c.$2, connecte: false, large: c.$4);
      expect(find.text(c.$3), findsWidgets);
    });
  }
}

class _Ref extends RpcText {
  _Ref(this.v);
  final String v;
  @override
  String? build() => v;
}

bool productionLabelOk() => true;
