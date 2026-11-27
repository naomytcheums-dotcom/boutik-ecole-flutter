import 'package:boutik_ecole/app.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/render.dart';

/// H13.1 · LOT ACTORS : un parcours d'INTERFACE par acteur de la navigation, du début à la fin : connexion (compte restauré par le vrai client) -> tableau de bord
/// (lectures serveur réellement émises) -> action (geste de l'utilisateur, appel réellement émis avec ses paramètres) -> REFUS (refus du serveur affiché tel quel, sans faux succès,
/// ou garde de route : page neutre « Page introuvable » et journal d'accès refusé). Le vrai client Supabase parle à un faux serveur local (test/helpers/fake_supabase.dart).
/// Les parcours serveur correspondants (RLS, droits, isolation) sont joués sur la base rejouée par supabase/tests/marketplace_pglite/h131_parcours_*.mjs.
Account _compte(String nom, int role, {String staff = ''}) => Account(
      name: nom,
      phone: '690000777',
      email: 'h131.test@example.test',
      password: '',
      role: role,
      staff: staff,
      institution: 'Établissement de test',
      department: 'Département de test',
      serverId: FakeSupabase.userId,
    );

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
    srv.rpc.clear();
    srv.tables.clear();
    srv.writeResult.clear();
    srv.calls.clear();
    srv.unknownIsError = false;
  });
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = true;
  });

  Future<void> ouvrir(WidgetTester t, Account a, String route, {Size size = const Size(390, 900)}) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: [initialAccountProvider.overrideWithValue(a)], child: BoutikEcoleApp(initialLocation: route)));
    await settleReal(t);
  }

  Future<void> fermer(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 60));
  }

  Future<void> toucher(WidgetTester t, String texte) async {
    final f = find.text(texte).hitTestable();
    expect(f, findsWidgets, reason: 'texte « $texte » introuvable ou masqué');
    await t.tap(f.first);
    await settleReal(t);
  }

  /// Attend (temps réel) que le faux serveur ait reçu un appel de [fn] : les lectures s'enchaînent l'une après l'autre.
  Future<void> attendre(WidgetTester t, String fn) async {
    for (var i = 0; i < 40 && srv.callsOf(fn).isEmpty; i++) {
      await settleReal(t, rounds: 1);
    }
    await settleReal(t, rounds: 12);
  }

  void refusDeRoute() {
    expect(find.text('Page introuvable'), findsOneWidget, reason: 'la garde de route doit montrer la page neutre');
    expect(srv.callsOf('log_audit'), isNotEmpty, reason: 'l\'accès refusé est journalisé côté serveur');
  }

  testWidgets('CLIENT : connexion -> « Suivi de mes commandes » -> suivi d\'une commande -> refus des espaces des autres acteurs', (t) async {
    srv.tables['orders'] = [
      {'number': '#BE-H131-0001', 'subtotal': 12000, 'fee': 0, 'method': 'Paiement à la livraison', 'reference': null, 'status': 0, 'paid': false, 'created_at': '2026-11-20T10:00:00Z', 'order_lines': [{'title': 'Lampe de test H131', 'qty': 1, 'unit_price': 12000, 'fulfillment': 0}]},
    ];
    srv.rpc['order_tracking'] = (a) => {'number': a['p_number'], 'status': 0, 'steps': []};
    await ouvrir(t, _compte('Cora Cliente', 0), '/commandes/suivi');
    // tableau de bord : la lecture réelle des commandes a été émise et la commande de CE compte est listée, aucune autre
    expect(srv.calls.where((c) => c.kind == 'table' && c.name == 'orders'), isNotEmpty);
    expect(find.textContaining('#BE-H131-0001'), findsWidgets);
    expect(find.text('Vous n’avez pas encore de commande. Vos achats apparaîtront ici avec leur suivi.'), findsNothing);
    // action : ouvrir le suivi de la commande -> appel order_tracking avec le numéro
    await t.tap(find.textContaining('#BE-H131-0001').first);
    await settleReal(t);
    expect(srv.callsOf('order_tracking'), isNotEmpty, reason: 'le suivi interroge le serveur');
    expect(srv.callsOf('order_tracking').first.args['p_number'], '#BE-H131-0001');
    await fermer(t);
    // refus : espaces du département, de l'administration, du vendeur
    for (final r in ['/departement', '/admin/entreprises', '/comptes-test']) {
      srv.calls.clear();
      await ouvrir(t, _compte('Cora Cliente', 0), r);
      refusDeRoute();
      await fermer(t);
    }
  });

  testWidgets('ÉTUDIANT-VENDEUR : connexion -> espace vendeur (capacité lue sur le serveur) -> conditions non remplies affichées -> refus de l\'administration', (t) async {
    srv.rpc['my_seller_capability'] = (_) => {
          'can_sell': false,
          'role': 'student',
          'can_publish': false,
          'paused': false,
          'can_receive_orders': false,
          'missing': ['student_verified', 'phone_verified'],
          'conditions': [
            {'key': 'student', 'label': 'Compte étudiant', 'ok': true},
            {'key': 'student_verified', 'label': 'Statut d’étudiant vérifié (pièce validée ou compte certifié)', 'ok': false},
            {'key': 'phone_verified', 'label': 'Numéro de téléphone vérifié par un code', 'ok': false},
          ],
        };
    await ouvrir(t, _compte('Awa Étudiante', 1), '/marche/vendeur');
    expect(srv.callsOf('my_seller_capability'), isNotEmpty, reason: 'la capacité de vente vient du serveur, jamais d\'un état local');
    expect(find.textContaining('Statut d’étudiant vérifié'), findsWidgets, reason: 'les conditions manquantes sont dites honnêtement');
    expect(find.textContaining('Numéro de téléphone vérifié'), findsWidgets);
    // aucune écriture de boutique ou d'annonce n'a été émise sans action de l'utilisateur
    expect(srv.calls.where((c) => c.kind == 'write'), isEmpty);
    await fermer(t);
    srv.calls.clear();
    await ouvrir(t, _compte('Awa Étudiante', 1), '/admin/entreprises');
    refusDeRoute();
    await fermer(t);
    srv.calls.clear();
    await ouvrir(t, _compte('Awa Étudiante', 1), '/departement/validations');
    refusDeRoute();
    await fermer(t);
  });

  testWidgets('ORGANISATION : connexion -> fiche d\'organisation -> envoi pour vérification refusé sans pièce (aucune écriture) -> refus du département et de l\'administration', (t) async {
    srv.rpc['company_get'] = (_) => null;
    await ouvrir(t, _compte('Orange Cameroun', 2), '/entreprise/profil');
    expect(srv.callsOf('company_get'), isNotEmpty);
    expect(find.text('Fiche de l’organisation'), findsOneWidget);
    expect(find.textContaining('Brouillon'), findsWidgets);
    // action : envoyer une fiche vide pour vérification -> le refus liste ce qui manque, aucun appel d'écriture n'est émis
    final envoi = find.text('Enregistrer et envoyer pour vérification');
    await t.scrollUntilVisible(envoi, 300, scrollable: find.byType(Scrollable).first);
    await t.tap(envoi);
    await settleReal(t);
    expect(find.textContaining('Pour envoyer la demande, renseignez'), findsOneWidget);
    expect(srv.callsOf('company_submit'), isEmpty, reason: 'jamais de demande envoyée avec une fiche incomplète');
    expect(srv.callsOf('company_save'), isEmpty);
    await fermer(t);
    for (final r in ['/departement', '/admin/entreprises']) {
      srv.calls.clear();
      await ouvrir(t, _compte('Orange Cameroun', 2), r);
      refusDeRoute();
      await fermer(t);
    }
  });

  testWidgets('RESPONSABLE DE DÉPARTEMENT : connexion -> tableau de bord du département -> enregistrement refusé par le serveur (autre département) -> refus de l\'administration', (t) async {
    srv.rpc['my_department'] = (_) => {'role': 'dept', 'attached': true, 'department_id': 'd1', 'department': 'Génie logiciel', 'institution': 'IUT test', 'title': 'Chef de département', 'name': 'Dr Mbarga'};
    srv.rpc['dept_overview'] = (_) => {
          'department_id': 'd1', 'department': 'Génie logiciel', 'institution': 'IUT test', 'students': 42, 'students_verified': 30, 'students_certified': 8, 'sellers': 5, 'listings': 12,
          'projects': {'total': 9, 'approved': 4, 'submitted': 3, 'draft': 1, 'rejected': 1}, 'innovations': {'total': 0}, 'skills': {'total': 0}, 'opportunities': {'published': 0},
          'partnerships': {'total': 0}, 'sales': {'revenue': 0, 'orders': 0}, 'validations': {'total': 0},
        };
    srv.rpc['dept_identity_get'] = (_) => {
          'department_id': 'd1', 'name': 'Génie logiciel', 'institution': 'IUT test', 'description': 'Formation en génie logiciel', 'mission': '', 'programs': ['Licence pro'], 'head_name': 'Dr Mbarga',
          'contact_email': 'gl@iut.cm', 'contact_phone': '', 'address': '', 'website': '', 'contact_public': false, 'accounts': [],
        };
    srv.rpc['dept_identity_save'] = (_) => throw const FakeRpcError('Ce département n’est pas le vôtre');
    final compte = _compte('Dr Mbarga', 3, staff: 'Resp. département');
    await ouvrir(t, compte, '/departement');
    expect(srv.callsOf('my_department'), isNotEmpty);
    await attendre(t, 'dept_overview');
    String vu() => '${srv.calls.map((c) => c.name).toList()} / ${t.widgetList<RichText>(find.byType(RichText)).map((r) => r.text.toPlainText().trim()).where((s) => s.isNotEmpty).take(12).toList()}';
    expect(srv.callsOf('dept_overview'), isNotEmpty, reason: vu());
    expect(find.text('Génie logiciel'), findsWidgets);
    expect(find.text('42'), findsOneWidget, reason: 'les chiffres affichés sont ceux du serveur');
    await fermer(t);
    // action : modifier l'identité du département -> le serveur refuse : message affiché tel quel, pas de faux succès
    await ouvrir(t, compte, '/departement/identite', size: const Size(390, 2600));
    await attendre(t, 'dept_identity_get');
    expect(find.text('Formation en génie logiciel'), findsOneWidget);
    await toucher(t, 'Enregistrer');
    expect(srv.callsOf('dept_identity_save'), hasLength(1));
    expect(find.textContaining('pas le vôtre'), findsWidgets, reason: 'le refus du serveur est affiché');
    await fermer(t);
    for (final r in ['/admin/entreprises', '/comptes-test']) {
      srv.calls.clear();
      await ouvrir(t, compte, r);
      refusDeRoute();
      await fermer(t);
    }
  });

  testWidgets('ADMINISTRATEUR : connexion -> liste des comptes -> suspension (appel exact) -> refus du serveur (2FA) affiché sans faux succès -> ses espaces sont ouverts', (t) async {
    final adminRow = {'id': FakeSupabase.userId, 'name': 'Ada Admin', 'role': 'admin', 'email': 'admin.test@example.test', 'institution': 'Plateforme', 'suspended': false, 'created_at': DateTime.now().toUtc().toIso8601String()};
    srv.tables['profiles'] = [
      adminRow,
      for (var i = 1; i <= 3; i++) {'id': '00000000-0000-4000-8000-00000000010$i', 'name': 'Compte Test $i', 'role': 'client', 'email': 'c$i@example.test', 'institution': 'Inst $i', 'suspended': false, 'created_at': DateTime.now().toUtc().toIso8601String()},
    ];
    srv.rpc['admin_set_account'] = (_) => null;
    final compte = _compte('Ada Admin', 3, staff: 'Admin global');
    await ouvrir(t, compte, '/s/128', size: const Size(1280, 900));
    expect(find.text('Compte Test 1'), findsOneWidget);
    expect(find.text('Compte Test 3'), findsOneWidget);
    await toucher(t, 'Compte Test 2');
    await toucher(t, 'Compte suspendu');
    await toucher(t, 'Enregistrer');
    final c = srv.callsOf('admin_set_account');
    expect(c, hasLength(1));
    expect(c.single.args, {'p_user': '00000000-0000-4000-8000-000000000102', 'p_role': 'client', 'p_suspended': true});
    await fermer(t);
    // refus : le serveur exige la double authentification (nouvelle ouverture : aucun message du premier enregistrement)
    srv.rpc['admin_set_account'] = (_) => throw const FakeRpcError('Action sensible : double authentification requise');
    await ouvrir(t, compte, '/s/128', size: const Size(1280, 900));
    await toucher(t, 'Compte Test 3');
    await toucher(t, 'Enregistrer');
    expect(find.text('Compte non modifié'), findsOneWidget);
    expect(find.textContaining('double authentification'), findsOneWidget);
    expect(find.text('Compte mis à jour par le serveur'), findsNothing);
    await fermer(t);
    // ses espaces sont ouverts : aucun refus de route
    srv.calls.clear();
    await ouvrir(t, compte, '/comptes-test');
    expect(find.text('Page introuvable'), findsNothing);
    expect(srv.callsOf('test_accounts_list'), isNotEmpty);
    await fermer(t);
  });
}





