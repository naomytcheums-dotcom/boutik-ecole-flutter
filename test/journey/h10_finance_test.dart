import 'package:boutik_ecole/figma/g/g_134.dart';
import 'package:boutik_ecole/figma/g/g_141.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/finance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/render.dart';

/// H10 · finance : rapprochement RÉEL (écrans 134 et 141). Faux serveur local : muet, vide, liste ; « rapproché » seulement avec une preuve fournie par le serveur ;
/// l'enregistrement d'une preuve passe par finance_reconcile_record (refus du serveur annoncé, jamais de confirmation si l'écriture échoue).
Map<String, dynamic> _proof(String source, String ref) => {'source': source, 'reference': ref, 'date': '2026-11-20', 'author': 'Fin Finance'};

Map<String, dynamic> _row(String label, {bool reconciled = false, Map<String, dynamic>? proof, int credit = 0, int debit = 0, String kind = 'order', String? ref}) => {
      'date': '2026-11-19',
      'label': label,
      'debit': debit,
      'credit': credit,
      'reconciled': reconciled,
      'kind': kind,
      'ref': ref ?? label.split(' ').last,
      'proof': proof,
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
    GScreen.mockupFrame = false;
    GAnim.enabled = false;
    Backend.ready = true;
    srv.rpc.clear();
    srv.tables.clear();
    srv.calls.clear();
    srv.failRpc.clear();
    srv.unknownIsError = false;
  });
  tearDown(() => GScreen.mockupFrame = true);

  Future<void> monter(WidgetTester t, Widget ecran) async {
    t.view.physicalSize = const Size(1280, 890);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(child: MaterialApp(home: ecran)));
    await t.pump(const Duration(milliseconds: 100));
    ProviderScope.containerOf(t.element(find.byWidget(ecran))).read(authProvider.notifier).login(demoAccount);
    await t.pump(const Duration(milliseconds: 100));
  }

  Future<void> attendre(WidgetTester t, Finder f) async {
    for (var i = 0; i < 60 && f.evaluate().isEmpty; i++) {
      await settleReal(t, rounds: 2, ms: 100);
    }
  }

  Future<void> fin(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 60));
  }

  group('141 · journal financier', () {
    testWidgets('serveur muet (404) : message honnête, aucune ligne, aucun « rapproché », aucun zéro', (t) async {
      srv.unknownIsError = true;
      await monter(t, const G_141());
      await attendre(t, find.textContaining('Accès réservé'));
      expect(find.textContaining('Accès réservé'), findsWidgets);
      expect(find.text('Oui'), findsNothing);
      expect(find.text('À rapprocher'), findsNothing);
      expect(find.text('Lignes à rapprocher'), findsNothing);
      await fin(t);
    });

    testWidgets('panne serveur (500) : même message, aucune confirmation', (t) async {
      srv.failRpc.add('finance_journal');
      await monter(t, const G_141());
      await attendre(t, find.textContaining('Accès réservé'));
      expect(find.textContaining('Accès réservé'), findsWidgets);
      expect(find.text('Oui'), findsNothing);
      await fin(t);
    });

    testWidgets('journal vide : état vide honnête, compteurs du serveur', (t) async {
      srv.rpc['finance_journal'] = (_) => {'rows': <Map<String, dynamic>>[], 'total_credit': 0, 'total_debit': 0, 'to_reconcile': 0, 'reconciled': 0, 'total_rows': 0};
      await monter(t, const G_141());
      await attendre(t, find.text('Aucune écriture pour le moment.'));
      expect(find.text('Aucune écriture pour le moment.'), findsOneWidget);
      expect(find.text('Oui'), findsNothing);
      await fin(t);
    });

    testWidgets('liste : « Oui » seulement avec une preuve ; une ligne « rapprochée » sans preuve reste à rapprocher', (t) async {
      srv.rpc['finance_journal'] = (_) => {
            'rows': [
              _row('Encaissement #BE-1', reconciled: true, proof: _proof('webhook_prestataire', 'NP-1'), credit: 25000),
              _row('Encaissement #BE-2', credit: 10000),
              _row('Reversement RV-1', reconciled: true, debit: 5000, kind: 'payout'),
            ],
            'total_credit': 35000,
            'total_debit': 5000,
            'to_reconcile': 2,
            'reconciled': 1,
            'total_rows': 3,
          };
      await monter(t, const G_141());
      await attendre(t, find.text('Encaissement #BE-1'));
      expect(find.text('Oui'), findsOneWidget);
      expect(find.text('À rapprocher'), findsNWidgets(2));
      expect(find.text('2 sur 3'), findsOneWidget);
      expect(find.text('Encaissement #0142'), findsNothing);
      await fin(t);
    });

    testWidgets('ligne à rapprocher : la preuve est enregistrée par le serveur puis le journal est relu', (t) async {
      var recorded = false;
      srv.rpc['finance_journal'] = (_) => {
            'rows': [recorded ? _row('Encaissement #BE-2', reconciled: true, proof: _proof('releve_prestataire', 'REL-2026-0002'), credit: 10000) : _row('Encaissement #BE-2', credit: 10000)],
            'total_credit': 10000,
            'total_debit': 0,
            'to_reconcile': recorded ? 0 : 1,
            'reconciled': recorded ? 1 : 0,
            'total_rows': 1,
          };
      srv.rpc['finance_reconcile_record'] = (_) {
        recorded = true;
        return {'state': 'recorded', 'reference': 'REL-2026-0002', 'source': 'releve_prestataire'};
      };
      await monter(t, const G_141());
      await attendre(t, find.text('Encaissement #BE-2'));
      await t.tap(find.text('Encaissement #BE-2'));
      await settleReal(t, rounds: 4, ms: 60);
      expect(find.text('Enregistrer la preuve de rapprochement'), findsOneWidget);
      await t.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)).first, 'REL-2026-0002');
      await t.tap(find.text('Enregistrer'));
      await settleReal(t, rounds: 6, ms: 60);
      final calls = srv.callsOf('finance_reconcile_record');
      expect(calls, hasLength(1));
      expect(calls.first.args, {'p_kind': 'order', 'p_ref': '#BE-2', 'p_provider_ref': 'REL-2026-0002', 'p_source': 'releve_prestataire'});
      await attendre(t, find.text('Oui'));
      expect(find.text('Oui'), findsOneWidget);
      expect(srv.callsOf('finance_journal').length, greaterThanOrEqualTo(2));
      await fin(t);
    });

    testWidgets('refus du serveur (permission, 2FA) : message du serveur, la ligne reste à rapprocher, aucune confirmation', (t) async {
      srv.rpc['finance_journal'] = (_) => {'rows': [_row('Encaissement #BE-2', credit: 10000)], 'total_credit': 10000, 'total_debit': 0, 'to_reconcile': 1, 'reconciled': 0, 'total_rows': 1};
      srv.rpc['finance_reconcile_record'] = (_) => throw const FakeRpcError('Action non autorisée');
      await monter(t, const G_141());
      await attendre(t, find.text('Encaissement #BE-2'));
      await t.tap(find.text('Encaissement #BE-2'));
      await settleReal(t, rounds: 4, ms: 60);
      await t.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)).first, 'REL-2026-0002');
      await t.tap(find.text('Enregistrer'));
      await settleReal(t, rounds: 6, ms: 60);
      expect(srv.callsOf('finance_reconcile_record'), hasLength(1));
      expect(find.textContaining('Preuve enregistrée'), findsNothing);
      expect(find.text('Oui'), findsNothing);
      expect(find.text('À rapprocher'), findsOneWidget);
      await fin(t);
    });

    testWidgets('ligne rapprochée : le détail montre la source, la référence et l’auteur', (t) async {
      srv.rpc['finance_journal'] = (_) => {
            'rows': [_row('Encaissement #BE-1', reconciled: true, proof: _proof('webhook_prestataire', 'NP-1'), credit: 25000)],
            'total_credit': 25000,
            'total_debit': 0,
            'to_reconcile': 0,
            'reconciled': 1,
            'total_rows': 1,
          };
      await monter(t, const G_141());
      await attendre(t, find.text('Encaissement #BE-1'));
      await t.tap(find.text('Encaissement #BE-1'));
      await settleReal(t, rounds: 4, ms: 60);
      expect(find.textContaining('confirmation du prestataire'), findsOneWidget);
      expect(find.textContaining('Référence : NP-1'), findsOneWidget);
      expect(find.textContaining('Enregistré par : Fin Finance'), findsOneWidget);
      expect(srv.callsOf('finance_reconcile_record'), isEmpty);
      await fin(t);
    });
  });

  group('134 · transactions et rapprochements', () {
    testWidgets('serveur muet : message honnête, aucune transaction de maquette', (t) async {
      srv.unknownIsError = true;
      await monter(t, const G_134());
      await attendre(t, find.textContaining('Cette liste ne peut pas être chargée'));
      expect(find.textContaining('Cette liste ne peut pas être chargée'), findsOneWidget);
      expect(find.textContaining('rapproché'), findsNothing);
      expect(find.text('TX-88421'), findsNothing);
      await fin(t);
    });

    testWidgets('liste vide : état vide', (t) async {
      srv.rpc['finance_payments'] = (_) => <Map<String, dynamic>>[];
      await monter(t, const G_134());
      await attendre(t, find.text('Aucun paiement déclaré pour le moment.'));
      expect(find.text('Aucun paiement déclaré pour le moment.'), findsOneWidget);
      await fin(t);
    });

    testWidgets('liste : « rapproché » seulement avec la source de la preuve, sinon « à rapprocher » ; un paiement non vérifié n’est pas rapproché', (t) async {
      srv.rpc['finance_payments'] = (_) => [
            {'reference': 'NP-1', 'order': '#BE-1', 'method': 'Orange Money', 'amount': 25000, 'state': 'verified', 'reconciled': true, 'proof_source': 'webhook_prestataire', 'proof_reference': 'NP-1'},
            {'reference': 'NP-2', 'order': '#BE-2', 'method': 'MTN MoMo', 'amount': 10000, 'state': 'verified', 'reconciled': false, 'proof_source': null},
            {'reference': 'NP-3', 'order': '#BE-3', 'method': 'Orange Money', 'amount': 8000, 'state': 'to_verify', 'reconciled': false, 'proof_source': null},
            {'reference': 'NP-4', 'order': '#BE-4', 'method': 'Orange Money', 'amount': 6000, 'state': 'verified', 'reconciled': true, 'proof_source': null},
          ];
      await monter(t, const G_134());
      await attendre(t, find.textContaining('NP-1'));
      expect(find.textContaining('rapproché (confirmation du prestataire)'), findsOneWidget);
      expect(find.textContaining('· à rapprocher'), findsNWidgets(2));
      expect(find.textContaining('rapproché ('), findsOneWidget);
      await fin(t);
    });
  });

  test('libellés de rapprochement : preuve obligatoire', () {
    expect(reconciliationLabel(_row('x', reconciled: true, proof: _proof('releve_prestataire', 'REL-1'))), 'Rapproché');
    expect(reconciliationLabel(_row('x', reconciled: true)), 'À rapprocher');
    expect(reconciliationLabel(_row('x', proof: _proof('releve_prestataire', 'REL-1'))), 'À rapprocher');
    expect(reconciliationLabel({'reconciled': true, 'proof': {'source': 'releve_prestataire', 'reference': ''}}), 'À rapprocher');
    expect(proofSourceLabel('remise_caisse'), 'remise en caisse');
    expect(paymentReconciliationNote({'state': 'to_verify'}), '');
  });
}
