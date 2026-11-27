import 'dart:convert';
import 'dart:io';

import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/admin_centre.dart' show AdminTeamScreen;
import 'package:boutik_ecole/figma/live/admin_exports.dart';
import 'package:boutik_ecole/figma/live/admin_sante.dart';
import 'package:boutik_ecole/figma/live/auth.dart' show Account, initialAccountProvider;
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/render.dart';

/// H13 · ADMIN : santé des services (tuile de la console technique) et exports CSV serveur (journal d'audit, file des rattachements, contestations de score), en mode connecté (faux serveur).
/// Serveur muet / refus / panne : message honnête, aucun état « en service » ni zéro inventé, aucun fichier ; succès : le CSV du serveur (avec BOM) part dans le presse-papiers (hors navigateur).
/// Le comportement serveur (permission, journal, plafond, limite de débit) est prouvé par supabase/tests/marketplace_pglite/h13_audit.mjs.
final _tokens = jsonDecode(File('tool/maquette_tokens.json').readAsStringSync()) as Map<String, dynamic>;
final _noms = <String>{...(_tokens['personas'] as List).cast<String>(), ...(_tokens['entities'] as List).cast<String>(), ...(_tokens['self'] as List).cast<String>()}.where((e) => e.length >= 4).toList();

String _textes(WidgetTester t) => [for (final w in t.widgetList<m.Text>(find.byType(m.Text))) w.data ?? w.textSpan?.toPlainText() ?? ''].join('\n');

Map<String, dynamic> _service(String code, String label, String status, {String detail = '', Map<String, dynamic>? metrics, String? last}) =>
    {'code': code, 'label': label, 'status': status, 'detail': detail, 'last_event_at': last, 'metrics': metrics ?? <String, dynamic>{}};

Map<String, dynamic> _sante(List<Map<String, dynamic>> services) => {'generated_at': '2026-11-26T08:00:00Z', 'counts': <String, dynamic>{}, 'services': services};

void main() {
  late FakeSupabase srv;
  final presse = <String>[];
  setUpAll(() async {
    await loadAppFonts();
    srv = await FakeSupabase.start();
    await srv.initSupabase();
  });
  tearDownAll(() => srv.close());

  setUp(() {
    GAnim.enabled = false;
    GScreen.mockupFrame = false;
    Backend.ready = true;
    srv.unknownIsError = false;
    srv.rpc.clear();
    srv.calls.clear();
    srv.failRpc.clear();
    presse.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') presse.add((call.arguments as Map)['text'] as String);
      return null;
    });
  });
  tearDown(() {
    GScreen.mockupFrame = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> monter(WidgetTester t, Widget w) async {
    t.view.physicalSize = const Size(420, 5000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: w)))));
    await settleReal(t, rounds: 20);
  }

  Future<void> fin(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 20));
  }

  void sansMaquette(WidgetTester t) {
    final txt = _textes(t);
    for (final n in _noms) {
      expect(txt.contains(n), isFalse, reason: 'jeton de maquette « $n »');
    }
    expect(txt.contains('9:41'), isFalse);
    expect(t.takeException(), isNull);
  }

  group('logique', () {
    test('statut hors vocabulaire = Inconnu, jamais « En service »', () {
      expect(healthStatusLabel('ok'), 'En service');
      expect(healthStatusLabel('degrade'), 'Dégradé');
      expect(healthStatusLabel('erreur'), 'En erreur');
      expect(healthStatusLabel('non_configure'), 'Non configuré');
      expect(healthStatusLabel('inconnu'), 'Inconnu');
      expect(healthStatusLabel('fonctionne'), 'Inconnu');
      expect(healthStatusLabel(null), 'Inconnu');
    });

    test('mesures : null = « inconnu » (jamais 0), nombre = valeur, clé inconnue ignorée', () {
      final s = ServiceHealth(code: 'x', label: 'X', status: 'inconnu', detail: '', metrics: const {'failed_24h': null, 'sent_24h': 0, 'queued': 3, 'secret': 'abc', 'enabled': true});
      expect(healthMetricLines(s), [('Échecs (24 h)', 'inconnu'), ('Envoyés (24 h)', '0'), ('En attente', '3')]);
    });

    test('réponse du serveur : forme inattendue = aucun état affirmé', () {
      expect(parseServiceHealth(null), isNull);
      expect(parseServiceHealth([]), isNull);
      expect(parseServiceHealth({'services': 'x'}), isNull);
      expect(parseServiceHealth({'services': [1]}), isNull);
      final ok = parseServiceHealth(_sante([_service('payments', 'Paiements', 'inconnu', metrics: {'events_total': null})]))!;
      expect(ok.single.status, 'inconnu');
      expect(ok.single.metrics['events_total'], isNull);
      expect(parseServiceHealth({'services': [{'code': 'a'}]})!.single.status, 'inconnu', reason: 'statut absent = inconnu');
    });

    test('export : forme inattendue = pas de fichier ; messages exacts', () {
      expect(parseAdminCsv(null), isNull);
      expect(parseAdminCsv({'csv': '', 'filename': 'a.csv', 'rows': 0, 'kind': 'audit'}), isNull);
      expect(parseAdminCsv({'csv': 'x', 'filename': 'a.csv', 'rows': 'deux', 'kind': 'audit'}), isNull);
      final f = parseAdminCsv({'csv': '"A"\r\n', 'filename': 'journal-audit.csv', 'rows': 0, 'kind': 'audit', 'truncated': false})!;
      expect(adminCsvMessage(f, downloaded: true), 'Aucune ligne à exporter : fichier vide créé (en-têtes seulement)');
      final g = parseAdminCsv({'csv': '"A"\r\n"1"\r\n', 'filename': 'x.csv', 'rows': 1, 'kind': 'audit'})!;
      expect(adminCsvMessage(g, downloaded: false), '1 ligne exportée (copié dans le presse-papiers)');
      final h = parseAdminCsv({'csv': 'x', 'filename': 'x.csv', 'rows': 5000, 'kind': 'audit', 'truncated': true})!;
      expect(adminCsvMessage(h, downloaded: true), 'Export limité aux 5 000 premières lignes (x.csv) : affinez les filtres');
      expect(adminCsvMessage(parseAdminCsv({'csv': 'x', 'filename': 'x.csv', 'rows': 12, 'kind': 'audit'})!, downloaded: true), '12 lignes exportées (x.csv)');
      expect(kAdminCsvKinds, {'audit', 'rattachements', 'contestations'});
    });
  });

  group('santé des services', () {
    testWidgets('serveur muet : erreur honnête avec « Réessayer », aucun état « En service » ni zéro', (t) async {
      srv.unknownIsError = true;
      await monter(t, const ServiceHealthSection());
      expect(find.text('Santé des services'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
      final txt = _textes(t);
      expect(txt.contains('En service'), isFalse);
      expect(RegExp(r'\b0\b').hasMatch(txt), isFalse);
      sansMaquette(t);
      await fin(t);
    });

    testWidgets('refus du serveur (permission) : le message du serveur, pas de liste', (t) async {
      srv.rpc['admin_service_health'] = (_) => throw const FakeRpcError('Réservé : exige une permission technique (tech.config, tech.maintenance, tech.logs ou tech.integrations)');
      await monter(t, const ServiceHealthSection());
      expect(find.textContaining('Réservé : exige une permission technique'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('En service'), findsNothing);
      await fin(t);
    });

    testWidgets('panne serveur (500) : erreur, jamais un tableau vide ni « En service »', (t) async {
      srv.failRpc.add('admin_service_health');
      await monter(t, const ServiceHealthSection());
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('En service'), findsNothing);
      await fin(t);
    });

    testWidgets('forme inattendue : erreur, aucun état affirmé', (t) async {
      srv.rpc['admin_service_health'] = (_) => {'services': 'oui'};
      await monter(t, const ServiceHealthSection());
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('En service'), findsNothing);
      await fin(t);
    });

    testWidgets('tous les états : en service, dégradé, erreur, non configuré, inconnu (mesures null = « inconnu », jamais 0)', (t) async {
      srv.rpc['admin_service_health'] = (_) => _sante([
            _service('database', 'Base de données', 'ok', detail: 'Le serveur a répondu à cette requête.'),
            _service('notifications', 'Envoi des notifications', 'degrade', detail: 'Des envois ont échoué dans les dernières 24 h.', metrics: {'queued': 2, 'failed_24h': 1, 'sent_24h': 9, 'oldest_queued_minutes': null}, last: '2026-11-26T07:30:00Z'),
            _service('integrations', 'Connexions externes (profils)', 'erreur', detail: 'Toutes les synchronisations des dernières 24 h ont échoué.', metrics: {'failed_24h': 4, 'ok_24h': 0}),
            _service('live_recording', 'Enregistrement des lives', 'non_configure', detail: 'L’enregistrement des lives est désactivé.', metrics: {'enabled': false, 'failed_24h': null, 'ready_7d': null}),
            _service('payments', 'Paiements (rappels du prestataire)', 'inconnu', detail: 'Aucun événement de paiement reçu : ni preuve de bon fonctionnement, ni panne constatée.', metrics: {'events_total': null, 'events_24h': null}),
            _service('backups', 'Sauvegardes', 'bizarre', detail: 'Non mesurable depuis la base : consulter le tableau de bord du fournisseur.'),
          ]);
      await monter(t, const ServiceHealthSection());
      expect(find.text('En service'), findsOneWidget);
      expect(find.text('Dégradé'), findsOneWidget);
      expect(find.text('En erreur'), findsOneWidget);
      expect(find.text('Non configuré'), findsOneWidget);
      expect(find.text('Inconnu'), findsNWidgets(2), reason: 'un inconnu réel + un statut hors vocabulaire');
      expect(find.text('Échecs (24 h) : inconnu'), findsOneWidget);
      expect(find.text('Événements reçus : inconnu'), findsOneWidget);
      expect(find.text('Réussis (7 jours) : inconnu'), findsOneWidget);
      expect(find.text('En attente : 2'), findsOneWidget);
      expect(find.text('Réussies (24 h) : 0'), findsOneWidget, reason: 'un zéro MESURÉ par le serveur reste affiché');
      expect(find.text('Plus ancien en attente (min) : inconnu'), findsOneWidget, reason: 'mesure null = ligne « inconnu », jamais 0');
      expect(find.textContaining('Dernier événement'), findsOneWidget);
      expect(find.textContaining('Aucun événement de paiement reçu'), findsOneWidget);
      sansMaquette(t);
      await fin(t);
    });
  });

  group('console technique : tuile « Santé des services »', () {
    Future<void> console(WidgetTester t, String team, Map<String, dynamic> acces) async {
      srv.rpc['my_admin_access'] = (_) => acces;
      srv.rpc['admin_team_dashboard'] = (_) => {'counters': <Object>[]};
      t.view.physicalSize = const Size(420, 5000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final compte = Account(name: 'Compte Test', phone: '690000999', email: 'admin.test@example.test', password: '', role: 0, staff: 'Support', institution: 'Plateforme', serverId: FakeSupabase.userId);
      await t.pumpWidget(ProviderScope(overrides: [initialAccountProvider.overrideWithValue(compte)], child: MaterialApp(home: AdminTeamScreen(team: team))));
      await settleReal(t, rounds: 20);
    }

    testWidgets('permission technique : la tuile est là et lit admin_service_health', (t) async {
      srv.rpc['admin_service_health'] = (_) => _sante([_service('database', 'Base de données', 'ok', detail: 'Le serveur a répondu à cette requête.')]);
      await console(t, 'tech', {'role': 'support', 'is_admin': false, 'teams': {'tech': ['tech.logs']}});
      expect(find.text('Santé des services'), findsOneWidget);
      expect(find.text('Base de données'), findsOneWidget);
      expect(srv.callsOf('admin_service_health'), hasLength(1));
      await fin(t);
    });

    testWidgets('administrateur global : la tuile est là', (t) async {
      srv.rpc['admin_service_health'] = (_) => _sante([_service('backups', 'Sauvegardes', 'inconnu')]);
      await console(t, 'tech', {'role': 'admin', 'is_admin': true, 'teams': <String, dynamic>{}});
      expect(find.text('Santé des services'), findsOneWidget);
      expect(find.text('Inconnu'), findsOneWidget);
      await fin(t);
    });

    testWidgets('équipe technique sans permission (droits minimaux) : pas de tuile, aucun appel', (t) async {
      await console(t, 'tech', {'role': 'support', 'is_admin': false, 'teams': {'tech': <String>[]}});
      expect(find.text('Santé des services'), findsNothing);
      expect(srv.callsOf('admin_service_health'), isEmpty);
      await fin(t);
    });

    testWidgets('autre équipe (sécurité) : pas de tuile, aucun appel', (t) async {
      await console(t, 'security', {'role': 'support', 'is_admin': false, 'teams': {'security': ['security.audit']}});
      expect(find.text('Santé des services'), findsNothing);
      expect(srv.callsOf('admin_service_health'), isEmpty);
      await fin(t);
    });
  });

  group('exports CSV', () {
    Future<void> monterBoutons(WidgetTester t) async {
      t.view.physicalSize = const Size(420, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (c) => Column(children: [
                TextButton(onPressed: () => exportAdminCsv(c, 'contestations', filters: {'status': 'open'}), child: const m.Text('bouton-contestations')),
                TextButton(onPressed: () => exportAdminCsv(c, 'audit', filters: {'categories': ['Comptes'], 'q': 'x'}), child: const m.Text('bouton-audit')),
                TextButton(onPressed: () => exportAdminCsv(c, 'rattachements'), child: const m.Text('bouton-rattachements')),
              ]),
            ),
          ),
        ),
      ));
      await settleReal(t);
    }

    testWidgets('succès : le serveur reçoit le genre et les filtres ; le CSV (BOM + en-têtes) part dans le presse-papiers ; message avec le nombre de lignes du serveur', (t) async {
      srv.rpc['admin_export_csv'] = (a) => {
            'kind': a['p_kind'],
            'filename': 'contestations-score.csv',
            'rows': 2,
            'truncated': false,
            'csv': '"Date";"Étudiant"\r\n"2026-11-26 06:44";"Sandra C."\r\n"2026-11-26 06:45";"Paul D."\r\n',
          };
      await monterBoutons(t);
      await t.tap(find.text('bouton-contestations'));
      await settleReal(t);
      final call = srv.callsOf('admin_export_csv').single;
      expect(call.args['p_kind'], 'contestations');
      expect(call.args['p_filters'], {'status': 'open'});
      expect(presse.single, startsWith('\uFEFF"Date";"Étudiant"'));
      expect(find.textContaining('2 lignes exportées (copié dans le presse-papiers)'), findsOneWidget);
      await fin(t);
    });

    testWidgets('journal d’audit : les catégories et la recherche de l’écran sont transmises au serveur', (t) async {
      srv.rpc['admin_export_csv'] = (a) => {'kind': 'audit', 'filename': 'journal-audit.csv', 'rows': 1, 'truncated': true, 'csv': '"Date"\r\n"x"\r\n'};
      await monterBoutons(t);
      await t.tap(find.text('bouton-audit'));
      await settleReal(t);
      expect(srv.callsOf('admin_export_csv').single.args['p_filters'], {'categories': ['Comptes'], 'q': 'x'});
      expect(find.textContaining('Export limité aux 5 000 premières lignes (copié dans le presse-papiers)'), findsOneWidget);
      await fin(t);
    });

    testWidgets('liste vide : fichier d’en-têtes dit « vide », jamais une confirmation de lignes', (t) async {
      srv.rpc['admin_export_csv'] = (a) => {'kind': 'rattachements', 'filename': 'rattachements-departements.csv', 'rows': 0, 'truncated': false, 'csv': '"Nom";"E-mail"\r\n'};
      await monterBoutons(t);
      await t.tap(find.text('bouton-rattachements'));
      await settleReal(t);
      expect(find.textContaining('Aucune ligne à exporter'), findsOneWidget);
      expect(find.textContaining('0 ligne'), findsNothing);
      await fin(t);
    });

    testWidgets('refus du serveur (permission) : message du serveur, aucun fichier', (t) async {
      srv.rpc['admin_export_csv'] = (_) => throw const FakeRpcError('Réservé : exige la permission ranking.moderate');
      await monterBoutons(t);
      await t.tap(find.text('bouton-contestations'));
      await settleReal(t);
      expect(find.textContaining('Réservé : exige la permission ranking.moderate'), findsOneWidget);
      expect(presse, isEmpty);
      expect(find.textContaining('exportée'), findsNothing);
      await fin(t);
    });

    testWidgets('limite de débit atteinte : message du serveur, aucun fichier', (t) async {
      srv.rpc['admin_export_csv'] = (_) => throw const FakeRpcError('Trop de requêtes : réessayez dans un instant', code: 'P0429');
      await monterBoutons(t);
      await t.tap(find.text('bouton-audit'));
      await settleReal(t);
      expect(find.textContaining('Trop de requêtes'), findsOneWidget);
      expect(presse, isEmpty);
      await fin(t);
    });

    testWidgets('panne serveur (500) et réponse inattendue : aucun fichier, aucune confirmation', (t) async {
      srv.failRpc.add('admin_export_csv');
      await monterBoutons(t);
      await t.tap(find.text('bouton-audit'));
      await settleReal(t);
      expect(presse, isEmpty);
      expect(find.textContaining('exportée'), findsNothing);
      await t.pump(const Duration(seconds: 8));
      await t.pump(const Duration(seconds: 1));
      srv.failRpc.clear();
      srv.rpc['admin_export_csv'] = (_) => {'csv': 12};
      await t.tap(find.text('bouton-audit'));
      await settleReal(t);
      await t.pump(const Duration(seconds: 1));
      expect(find.textContaining('Réponse inattendue du serveur : aucun fichier créé.'), findsOneWidget);
      expect(presse, isEmpty);
      await fin(t);
    });

    testWidgets('double appui : un seul appel au serveur tant que l’export est en cours', (t) async {
      srv.rpc['admin_export_csv'] = (a) => {'kind': 'audit', 'filename': 'journal-audit.csv', 'rows': 1, 'truncated': false, 'csv': '"Date"\r\n"x"\r\n'};
      await monterBoutons(t);
      await t.tap(find.text('bouton-audit'));
      await t.tap(find.text('bouton-audit'));
      await settleReal(t);
      expect(srv.callsOf('admin_export_csv'), hasLength(1));
      await fin(t);
    });

    testWidgets('hors connexion : aucun appel, message clair', (t) async {
      Backend.ready = false;
      await monterBoutons(t);
      await t.tap(find.text('bouton-audit'));
      await settleReal(t);
      expect(srv.callsOf('admin_export_csv'), isEmpty);
      expect(find.textContaining('Connectez-vous avec un compte autorisé'), findsOneWidget);
      await fin(t);
    });
  });
}
