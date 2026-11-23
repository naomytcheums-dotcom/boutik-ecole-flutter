import 'dart:convert';
import 'dart:io';

import 'package:boutik_ecole/app.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/tp_ui.dart' show TpButton;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/render.dart';

/// H6 · L3 (centre d'administration 300 à 306, quatre équipes, rattachement des comptes Département, revue des comptes Finance / Support, comptes suspects) :
///  1. zéro donnée de maquette en connecté (serveur muet, listes vides, données réelles) : aucun nom, photo, chiffre figé, « 9:41 », aucune toile de maquette ;
///  2. chaque action d'administration va jusqu'au serveur (faux serveur HTTP + vrai client Supabase) : bons paramètres, liste rafraîchie, message honnête en cas de refus (2FA, droit) ;
///  3. un agent d'équipe ne reçoit jamais les actions réservées à l'administrateur global.
/// Les preuves serveur (gardes, 2FA, historique, suspension réelle) sont dans supabase/tests/marketplace_pglite/h6_centre.mjs.
final _tokens = jsonDecode(File('tool/maquette_tokens.json').readAsStringSync()) as Map<String, dynamic>;
final _noms = <String>{...(_tokens['personas'] as List).cast<String>(), ...(_tokens['entities'] as List).cast<String>(), ...(_tokens['self'] as List).cast<String>()}.where((e) => e.length >= 4).toList();

const _ecrans = ['300', '301', '302', '303', '304', '305', '306'];

/// Intitulé d'une fonction de la plateforme (lien du centre vers l'écran 269), pas une donnée : seul nom du jeton « entités » toléré dans les libellés.
const _libelleStructurel = 'Innovation Radar';

Account _compte(String staff) => Account(
      name: 'Compte Test',
      phone: '690000999',
      email: 'admin.test@example.test',
      password: '',
      role: staff == 'Admin global' ? 3 : 0,
      staff: staff,
      institution: 'Plateforme',
      serverId: FakeSupabase.userId,
    );

final _admin = _compte('Admin global');

/// Laisse le faux serveur répondre (réseau réel, machine parfois chargée) jusqu'à la disparition des indicateurs de chargement.
Future<void> attendre(WidgetTester t) async {
  await settleReal(t, rounds: 8);
  for (var i = 0; i < 80 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
    await settleReal(t, rounds: 1);
  }
  await settleReal(t, rounds: 2);
}

/// Test d'écran : l'application arme une minuterie de 2 s au démarrage ; on la laisse s'écouler avant la fin du test.
void cas(String name, Future<void> Function(WidgetTester t) body) => testWidgets(name, (t) async {
      try {
        await body(t);
      } finally {
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 60));
      }
    });

void main() {
  test('statique : aucun nom ni heure de maquette dans les écrans du centre d’administration et des équipes', () {
    for (final f in ['lib/figma/live/admin_centre.dart', 'lib/figma/live/admin_equipes.dart', 'lib/features/admin_centre/screens.dart']) {
      final src = File(f).readAsStringSync();
      for (final n in _noms.where((n) => n != _libelleStructurel)) {
        expect(src.contains("'$n'") || src.contains('"$n"'), isFalse, reason: '$f cite « $n »');
      }
      expect(src.contains('9:41'), isFalse, reason: '$f : heure de maquette');
    }
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
    GScreen.mockupFrame = false;
  });
  tearDown(() {
    Backend.ready = true;
    GScreen.mockupFrame = true;
  });

  Future<void> monter(WidgetTester t, String location, Account compte, {double h = 2400}) async {
    t.view.physicalSize = Size(390, h);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: [initialAccountProvider.overrideWithValue(compte)], child: BoutikEcoleApp(initialLocation: location)));
    await attendre(t);
  }

  Finder txt(String s) => find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText() == s);
  Finder txtC(String s) => find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains(s));
  Finder btn(String label) => find.byWidgetPredicate((w) => w is TpButton && w.label == label);
  Finder tbtn(String label) => find.ancestor(of: txt(label), matching: find.byType(TextButton));

  Iterable<String> textes(WidgetTester t) => [
        for (final r in t.widgetList<RichText>(find.byType(RichText)))
          if (r.text.toPlainText().trim().isNotEmpty) r.text.toPlainText().trim(),
      ];

  void controle(WidgetTester t, String id, {required bool chiffresAdmis}) {
    expect(t.takeException(), isNull, reason: '$id : exception ou débordement');
    for (final x in textes(t)) {
      for (final n in _noms.where((n) => n != _libelleStructurel)) {
        expect(x.contains(n), isFalse, reason: '$id : nom de maquette « $n » dans « $x »');
      }
      expect(x.contains('9:41'), isFalse, reason: '$id : heure de maquette');
      if (!chiffresAdmis) expect(RegExp(r'\d').hasMatch(x), isFalse, reason: '$id : chiffre sans donnée réelle dans « $x »');
    }
    for (final i in t.widgetList<Image>(find.byType(Image))) {
      final p = i.image;
      if (p is AssetImage) expect(gIsMockPhoto(p.assetName), isFalse, reason: '$id : photo de maquette ${p.assetName}');
    }
    expect(t.widgetList<GScreen>(find.byType(GScreen)).where((s) => s.w >= 1000), isEmpty, reason: '$id : toile de maquette en connecté');
  }

  // ------------------------------------------------------------------ 1. zéro maquette
  for (final id in _ecrans) {
    cas('serveur muet : $id sans aucun chiffre ni nom de maquette', (t) async {
      srv.unknownIsError = true;
      await monter(t, '/s/$id', _admin);
      controle(t, id, chiffresAdmis: false);
    });

    cas('listes vides : $id sans aucun chiffre ni nom de maquette', (t) async {
      srv.rpc['my_admin_access'] = (_) => {'role': 'admin', 'is_admin': true, 'teams': <String, dynamic>{}};
      srv.rpc['admin_team_dashboard'] = (_) => {'counters': <Map<String, dynamic>>[]};
      await monter(t, '/s/$id', _admin);
      controle(t, id, chiffresAdmis: false);
    });
  }

  cas('données réelles : le tableau de bord affiche les compteurs du serveur, rien d’autre', (t) async {
    srv.rpc['my_admin_access'] = (_) => {
          'role': 'admin',
          'is_admin': true,
          'teams': {'finance': ['finance.read', 'finance.payments'], 'support': <String>[], 'security': <String>[], 'tech': <String>[]},
        };
    srv.rpc['admin_team_dashboard'] = (a) => {
          'counters': [
            {'key': 'payments_pending', 'label': 'Paiements à vérifier', 'value': 7, 'permission': 'finance.payments'},
            {'key': 'escrow_held', 'label': 'Montants en séquestre (FCFA)', 'value': 123456, 'permission': 'finance.read', 'unit': 'FCFA'},
          ],
        };
    await monter(t, '/s/301', _admin);
    controle(t, '301', chiffresAdmis: true);
    expect(txt('Paiements à vérifier'), findsOneWidget);
    expect(txt('7'), findsOneWidget);
    expect(txtC('123 456'), findsOneWidget);
    expect(srv.callsOf('admin_team_dashboard').single.args['p_team'], 'finance');
  });

  cas('serveur : une erreur du tableau de bord est annoncée (jamais un compteur inventé) avec « Réessayer »', (t) async {
    srv.rpc['my_admin_access'] = (_) => {'role': 'admin', 'is_admin': true, 'teams': {'finance': <String>[]}};
    srv.rpc['admin_team_dashboard'] = (_) => throw const FakeRpcError('Réservé aux agents de cette équipe');
    await monter(t, '/s/301', _admin);
    expect(txt('Réessayer'), findsOneWidget);
    expect(txtC('Paiements à vérifier'), findsNothing);
  });

  // ------------------------------------------------------------------ 2. comptes suspects (306)
  group('306 comptes suspects : l’administrateur tranche', () {
    List<Map<String, dynamic>> flags = [];
    Map<String, dynamic> flag(String id, String name, String status, {bool suspended = false}) => {
          'id': id,
          'user_id': 'u-$id',
          'name': name,
          'email': '$id@t.cm',
          'role': 'client',
          'suspended': suspended,
          'reason': 'Paiements refusés en série ($id)',
          'status': status,
          'created_at': '2026-11-20T08:00:00Z',
          'flagged_by': 'Agent Sécurité',
        };

    setUp(() {
      flags = [flag('f1', 'Compte Un', 'escalated'), flag('f2', 'Compte Deux', 'open')];
      srv.rpc['security_flags_list'] = (a) => [for (final f in flags) if (a['p_status'] == null || a['p_status'] == '' || f['status'] == a['p_status']) f];
    });

    cas('administrateur : « Suspendre » et « Classer » sur un transmis ; pas les boutons de l’agent', (t) async {
      await monter(t, '/s/306', _admin);
      await t.tap(txt('Transmis'));
      await attendre(t);
      expect(txt('Compte Un'), findsOneWidget);
      expect(txt('Suspendre'), findsOneWidget);
      expect(txt('Classer'), findsOneWidget);
      expect(txt('Transmettre'), findsNothing);
      expect(txt('Hors de cause'), findsOneWidget, reason: 'seulement le filtre de la liste');
      expect(t.takeException(), isNull);
    });

    cas('suspension : confirmation, motif, appel serveur avec les bons paramètres, liste rafraîchie', (t) async {
      srv.rpc['security_flag_resolve'] = (a) {
        flags = [for (final f in flags) if (f['id'] != a['p_id']) f];
        return a['p_decision'];
      };
      await monter(t, '/s/306', _admin);
      await t.tap(txt('Transmis'));
      await attendre(t);
      await t.tap(btn('Suspendre'));
      await attendre(t);
      await t.tap(tbtn('Suspendre'));
      await attendre(t);
      await t.enterText(find.byType(TextField), 'Fraude confirmée');
      await t.tap(tbtn('Suspendre'));
      await attendre(t);
      final c = srv.callsOf('security_flag_resolve');
      expect(c, hasLength(1));
      expect(c.single.args, {'p_id': 'f1', 'p_decision': 'suspend', 'p_note': 'Fraude confirmée'});
      expect(txt('Compte Un'), findsNothing, reason: 'la liste n’a pas été rafraîchie');
      expect(txtC('est suspendu'), findsOneWidget);
    });

    cas('suspension refusée par le serveur (2FA) : message du serveur, rien n’est annoncé comme fait', (t) async {
      srv.rpc['security_flag_resolve'] = (a) => throw const FakeRpcError('Cette action exige la double authentification (aal2)');
      await monter(t, '/s/306', _admin);
      await t.tap(txt('Transmis'));
      await attendre(t);
      await t.tap(btn('Suspendre'));
      await attendre(t);
      await t.tap(tbtn('Suspendre'));
      await attendre(t);
      await t.tap(tbtn('Suspendre'));
      await attendre(t);
      expect(srv.callsOf('security_flag_resolve'), hasLength(1));
      expect(txt('Action impossible'), findsOneWidget);
      expect(txtC('double authentification'), findsOneWidget);
      expect(txtC('est suspendu'), findsNothing);
      expect(txt('Compte Un'), findsOneWidget);
    });

    cas('classement : motif de 5 caractères exigé avant tout appel, puis appel et liste rafraîchie', (t) async {
      srv.rpc['security_flag_resolve'] = (a) {
        flags = [for (final f in flags) if (f['id'] != a['p_id']) f];
        return a['p_decision'];
      };
      await monter(t, '/s/306', _admin);
      await t.tap(btn('Classer').first);
      await attendre(t);
      await t.enterText(find.byType(TextField), 'ok');
      await t.tap(tbtn('Classer'));
      await attendre(t);
      expect(srv.callsOf('security_flag_resolve'), isEmpty, reason: 'motif trop court accepté');
      expect(txtC('au moins 5'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'Messages légitimes');
      await t.tap(tbtn('Classer'));
      await attendre(t);
      final c = srv.callsOf('security_flag_resolve');
      expect(c, hasLength(1));
      expect(c.single.args['p_decision'], 'dismiss');
      expect(c.single.args['p_note'], 'Messages légitimes');
      expect(txtC('Signalement classé'), findsOneWidget);
    });

    cas('compte déjà suspendu : « Suspendre » désactivé', (t) async {
      flags = [flag('f3', 'Compte Trois', 'open', suspended: true)];
      await monter(t, '/s/306', _admin);
      expect(t.widget<TpButton>(btn('Suspendre')).onTap, isNull);
    });

    cas('agent Sécurité (non administrateur) : « Hors de cause » et « Transmettre », jamais « Suspendre »', (t) async {
      srv.rpc['my_admin_access'] = (_) => {'role': 'support', 'is_admin': false, 'teams': {'security': ['security.accounts']}};
      await monter(t, '/s/306', _compte('Support'));
      expect(txt('Compte Deux'), findsOneWidget);
      expect(btn('Transmettre'), findsOneWidget);
      expect(btn('Suspendre'), findsNothing);
      expect(btn('Classer'), findsNothing);
    });
  });

  // ------------------------------------------------------------------ 3. équipes : revue des anciens comptes Finance / Support (305)
  group('305 revue des comptes : droits minimaux voulus et historique par compte', () {
    List<Map<String, dynamic>> revue = [];
    Map<String, dynamic> compte(String id, String name, {bool needs = true, bool confirmed = false}) => {
          'user_id': id,
          'name': name,
          'email': '$id@t.cm',
          'role': 'finance',
          'suspended': false,
          'needs_review': needs,
          'minimal_confirmed': confirmed,
          'teams': [{'team': 'finance', 'permissions': <String>[], 'explicit': false}],
          'previous': <Map<String, dynamic>>[],
        };

    setUp(() {
      revue = [compte('u1', 'Legs Finance')];
      srv.rpc['admin_teams_overview'] = (_) => [
            for (final c in ['finance', 'support', 'security', 'tech'])
              {
                'code': c,
                'name': c,
                'description': 'Description $c',
                'members': 0,
                'defaults': <String>[],
                'permissions': [
                  {'code': '$c.read', 'label': 'Lecture', 'description': 'd', 'sensitive': false},
                ],
              },
          ];
      srv.rpc['admin_team_members_list'] = (_) => <Map<String, dynamic>>[];
      srv.rpc['admin_team_accounts_review'] = (_) => revue;
    });

    cas('« Droits minimaux voulus » : motif exigé, appel serveur, le compte sort de la liste à réviser et apparaît confirmé', (t) async {
      srv.rpc['admin_team_account_keep_minimal'] = (a) {
        revue = [compte(a['p_user'] as String, 'Legs Finance', needs: false, confirmed: true)];
        return {'user': a['p_user'], 'minimal_confirmed': true};
      };
      await monter(t, '/s/305', _admin, h: 3000);
      expect(txt('Legs Finance'), findsWidgets);
      await t.tap(btn('Droits minimaux voulus'));
      await attendre(t);
      await t.enterText(find.byType(TextField), 'ab');
      await t.tap(tbtn('Confirmer'));
      await attendre(t);
      expect(srv.callsOf('admin_team_account_keep_minimal'), isEmpty, reason: 'motif trop court accepté');
      await t.enterText(find.byType(TextField), 'Compte de formation, lecture seule');
      await t.tap(tbtn('Confirmer'));
      await attendre(t);
      final c = srv.callsOf('admin_team_account_keep_minimal');
      expect(c, hasLength(1));
      expect(c.single.args, {'p_user': 'u1', 'p_note': 'Compte de formation, lecture seule'});
      expect(txtC('Aucun compte à réviser'), findsOneWidget);
      expect(txt('Droits minimaux confirmés par l’administrateur.'), findsOneWidget);
      expect(btn('Droits minimaux voulus'), findsNothing);
    });

    cas('confirmation refusée (2FA ou droit) : message du serveur, le compte reste à réviser', (t) async {
      srv.rpc['admin_team_account_keep_minimal'] = (a) => throw const FakeRpcError('Cette action exige la double authentification (aal2)');
      await monter(t, '/s/305', _admin, h: 3000);
      await t.tap(btn('Droits minimaux voulus'));
      await attendre(t);
      await t.enterText(find.byType(TextField), 'Compte de formation');
      await t.tap(tbtn('Confirmer'));
      await attendre(t);
      expect(txt('Confirmation impossible'), findsOneWidget);
      expect(txtC('double authentification'), findsOneWidget);
      expect(btn('Droits minimaux voulus'), findsOneWidget);
    });

    cas('« Historique » du compte : lecture serveur filtrée sur le compte, événements et motif affichés', (t) async {
      srv.rpc['admin_team_history_list'] = (a) => [
            {'id': 3, 'at': '2026-11-20T09:00:00Z', 'action': 'keep_minimal', 'user': 'Legs Finance', 'team': 'finance', 'actor': 'Ada Admin', 'after': <String>[], 'note': 'Compte de formation'},
            {'id': 2, 'at': '2026-11-19T09:00:00Z', 'action': 'reduce', 'user': 'Legs Finance', 'team': 'finance', 'actor': null, 'after': <String>[], 'note': null},
          ];
      await monter(t, '/s/305', _admin, h: 3000);
      await t.tap(btn('Historique'));
      await attendre(t);
      final c = srv.callsOf('admin_team_history_list');
      expect(c, isNotEmpty);
      expect(c.last.args['p_user'], 'u1');
      expect(txt('Historique de Legs Finance'), findsOneWidget);
      expect(txtC('Droits minimaux confirmés'), findsOneWidget);
      expect(txtC('« Compte de formation »'), findsOneWidget);
      expect(txtC('par Ada Admin'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  // ------------------------------------------------------------------ 4. rattachement des comptes Département
  group('rattachement des comptes Département (administrateur)', () {
    List<Map<String, dynamic>> comptes = [];
    Map<String, dynamic> dep(String id, String name, {bool attached = true, bool review = false}) => {
          'id': id,
          'name': name,
          'email': '$id@t.cm',
          'suspended': false,
          'title': 'Responsable',
          'department_id': attached ? 'd1' : null,
          'department': attached ? 'Gestion' : null,
          'institution': attached ? 'IUT Test' : null,
          'attached': attached,
          'state': attached ? 'ok' : 'none',
          'to_review': review,
        };

    setUp(() {
      comptes = [dep('c1', 'Dep Premier', review: true), dep('c2', 'Dep Second', attached: false)];
      srv.rpc['admin_dept_accounts'] = (_) => comptes;
      srv.rpc['admin_dept_unassigned_accounts'] = (_) => <Map<String, dynamic>>[];
    });

    cas('liste : e-mail de chaque compte (homonymes), état, aucun nom de maquette', (t) async {
      await monter(t, '/departement/rattachements', _admin, h: 2400);
      expect(txt('Dep Premier'), findsOneWidget);
      expect(txt('c1@t.cm'), findsOneWidget);
      expect(txt('c2@t.cm'), findsOneWidget);
      expect(txt('Rattaché'), findsOneWidget);
      expect(txt('Non rattaché'), findsOneWidget);
      expect(txt('À confirmer'), findsOneWidget);
      controle(t, 'rattachements', chiffresAdmis: true);
    });

    cas('« Confirmer » appelle admin_dept_assign avec le département et la fonction actuels ; refus 2FA affiché', (t) async {
      srv.rpc['admin_dept_assign'] = (a) => throw const FakeRpcError('Cette action exige la double authentification (aal2)');
      await monter(t, '/departement/rattachements', _admin, h: 2400);
      await t.tap(btn('Confirmer'));
      await attendre(t);
      final c = srv.callsOf('admin_dept_assign');
      expect(c, hasLength(1));
      expect(c.single.args, {'p_user': 'c1', 'p_department': 'd1', 'p_title': 'Responsable'});
      expect(txt('Confirmation impossible'), findsOneWidget);
      expect(txtC('double authentification'), findsOneWidget);
    });

    cas('« Retirer » : confirmation, appel serveur, liste rafraîchie', (t) async {
      srv.rpc['admin_dept_unassign'] = (a) {
        comptes = [dep('c1', 'Dep Premier', attached: false), comptes[1]];
        return null;
      };
      await monter(t, '/departement/rattachements', _admin, h: 2400);
      await t.tap(btn('Retirer'));
      await attendre(t);
      await t.tap(tbtn('Retirer'));
      await attendre(t);
      expect(srv.callsOf('admin_dept_unassign').single.args, {'p_user': 'c1'});
      expect(txt('Rattaché'), findsNothing, reason: 'liste non rafraîchie');
      expect(txt('Non rattaché'), findsNWidgets(2));
    });

    cas('historique d’un compte : lecture serveur filtrée, actions et acteur affichés', (t) async {
      srv.rpc['admin_dept_assignments_history'] = (a) => [
            {'id': 2, 'at': '2026-11-20T09:00:00Z', 'action': 'change', 'user_id': 'c1', 'user': 'Dep Premier', 'department': 'Gestion', 'institution': 'IUT Test', 'previous': 'Génie logiciel', 'title': 'Responsable', 'actor': 'Ada Admin', 'note': null},
            {'id': 1, 'at': '2026-11-19T09:00:00Z', 'action': 'existing', 'user_id': 'c1', 'user': 'Dep Premier', 'department': 'Génie logiciel', 'institution': 'IUT Test', 'previous': null, 'title': 'Responsable', 'actor': null, 'note': 'Repris automatiquement par le système'},
          ];
      await monter(t, '/departement/rattachements', _admin, h: 2400);
      await t.tap(btn('Historique').first);
      await attendre(t);
      expect(srv.callsOf('admin_dept_assignments_history').last.args['p_user'], 'c1');
      expect(txt('Historique de Dep Premier'), findsOneWidget);
      expect(txt('Département changé'), findsOneWidget);
      expect(txtC('avant : Génie logiciel'), findsOneWidget);
      expect(txtC('par Ada Admin'), findsOneWidget);
      expect(txtC('Responsable · par le système'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    cas('historique vide : état honnête, jamais de ligne inventée', (t) async {
      srv.rpc['admin_dept_assignments_history'] = (a) => <Map<String, dynamic>>[];
      await monter(t, '/departement/rattachements', _admin, h: 2400);
      await t.tap(btn('Historique').first);
      await attendre(t);
      expect(txt('Aucun rattachement enregistré.'), findsOneWidget);
    });
  });
}
