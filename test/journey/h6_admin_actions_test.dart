import 'package:boutik_ecole/app.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/entreprise.dart' show dateCourte;
import 'package:boutik_ecole/figma/live/ops.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/render.dart';

/// H6 · L2 : FONCTIONS de l'espace admin (127-138, 145-147, 180/181, 264-269, 277, 280-283).
/// Le VRAI client Supabase parle à un faux serveur local (test/helpers/fake_supabase.dart) : on vérifie l'appel réellement émis
/// (fonction, paramètres), la réaction de l'écran à un refus du serveur (garde de permission, 2FA…) et le rafraîchissement.
void main() {
  late FakeSupabase srv;
  final admin = Account(
    name: 'Compte Administrateur',
    phone: '690000999',
    email: 'admin.test@example.test',
    password: '',
    role: 3,
    staff: 'Admin global',
    institution: 'Plateforme',
    serverId: FakeSupabase.userId,
  );

  setUpAll(() async {
    await loadAppFonts();
    srv = await FakeSupabase.start();
    await srv.initSupabase();
  });
  tearDownAll(() => srv.close());

  final adminRow = {'id': FakeSupabase.userId, 'name': 'Compte Administrateur', 'role': 'admin', 'email': 'admin.test@example.test', 'institution': 'Plateforme', 'suspended': false, 'created_at': DateTime.now().toUtc().toIso8601String()};

  setUp(() {
    GScreen.mockupFrame = false;
    GAnim.enabled = false;
    srv.rpc.clear();
    srv.tables.clear();
    srv.tables['profiles'] = [adminRow]; // le compte connecté existe côté serveur (restauration de session)
    srv.writeResult.clear();
    srv.calls.clear();
    srv.unknownIsError = false;
  });
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = true;
  });

  Future<void> open(WidgetTester tester, String id) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(overrides: [initialAccountProvider.overrideWithValue(admin)], child: BoutikEcoleApp(initialLocation: '/s/$id')));
    await settleReal(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 60));
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final f = find.text(text).hitTestable();
    expect(f, findsWidgets, reason: 'texte « $text » introuvable ou masqué');
    await tester.tap(f.first);
    await settleReal(tester);
  }

  /// Attend (temps réel) que le faux serveur ait reçu [n] appels de [fn] : les appels s'enchaînent l'un après l'autre.
  Future<void> waitCalls(WidgetTester tester, String fn, int n) async {
    for (var i = 0; i < 40 && srv.callsOf(fn).length < n; i++) {
      await settleReal(tester, rounds: 1);
    }
    await settleReal(tester, rounds: 12);
  }

  /// Harnais d'une fonction (boîte de dialogue) appelée par un bouton, dans un vrai ProviderScope.
  Future<void> pumpHarness(WidgetTester tester, Widget Function(BuildContext, WidgetRef) body) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [initialAccountProvider.overrideWithValue(admin)],
      child: MaterialApp(home: Scaffold(body: Consumer(builder: (c, ref, _) => body(c, ref)))),
    ));
    await settleReal(tester);
  }

  final now = DateTime.now().toUtc().toIso8601String();

  group('128 comptes', () {
    List<Map<String, dynamic>> profiles() => [
          adminRow,
          for (var i = 1; i <= 8; i++) {'id': '00000000-0000-4000-8000-00000000010$i', 'name': 'Compte Test $i', 'role': i == 8 ? 'finance' : 'client', 'email': 'c$i@example.test', 'institution': 'Inst $i', 'suspended': false, 'created_at': now},
        ];

    testWidgets('la liste affiche TOUS les comptes (plus de limite aux cinq premiers)', (tester) async {
      srv.tables['profiles'] = profiles();
      await open(tester, '128');
      for (var i = 1; i <= 8; i++) {
        expect(find.text('Compte Test $i'), findsOneWidget, reason: 'compte $i absent');
      }
      await close(tester);
    });

    testWidgets('changer le rôle ou suspendre appelle admin_set_account avec les bons paramètres puis recharge la liste', (tester) async {
      srv.tables['profiles'] = profiles();
      srv.rpc['admin_set_account'] = (_) => null;
      await open(tester, '128');
      await tapText(tester, 'Compte Test 7');
      await tapText(tester, 'Compte suspendu');
      final reads = srv.calls.where((c) => c.kind == 'table' && c.name == 'profiles').length;
      await tapText(tester, 'Enregistrer');
      final c = srv.callsOf('admin_set_account');
      expect(c, hasLength(1));
      expect(c.single.args, {'p_user': '00000000-0000-4000-8000-000000000107', 'p_role': 'client', 'p_suspended': true});
      expect(srv.calls.where((c) => c.kind == 'table' && c.name == 'profiles').length, greaterThan(reads), reason: 'la liste doit être relue après la modification');
      await close(tester);
    });

    testWidgets('un refus du serveur (2FA, garde) est affiché tel quel, sans faux succès', (tester) async {
      srv.tables['profiles'] = profiles();
      srv.rpc['admin_set_account'] = (_) => throw const FakeRpcError('Action sensible : double authentification requise');
      await open(tester, '128');
      await tapText(tester, 'Compte Test 3');
      await tapText(tester, 'Enregistrer');
      expect(find.text('Compte non modifié'), findsOneWidget);
      expect(find.textContaining('double authentification'), findsOneWidget);
      expect(find.text('Compte mis à jour par le serveur'), findsNothing);
      await close(tester);
    });

    testWidgets('lecture refusée : message d’accès, jamais une liste vide trompeuse', (tester) async {
      srv.tables.remove('profiles'); // serveur muet : la lecture des comptes échoue (404)
      srv.unknownIsError = true;
      await open(tester, '128');
      expect(find.textContaining('Accès réservé à la gestion'), findsOneWidget);
      expect(find.text('Aucun compte pour le moment.'), findsNothing);
      await close(tester);
    });
  });

  group('130 modération et 131 signalements', () {
    testWidgets('130 : la file réelle s’affiche et « Valider » enregistre la décision sur le serveur', (tester) async {
      srv.rpc['listing_review_queue'] = (_) => [
            {'id': '00000000-0000-4000-8000-0000000000a1', 'title': 'Lampe de bureau', 'seller_name': 'Vendeur Test', 'category': 'Maison', 'price': 5000, 'status': 'pending', 'updated_at': now, 'stock': 3},
          ];
      srv.writeResult['listings'] = [
        {'id': '00000000-0000-4000-8000-0000000000a1'},
      ];
      await open(tester, '130');
      expect(find.text('Lampe de bureau'), findsOneWidget);
      expect(find.text('Examiner'), findsWidgets);
      await tapText(tester, 'Lampe de bureau');
      await tapText(tester, 'Valider');
      final w = srv.calls.where((c) => c.kind == 'write' && c.name == 'listings');
      expect(w, hasLength(1));
      expect(w.single.args['status'], 'approved');
      await close(tester);
    });

    testWidgets('130 : sans droit sur la table, la décision refusée par la politique est annoncée (pas de faux succès)', (tester) async {
      srv.rpc['listing_review_queue'] = (_) => [
            {'id': '00000000-0000-4000-8000-0000000000a2', 'title': 'Sac à dos', 'seller_name': 'Vendeur', 'category': 'Mode', 'price': 7000, 'status': 'pending', 'updated_at': now},
          ];
      await open(tester, '130'); // aucune ligne modifiée côté serveur
      await tapText(tester, 'Sac à dos');
      await tapText(tester, 'Valider');
      expect(find.text('Décision non enregistrée'), findsOneWidget);
      expect(find.text('Annonce validée et publiée'), findsNothing);
      await close(tester);
    });

    testWidgets('131 : tous les signalements sont listés ; l’enregistrement appelle set_report_status puis relit', (tester) async {
      srv.tables['listing_reports'] = [
        for (var i = 1; i <= 6; i++) {'id': '00000000-0000-4000-8000-00000000020$i', 'listing_id': '00000000-0000-4000-8000-00000000030$i', 'reason': 'fraud', 'status': 'open', 'created_at': now, 'listings': {'title': 'Annonce $i'}},
      ];
      srv.rpc['set_report_status'] = (_) => null;
      await open(tester, '131');
      for (var i = 1; i <= 6; i++) {
        expect(find.text('Annonce « Annonce $i »'), findsOneWidget);
      }
      await tapText(tester, 'Annonce « Annonce 6 »');
      await tapText(tester, 'Enregistrer');
      final c = srv.callsOf('set_report_status');
      expect(c, hasLength(1));
      expect(c.single.args, {'p_report': '00000000-0000-4000-8000-000000000206', 'p_status': 'open'});
      await close(tester);
    });

    testWidgets('131 : refus du serveur annoncé', (tester) async {
      srv.tables['listing_reports'] = [
        {'id': '00000000-0000-4000-8000-000000000211', 'listing_id': '00000000-0000-4000-8000-000000000311', 'reason': 'price', 'status': 'open', 'created_at': now, 'listings': {'title': 'Annonce Z'}},
      ];
      srv.rpc['set_report_status'] = (_) => throw const FakeRpcError('Action non autorisée');
      await open(tester, '131');
      await tapText(tester, 'Annonce « Annonce Z »');
      await tapText(tester, 'Enregistrer');
      expect(find.text('Signalement non modifié'), findsOneWidget);
      expect(find.textContaining('Action non autorisée'), findsOneWidget);
      await close(tester);
    });
  });

  group('132 commandes de la plateforme', () {
    testWidgets('admin_orders est appelée et alimente liste et compteurs réels', (tester) async {
      srv.rpc['admin_orders'] = (a) => [
            {'number': 'BE-TEST-1', 'status': 1, 'paid': true, 'cancelled': false, 'method': 'orange_money', 'total': 12500, 'created_at': now, 'buyer': 'Cliente Test', 'sellers': 'Vendeur A, Vendeur B'},
            {'number': 'BE-TEST-2', 'status': 0, 'paid': false, 'cancelled': true, 'method': 'cod', 'total': 4000, 'created_at': now, 'buyer': 'Client Deux', 'sellers': 'Vendeur C'},
          ];
      await open(tester, '132');
      expect(srv.callsOf('admin_orders').first.args['p_limit'], 200);
      expect(find.text('#BE-TEST-1'), findsOneWidget);
      expect(find.text('Cliente Test'), findsOneWidget);
      expect(find.text('Vendeur A, Vendeur B'), findsOneWidget);
      expect(find.text('En préparation'), findsWidgets);
      expect(find.text('Annulée'), findsOneWidget);
      await close(tester);
    });

    testWidgets('refus (garde de permission) : message d’accès, aucun chiffre', (tester) async {
      srv.rpc['admin_orders'] = (_) => throw const FakeRpcError('Action non autorisée');
      await open(tester, '132');
      expect(find.textContaining('Accès réservé à la gestion'), findsOneWidget);
      await close(tester);
    });
  });

  group('135 commissions', () {
    testWidgets('les règles affichées sont celles du serveur ; sans règle enregistrée : « — »', (tester) async {
      srv.rpc['settings_all'] = (_) => {'commission.product': 6, 'commission.service': 8, 'commission.financing': 3, 'commission.payout_threshold': 20000, 'commission.updated_at': '2026-11-01T10:00:00Z'};
      await open(tester, '135');
      expect(find.text('6 %'), findsOneWidget);
      expect(find.text('8 %'), findsOneWidget);
      expect(find.text('3 %'), findsOneWidget);
      await close(tester);
      srv.rpc['settings_all'] = (_) => <String, dynamic>{};
      await open(tester, '135');
      expect(find.text('—'), findsWidgets);
      expect(find.text('5 %'), findsNothing);
      expect(find.textContaining('Aucune modification enregistrée'), findsOneWidget);
      await close(tester);
    });

    testWidgets('« Enregistrer » écrit les quatre règles (setting_set) et journalise ; échec : erreur affichée, pas de faux succès', (tester) async {
      srv.rpc['settings_all'] = (_) => <String, dynamic>{};
      srv.rpc['setting_set'] = (_) => null;
      await pumpHarness(tester, (c, ref) => TextButton(onPressed: () => commissionDialog(c, ref), child: const Text('Ouvrir')));
      await tester.tap(find.text('Ouvrir'));
      await settleReal(tester);
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '6');
      await tester.enterText(fields.at(1), '8');
      await tester.enterText(fields.at(2), '3');
      await tester.enterText(fields.at(3), '25000');
      await tapText(tester, 'Enregistrer');
      await waitCalls(tester, 'setting_set', 5);
      final keys = {for (final c in srv.callsOf('setting_set')) c.args['p_key']: c.args['p_value']};
      expect(keys['commission.product'], 6);
      expect(keys['commission.service'], 8);
      expect(keys['commission.financing'], 3);
      expect(keys['commission.payout_threshold'], 25000);
      expect(keys['commission.updated_at'], isA<String>());
      expect(find.text('Modifier les commissions'), findsNothing, reason: 'boîte fermée après succès');
      await close(tester);

      srv.calls.clear();
      srv.rpc['setting_set'] = (_) => throw const FakeRpcError('Les réglages financiers sont réservés à l’administrateur global');
      await pumpHarness(tester, (c, ref) => TextButton(onPressed: () => commissionDialog(c, ref), child: const Text('Ouvrir')));
      await tester.tap(find.text('Ouvrir'));
      await settleReal(tester);
      final f2 = find.byType(TextField);
      for (var i = 0; i < 3; i++) {
        await tester.enterText(f2.at(i), '5');
      }
      await tester.enterText(f2.at(3), '10000');
      await tapText(tester, 'Enregistrer');
      expect(find.textContaining('réservés à l’administrateur global'), findsOneWidget);
      expect(find.text('Modifier les commissions'), findsOneWidget, reason: 'la boîte reste ouverte sur un refus');
      await close(tester);
    });

    testWidgets('valeurs hors limites refusées sans appel serveur', (tester) async {
      srv.rpc['settings_all'] = (_) => <String, dynamic>{};
      await pumpHarness(tester, (c, ref) => TextButton(onPressed: () => commissionDialog(c, ref), child: const Text('Ouvrir')));
      await tester.tap(find.text('Ouvrir'));
      await settleReal(tester);
      final f = find.byType(TextField);
      await tester.enterText(f.at(0), '45');
      await tester.enterText(f.at(1), '8');
      await tester.enterText(f.at(2), '3');
      await tester.enterText(f.at(3), '1000');
      await tapText(tester, 'Enregistrer');
      expect(find.textContaining('Taux entre 0 et 30'), findsOneWidget);
      expect(srv.callsOf('setting_set'), isEmpty);
      await close(tester);
    });
  });

  group('137 journal d’audit et export', () {
    final actor = '00000000-0000-4000-8000-000000000501';

    testWidgets('le journal du SERVEUR s’affiche (acteur résolu en nom de compte) et l’onglet filtre', (tester) async {
      srv.tables['profiles'] = [
        adminRow,
        {'id': actor, 'name': 'Agent Finance Test', 'role': 'finance', 'email': 'f@example.test', 'created_at': now},
      ];
      srv.tables['audit_log'] = [
        {'actor': actor, 'action': 'Réglage modifié', 'target': 'commission.product', 'category': 'Réglages', 'level': 'Info', 'created_at': now},
        {'actor': 'Admin', 'action': 'Compte suspendu', 'target': 'Compte X', 'category': 'Comptes', 'level': 'Sensible', 'created_at': now},
      ];
      await open(tester, '137');
      expect(find.text('Agent Finance Test'), findsOneWidget);
      expect(find.text('Réglage modifié'), findsOneWidget);
      expect(find.text('Compte suspendu'), findsOneWidget);
      await tapText(tester, 'Comptes');
      expect(find.text('Compte suspendu'), findsOneWidget);
      expect(find.text('Réglage modifié'), findsNothing);
      await close(tester);
    });

    testWidgets('« Exporter » produit un vrai fichier CSV des entrées affichées', (tester) async {
      srv.tables['audit_log'] = [
        {'actor': 'Admin', 'action': 'Compte "suspendu"', 'target': 'Compte X', 'category': 'Comptes', 'level': 'Sensible', 'created_at': now},
      ];
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await open(tester, '137');
      expect(find.text('Compte X'), findsOneWidget);
      // zone « Exporter » de la maquette (1009,134 → 1252,184), dans le repère de l'écran
      await tester.tapAt(tester.getTopLeft(find.byType(GScreen)) + const Offset(1130, 159));
      await settleReal(tester);
      expect(copied, isNotNull, reason: 'le fichier CSV doit être produit');
      expect(copied, contains('Date;Acteur;Action;Cible;Catégorie;Niveau'));
      expect(copied, contains('"Compte ""suspendu"""'));
      await close(tester);
    });

    testWidgets('journal illisible : message d’accès, export refusé honnêtement', (tester) async {
      srv.unknownIsError = true;
      await open(tester, '137');
      expect(find.textContaining('Lecture réservée'), findsOneWidget);
      await close(tester);
    });
  });

  group('133 réclamations', () {
    testWidgets('rejeter une réclamation appelle claim_decide (release) puis relit la liste', (tester) async {
      srv.tables['claims'] = [
        {'id': '00000000-0000-4000-8000-000000000601', 'reason': 'not_received', 'details': 'Colis jamais arrivé', 'status': 'open', 'created_at': now},
      ];
      srv.rpc['claim_decide'] = (_) => null;
      await open(tester, '133');
      await tapText(tester, 'Colis jamais arrivé · ${_dateOf(now)}');
      await tapText(tester, 'Rejeter la réclamation');
      final c = srv.callsOf('claim_decide');
      expect(c, hasLength(1));
      expect(c.single.args, {'p_id': '00000000-0000-4000-8000-000000000601', 'p_decision': 'release', 'p_note': ''});
      await close(tester);
    });

    testWidgets('décision refusée par le serveur (permission de remboursement) : message du serveur, pas de faux succès', (tester) async {
      srv.tables['claims'] = [
        {'id': '00000000-0000-4000-8000-000000000602', 'reason': 'damaged', 'details': 'Article abîmé', 'status': 'open', 'created_at': now},
      ];
      srv.rpc['claim_decide'] = (_) => throw const FakeRpcError('Action non autorisée');
      await open(tester, '133');
      await tapText(tester, 'Article abîmé · ${_dateOf(now)}');
      await tapText(tester, 'Rejeter la réclamation');
      expect(find.textContaining('Acheteur remboursé'), findsNothing);
      expect(find.textContaining('Réclamation non retenue'), findsNothing);
      await close(tester);
    });
  });

  group('181 permissions réelles', () {
    testWidgets('le catalogue des permissions vient du serveur (plus de matrice « Oui / Valide » figée)', (tester) async {
      srv.tables['admin_teams'] = [
        {'code': 'finance', 'name': 'Finance', 'description': 'd', 'position': 1},
      ];
      srv.tables['admin_permissions'] = [
        {'code': 'finance.read', 'team_code': 'finance', 'label': 'Consulter les tableaux financiers', 'description': 'Lecture seule', 'sensitive': false, 'position': 1},
        {'code': 'finance.payouts', 'team_code': 'finance', 'label': 'Traiter les retraits', 'description': 'Verser', 'sensitive': true, 'position': 3},
      ];
      await open(tester, '181');
      expect(find.text('Consulter les tableaux financiers'), findsOneWidget);
      expect(find.textContaining('Traiter les retraits · sensible'), findsOneWidget);
      expect(find.text('Oui'), findsNothing);
      expect(find.text('Valide'), findsNothing);
      await close(tester);
    });
  });

  group('147-2 incidents de bornes', () {
    testWidgets('résoudre un incident appelle kiosk_incident_resolve (borne remise en ligne) puis relit les listes', (tester) async {
      srv.tables['kiosk_incidents'] = [
        {'id': 7, 'kiosk_id': 'borne-1', 'kind': 'hardware', 'message': 'Lecteur QR bloqué', 'created_at': now, 'resolved_at': null},
      ];
      srv.tables['kiosks'] = [
        {'id': 'borne-1', 'name': 'Hall test', 'location': 'RDC', 'status': 'maintenance', 'updated_at': now, 'last_seen_at': now},
      ];
      srv.rpc['kiosk_incident_resolve'] = (_) => null;
      await open(tester, '147-2');
      await tapText(tester, 'Lecteur QR bloqué');
      final reads = srv.calls.where((c) => c.kind == 'table' && c.name == 'kiosk_incidents').length;
      await tapText(tester, 'Résolu : remettre la borne en ligne');
      final c = srv.callsOf('kiosk_incident_resolve');
      expect(c, hasLength(1));
      expect(c.single.args, {'p_id': 7, 'p_status': 'online'});
      expect(srv.calls.where((c) => c.kind == 'table' && c.name == 'kiosk_incidents').length, greaterThan(reads), reason: 'liste relue après la résolution');
      await close(tester);
    });

    testWidgets('refus du serveur (pas de permission) : message affiché, incident toujours ouvert', (tester) async {
      srv.tables['kiosk_incidents'] = [
        {'id': 8, 'kiosk_id': 'borne-1', 'kind': 'other', 'message': 'Écran noir', 'created_at': now, 'resolved_at': null},
      ];
      srv.rpc['kiosk_incident_resolve'] = (_) => throw const FakeRpcError('Action non autorisée');
      await open(tester, '147-2');
      await tapText(tester, 'Écran noir');
      await tapText(tester, 'Résolu : ne pas changer l’état de la borne');
      expect(find.textContaining('Action non autorisée'), findsOneWidget);
      expect(find.text('Incident marqué comme résolu.'), findsNothing);
      await close(tester);
    });

    testWidgets('lecture des compteurs impossible : message honnête, pas de zéro trompeur', (tester) async {
      srv.tables.remove('profiles');
      srv.unknownIsError = true;
      await open(tester, '147-2');
      expect(find.text('Compteurs indisponibles pour le moment.'), findsOneWidget);
      await close(tester);
    });
  });

  group('282 bornes', () {
    testWidgets('les bornes proposées sont celles du serveur (plus de « Borne 1 à 4 » figées)', (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      srv.tables['kiosks'] = [
        {'id': 'borne-hall', 'name': 'Hall du bâtiment A', 'location': 'RDC', 'status': 'online', 'updated_at': now, 'last_seen_at': now},
      ];
      await tester.pumpWidget(ProviderScope(overrides: [initialAccountProvider.overrideWithValue(admin)], child: const BoutikEcoleApp(initialLocation: '/s/282')));
      await settleReal(tester);
      expect(find.text('Hall du bâtiment A'), findsWidgets);
      expect(find.text('Borne 1'), findsNothing);
      await close(tester);
    });
  });
}

String _dateOf(String iso) => dateCourte(iso);
