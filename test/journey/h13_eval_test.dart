import 'dart:convert';
import 'dart:io';

import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/evaluations.dart';
import 'package:boutik_ecole/figma/live/evaluations_etat.dart';
import 'package:boutik_ecole/figma/live/evaluations_org.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/render.dart';

/// H13 · EVAL : parcours complet du candidat (tous les états : fournisseur non configuré, en attente, acceptée, en cours, terminée, erreur), avancement d'une campagne pour l'organisation
/// et administration (santé du fournisseur sans secret, registre, test d'intégration, journal d'envoi), en mode connecté (faux serveur, `mockupFrame = false`).
/// Serveur muet : aucune affirmation ni zéro ; refus (400) et panne (500) : message du serveur, jamais de confirmation.
final _tokens = jsonDecode(File('tool/maquette_tokens.json').readAsStringSync()) as Map<String, dynamic>;
final _noms = <String>{...(_tokens['personas'] as List).cast<String>(), ...(_tokens['entities'] as List).cast<String>(), ...(_tokens['self'] as List).cast<String>()}.where((e) => e.length >= 4).toList();

String _textes(WidgetTester t) => [for (final w in t.widgetList<Text>(find.byType(Text))) w.data ?? w.textSpan?.toPlainText() ?? ''].join('\n');

List<Map<String, dynamic>> _familles() => [for (var i = 1; i <= 3; i++) {'code': 'famille_$i', 'label': 'Famille de métiers n°$i', 'position': i, 'covered': false}];

Map<String, dynamic> _quota({int active = 1, int used = 0}) => {
      'eligible': true,
      'monthly_free': 1,
      'used': used,
      'remaining': 1 - used,
      'next_reset': '2026-12-31T23:00:00Z',
      'pending': false,
      'active_providers': active,
      'extra': {'available': false, 'price_xaf': null, 'payment_ready': false, 'message': 'Évaluation supplémentaire indisponible : son tarif n’a pas encore été décidé.'},
    };

Map<String, dynamic> _demande(String id, String status, {String? note, String? url, String? result, int attempts = 0, String? provider = 'Fournisseur du banc'}) => {
      'id': id,
      'family_code': 'famille_1',
      'family_label': 'Famille $id',
      'mode': 'ecrit',
      'status': status,
      'funding': 'gratuite_mensuelle',
      'created_at': '2026-11-02T10:00:00Z',
      'status_note': note,
      'candidate_url': url,
      'result_id': result,
      'validation_status': result == null ? null : 'automatique',
      'provider_name': provider,
      'dispatch_attempts': attempts,
    };

Map<String, dynamic> _sante({bool ready = true, List<Map<String, dynamic>>? providers}) => {
      'ready': ready,
      'fresh_hours': 3,
      'providers': providers ?? <Object>[],
      'queue': {'waiting': 2, 'running': 1, 'failed_24h': 3, 'last_event_at': '2026-11-25T09:30:00Z'},
    };

void main() {
  late FakeSupabase srv;
  setUpAll(() async {
    await loadAppFonts();
    srv = await FakeSupabase.start();
    await srv.initSupabase();
  });
  tearDownAll(() => srv.close());

  setUp(() {
    GAnim.enabled = false;
    GScreen.mockupFrame = false;
    srv.unknownIsError = false;
    srv.rpc.clear();
    srv.calls.clear();
    srv.failRpc.clear();
  });
  tearDown(() => GScreen.mockupFrame = true);

  Future<void> monter(WidgetTester t, Widget w) async {
    t.view.physicalSize = const Size(420, 7000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(child: MaterialApp(home: w)));
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

  group('logique des états', () {
    test('phase : issue du statut serveur ; « non configuré » seulement si le serveur l’a dit', () {
      expect(assessmentPhase({'status': 'envoyee'}), AssessmentPhase.waiting);
      expect(assessmentPhase({'status': 'envoyee'}, providerReady: true), AssessmentPhase.waiting);
      expect(assessmentPhase({'status': 'envoyee'}, providerReady: false), AssessmentPhase.notConfigured);
      expect(assessmentPhase({'status': 'acceptee'}, providerReady: false), AssessmentPhase.accepted);
      expect(assessmentPhase({'status': 'en_cours'}), AssessmentPhase.running);
      expect(assessmentPhase({'status': 'terminee'}), AssessmentPhase.done);
      expect(assessmentPhase({'status': 'refusee'}), AssessmentPhase.error);
      expect(assessmentPhase({'status': 'echouee'}), AssessmentPhase.error);
      expect(assessmentPhase({'status': 'paiement_requis'}), AssessmentPhase.unavailable);
      expect(assessmentPhase({'status': 'annulee'}), AssessmentPhase.cancelled);
    });

    test('secrets manquants : noms de variables seulement, jamais de valeur', () {
      expect(assessmentSecretNames('prov_x'), ['ASSESSMENT_PROV_X_BASE_URL', 'ASSESSMENT_PROV_X_API_KEY', 'ASSESSMENT_PROV_X_WEBHOOK_SECRET']);
      expect(assessmentMissingSecrets({'code': 'prov_x', 'has_base_url': true, 'has_api_key': false, 'has_webhook_secret': null}), ['ASSESSMENT_PROV_X_API_KEY', 'ASSESSMENT_PROV_X_WEBHOOK_SECRET']);
      expect(assessmentHealthLine(null), contains('non vérifiée'));
      expect(assessmentHealthLine({'reported': false}), contains('non vérifiée'));
    });
  });

  group('candidat', () {
    testWidgets('serveur muet : erreurs honnêtes, aucun « non configuré » ni quota inventé, lecture de disponibilité silencieuse', (t) async {
      srv.unknownIsError = true;
      await monter(t, const AssessmentsScreen());
      final txt = _textes(t);
      expect(find.text('Réessayer'), findsNWidgets(3));
      expect(txt.contains('non configuré'), isFalse);
      expect(txt.contains('restante'), isFalse);
      expect(RegExp(r'\b0\b').hasMatch(txt), isFalse);
      sansMaquette(t);
      await fin(t);
    });

    testWidgets('fournisseur non configuré : bandeau explicite, demande bloquée, aucun envoi, demande en attente expliquée', (t) async {
      srv.rpc['assessment_families'] = (_) => _familles();
      srv.rpc['assessment_quota'] = (_) => _quota();
      srv.rpc['assessment_provider_readiness'] = (_) => {'ready': false};
      srv.rpc['assessment_my_list'] = (_) => [_demande('r1', 'envoyee')];
      srv.rpc['assessment_request'] = (_) => {'ok': true};
      await monter(t, const AssessmentsScreen());
      expect(find.text('Fournisseur d’évaluation non configuré'), findsOneWidget);
      expect(find.textContaining('Aucun résultat n’est simulé'), findsOneWidget);
      expect(find.textContaining('Fournisseur non configuré : votre demande reste en attente'), findsOneWidget);
      await t.tap(find.text('Famille de métiers n°1'));
      await settleReal(t);
      expect(find.textContaining('Fournisseur non configuré : aucune demande ne peut partir'), findsOneWidget);
      await t.tap(find.text('Questions écrites'));
      await t.tap(find.textContaining('J’accepte que mes réponses'));
      await t.pump();
      await t.tap(find.text('Demander'));
      await settleReal(t);
      expect(srv.callsOf('assessment_request'), isEmpty, reason: 'rien ne part tant que le serveur dit « non configuré »');
      sansMaquette(t);
      await fin(t);
    });

    testWidgets('fournisseur prêt : pas de bandeau ; envoi expliqué (tentatives), fournisseur attribué par le serveur', (t) async {
      srv.rpc['assessment_families'] = (_) => _familles();
      srv.rpc['assessment_quota'] = (_) => _quota();
      srv.rpc['assessment_provider_readiness'] = (_) => {'ready': true};
      srv.rpc['assessment_my_list'] = (_) => [_demande('r1', 'envoyee'), _demande('r2', 'envoyee', attempts: 2)];
      await monter(t, const AssessmentsScreen());
      expect(find.text('Fournisseur d’évaluation non configuré'), findsNothing);
      expect(find.textContaining('Fournisseur non configuré'), findsNothing);
      expect(find.text('Demande enregistrée : le serveur l’envoie au fournisseur attribué.'), findsOneWidget);
      expect(find.text('Le serveur a tenté l’envoi 2 fois sur 5 ; il réessaiera automatiquement.'), findsOneWidget);
      expect(find.text('Fournisseur attribué par le serveur : Fournisseur du banc'), findsNWidgets(2));
      await fin(t);
    });

    testWidgets('tous les états : en attente, acceptée (avec et sans lien), en cours, terminée, erreurs avec message du serveur, paiement requis, annulée', (t) async {
      srv.rpc['assessment_families'] = (_) => _familles();
      srv.rpc['assessment_quota'] = (_) => _quota();
      srv.rpc['assessment_provider_readiness'] = (_) => {'ready': true};
      srv.rpc['assessment_my_list'] = (_) => [
            _demande('r1', 'envoyee'),
            _demande('r2', 'acceptee', url: 'https://passer.exemple.test/e/2'),
            _demande('r3', 'acceptee'),
            _demande('r4', 'en_cours'),
            _demande('r5', 'terminee', result: 'res5'),
            _demande('r6', 'terminee'),
            _demande('r7', 'refusee', note: 'Le fournisseur a refusé : famille non couverte'),
            _demande('r8', 'echouee', note: 'Le fournisseur n’a pas pu être joint après plusieurs tentatives.'),
            _demande('r9', 'echouee'),
            _demande('r10', 'paiement_requis', provider: null),
            _demande('r11', 'annulee'),
          ];
      await monter(t, const AssessmentsScreen());
      expect(find.text('Envoyée · en attente de la réponse du fournisseur'), findsOneWidget);
      expect(find.text('Acceptée par le fournisseur'), findsNWidgets(2));
      expect(find.text('Commencer l’évaluation'), findsOneWidget, reason: 'seulement avec le lien https du fournisseur');
      expect(find.text('Le fournisseur a accepté votre demande : vous pouvez commencer.'), findsOneWidget);
      expect(find.textContaining('n’a pas encore transmis le lien de démarrage'), findsOneWidget);
      expect(find.text('En cours'), findsOneWidget);
      expect(find.textContaining('Le fournisseur traite votre évaluation'), findsOneWidget);
      expect(find.text('Terminée'), findsNWidgets(2));
      expect(find.text('Voir le résultat'), findsOneWidget);
      expect(find.textContaining('aucun résultat n’est encore disponible ici'), findsOneWidget);
      expect(find.text('Le fournisseur a refusé : famille non couverte'), findsOneWidget);
      expect(find.text('Le fournisseur n’a pas pu être joint après plusieurs tentatives.'), findsOneWidget);
      expect(find.text('Le serveur n’a pas transmis de détail sur cette erreur.'), findsOneWidget);
      expect(find.textContaining('Paiement requis'), findsOneWidget);
      expect(find.text('Annulée'), findsOneWidget);
      // fournisseur attribué : jamais pour une demande non envoyée (paiement requis)
      expect(find.text('Fournisseur attribué par le serveur : Fournisseur du banc'), findsNWidgets(10));
      sansMaquette(t);
      await fin(t);
    });

    testWidgets('liste en panne (500) : erreur et Réessayer, aucune demande inventée', (t) async {
      srv.rpc['assessment_families'] = (_) => _familles();
      srv.rpc['assessment_quota'] = (_) => _quota();
      srv.failRpc.add('assessment_my_list');
      await monter(t, const AssessmentsScreen());
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('Aucune évaluation pour le moment.'), findsNothing);
      await fin(t);
    });

    testWidgets('demande : refus (400) puis panne (500) = message, feuille ouverte, aucune confirmation', (t) async {
      srv.rpc['assessment_families'] = (_) => _familles();
      srv.rpc['assessment_quota'] = (_) => _quota();
      srv.rpc['assessment_my_list'] = (_) => <Object>[];
      srv.rpc['assessment_provider_readiness'] = (_) => {'ready': true};
      srv.rpc['assessment_request'] = (_) => throw const FakeRpcError('Accès refusé : les évaluations sont réservées aux candidats.');
      await monter(t, const AssessmentsScreen());
      await t.tap(find.text('Famille de métiers n°2'));
      await settleReal(t);
      await t.tap(find.text('Questions écrites'));
      await t.tap(find.textContaining('J’accepte que mes réponses'));
      await t.pump();
      await t.tap(find.text('Demander'));
      await settleReal(t);
      expect(srv.callsOf('assessment_request'), hasLength(1));
      expect(find.textContaining('Accès refusé'), findsOneWidget);
      srv.rpc.remove('assessment_request');
      srv.failRpc.add('assessment_request');
      await t.tap(find.text('Demander'));
      await settleReal(t);
      expect(srv.callsOf('assessment_request'), hasLength(2));
      expect(find.text('Demander'), findsOneWidget, reason: 'feuille toujours ouverte');
      expect(find.textContaining('Demande enregistrée'), findsNothing);
      expect(find.textContaining('Demande envoyée'), findsNothing);
      await fin(t);
    });

    testWidgets('contestation en panne (500) : pas de confirmation ; résultat du serveur avec preuves', (t) async {
      srv.rpc['assessment_families'] = (_) => _familles();
      srv.rpc['assessment_quota'] = (_) => _quota();
      srv.rpc['assessment_my_list'] = (_) => [_demande('r5', 'terminee', result: 'res5')];
      srv.rpc['assessment_result'] = (_) => {
            'id': 'res5',
            'competences': [{'name': 'Usinage'}],
            'criteria': [{'name': 'Précision'}],
            'evidence': [{'kind': 'Rapport du fournisseur'}],
            'limits': 'Évaluation à distance.',
            'recommendations': <Object>[],
            'validation_status': 'automatique',
            'dispute_possible': true,
            'disputes': <Object>[],
          };
      srv.failRpc.add('assessment_dispute');
      await monter(t, const AssessmentsScreen());
      await t.tap(find.text('Voir le résultat'));
      await settleReal(t);
      expect(find.text('Preuves'), findsOneWidget);
      expect(find.text('• Rapport du fournisseur'), findsOneWidget);
      await t.tap(find.text('Contester ce résultat'));
      await settleReal(t);
      await t.enterText(find.byType(TextField), 'Le résultat ne reflète pas mon travail.');
      await t.tap(find.text('Envoyer'));
      await settleReal(t);
      expect(srv.callsOf('assessment_dispute'), hasLength(1));
      expect(find.text('Contestation envoyée. Le résultat sera réexaminé.'), findsNothing);
      await fin(t);
    });
  });

  group('organisation', () {
    Map<String, dynamic> campagne({String status = 'ouverte'}) => {
          'id': 'c1',
          'title': 'Recrutement',
          'family_code': 'compta',
          'family_label': 'Comptabilité et finance',
          'mode': 'etude_cas',
          'status': status,
          'created_at': '2026-11-20T10:00:00Z',
          'invited': 3,
          'shared_results': 1,
        };

    testWidgets('avancement du serveur : compteurs et fournisseur non configuré dit clairement', (t) async {
      srv.rpc['assessment_campaigns_list'] = (_) => [campagne()];
      srv.rpc['assessment_campaign_progress'] = (_) => {'campaign_id': 'c1', 'status': 'ouverte', 'invited': 3, 'waiting': 1, 'running': 1, 'done': 1, 'error': 0, 'reused': 2, 'provider_ready': false};
      await monter(t, const AssessmentCampaignsOrgScreen());
      expect(find.textContaining('1 en attente · 1 en cours · 1 terminée(s) · 0 en erreur'), findsOneWidget);
      expect(find.text('Évaluations existantes partagées : 2'), findsOneWidget);
      expect(find.textContaining('Fournisseur non configuré pour cette campagne'), findsOneWidget);
      expect(srv.callsOf('assessment_campaign_progress').single.args, containsPair('p_campaign', 'c1'));
      sansMaquette(t);
      await fin(t);
    });

    testWidgets('avancement : fournisseur prêt = aucun avertissement ; campagne en attente de financement = aucun avertissement', (t) async {
      srv.rpc['assessment_campaigns_list'] = (_) => [campagne(), campagne(status: 'en_attente_financement')..['id'] = 'c2'];
      srv.rpc['assessment_campaign_progress'] = (a) => {'status': a['p_campaign'] == 'c1' ? 'ouverte' : 'en_attente_financement', 'waiting': 0, 'running': 0, 'done': 0, 'error': 0, 'reused': 0, 'provider_ready': a['p_campaign'] == 'c1'};
      await monter(t, const AssessmentCampaignsOrgScreen());
      expect(find.textContaining('Fournisseur non configuré'), findsNothing);
      await fin(t);
    });

    testWidgets('avancement en panne (500) : « indisponible », jamais un zéro', (t) async {
      srv.rpc['assessment_campaigns_list'] = (_) => [campagne()];
      srv.failRpc.add('assessment_campaign_progress');
      await monter(t, const AssessmentCampaignsOrgScreen());
      expect(find.textContaining('Avancement indisponible'), findsOneWidget);
      expect(find.textContaining('en attente ·'), findsNothing);
      await fin(t);
    });
  });

  group('administration', () {
    Map<String, dynamic> fournisseur({String code = 'prov_x', String status = 'candidat'}) =>
        {'code': code, 'name': 'Fournisseur X', 'status': status, 'family_codes': ['famille_1'], 'modes': ['ecrit'], 'activated_at': null, 'last_test': null};

    testWidgets('santé : indicateur, file, secrets manquants (noms seulement), aucun secret affiché', (t) async {
      srv.rpc['assessment_providers_admin_list'] = (_) => [fournisseur(status: 'actif'), fournisseur(code: 'prov_y')];
      srv.rpc['assessment_provider_readiness'] = (_) => _sante(ready: false, providers: [
            {'code': 'prov_x', 'name': 'Fournisseur X', 'status': 'actif', 'reported': true, 'has_base_url': true, 'has_api_key': false, 'has_webhook_secret': true, 'configured': false, 'checked_at': '2026-11-25T09:00:00Z', 'stale': false},
            {'code': 'prov_y', 'name': 'Fournisseur Y', 'status': 'candidat', 'reported': false, 'has_base_url': null, 'has_api_key': null, 'has_webhook_secret': null, 'configured': null, 'checked_at': null, 'stale': false},
          ]);
      await monter(t, const AssessmentProvidersAdminScreen());
      expect(find.text('Envoi impossible : aucun fournisseur actif et configuré'), findsOneWidget);
      expect(find.textContaining('2 en attente · 1 en cours · 3 échec(s) sur 24 h'), findsOneWidget);
      expect(find.textContaining('il manque ASSESSMENT_PROV_X_API_KEY'), findsOneWidget);
      expect(find.textContaining('non vérifiée (aucun rapport de la fonction d’envoi)'), findsOneWidget);
      expect(find.text('Journal d’envoi'), findsOneWidget);
      expect(find.text('Validation humaine et contestations'), findsOneWidget);
      sansMaquette(t);
      await fin(t);
    });

    testWidgets('santé : configuration complète = envoi possible ; rapport ancien signalé', (t) async {
      srv.rpc['assessment_providers_admin_list'] = (_) => [fournisseur(status: 'actif')];
      srv.rpc['assessment_provider_readiness'] = (_) => _sante(providers: [
            {'code': 'prov_x', 'name': 'Fournisseur X', 'status': 'actif', 'reported': true, 'has_base_url': true, 'has_api_key': true, 'has_webhook_secret': true, 'configured': true, 'checked_at': '2026-11-25T01:00:00Z', 'stale': true},
          ]);
      await monter(t, const AssessmentProvidersAdminScreen());
      expect(find.text('Envoi possible : un fournisseur actif est configuré'), findsOneWidget);
      expect(find.textContaining('complète (URL, clé et secret de rappel présents)'), findsOneWidget);
      expect(find.textContaining('rapport ancien, à revérifier'), findsOneWidget);
      await fin(t);
    });

    testWidgets('santé illisible (serveur muet) : erreur dite, le registre reste utilisable, rien n’est affirmé', (t) async {
      srv.rpc['assessment_providers_admin_list'] = (_) => [fournisseur()];
      srv.failRpc.add('assessment_provider_readiness');
      await monter(t, const AssessmentProvidersAdminScreen());
      expect(find.text('Envoi possible : un fournisseur actif est configuré'), findsNothing);
      expect(find.text('Envoi impossible : aucun fournisseur actif et configuré'), findsNothing);
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('Activer'), findsOneWidget);
      expect(find.textContaining('non vérifiée'), findsOneWidget);
      await fin(t);
    });

    testWidgets('test d’intégration : arguments exacts ; refus du serveur affiché sans confirmation', (t) async {
      srv.rpc['assessment_providers_admin_list'] = (_) => [fournisseur()];
      srv.rpc['assessment_provider_readiness'] = (_) => _sante(providers: <Map<String, dynamic>>[]);
      srv.rpc['assessment_provider_record_test'] = (_) => throw const FakeRpcError('Réservé à l’administrateur global');
      await monter(t, const AssessmentProvidersAdminScreen());
      await t.tap(find.text('Enregistrer un test d’intégration'));
      await settleReal(t);
      await t.tap(find.text('Test réussi'));
      await t.enterText(find.byType(TextField), 'HTTP 200 en bac à sable');
      await t.pump();
      await t.tap(find.text('Enregistrer'));
      await settleReal(t);
      final a = srv.callsOf('assessment_provider_record_test').single.args;
      expect(a, containsPair('p_code', 'prov_x'));
      expect(a, containsPair('p_ok', true));
      expect(a, containsPair('p_note', 'HTTP 200 en bac à sable'));
      expect(find.textContaining('Réservé à l’administrateur global'), findsWidgets);
      expect(find.text('Test d’intégration enregistré.'), findsNothing);
      await fin(t);
    });

    testWidgets('enregistrement d’un fournisseur : champs exigés, arguments exacts, refus (500) sans confirmation', (t) async {
      srv.rpc['assessment_providers_admin_list'] = (_) => <Object>[];
      srv.rpc['assessment_provider_readiness'] = (_) => _sante(providers: <Map<String, dynamic>>[]);
      srv.rpc['assessment_families'] = (_) => _familles();
      srv.failRpc.add('assessment_provider_register');
      await monter(t, const AssessmentProvidersAdminScreen());
      await t.tap(find.text('Enregistrer un fournisseur'));
      await settleReal(t);
      await t.tap(find.text('Enregistrer'));
      await settleReal(t);
      expect(srv.callsOf('assessment_provider_register'), isEmpty, reason: 'code, nom, mode et famille exigés');
      await t.enterText(find.byType(TextField).at(0), 'Prov_Test');
      await t.enterText(find.byType(TextField).at(1), 'Fournisseur de test');
      await t.tap(find.text('Questions écrites'));
      await t.tap(find.text('Famille de métiers n°2'));
      await t.pump();
      await t.tap(find.text('Enregistrer'));
      await settleReal(t);
      final a = srv.callsOf('assessment_provider_register').single.args;
      expect(a, containsPair('p_code', 'prov_test'));
      expect(a, containsPair('p_name', 'Fournisseur de test'));
      expect(a['p_modes'], ['ecrit']);
      expect(a['p_families'], ['famille_2']);
      expect(find.text('Enregistrer un fournisseur'), findsWidgets);
      expect(find.textContaining('Fournisseur enregistré'), findsNothing);
      await fin(t);
    });

    testWidgets('journal d’envoi : événements du serveur ; refus pour une autre équipe, jamais un journal vide', (t) async {
      srv.rpc['assessment_providers_admin_list'] = (_) => <Object>[];
      srv.rpc['assessment_provider_readiness'] = (_) => _sante(providers: <Map<String, dynamic>>[]);
      srv.rpc['assessment_dispatch_log_admin'] = (_) => [
            {'id': 3, 'request_id': 'aaaaaaaa-1111-4111-8111-111111111111', 'provider': 'prov_x', 'event': 'failed', 'http_status': 503, 'detail': 'HTTP 503', 'at': '2026-11-25T09:30:00Z'},
            {'id': 2, 'request_id': 'aaaaaaaa-1111-4111-8111-111111111111', 'provider': 'prov_x', 'event': 'claimed', 'http_status': null, 'detail': null, 'at': '2026-11-25T09:29:00Z'},
          ];
      await monter(t, const AssessmentProvidersAdminScreen());
      await t.tap(find.text('Journal d’envoi'));
      await settleReal(t);
      expect(srv.callsOf('assessment_dispatch_log_admin').single.args, containsPair('p_limit', 100));
      expect(find.text('Échec · prov_x'), findsOneWidget);
      expect(find.text('Envoi tenté · prov_x'), findsOneWidget);
      expect(find.textContaining('HTTP 503 · HTTP 503'), findsOneWidget);
      await t.tap(find.text('Fermer'));
      await settleReal(t);

      srv.rpc['assessment_dispatch_log_admin'] = (_) => throw const FakeRpcError('Réservé à l’administrateur global', status: 403, code: '42501');
      await t.tap(find.text('Journal d’envoi'));
      await settleReal(t);
      expect(find.textContaining('Réservé à l’administrateur global'), findsWidgets);
      expect(find.text('Aucun envoi journalisé pour le moment.'), findsNothing);
      await fin(t);
    });

    testWidgets('journal vide : dit vide', (t) async {
      srv.rpc['assessment_providers_admin_list'] = (_) => <Object>[];
      srv.rpc['assessment_provider_readiness'] = (_) => _sante(providers: <Map<String, dynamic>>[]);
      srv.rpc['assessment_dispatch_log_admin'] = (_) => <Object>[];
      await monter(t, const AssessmentProvidersAdminScreen());
      await t.tap(find.text('Journal d’envoi'));
      await settleReal(t);
      expect(find.text('Aucun envoi journalisé pour le moment.'), findsOneWidget);
      await fin(t);
    });
  });
}
