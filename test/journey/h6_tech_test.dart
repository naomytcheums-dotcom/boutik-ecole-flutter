import 'dart:convert';
import 'dart:io';

import 'package:boutik_ecole/app.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/access.dart';
import 'package:boutik_ecole/figma/live/admin_access.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/marche/marche_appels.dart' show canProposeOnMission;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/render.dart';

/// H6 · L4 (points techniques) :
///  (a) qui peut proposer un devis sur une mission (prestation de service) : étudiants seulement côté application, capacité vendeur imposée par le serveur (scénario h6_vendeur.mjs) ;
///  (b) pied de page des écrans Département = département rattaché (`my_department`), jamais le texte libre du profil ;
///  (c) les toiles 108 à 115 ne servent jamais de données de maquette dans un parcours connecté ;
///  (d) aperçus hors connexion des écrans du personnel : bandeau « Aperçu de démonstration », droits d'exemple marqués.
final _tokens = jsonDecode(File('tool/maquette_tokens.json').readAsStringSync()) as Map<String, dynamic>;
final _noms = <String>{...(_tokens['personas'] as List).cast<String>(), ...(_tokens['entities'] as List).cast<String>(), ...(_tokens['self'] as List).cast<String>()}.where((e) => e.length >= 4).toList();

const _ecransDept = ['108', '109', '110', '111', '112', '113', '114', '115'];
const _departementRattache = 'Département Réel Test';
const _texteLibreDuProfil = 'Texte libre du profil';

Account _staff(String staff, {String department = ''}) => Account(
      name: 'Compte Personnel',
      phone: '690000777',
      email: 'personnel@example.test',
      password: '',
      staff: staff,
      institution: 'Plateforme',
      department: department,
      serverId: FakeSupabase.userId,
    );

String _fichier(String id) => 'lib/figma/g/g_$id.dart';

void main() {
  test('(a) proposer un devis sur un besoin : étudiants (et visiteur invité à se connecter) seulement', () {
    expect(canProposeOnMission(null), isTrue);
    expect(canProposeOnMission(Account(name: 'E', phone: '1', email: 'e@t.t', password: '', role: 1)), isTrue);
    expect(canProposeOnMission(Account(name: 'C', phone: '1', email: 'c@t.t', password: '', role: 0)), isFalse);
    expect(canProposeOnMission(Account(name: 'O', phone: '1', email: 'o@t.t', password: '', role: 2)), isFalse);
    expect(canProposeOnMission(_staff('Resp. département')), isFalse, reason: 'le département attribue, il ne propose pas de devis');
    expect(canProposeOnMission(_staff('Admin global')), isFalse);
  });

  test('(b) statique : le pied de page des toiles Département lit my_department, jamais le profil', () {
    for (final id in [..._ecransDept, '116']) {
      final src = File(_fichier(id)).readAsStringSync();
      expect(src.contains('deptFooterText(ref)'), isTrue, reason: 'g_$id : pied de page non relié à my_department');
      expect(RegExp(r'\ba\.department\b').hasMatch(src), isFalse, reason: 'g_$id : le texte libre du profil sert encore de pied de page');
    }
  });

  test('(c) statique : en connecté, chaque toile 108 à 115 laisse la place à la page réelle', () {
    expect(File(_fichier('108')).readAsStringSync(), contains('if (!demoContent) gP(204, 56, 1068, 704, const DeptConsoleOverview())'));
    for (final id in _ecransDept.skip(1)) {
      expect(File(_fichier(id)).readAsStringSync(), contains("if (!demoContent) gP(240, 56, 1040, 834, const DeptConsolePage('$id'))"), reason: 'g_$id : pas de page réelle en connecté');
    }
  });

  test('(d) statique : isStaffScreenId ne couvre que les écrans du personnel', () {
    for (final id in ['108', '116', '117', '127', '130', '139', '145', '180', '264', '284', '300', '305', '306']) {
      expect(isStaffScreenId(id), isTrue, reason: id);
    }
    for (final id in ['01', '10', '57', '88', '95b', 'D1', '205', '191']) {
      expect(isStaffScreenId(id), isFalse, reason: id);
    }
  });

  test('(d) droits d’exemple : marqués aperçu ; droits du serveur : jamais', () {
    expect(AdminAccess.fromAccount(_staff('Finance')).preview, isTrue);
    expect(AdminAccess.fromAccount(_staff('Support')).preview, isTrue);
    expect(AdminAccess.fromAccount(_staff('Admin global')).preview, isTrue);
    expect(AdminAccess.fromJson({'role': 'finance', 'is_admin': false, 'teams': <String, dynamic>{'finance': <String>[]}}).preview, isFalse);
    expect(AdminAccess.none.preview, isFalse);
  });

  late FakeSupabase srv;
  setUpAll(() async {
    await loadAppFonts();
    srv = await FakeSupabase.start();
    await srv.initSupabase();
  });
  tearDownAll(() => srv.close());

  setUp(() {
    GAnim.enabled = false;
    srv.unknownIsError = false;
    srv.rpc.clear();
    srv.calls.clear();
    Backend.ready = true;
    GScreen.mockupFrame = false; // comportement réel de l'application (la config de test force le cadre de maquette)
  });
  tearDown(() {
    Backend.ready = true;
    GScreen.mockupFrame = true;
  });

  Future<void> monter(WidgetTester tester, String id, Account compte, {required Size taille}) async {
    tester.view.physicalSize = taille;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(overrides: [initialAccountProvider.overrideWithValue(compte)], child: BoutikEcoleApp(initialLocation: '/s/$id')));
    await settleReal(tester);
  }

  Set<String> textes(WidgetTester tester) => {
        for (final t in tester.widgetList<RichText>(find.byType(RichText)))
          if (t.text.toPlainText().trim().isNotEmpty) t.text.toPlainText().trim(),
      };

  void rattache() => srv.rpc['my_department'] = (_) => {
        'role': 'dept',
        'attached': true,
        'waiting': false,
        'state': 'ok',
        'department_id': '22222222-2222-4222-8222-222222222222',
        'department': _departementRattache,
        'institution': 'Institut Test',
        'name': 'Compte Personnel',
      };

  group('(b)(c) département connecté, toiles 108 à 115', () {
    for (final id in _ecransDept) {
      testWidgets('toile $id (ordinateur) : pied de page = département rattaché, aucune donnée de maquette', (tester) async {
        rattache();
        await monter(tester, id, _staff('Resp. département', department: _texteLibreDuProfil), taille: const Size(1280, 900));
        expect(tester.takeException(), isNull, reason: 'débordement ou exception sur la toile $id');
        final t = textes(tester);
        expect(t.any((x) => x == 'Dép. $_departementRattache'), isTrue, reason: 'pied de page absent ou faux : ${t.where((x) => x.startsWith('Dép.')).toList()}');
        expect(t.any((x) => x.contains(_texteLibreDuProfil)), isFalse, reason: 'le texte libre du profil est affiché');
        expect(t.where((x) => x.contains('Génie informatique')).toList(), isEmpty, reason: 'nom de département de maquette ou valeur par défaut affiché');
        for (final x in t) {
          for (final n in _noms) {
            expect(x.contains(n), isFalse, reason: 'donnée de maquette « $n » dans « $x » (toile $id connectée)');
          }
          expect(x.contains('9:41'), isFalse);
        }
        for (final i in tester.widgetList<Image>(find.byType(Image))) {
          final p = i.image;
          expect(p is AssetImage && gIsMockPhoto(p.assetName), isFalse, reason: 'photo de maquette sur la toile $id connectée');
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 60));
      });

      testWidgets('toile $id (téléphone) : page réelle mobile, aucune toile 1280 px', (tester) async {
        rattache();
        await monter(tester, id, _staff('Resp. département', department: _texteLibreDuProfil), taille: const Size(390, 900));
        expect(tester.takeException(), isNull);
        expect(tester.widgetList<GScreen>(find.byType(GScreen)).where((s) => s.w >= 1000), isEmpty, reason: 'la toile $id sert en connecté sur téléphone');
        final t = textes(tester);
        expect(t.any((x) => x.contains(_texteLibreDuProfil)), isFalse);
        for (final x in t) {
          for (final n in _noms) {
            expect(x.contains(n), isFalse, reason: 'donnée de maquette « $n » dans « $x »');
          }
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 60));
      });
    }

    testWidgets('département non rattaché : écran d’attente, ni toile ni pied de page', (tester) async {
      srv.rpc['my_department'] = (_) => {'role': 'dept', 'attached': false, 'waiting': true, 'state': 'none', 'reason': 'Aucun département ne vous a encore été attribué.'};
      await monter(tester, '109', _staff('Resp. département', department: _texteLibreDuProfil), taille: const Size(1280, 900));
      expect(find.text('En attente de rattachement'), findsOneWidget);
      expect(tester.widgetList<GScreen>(find.byType(GScreen)).where((s) => s.w >= 1000), isEmpty);
      expect(textes(tester).any((x) => x.startsWith('Dép.') || x.contains(_texteLibreDuProfil)), isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 60));
    });

    testWidgets('administrateur sur la toile 108 : jamais le département du profil en pied de page', (tester) async {
      srv.rpc['my_department'] = (_) => {'role': 'admin', 'attached': false, 'waiting': false, 'state': 'none', 'name': 'Compte Personnel'};
      await monter(tester, '108', _staff('Admin global', department: _texteLibreDuProfil), taille: const Size(1280, 900));
      final t = textes(tester);
      expect(t.any((x) => x.startsWith('Dép.')), isFalse, reason: '${t.where((x) => x.startsWith('Dép.')).toList()}');
      expect(t.any((x) => x.contains(_texteLibreDuProfil)), isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 60));
    });
  });

  group('(d) aperçus hors connexion des écrans du personnel', () {
    const cas = <(String, String)>[
      ('108', 'Resp. département'),
      ('110', 'Resp. département'),
      ('117', 'Direction'),
      ('127', 'Admin global'),
      ('130', 'Admin global'),
      ('139', 'Finance'),
      ('145', 'Support'),
      ('300', 'Admin global'),
      ('301', 'Finance'),
    ];
    for (final (id, staff) in cas) {
      testWidgets('hors connexion $id ($staff) : bandeau « Aperçu de démonstration »', (tester) async {
        Backend.ready = false;
        await monter(tester, id, _staff(staff), taille: const Size(1280, 900));
        expect(find.byKey(demoPreviewBannerKey), findsOneWidget, reason: 'écran $id sans bandeau d’aperçu');
        expect(find.textContaining('Aperçu de démonstration'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 60));
      });
    }

    testWidgets('connecté : jamais de bandeau d’aperçu', (tester) async {
      rattache();
      await monter(tester, '127', _staff('Admin global'), taille: const Size(1280, 900));
      expect(find.byKey(demoPreviewBannerKey), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 60));
    });

    testWidgets('hors connexion : pas de bandeau sur un écran qui n’est pas du personnel (espace vendeur)', (tester) async {
      Backend.ready = false;
      await monter(tester, '57', Account(name: 'E', phone: '1', email: 'e@t.t', password: '', role: 1, serverId: FakeSupabase.userId), taille: const Size(390, 900));
      expect(find.byKey(demoPreviewBannerKey), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 60));
    });
  });
}
