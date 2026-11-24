import 'dart:convert';
import 'dart:io';

import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/evaluations.dart';
import 'package:boutik_ecole/figma/live/evaluations_org.dart';
import 'package:boutik_ecole/figma/live/evaluations_validateur.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/render.dart';

/// H10 · EVAL : campagnes d'évaluation de l'organisation, écran du validateur humain (tech.assessments) et côté candidat (invitations, partage, révocation),
/// en mode connecté (`Backend.ready`, faux serveur, `mockupFrame = false`). Le serveur est le seul porteur des données ; une écriture refusée (500) ne confirme jamais.
final _tokens = jsonDecode(File('tool/maquette_tokens.json').readAsStringSync()) as Map<String, dynamic>;
final _noms = <String>{...(_tokens['personas'] as List).cast<String>(), ...(_tokens['entities'] as List).cast<String>(), ...(_tokens['self'] as List).cast<String>()}.where((e) => e.length >= 4).toList();

String _textes(WidgetTester t) => [for (final w in t.widgetList<Text>(find.byType(Text))) w.data ?? w.textSpan?.toPlainText() ?? ''].join('\n');

Map<String, dynamic> _campagne({String id = 'c1', String status = 'en_attente_financement', Object? shared = 0, String title = 'Recrutement comptables'}) => {
      'id': id,
      'title': title,
      'family_code': 'compta',
      'family_label': 'Comptabilité et finance',
      'mode': 'etude_cas',
      'status': status,
      'created_at': '2026-11-20T10:00:00Z',
      'invited': 2,
      'shared_results': shared,
      'note': status == 'en_attente_financement' ? 'Financement non décidé : aucun paiement n’est demandé, la campagne n’est pas ouverte aux candidats.' : null,
    };

Map<String, dynamic> _resultatARelire() => {
      'result_id': 'res1',
      'request_id': 'rq1',
      'family_code': 'compta',
      'mode': 'etude_cas',
      'candidate': 'Candidat Test',
      'competences': [{'name': 'Rapprochement bancaire'}],
      'criteria': [{'name': 'Exactitude'}],
      'evidence': [{'kind': 'Réponse écrite'}],
      'limits': 'Geste non observé à distance.',
      'validation_status': 'validation_humaine_requise',
      'created_at': '2026-11-21T10:00:00Z',
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
    t.view.physicalSize = const Size(420, 6000);
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

  group('organisation : campagnes', () {
    testWidgets('serveur muet : erreur honnête, aucune campagne ni zéro inventé', (t) async {
      srv.unknownIsError = true;
      await monter(t, const AssessmentCampaignsOrgScreen());
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('Aucune campagne pour le moment.'), findsNothing);
      expect(find.textContaining('Candidats invités'), findsNothing);
      sansMaquette(t);
      await fin(t);
    });

    testWidgets('liste vide : dite vide, financement non ouvert dit clairement', (t) async {
      srv.rpc['assessment_campaigns_list'] = (_) => <Object>[];
      await monter(t, const AssessmentCampaignsOrgScreen());
      expect(find.text('Aucune campagne pour le moment.'), findsOneWidget);
      expect(find.textContaining('financement des campagnes n’est pas encore ouvert'), findsOneWidget);
      expect(find.textContaining('Vous ne voyez que les résultats que les candidats ont accepté de partager'), findsOneWidget);
      sansMaquette(t);
      await fin(t);
    });

    testWidgets('liste : statut honnête, droits d’écriture seulement si le serveur les indique', (t) async {
      srv.rpc['assessment_campaigns_list'] = (_) => [_campagne(), _campagne(id: 'c2', status: 'close', title: 'Ancienne campagne'), _campagne(id: 'c3', shared: null, title: 'Lecture seule')];
      await monter(t, const AssessmentCampaignsOrgScreen());
      expect(find.textContaining('En attente de financement · le financement n’est pas encore ouvert'), findsNWidgets(2));
      expect(find.text('Close'), findsOneWidget);
      expect(find.text('Résultats partagés par les candidats : 0'), findsNWidgets(2));
      expect(find.text('Inviter un candidat'), findsOneWidget, reason: 'c1 seule : c2 est close, c3 en lecture seule');
      expect(find.text('Clôturer la campagne'), findsOneWidget);
      expect(find.text('Résultats partagés'), findsNWidgets(2));
      sansMaquette(t);
      await fin(t);
    });

    testWidgets('création : arguments exacts vers le serveur, succès confirmé', (t) async {
      srv.rpc['assessment_campaigns_list'] = (_) => <Object>[];
      srv.rpc['assessment_families'] = (_) => [{'code': 'compta', 'label': 'Comptabilité et finance', 'position': 1, 'covered': false}];
      srv.rpc['assessment_campaign_create'] = (_) => {'ok': true, 'id': 'c9', 'status': 'en_attente_financement', 'message': 'Campagne enregistrée « en attente de financement »'};
      await monter(t, const AssessmentCampaignsOrgScreen());
      await t.tap(find.text('Créer une campagne'));
      await settleReal(t);
      expect(find.text('Créer'), findsOneWidget);
      await t.tap(find.text('Créer'));
      await settleReal(t);
      expect(srv.callsOf('assessment_campaign_create'), isEmpty, reason: 'titre, famille et mode exigés');
      await t.enterText(find.byType(TextField), 'Recrutement comptables');
      await t.tap(find.text('Comptabilité et finance').last);
      await t.tap(find.text('Étude de cas'));
      await t.pump();
      await t.tap(find.text('Créer'));
      await settleReal(t);
      final a = srv.callsOf('assessment_campaign_create').single.args;
      expect(a, containsPair('p_title', 'Recrutement comptables'));
      expect(a, containsPair('p_family', 'compta'));
      expect(a, containsPair('p_mode', 'etude_cas'));
      await t.pump(const Duration(seconds: 1));
      expect(find.text('Nouvelle campagne'), findsNothing, reason: 'feuille fermée après succès');
      await fin(t);
    });

    testWidgets('création refusée (500) : feuille ouverte, message d’erreur, aucune confirmation', (t) async {
      srv.rpc['assessment_campaigns_list'] = (_) => <Object>[];
      srv.rpc['assessment_families'] = (_) => [{'code': 'compta', 'label': 'Comptabilité et finance', 'position': 1, 'covered': false}];
      srv.failRpc.add('assessment_campaign_create');
      await monter(t, const AssessmentCampaignsOrgScreen());
      await t.tap(find.text('Créer une campagne'));
      await settleReal(t);
      await t.enterText(find.byType(TextField), 'Recrutement comptables');
      await t.tap(find.text('Comptabilité et finance').last);
      await t.tap(find.text('Étude de cas'));
      await t.pump();
      await t.tap(find.text('Créer'));
      await settleReal(t);
      expect(srv.callsOf('assessment_campaign_create'), hasLength(1));
      expect(find.text('Nouvelle campagne'), findsOneWidget);
      expect(find.textContaining('Campagne enregistrée'), findsNothing);
      await fin(t);
    });

    testWidgets('invitation et clôture : arguments exacts ; clôture en panne = pas de confirmation', (t) async {
      srv.rpc['assessment_campaigns_list'] = (_) => [_campagne()];
      srv.rpc['assessment_campaign_invite'] = (_) => 'invited';
      await monter(t, const AssessmentCampaignsOrgScreen());
      await t.tap(find.text('Inviter un candidat'));
      await settleReal(t);
      await t.enterText(find.byType(TextField), 'candidat@example.test');
      await t.tap(find.text('Inviter').last);
      await settleReal(t);
      final i = srv.callsOf('assessment_campaign_invite').single.args;
      expect(i, containsPair('p_campaign', 'c1'));
      expect(i, containsPair('p_email', 'candidat@example.test'));

      srv.failRpc.add('assessment_campaign_close');
      await t.tap(find.text('Clôturer la campagne'));
      await settleReal(t);
      await t.tap(find.text('Clôturer').last);
      await settleReal(t);
      expect(srv.callsOf('assessment_campaign_close').single.args, containsPair('p_campaign', 'c1'));
      expect(find.text('Campagne clôturée.'), findsNothing);
      await fin(t);
    });

    testWidgets('résultats partagés : vides = dits vides ; sinon contenu du serveur seulement', (t) async {
      srv.rpc['assessment_campaigns_list'] = (_) => [_campagne(shared: 1)];
      srv.rpc['assessment_campaign_results'] = (_) => {'campaign': {'id': 'c1'}, 'invited': 2, 'results': <Object>[]};
      await monter(t, const AssessmentCampaignsOrgScreen());
      await t.tap(find.text('Résultats partagés'));
      await settleReal(t);
      expect(srv.callsOf('assessment_campaign_results').single.args, containsPair('p_campaign', 'c1'));
      expect(find.text('Aucun candidat n’a partagé de résultat pour le moment.'), findsOneWidget);
      await fin(t);

      srv.rpc['assessment_campaign_results'] = (_) => {
            'invited': 2,
            'results': [
              {..._resultatARelire(), 'reused': true, 'recommendations': ['Faire valider en présentiel']},
            ],
          };
      await monter(t, const AssessmentCampaignsOrgScreen());
      await t.tap(find.text('Résultats partagés'));
      await settleReal(t);
      expect(find.text('Candidat Test'), findsOneWidget);
      expect(find.text('• Rapprochement bancaire'), findsOneWidget);
      expect(find.text('Geste non observé à distance.'), findsOneWidget);
      expect(find.text('• Faire valider en présentiel'), findsOneWidget);
      expect(find.textContaining('évaluation existante partagée'), findsOneWidget);
      await fin(t);
    });
  });

  group('validateur humain', () {
    testWidgets('serveur muet (ou droit refusé) : erreur honnête, aucune file inventée', (t) async {
      srv.unknownIsError = true;
      await monter(t, const AssessmentReviewScreen());
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.textContaining('Aucun résultat n’attend'), findsNothing);
      await fin(t);
    });

    testWidgets('file vide : dite vide', (t) async {
      srv.rpc['assessment_review_queue'] = (_) => {'results': <Object>[], 'disputes': <Object>[]};
      await monter(t, const AssessmentReviewScreen());
      expect(find.text('Aucun résultat n’attend de validation humaine.'), findsOneWidget);
      expect(find.text('Aucune contestation à traiter.'), findsOneWidget);
      sansMaquette(t);
      await fin(t);
    });

    testWidgets('validation : motif exigé, arguments exacts ; 500 = aucune confirmation', (t) async {
      srv.rpc['assessment_review_queue'] = (_) => {'results': [_resultatARelire()], 'disputes': <Object>[]};
      srv.rpc['assessment_human_validate'] = (_) => {'ok': true};
      await monter(t, const AssessmentReviewScreen());
      expect(find.text('• Exactitude'), findsOneWidget);
      await t.tap(find.text('Valider'));
      await settleReal(t);
      await t.enterText(find.byType(TextField), 'court');
      await t.pump();
      await t.tap(find.text('Confirmer'));
      await settleReal(t);
      expect(srv.callsOf('assessment_human_validate'), isEmpty, reason: 'motif de moins de 10 caractères');
      await t.enterText(find.byType(TextField), 'Réponses cohérentes avec la grille.');
      await t.pump();
      await t.tap(find.text('Confirmer'));
      await settleReal(t);
      final a = srv.callsOf('assessment_human_validate').single.args;
      expect(a, containsPair('p_result', 'res1'));
      expect(a, containsPair('p_outcome', 'validee_humainement'));
      expect(a, containsPair('p_note', 'Réponses cohérentes avec la grille.'));
      await fin(t);
    });

    testWidgets('validation refusée (500) : aucune confirmation au validateur', (t) async {
      srv.rpc['assessment_review_queue'] = (_) => {'results': [_resultatARelire()], 'disputes': <Object>[]};
      srv.failRpc.add('assessment_human_validate');
      await monter(t, const AssessmentReviewScreen());
      await t.tap(find.text('Non vérifiable à distance'));
      await settleReal(t);
      await t.enterText(find.byType(TextField), 'Geste à observer en présentiel.');
      await t.pump();
      await t.tap(find.text('Confirmer'));
      await settleReal(t);
      expect(srv.callsOf('assessment_human_validate').last.args, containsPair('p_outcome', 'non_verifiable_a_distance'));
      expect(find.textContaining('Décision enregistrée'), findsNothing);
      await fin(t);
    });

    testWidgets('contestations : ouverte -> en examen -> close avec résolution motivée', (t) async {
      var statut = 'ouverte';
      srv.rpc['assessment_review_queue'] = (_) => {
            'results': <Object>[],
            'disputes': [{'id': 'd1', 'result_id': 'res1', 'status': statut, 'reason': 'Critère mal appliqué.', 'candidate': 'Candidat Test', 'created_at': '2026-11-22T10:00:00Z', 'family_code': 'compta', 'mode': 'etude_cas', 'limits': 'Limites X'}],
          };
      srv.rpc['assessment_dispute_handle'] = (a) {
        statut = a['p_action'] == 'take' ? 'en_examen' : 'close';
        return {'ok': true, 'id': 'd1', 'status': statut};
      };
      await monter(t, const AssessmentReviewScreen());
      expect(find.text('Clore avec une résolution motivée'), findsNothing);
      await t.tap(find.text('Prendre en examen'));
      await settleReal(t);
      expect(srv.callsOf('assessment_dispute_handle').single.args, containsPair('p_action', 'take'));
      expect(find.text('Clore avec une résolution motivée'), findsOneWidget);
      await t.tap(find.text('Clore avec une résolution motivée'));
      await settleReal(t);
      await t.enterText(find.byType(TextField), 'Trop court');
      await t.pump();
      await t.tap(find.text('Confirmer'));
      await settleReal(t);
      expect(srv.callsOf('assessment_dispute_handle'), hasLength(1), reason: 'résolution de moins de 20 caractères');
      await t.enterText(find.byType(TextField), 'Après relecture, le critère a été correctement appliqué.');
      await t.pump();
      await t.tap(find.text('Confirmer'));
      await settleReal(t);
      final c = srv.callsOf('assessment_dispute_handle').last.args;
      expect(c, containsPair('p_id', 'd1'));
      expect(c, containsPair('p_action', 'close'));
      expect(c, containsPair('p_resolution', 'Après relecture, le critère a été correctement appliqué.'));
      expect(find.text('Aucune contestation à traiter.'), findsNothing, reason: 'la file se relit auprès du serveur');
      await fin(t);
    });
  });

  group('candidat : campagnes, partage, révocation', () {
    Map<String, dynamic> invitation({String status = 'ouverte', bool requested = false}) => {
          'campaign_id': 'c1',
          'title': 'Recrutement comptables',
          'family_code': 'compta',
          'family_label': 'Comptabilité et finance',
          'mode': 'etude_cas',
          'status': status,
          'organization': 'Organisation Test',
          'requested': requested,
        };

    void base() {
      srv.rpc['assessment_families'] = (_) => <Object>[];
      srv.rpc['assessment_quota'] = (_) => {'eligible': true, 'monthly_free': 1, 'used': 0, 'remaining': 1, 'next_reset': '2026-12-31T23:00:00Z', 'active_providers': 1, 'extra': {'available': false, 'message': 'Évaluation supplémentaire indisponible.'}};
    }

    testWidgets('campagne pas ouverte : dit clairement, aucun bouton pour passer l’évaluation', (t) async {
      base();
      srv.rpc['assessment_my_list'] = (_) => <Object>[];
      srv.rpc['assessment_my_invitations'] = (_) => [invitation(status: 'en_attente_financement')];
      await monter(t, const AssessmentsScreen());
      expect(find.textContaining('le financement des campagnes n’est pas encore ouvert'), findsOneWidget);
      expect(find.text('Passer l’évaluation'), findsNothing);
      await fin(t);
    });

    testWidgets('campagne ouverte : consentement puis demande financée par l’organisation, arguments exacts', (t) async {
      base();
      srv.rpc['assessment_my_list'] = (_) => <Object>[];
      srv.rpc['assessment_my_invitations'] = (_) => [invitation()];
      srv.rpc['assessment_request'] = (_) => {'ok': true, 'id': 'rq1', 'status': 'envoyee', 'message': 'Demande envoyée au fournisseur.'};
      await monter(t, const AssessmentsScreen());
      await t.tap(find.text('Passer l’évaluation'));
      await settleReal(t);
      await t.tap(find.text('Retour'));
      await settleReal(t);
      expect(srv.callsOf('assessment_request'), isEmpty);
      await t.tap(find.text('Passer l’évaluation'));
      await settleReal(t);
      await t.tap(find.text('J’accepte'));
      await settleReal(t);
      final a = srv.callsOf('assessment_request').single.args;
      expect(a, containsPair('p_funding', 'financee_organisation'));
      expect(a, containsPair('p_campaign', 'c1'));
      expect(a, containsPair('p_family', 'compta'));
      expect(a, containsPair('p_mode', 'etude_cas'));
      expect(a, containsPair('p_consent', true));
      await fin(t);
    });

    testWidgets('partage : activer, retirer ; échec 500 = aucune confirmation', (t) async {
      base();
      srv.rpc['assessment_my_invitations'] = (_) => <Object>[];
      srv.rpc['assessment_my_list'] = (_) => [
            {'id': 'rq1', 'family_label': 'Comptabilité et finance', 'mode': 'etude_cas', 'status': 'terminee', 'created_at': '2026-11-02T10:00:00Z', 'campaign_id': 'c1', 'shared_with_org': false, 'result_id': 'res1', 'validation_status': 'automatique'},
            {'id': 'rq2', 'family_label': 'Comptabilité et finance', 'mode': 'etude_cas', 'status': 'terminee', 'created_at': '2026-11-03T10:00:00Z', 'campaign_id': 'c2', 'shared_with_org': true, 'reuse_of': 'rq0', 'result_id': 'res0', 'validation_status': 'validee_humainement'},
          ];
      srv.rpc['assessment_share_set'] = (_) => {'ok': true, 'share_with_org': true};
      srv.rpc['assessment_reuse_revoke'] = (_) => {'ok': true};
      await monter(t, const AssessmentsScreen());
      expect(find.text('Résultat non partagé : l’organisation ne le voit pas.'), findsOneWidget);
      expect(find.text('Résultat partagé avec l’organisation qui vous a invité(e).'), findsOneWidget);
      await t.tap(find.text('Partager avec l’organisation'));
      await settleReal(t);
      final s = srv.callsOf('assessment_share_set').single.args;
      expect(s, containsPair('p_request', 'rq1'));
      expect(s, containsPair('p_share', true));

      srv.failRpc.add('assessment_reuse_revoke');
      await t.tap(find.text('Retirer le partage'));
      await settleReal(t);
      expect(srv.callsOf('assessment_reuse_revoke').single.args, containsPair('p_request', 'rq2'));
      expect(find.textContaining('Partage retiré'), findsNothing);
      await fin(t);
    });

    testWidgets('résultat détaillé : statut, avis de l’évaluateur, critères, preuves, limites, recommandations, contestation close', (t) async {
      base();
      srv.rpc['assessment_my_invitations'] = (_) => <Object>[];
      srv.rpc['assessment_my_list'] = (_) => [
            {'id': 'rq1', 'family_label': 'Comptabilité et finance', 'mode': 'etude_cas', 'status': 'terminee', 'created_at': '2026-11-02T10:00:00Z', 'result_id': 'res1', 'validation_status': 'validee_humainement', 'dispute_status': 'close'},
          ];
      srv.rpc['assessment_result'] = (_) => {
            'id': 'res1',
            'competences': [{'name': 'Rapprochement bancaire'}],
            'criteria': [{'name': 'Exactitude'}],
            'evidence': [{'kind': 'Réponse écrite'}],
            'limits': 'Geste non observé à distance.',
            'recommendations': ['Compléter par un exercice pratique'],
            'validation_status': 'validee_humainement',
            'review_note': 'Cohérent avec la grille.',
            'human_validation_required': false,
            'dispute_possible': true,
            'disputes': [{'id': 'd1', 'status': 'close', 'reason': 'Critère mal appliqué', 'resolution': 'Relecture faite, résultat maintenu.'}],
          };
      await monter(t, const AssessmentsScreen());
      await t.tap(find.text('Voir le résultat'));
      await settleReal(t);
      expect(find.text('Statut : Validée par un évaluateur'), findsOneWidget);
      expect(find.text('Avis de l’évaluateur : Cohérent avec la grille.'), findsOneWidget);
      expect(find.text('• Exactitude'), findsOneWidget);
      expect(find.text('• Réponse écrite'), findsOneWidget);
      expect(find.text('Geste non observé à distance.'), findsOneWidget);
      expect(find.text('• Compléter par un exercice pratique'), findsOneWidget);
      expect(find.textContaining('Relecture faite, résultat maintenu.'), findsOneWidget);
      expect(find.text('Contester ce résultat'), findsOneWidget, reason: 'une contestation close permet d’en ouvrir une nouvelle si le serveur l’autorise');
      await fin(t);
    });
  });
}
