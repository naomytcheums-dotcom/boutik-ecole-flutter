import 'dart:convert';
import 'dart:io';

import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/evaluations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/render.dart';

/// H9 · EVAL : écrans « Évaluations » (étudiant) et « Fournisseurs d'évaluation » (administration), en mode connecté (`Backend.ready`, faux serveur, `mockupFrame = false`).
/// Le serveur est le seul porteur des données : muet, il ne donne ni zéro ni quota ; vide, il ne donne ni résultat, ni score, ni fournisseur, ni prix.
final _tokens = jsonDecode(File('tool/maquette_tokens.json').readAsStringSync()) as Map<String, dynamic>;
final _noms = <String>{...(_tokens['personas'] as List).cast<String>(), ...(_tokens['entities'] as List).cast<String>(), ...(_tokens['self'] as List).cast<String>()}.where((e) => e.length >= 4).toList();

List<Map<String, dynamic>> _familles() => [for (var i = 1; i <= 33; i++) {'code': 'famille_$i', 'label': 'Famille de métiers n°$i', 'position': i, 'covered': false}];

Map<String, dynamic> _quota({int active = 0, int used = 0, Object? price}) => {
      'eligible': true,
      'monthly_free': 1,
      'used': used,
      'remaining': 1 - used,
      'next_reset': '2026-12-31T23:00:00Z',
      'pending': false,
      'active_providers': active,
      'extra': {
        'available': price != null,
        'price_xaf': price,
        'payment_ready': false,
        'message': price == null ? 'Évaluation supplémentaire indisponible : son tarif n’a pas encore été décidé.' : 'Évaluation supplémentaire : $price FCFA, annoncés avant toute confirmation.',
      },
    };

String _tousLesTextes(WidgetTester t) => [for (final w in t.widgetList<Text>(find.byType(Text))) w.data ?? w.textSpan?.toPlainText() ?? ''].join('\n');

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
  });
  tearDown(() => GScreen.mockupFrame = true);

  Future<void> monter(WidgetTester t, Widget w) async {
    t.view.physicalSize = const Size(420, 5200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(child: MaterialApp(home: w)));
    await settleReal(t, rounds: 20);
  }

  Future<void> fin(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 20));
  }

  void verifierSansMaquette(WidgetTester t) {
    final txt = _tousLesTextes(t);
    for (final n in _noms) {
      expect(txt.contains(n), isFalse, reason: 'jeton de maquette « $n »');
    }
    expect(txt.contains('9:41'), isFalse);
    expect(t.takeException(), isNull);
  }

  testWidgets('serveur muet : erreurs honnêtes, aucun zéro, aucun quota, aucune famille inventée', (t) async {
    srv.unknownIsError = true;
    await monter(t, const AssessmentsScreen());
    final txt = _tousLesTextes(t);
    expect(find.text('Réessayer'), findsNWidgets(3));
    expect(txt, contains('n’est pas disponible pour le moment'));
    expect(txt.contains('restante'), isFalse);
    expect(RegExp(r'\b0\b').hasMatch(txt), isFalse, reason: 'une erreur n’est jamais un zéro');
    expect(txt.contains('Aucun fournisseur d’évaluation actif'), isFalse, reason: 'sans lecture du quota, rien n’est affirmé');
    expect(find.textContaining('Famille de métiers'), findsNothing);
    verifierSansMaquette(t);
    await fin(t);
  });

  testWidgets('registre vide : 33 familles du serveur, quota réel, message « aucun fournisseur actif », liste vide', (t) async {
    srv.rpc['assessment_families'] = (_) => _familles();
    srv.rpc['assessment_quota'] = (_) => _quota();
    srv.rpc['assessment_my_list'] = (_) => <Object>[];
    await monter(t, const AssessmentsScreen());
    expect(find.textContaining('Famille de métiers n°'), findsNWidgets(33));
    expect(find.text('1 restante sur 1 ce mois-ci'), findsOneWidget);
    expect(find.text('Aucun fournisseur d’évaluation actif pour le moment'), findsOneWidget);
    expect(find.text('Aucune évaluation pour le moment.'), findsOneWidget);
    expect(find.textContaining('son tarif n’a pas encore été décidé'), findsOneWidget);
    expect(find.text('Fournisseur actif'), findsNothing);
    expect(find.text('Voir le résultat'), findsNothing);
    verifierSansMaquette(t);
    await fin(t);
  });

  testWidgets('quota issu du serveur : 1 utilisée, 0 restante', (t) async {
    srv.rpc['assessment_families'] = (_) => _familles();
    srv.rpc['assessment_quota'] = (_) => _quota(active: 1, used: 1);
    srv.rpc['assessment_my_list'] = (_) => <Object>[];
    await monter(t, const AssessmentsScreen());
    expect(find.text('0 restante sur 1 ce mois-ci'), findsOneWidget);
    expect(find.textContaining('Utilisée : 1'), findsOneWidget);
    expect(find.text('Aucun fournisseur d’évaluation actif pour le moment'), findsNothing);
    await fin(t);
  });

  testWidgets('demande refusée par le serveur : message du serveur, rien d’inventé ; consentement et mode exigés', (t) async {
    srv.rpc['assessment_families'] = (_) => _familles();
    srv.rpc['assessment_quota'] = (_) => _quota();
    srv.rpc['assessment_my_list'] = (_) => <Object>[];
    srv.rpc['assessment_request'] = (_) => {'ok': false, 'code': 'no_provider', 'message': 'Aucun fournisseur actif pour cette famille et ce mode : votre demande n’est pas enregistrée.'};
    await monter(t, const AssessmentsScreen());
    await t.tap(find.text('Famille de métiers n°3'));
    await settleReal(t);
    expect(find.text('Demander'), findsOneWidget);
    await t.tap(find.text('Demander'));
    await settleReal(t);
    expect(srv.callsOf('assessment_request'), isEmpty, reason: 'ni mode ni consentement : aucun envoi');
    await t.tap(find.text('Simulation professionnelle'));
    await t.tap(find.textContaining('J’accepte que mes réponses'));
    await t.pump();
    await t.tap(find.text('Demander'));
    await settleReal(t);
    final c = srv.callsOf('assessment_request');
    expect(c, hasLength(1));
    expect(c.single.args, containsPair('p_family', 'famille_3'));
    expect(c.single.args, containsPair('p_mode', 'simulation'));
    expect(c.single.args, containsPair('p_funding', 'gratuite_mensuelle'));
    expect(c.single.args, containsPair('p_consent', true));
    expect(find.textContaining('votre demande n’est pas enregistrée'), findsOneWidget);
    await fin(t);
  });

  testWidgets('quota épuisé sans prix décidé : supplémentaire indisponible, aucun envoi', (t) async {
    srv.rpc['assessment_families'] = (_) => _familles();
    srv.rpc['assessment_quota'] = (_) => _quota(active: 1, used: 1);
    srv.rpc['assessment_my_list'] = (_) => <Object>[];
    await monter(t, const AssessmentsScreen());
    await t.tap(find.text('Famille de métiers n°1'));
    await settleReal(t);
    await t.tap(find.text('Étude de cas'));
    await t.tap(find.textContaining('J’accepte que mes réponses'));
    await t.pump();
    await t.tap(find.text('Demander'));
    await settleReal(t);
    expect(srv.callsOf('assessment_request'), isEmpty);
    await fin(t);
  });

  testWidgets('prix décidé par le serveur : annoncé, puis transmis à l’identique', (t) async {
    srv.rpc['assessment_families'] = (_) => _familles();
    srv.rpc['assessment_quota'] = (_) => _quota(active: 1, used: 1, price: 4321);
    srv.rpc['assessment_my_list'] = (_) => <Object>[];
    srv.rpc['assessment_request'] = (_) => {'ok': false, 'code': 'price_mismatch', 'message': 'Le prix annoncé ne correspond pas au tarif en vigueur.'};
    await monter(t, const AssessmentsScreen());
    await t.tap(find.text('Famille de métiers n°1'));
    await settleReal(t);
    expect(find.textContaining('4321 FCFA'), findsWidgets);
    await t.tap(find.text('Étude de cas'));
    await t.tap(find.textContaining('J’accepte que mes réponses'));
    await t.pump();
    await t.tap(find.text('Demander'));
    await settleReal(t);
    final c = srv.callsOf('assessment_request').single.args;
    expect(c['p_funding'], 'payee_candidat');
    expect(c['p_announced_price'], 4321);
    expect(find.textContaining('ne correspond pas au tarif'), findsOneWidget);
    await fin(t);
  });

  testWidgets('liste : statuts honnêtes, validation humaine requise, résultat détaillé et contestation', (t) async {
    srv.rpc['assessment_families'] = (_) => _familles();
    srv.rpc['assessment_quota'] = (_) => _quota(active: 1, used: 1);
    srv.rpc['assessment_my_list'] = (_) => [
          {'id': 'r1', 'family_code': 'famille_1', 'family_label': 'Famille de métiers n°1', 'mode': 'simulation', 'status': 'terminee', 'funding': 'gratuite_mensuelle', 'created_at': '2026-11-02T10:00:00Z', 'result_id': 'res1', 'validation_status': 'validation_humaine_requise', 'dispute_status': null},
          {'id': 'r2', 'family_code': 'famille_2', 'family_label': 'Famille de métiers n°2', 'mode': 'ecrit', 'status': 'refusee', 'funding': 'gratuite_mensuelle', 'created_at': '2026-11-03T10:00:00Z', 'result_id': null, 'status_note': 'Fournisseur indisponible'},
        ];
    srv.rpc['assessment_result'] = (_) => {
          'id': 'res1',
          'competences': [{'name': 'Compétence A', 'verifiable_remotely': true}, {'name': 'Compétence B', 'verifiable_remotely': false}],
          'criteria': [{'name': 'Critère A'}],
          'evidence': [{'kind': 'Réponse écrite'}],
          'limits': 'Le geste technique n’a pas été observé.',
          'recommendations': ['Faire valider en présentiel'],
          'human_validation_required': true,
          'dispute_possible': true,
          'disputes': <Object>[],
        };
    srv.rpc['assessment_dispute'] = (_) => {'ok': true, 'id': 'd1'};
    await monter(t, const AssessmentsScreen());
    expect(find.text('Terminée'), findsOneWidget);
    expect(find.text('Validation humaine requise'), findsOneWidget);
    expect(find.textContaining('Refusée par le fournisseur · rien n’a été consommé'), findsOneWidget);
    expect(find.text('Fournisseur indisponible'), findsOneWidget);
    await t.tap(find.text('Voir le résultat'));
    await settleReal(t);
    expect(find.text('Compétences évaluées'), findsOneWidget);
    expect(find.text('• Compétence B'), findsOneWidget);
    expect(find.text('Limites de l’évaluation'), findsOneWidget);
    expect(find.text('Le geste technique n’a pas été observé.'), findsOneWidget);
    expect(find.textContaining('Validation humaine requise : une partie'), findsOneWidget);
    await t.tap(find.text('Contester ce résultat'));
    await settleReal(t);
    await t.enterText(find.byType(TextField), 'Le critère A a été mal appliqué à ma réponse.');
    await t.tap(find.text('Envoyer'));
    await settleReal(t);
    final d = srv.callsOf('assessment_dispute').single.args;
    expect(d['p_id'], 'res1');
    expect(d['p_reason'], 'Le critère A a été mal appliqué à ma réponse.');
    await fin(t);
  });

  testWidgets('administration : registre vide = aucun fournisseur actif, aucune donnée inventée', (t) async {
    srv.rpc['assessment_providers_admin_list'] = (_) => <Object>[];
    await monter(t, const AssessmentProvidersAdminScreen());
    expect(find.textContaining('Aucun fournisseur n’est actif'), findsOneWidget);
    expect(find.text('Activer'), findsNothing);
    verifierSansMaquette(t);
    await fin(t);
  });

  testWidgets('administration : activation relayée au serveur, refus du serveur (sans test réussi) affiché', (t) async {
    srv.rpc['assessment_providers_admin_list'] = (_) => [
          {'code': 'prov_x', 'name': 'Fournisseur X', 'status': 'candidat', 'family_codes': ['famille_1'], 'modes': ['ecrit'], 'activated_at': null, 'last_test': null},
        ];
    srv.rpc['assessment_provider_set_status'] = (_) => throw const FakeRpcError('Activation refusée : aucun test d’intégration réussi enregistré pour ce fournisseur');
    await monter(t, const AssessmentProvidersAdminScreen());
    expect(find.textContaining('Aucun test d’intégration enregistré'), findsOneWidget);
    await t.tap(find.text('Activer'));
    await settleReal(t);
    await t.tap(find.text('Confirmer'));
    await settleReal(t);
    final c = srv.callsOf('assessment_provider_set_status').single.args;
    expect(c, containsPair('p_code', 'prov_x'));
    expect(c, containsPair('p_status', 'actif'));
    expect(find.textContaining('aucun test d’intégration réussi'), findsWidgets);
    await fin(t);
  });
}
