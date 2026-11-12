import 'package:boutik_ecole/figma/live/concours_screens.dart';
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

Map<String, dynamic> _ann({String id = '1', bool verified = true, bool free = true, String? deadline, DateTime? created, bool popular = false, bool iut = false, bool saved = false}) => {
      'id': id,
      'title': 'Bourse Canada Excellence',
      'organizer': 'Université de Montréal',
      'organizer_kind': 'university',
      'country': 'Canada',
      'place_kind': 'online',
      'place': '',
      'domain': 'scholarship',
      'kind': 'scholarship',
      'deadline': deadline,
      'reward': 'Bourse complète',
      'eligible_level': 'Master',
      'eligible_age': '',
      'eligible_department': '',
      'eligible_country': 'Afrique',
      'iut_only': iut,
      'free': free,
      'cost_amount': free ? null : 5000,
      'cost_currency': 'FCFA',
      'verified': verified,
      'status': 'published',
      'created_at': (created ?? DateTime(2026, 1, 1)).toIso8601String(),
      'popular': popular,
      'saved': saved,
    };

void main() {
  final now = DateTime(2026, 11, 14, 10);

  test('badges : Vérifié, Nouveau, Bientôt expiré, Populaire', () {
    expect(annBadges(_ann(verified: false), now), isEmpty);
    expect(annBadges(_ann(), now), ['Vérifié']);
    expect(annBadges(_ann(verified: false, created: DateTime(2026, 11, 12)), now), ['Nouveau']);
    expect(annBadges(_ann(verified: false, deadline: '2026-11-18'), now), ['Bientôt expiré']);
    expect(annBadges(_ann(verified: false, deadline: '2026-12-30'), now), isEmpty);
    expect(annBadges(_ann(verified: false, deadline: '2026-11-01'), now), isEmpty, reason: 'déjà clôturée : pas « bientôt »');
    expect(annBadges(_ann(popular: true, verified: false), now), ['Populaire']);
    expect(annBadges(_ann(popular: true, created: DateTime(2026, 11, 13), deadline: '2026-11-16'), now), ['Vérifié', 'Nouveau', 'Bientôt expiré', 'Populaire']);
  });

  test('coût et éligibilité', () {
    expect(annCostLabel(_ann()), 'Gratuit');
    expect(annCostLabel(_ann(free: false)), 'Payant : 5000 FCFA');
    expect(annEligibility(_ann()), 'Master · Afrique · Ouvert à tous');
    expect(annEligibility(_ann(iut: true)), 'Master · Afrique · Réservé aux étudiants de l’IUT');
  });

  test('requête : filtres envoyés au serveur', () {
    const q = AnnQuery();
    expect(q.params.containsKey('p_kind'), isFalse);
    final f = q.copy(kind: 'hackathon', domain: 'tech', cost: 'free', place: 'onsite', within: '7', country: ' Cameroun ', q: 'orange', saved: true);
    expect(f.params['p_kind'], 'hackathon');
    expect(f.params['p_domain'], 'tech');
    expect(f.params['p_free'], 'free');
    expect(f.params['p_place'], 'onsite');
    expect(f.params['p_within_days'], 7);
    expect(f.params['p_country'], 'Cameroun');
    expect(f.params['p_q'], 'orange');
    expect(f.params['p_saved'], true);
    expect(const AnnQuery(kind: 'a') == const AnnQuery(kind: 'a'), isTrue);
  });

  testWidgets('carte : de quoi décider en 10 secondes', (t) async {
    await _pump(t, Scaffold(body: AnnouncementCard(a: _ann(deadline: '2026-11-26'), now: now, onSave: () {})));
    expect(find.text('Bourse Canada Excellence'), findsOneWidget);
    expect(find.textContaining('Université de Montréal · Université'), findsOneWidget);
    expect(find.text('Il reste 12 jours'), findsOneWidget);
    expect(find.text('Gain : Bourse complète'), findsOneWidget);
    expect(find.text('Qui peut postuler : Master · Afrique · Ouvert à tous'), findsOneWidget);
    expect(find.text('Gratuit'), findsOneWidget);
    expect(find.text('Vérifié'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
  });

  testWidgets('liste : vide clair et « Ils ont gagné » honnête', (t) async {
    await _pump(t, const ContestAnnouncementsScreen(), overrides: [
      annsProvider(const AnnQuery()).overrideWith((ref) async => <Map<String, dynamic>>[]),
      annWinsProvider.overrideWith((ref) async => <Map<String, dynamic>>[]),
    ]);
    expect(find.textContaining('Aucune annonce ne correspond pour le moment'), findsOneWidget);
    expect(find.text('Ils ont gagné'), findsOneWidget);
    expect(find.textContaining('apparaîtront ici, avec leur preuve'), findsOneWidget);
    expect(find.text('J’ai gagné'), findsOneWidget);
    expect(find.text('Publier'), findsOneWidget);
  });

  testWidgets('liste : annonces et victoires publiées', (t) async {
    await _pump(t, const ContestAnnouncementsScreen(), overrides: [
      annsProvider(const AnnQuery()).overrideWith((ref) async => [_ann(deadline: '2099-01-01')]),
      annWinsProvider.overrideWith((ref) async => [
            {'id': 'w', 'name': 'Awa A.', 'department': 'Génie informatique', 'title': 'Hackathon Orange Digital', 'prize': '1er prix', 'year': 2026, 'proof_url': 'https://orange.exemple.cm'}
          ]),
    ]);
    expect(find.text('Bourse Canada Excellence'), findsOneWidget);
    expect(find.text('Awa A., Génie informatique'), findsOneWidget);
    expect(find.text('Hackathon Orange Digital · 1er prix · 2026'), findsOneWidget);
    expect(find.text('Voir la preuve'), findsOneWidget);
  });

  testWidgets('fiche : conditions, documents, étapes, critères, dates, site officiel, rappel, partage', (t) async {
    await _pump(t, const AnnouncementDetailScreen(id: '1'), overrides: [
      annDetailProvider('1').overrideWith((ref) async => {
            ..._ann(deadline: '2099-12-31'),
            'description': 'Programme de bourses pour talents africains.',
            'why': 'Financer les études.',
            'conditions': ['Être étudiant', 'Avoir moins de 30 ans'],
            'documents': ['CV', 'Lettre de motivation'],
            'steps': ['Créer un compte', 'Déposer le dossier'],
            'criteria': ['Excellence académique'],
            'opens_on': '2026-10-01',
            'results_on': '2027-03-01',
            'program_start': '2027-09-01',
            'official_url': 'https://bourse.exemple.ca',
            'mine': false,
            'reminder': false,
          }),
    ]);
    expect(find.text('Programme de bourses pour talents africains.'), findsOneWidget);
    expect(find.text('Être étudiant'), findsOneWidget);
    expect(find.text('CV'), findsOneWidget);
    expect(find.text('Étape 1 · '), findsOneWidget);
    expect(find.text('Excellence académique'), findsOneWidget);
    expect(find.text('Date limite : 31/12/2099'), findsOneWidget);
    expect(find.text('Postuler sur le site officiel'), findsOneWidget);
    expect(find.text('Rappel 3 jours avant'), findsOneWidget);
    expect(find.text('Enregistrer'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Copier le lien'), findsOneWidget);
  });
}
