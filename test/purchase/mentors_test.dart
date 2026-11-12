import 'package:boutik_ecole/figma/live/mentors_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester t, Widget w, {List<Override> overrides = const []}) async {
  t.view.physicalSize = const Size(420, 2200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: w)));
  await t.pumpAndSettle();
}

Map<String, dynamic> _mentor({String avail = 'this_week', num? rating = 4.5, int reviews = 2}) => {
      'user_id': 'u1',
      'name': 'Awa A.',
      'promo': 'Promo 2021',
      'department': 'Génie informatique',
      'works_at': 'Orange Cameroun',
      'topics': ['Flutter', 'Entretien d’embauche'],
      'bio': 'Développeuse mobile',
      'availability': avail,
      'evening': true,
      'rating': rating,
      'reviews': reviews,
      'helped': 3,
    };

void main() {
  test('libellés de disponibilité', () {
    expect(availabilityLabels['this_week'], 'Disponible cette semaine');
    expect(availabilityLabels['busy'], 'Pas disponible');
    expect(stars(null), 'Pas encore noté');
    expect(stars(4.5), '★ 4.5');
  });

  testWidgets('carte mentor : promo, filière, employeur, sujets, disponibilité, note', (t) async {
    await _pump(t, Scaffold(body: MentorCard(m: _mentor())));
    expect(find.text('Awa A.'), findsOneWidget);
    expect(find.text('Promo 2021 · Génie informatique'), findsOneWidget);
    expect(find.text('Travaille chez Orange Cameroun'), findsOneWidget);
    expect(find.textContaining('Je peux aider : Flutter'), findsOneWidget);
    expect(find.text('Disponible cette semaine'), findsOneWidget);
    expect(find.text('★ 4.5 (2)'), findsOneWidget);
  });

  testWidgets('carte mentor sans avis : pas de note inventée', (t) async {
    await _pump(t, Scaffold(body: MentorCard(m: _mentor(rating: null, reviews: 0, avail: 'busy'))));
    expect(find.text('Pas encore noté'), findsOneWidget);
    expect(find.text('Pas disponible'), findsOneWidget);
  });

  testWidgets('annuaire vide : message clair, rien d’inventé', (t) async {
    await _pump(t, const MentorsScreen(), overrides: [
      mentorsProvider('').overrideWith((ref) async => <Map<String, dynamic>>[]),
      mentorStoriesProvider.overrideWith((ref) async => <Map<String, dynamic>>[]),
      myMentorProvider.overrideWith((ref) async => null),
    ]);
    expect(find.textContaining('Aucun mentor pour le moment'), findsOneWidget);
    expect(find.text('Devenir mentor'), findsOneWidget);
    expect(find.text('Proposer 3 mentors'), findsOneWidget);
    expect(find.textContaining('apparaîtront ici'), findsWidgets);
  });

  testWidgets('annuaire : mentors et histoires de réussite', (t) async {
    await _pump(t, const MentorsScreen(), overrides: [
      mentorsProvider('').overrideWith((ref) async => [_mentor()]),
      mentorStoriesProvider.overrideWith((ref) async => [
            {'id': 's', 'title': 'De l’IUT à Orange Cameroun', 'body': 'Après ma licence, j’ai été embauchée.', 'company': 'Orange Cameroun', 'author': 'Awa A.'},
          ]),
      myMentorProvider.overrideWith((ref) async => _mentor()),
    ]);
    expect(find.text('Mon profil mentor'), findsOneWidget);
    expect(find.text('Travaille chez Orange Cameroun'), findsOneWidget);
    expect(find.text('De l’IUT à Orange Cameroun'), findsOneWidget);
    expect(find.text('Awa A. · Orange Cameroun'), findsOneWidget);
  });

  testWidgets('fiche mentor : avis, demande en attente', (t) async {
    await _pump(t, const MentorDetailScreen(id: 'u1'), overrides: [
      mentorDetailProvider('u1').overrideWith((ref) async => {
            ..._mentor(),
            'review_list': [
              {'rating': 5, 'comment': 'Il m’a beaucoup aidé', 'author': 'Paul E.'}
            ],
            'my_request': {'id': 'r', 'topic': 'Flutter', 'status': 'requested'},
          }),
    ]);
    expect(find.textContaining('Il m’a beaucoup aidé'), findsOneWidget);
    expect(find.text('3 accompagnements acceptés · disponible le soir'), findsOneWidget);
    expect(find.text('Votre demande est en attente de réponse.'), findsOneWidget);
    expect(find.text('Demander un mentor'), findsNothing);
  });

  testWidgets('fiche mentor occupé : demande impossible', (t) async {
    await _pump(t, const MentorDetailScreen(id: 'u2'), overrides: [
      mentorDetailProvider('u2').overrideWith((ref) async => {..._mentor(avail: 'busy'), 'review_list': <Map<String, dynamic>>[], 'my_request': null}),
    ]);
    expect(find.text('Pas disponible pour le moment'), findsOneWidget);
    expect(find.textContaining('Pas encore d’avis'), findsOneWidget);
  });

  testWidgets('demandes : l’étudiant note après acceptation, le mentor accepte ou décline', (t) async {
    await _pump(t, const MentorRequestsScreen(), overrides: [
      myMentorProvider.overrideWith((ref) async => _mentor()),
      mentorRequestsProvider('student').overrideWith((ref) async => [
            {'id': '1', 'topic': 'Flutter', 'message': '', 'status': 'accepted', 'other': 'Awa A.', 'reviewed': false},
            {'id': '2', 'topic': 'Design', 'message': '', 'status': 'requested', 'other': 'Cora A.', 'reviewed': false},
          ]),
      mentorRequestsProvider('mentor').overrideWith((ref) async => [
            {'id': '3', 'topic': 'Entretien', 'message': 'Je cherche de l aide', 'status': 'requested', 'other': 'Paul E.', 'reviewed': false},
          ]),
    ]);
    expect(find.text('Noter ce mentor'), findsOneWidget);
    expect(find.text('Accepter'), findsOneWidget);
    expect(find.text('Décliner'), findsOneWidget);
    expect(find.text('Acceptée'), findsOneWidget);
    expect(find.text('En attente'), findsNWidgets(2));
  });
}
