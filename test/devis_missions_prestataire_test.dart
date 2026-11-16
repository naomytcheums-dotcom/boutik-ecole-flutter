import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boutik_ecole/figma/live/docs_prestataire.dart';
import 'package:boutik_ecole/figma/live/missions.dart';
import 'package:boutik_ecole/figma/live/missions_prestataire.dart';
import 'package:boutik_ecole/figma/live/notifs.dart';
import 'package:boutik_ecole/figma/live/services.dart';

Map<String, dynamic> _mission({String role = 'provider', String status = 'in_progress', List<Map<String, dynamic>>? miles, String id = 'm1'}) => {
      'id': id,
      'number': '#BR-2026-000001',
      'title': 'Identité visuelle',
      'kind': 'mission',
      'description': 'Un logo',
      'status': status,
      'role': role,
      'total': 100000,
      'team': 'Équipe A',
      'deadline': '2027-01-31',
      'created_at': '2026-11-01T10:00:00Z',
      'counterpart': role == 'client' ? 'Awa B.' : null,
      'agreement': {'invoice_number': 'MI-2026-00001', 'amount': 100000, 'delay_days': 20},
      'milestones': miles ??
          [
            {'position': 1, 'title': 'Brief validé', 'amount': 30000, 'status': 'validated', 'pay_status': 'confirmed', 'proof_note': 'Moodboard'},
            {'position': 2, 'title': 'Propositions', 'amount': 40000, 'status': 'validated', 'pay_status': 'declared', 'proof_note': 'Pistes'},
            {'position': 3, 'title': 'Livraison finale', 'amount': 30000, 'status': 'submitted', 'pay_status': 'unpaid', 'proof_note': 'Final'},
          ],
    };

void main() {
  group('devis côté prestataire (S4-40, S4-42)', () {
    test('libellés des nouveaux statuts', () {
      expect(quoteStatusLabel('rejected'), 'Demande déclinée par le prestataire');
      expect(quoteStatusLabel('expired'), 'Devis expiré');
      expect(quoteStatusLabel('quoted'), 'Devis reçu');
      expect(quoteStatusLabel('cancelled'), 'Demande annulée');
    });

    test('un devis dont la validité est passée est expiré', () {
      final now = DateTime.utc(2026, 11, 20);
      expect(quoteIsExpired({'status': 'quoted', 'valid_until': '2026-11-19T00:00:00Z'}, now), isTrue);
      expect(quoteIsExpired({'status': 'quoted', 'valid_until': '2026-11-21T00:00:00Z'}, now), isFalse);
      expect(quoteIsExpired({'status': 'expired'}, now), isTrue);
      expect(quoteIsExpired({'status': 'accepted', 'valid_until': '2026-01-01T00:00:00Z'}, now), isFalse, reason: 'un devis accepté ne périme plus');
      expect(quoteIsExpired({'status': 'quoted'}, now), isFalse, reason: 'sans date, le serveur décide');
    });

    test('la notification de devis a une destination', () {
      final n = NotificationItem(id: '1', kind: 'quote', title: 't', body: 'b', createdAt: DateTime(2026), read: false);
      expect(notificationActionLabel(n), 'Voir mes devis');
    });
  });

  group('missions : plusieurs missions (S4-89, S4-99)', () {
    test('la mission choisie est celle affichée, à défaut la plus récente', () {
      final all = [_mission(id: 'a', role: 'client'), _mission(id: 'b')];
      expect(pickMissionJson(all, 'b')!['id'], 'b');
      expect(pickMissionJson(all, '')!['id'], 'a');
      expect(pickMissionJson(all, 'inconnue')!['id'], 'a', reason: 'une sélection périmée ne masque pas les missions');
      expect(pickMissionJson(const [], 'a'), isNull);
    });

    test('une mission de prestataire garde son rôle, les règlements et la facture', () {
      final m = missionFromMyMissions(_mission());
      expect(m.isProvider, isTrue);
      expect(m.isClient, isFalse);
      expect(m.invoice, 'MI-2026-00001');
      expect(m.pays, ['confirmed', 'declared', 'unpaid']);
      expect(m.confirmedPaid, 30000);
      expect(m.validatedUnpaid, 40000);
      expect(m.awaitingValidation, 30000);
      expect(m.counterpart, isEmpty, reason: 'le prestataire ne connaît pas le client');
      final c = missionFromMyMissions(_mission(role: 'client'));
      expect(c.isClient, isTrue);
      expect(c.counterpart, 'Awa B.');
    });

    test('Gagnés ne vient plus de 70 % des jalons validés', () {
      final m = missionFromMyMissions(_mission());
      expect(m.confirmedPaid, isNot(m.studentEarned), reason: 'valeur réelle confirmée par le prestataire, pas 70 % calculé');
    });

    test('un talent sans mission retenue n\'est pas renvoyé vers le formulaire client sur 195 et 201', () {
      for (final s in ['195', '201']) {
        expect(redirectMissionScreen(ready: true, loaded: true, mission: Mission.none, screen: s, role: 'student'), isFalse);
      }
      expect(redirectMissionScreen(ready: true, loaded: true, mission: Mission.none, screen: '194', role: 'student'), isTrue);
      expect(redirectMissionScreen(ready: true, loaded: true, mission: Mission.none, screen: '201', role: 'client'), isTrue);
      expect(redirectMissionScreen(ready: true, loaded: true, mission: missionFromMyMissions(_mission()), screen: '194', role: 'student'), isFalse);
    });
  });

  group('preuve de livraison (S4-98, S4-100)', () {
    test('le jalon livrable est le premier à livrer dont les précédents sont validés', () {
      expect(nextDeliverablePosition(_mission(miles: [
        {'position': 1, 'status': 'validated'},
        {'position': 2, 'status': 'pending'},
        {'position': 3, 'status': 'pending'},
      ])['milestones'] as List<Map<String, dynamic>>), 2);
      expect(nextDeliverablePosition([
        {'position': 1, 'status': 'correction'},
        {'position': 2, 'status': 'pending'},
      ]), 1);
    });

    test('rien à livrer tant que le client n\'a pas décidé, ni quand tout est validé', () {
      expect(nextDeliverablePosition([
        {'position': 1, 'status': 'submitted'},
        {'position': 2, 'status': 'pending'},
      ]), isNull);
      expect(nextDeliverablePosition([
        {'position': 1, 'status': 'validated'},
        {'position': 2, 'status': 'validated'},
      ]), isNull);
    });
  });

  group('documents du prestataire (S4-73, S4-92)', () {
    test('totaux du relevé de ventes', () {
      final t = statementTotals({
        'sales': [
          {'total': 25000},
          {'total': 40000},
        ],
        'missions': [
          {'amount': 27000},
        ],
      });
      expect(t.sales, 65000);
      expect(t.orders, 2);
      expect(t.missions, 27000);
      final empty = statementTotals({});
      expect(empty.sales, 0);
      expect(empty.orders, 0);
    });

    test('libellé du règlement d\'un jalon', () {
      expect(milestonePayLabel('confirmed'), contains('confirmée'));
      expect(milestonePayLabel('declared'), contains('à confirmer'));
      expect(milestonePayLabel('unpaid'), 'Non réglé');
    });

    test('la facture de mission et le relevé se construisent en PDF', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final inv = {
        'number': 'MI-2026-00001',
        'issued_at': '2026-11-02T10:00:00Z',
        'mission_number': '#BR-2026-000001',
        'title': 'Identité visuelle',
        'client_name': 'Client Boutik-École (identité non communiquée)',
        'provider_name': 'Awa B.',
        'agreed_amount': 100000,
        'validated_amount': 70000,
        'declared_amount': 40000,
        'confirmed_amount': 30000,
        'notice': 'Accord direct',
        'milestones': (_mission()['milestones'] as List),
      };
      final doc = await buildMissionInvoicePdf(inv);
      expect((await doc.save()).length, greaterThan(1000));
      final st = await buildStatementPdf({
        'from': '2026-01-01', 'to': '2026-11-15', 'seller': 'Awa B.', 'generated_at': '2026-11-15T10:00:00Z',
        'sales': [{'number': '#BE-1', 'created_at': '2026-10-01', 'title': 'Lampe', 'qty': 1, 'total': 25000, 'payment': 'paid'}],
        'missions': [{'title': 'Identité visuelle', 'milestone': 'Brief', 'amount': 30000, 'pay_method': 'MoMo', 'confirmed_at': '2026-11-03'}],
      });
      expect((await st.save()).length, greaterThan(1000));
    });
  });

  testWidgets('Mes missions : sans serveur, aucun écran de client n\'est affiché et l\'état vide propose les besoins', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: Scaffold(body: SizedBox(width: 342, height: 640, child: ProviderMissionsPanel())))));
    await tester.pumpAndSettle();
    expect(find.text('Aucune mission retenue pour le moment.'), findsOneWidget);
    expect(find.text('Voir les besoins à pourvoir'), findsOneWidget);
    expect(find.textContaining('ne bloque ni ne verse'), findsOneWidget);
  });
}
