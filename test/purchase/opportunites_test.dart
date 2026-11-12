import 'package:boutik_ecole/figma/live/opportunites_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester t, Widget w, {List<Override> overrides = const []}) async {
  t.view.physicalSize = const Size(420, 3200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: w)));
  await t.pumpAndSettle();
}

Map<String, dynamic> _offer({String id = '1', String title = 'Stagiaire développeur Flutter', bool verified = true, String payKind = 'paid', int? amount = 50000, String? deadline, bool saved = false, bool iut = false}) => {
      'id': id,
      'org': 'Orange Cameroun',
      'verified': verified,
      'kind': 'stage',
      'contract': 'académique',
      'title': title,
      'location': 'Douala',
      'mode': 'hybrid',
      'duration': '3 mois',
      'pay_kind': payKind,
      'pay_amount': amount,
      'pay_note': '',
      'deadline': deadline,
      'skills': ['Flutter', 'Canva'],
      'iut_only': iut,
      'saved': saved,
      'applied': false,
    };

void main() {
  final now = DateTime(2026, 11, 14, 10);

  test('compte à rebours de la date limite', () {
    expect(oppDeadlineLabel(DateTime(2026, 11, 19), now), 'Il reste 5 jours');
    expect(oppDeadlineLabel(DateTime(2026, 11, 15), now), 'Il reste 1 jour');
    expect(oppDeadlineLabel(DateTime(2026, 11, 14), now), 'Dernier jour');
    expect(oppDeadlineLabel(DateTime(2026, 11, 10), now), 'Clôturée');
    expect(oppDeadlineLabel(null, now), 'Sans date limite');
  });

  test('rémunération', () {
    expect(oppPayLabel({'pay_kind': 'paid', 'pay_amount': 50000}), contains('Rémunéré'));
    expect(oppPayLabel({'pay_kind': 'paid', 'pay_amount': 50000}), contains('par mois'));
    expect(oppPayLabel({'pay_kind': 'paid', 'pay_amount': null}), 'Rémunéré');
    expect(oppPayLabel({'pay_kind': 'unpaid', 'pay_note': 'attestation de stage'}), 'Non rémunéré mais attestation de stage');
    expect(oppPayLabel({'pay_kind': 'unpaid', 'pay_note': ''}), 'Non rémunéré');
    expect(oppPayLabel({'pay_kind': 'negotiable'}), 'À négocier');
  });

  test('requête : filtres envoyés au serveur', () {
    const q = OppQuery();
    expect(q.filtered, isFalse);
    expect(q.params.containsKey('p_kind'), isFalse);
    final f = q.copy(kind: 'stage', paid: true, iut: true, q: ' flutter ', section: 'closing');
    expect(f.filtered, isTrue);
    expect(f.params['p_kind'], 'stage');
    expect(f.params['p_paid_only'], true);
    expect(f.params['p_iut_only'], true);
    expect(f.params['p_q'], 'flutter');
    expect(f.params['p_section'], 'closing');
    expect(const OppQuery(kind: 'stage') == const OppQuery(kind: 'stage'), isTrue);
  });

  testWidgets('carte : organisation vérifiée, poste, lieu, durée, paie, compte à rebours, compétences', (t) async {
    await _pump(t, Scaffold(body: OpportunityCard(o: _offer(deadline: '2026-11-17'), now: now, onSave: () {})));
    expect(find.text('Orange Cameroun'), findsOneWidget);
    expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    expect(find.text('Stagiaire développeur Flutter'), findsOneWidget);
    expect(find.textContaining('Douala · Hybride'), findsOneWidget);
    expect(find.textContaining('3 mois'), findsOneWidget);
    expect(find.textContaining('par mois'), findsOneWidget);
    expect(find.text('Il reste 3 jours'), findsOneWidget);
    expect(find.text('Flutter'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
  });

  testWidgets('carte : offre non vérifiée, réservée IUT, favori', (t) async {
    await _pump(t, Scaffold(body: OpportunityCard(o: _offer(verified: false, iut: true, saved: true, payKind: 'negotiable', amount: null), now: now, onSave: () {})));
    expect(find.byIcon(Icons.verified_rounded), findsNothing);
    expect(find.text('Réservé IUT'), findsOneWidget);
    expect(find.text('À négocier'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
  });

  testWidgets('page : aucune offre, message clair et assistant honnête', (t) async {
    await _pump(t, const OpportunitiesScreen(), overrides: [
      oppsProvider(const OppQuery()).overrideWith((ref) async => <Map<String, dynamic>>[]),
      oppsProvider(const OppQuery(section: 'new')).overrideWith((ref) async => <Map<String, dynamic>>[]),
      oppsProvider(const OppQuery(section: 'closing')).overrideWith((ref) async => <Map<String, dynamic>>[]),
      oppsProvider(const OppQuery(section: 'foryou')).overrideWith((ref) async => <Map<String, dynamic>>[]),
      oppsProvider(const OppQuery(section: 'iut')).overrideWith((ref) async => <Map<String, dynamic>>[]),
      oppsProvider(const OppQuery(paid: true)).overrideWith((ref) async => <Map<String, dynamic>>[]),
      oppHiredProvider.overrideWith((ref) async => <Map<String, dynamic>>[]),
      oppAlertProvider.overrideWith((ref) async => false),
    ]);
    expect(find.text('Assistant Opportunités'), findsOneWidget);
    expect(find.text('Aucune offre dans votre filière pour le moment'), findsOneWidget);
    expect(find.textContaining('Aucune opportunité publiée pour le moment'), findsOneWidget);
    expect(find.text('Ils ont été recrutés'), findsOneWidget);
    expect(find.text('—'), findsNothing, reason: 'aucun tiret de maquette');
    expect(find.byIcon(Icons.check_circle_outline), findsNWidgets(3), reason: 'trois lignes de l’assistant, icônes blanches');
  });

  testWidgets('page : sections remplies, compteurs de l’assistant, recrutés', (t) async {
    final one = [_offer(deadline: '2026-11-16')];
    await _pump(t, const OpportunitiesScreen(), overrides: [
      oppsProvider(const OppQuery()).overrideWith((ref) async => one),
      oppsProvider(const OppQuery(section: 'new')).overrideWith((ref) async => one),
      oppsProvider(const OppQuery(section: 'closing')).overrideWith((ref) async => one),
      oppsProvider(const OppQuery(section: 'foryou')).overrideWith((ref) async => one),
      oppsProvider(const OppQuery(section: 'iut')).overrideWith((ref) async => <Map<String, dynamic>>[]),
      oppsProvider(const OppQuery(paid: true)).overrideWith((ref) async => one),
      oppHiredProvider.overrideWith((ref) async => [
            {'name': 'Mballa K.', 'department': 'Génie électrique', 'org': 'Orange Cameroun', 'role': 'Stage développeur'}
          ]),
      oppAlertProvider.overrideWith((ref) async => true),
    ]);
    expect(find.text('1 offre dans votre filière'), findsOneWidget);
    expect(find.text('1 offre se termine dans 3 jours'), findsOneWidget);
    expect(find.text('1 nouvelle offre cette semaine'), findsOneWidget);
    expect(find.text('Pour vous'), findsOneWidget);
    expect(find.text('Date limite proche'), findsOneWidget);
    expect(find.text('Rémunérées en premier'), findsOneWidget);
    expect(find.text('Opportunités IUT'), findsNothing, reason: 'section vide masquée');
    expect(find.textContaining('Mballa K., Génie électrique, recruté(e) : Stage développeur chez Orange Cameroun'), findsOneWidget);
  });

  testWidgets('fiche : description, missions, profil, gains, postuler dans l’app et sur WhatsApp', (t) async {
    await _pump(t, const OpportunityDetailScreen(id: '1'), overrides: [
      oppDetailProvider('1').overrideWith((ref) async => {
            ..._offer(deadline: '2099-01-01'),
            'status': 'published',
            'description': 'Vous développerez des écrans mobiles.',
            'missions': ['Développer des écrans', 'Tester'],
            'profile_wanted': 'Étudiant motivé',
            'department_target': 'Génie informatique',
            'level': 'Licence 2',
            'gains': ['Attestation de stage', 'Expérience'],
            'apply_whatsapp': '+237690112233',
            'apply_in_app': true,
            'about_org': 'Opérateur de télécommunications',
            'mine': false,
            'my_application': null,
            'reminder': false,
            'other_offers': [
              {'id': '2', 'title': 'Stage réseaux', 'kind': 'stage'}
            ],
          }),
    ]);
    expect(find.text('Vous développerez des écrans mobiles.'), findsOneWidget);
    expect(find.text('Développer des écrans'), findsOneWidget);
    expect(find.text('Filière : Génie informatique'), findsOneWidget);
    expect(find.text('Attestation de stage'), findsOneWidget);
    expect(find.text('Postuler dans l’application'), findsOneWidget);
    expect(find.text('Postuler sur WhatsApp'), findsOneWidget);
    expect(find.text('Enregistrer'), findsOneWidget);
    expect(find.text('Me rappeler'), findsOneWidget);
    expect(find.text('Stage réseaux'), findsOneWidget);
  });

  testWidgets('fiche : candidature déjà envoyée, plus de bouton Postuler', (t) async {
    await _pump(t, const OpportunityDetailScreen(id: '1'), overrides: [
      oppDetailProvider('1').overrideWith((ref) async => {
            ..._offer(deadline: '2099-01-01'),
            'status': 'published',
            'description': 'Description',
            'missions': [],
            'gains': [],
            'apply_whatsapp': '',
            'apply_in_app': true,
            'mine': false,
            'my_application': {'id': 'a', 'status': 'shortlisted'},
            'other_offers': [],
          }),
    ]);
    expect(find.text('Votre candidature : retenue'), findsOneWidget);
    expect(find.text('Postuler dans l’application'), findsNothing);
  });
}
