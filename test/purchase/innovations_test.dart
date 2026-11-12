import 'package:boutik_ecole/figma/live/innovations_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester t, Widget w, {List<Override> overrides = const []}) async {
  t.view.physicalSize = const Size(420, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: w)));
  await t.pumpAndSettle();
}

void main() {
  test('niveaux', () {
    expect(levelLabels['bronze'], 'Aidant Bronze');
    expect(levelLabels['legend'], 'Légende IUT');
    expect(levelLabels.keys, ['none', 'bronze', 'silver', 'gold', 'legend']);
  });

  testWidgets('accueil : les innovations, rien d’inventé sans points', (t) async {
    await _pump(t, const InnovationsScreen(), overrides: [myPointsProvider.overrideWith((ref) async => null)]);
    expect(find.text('SOS Cours'), findsOneWidget);
    expect(find.text('Défis hebdomadaires'), findsOneWidget);
    expect(find.text('Marché des compétences'), findsOneWidget);
    expect(find.text('Mur des victoires'), findsOneWidget);
    expect(find.text('Communauté éphémère'), findsOneWidget);
    expect(find.textContaining('points ·'), findsNothing);
  });

  testWidgets('accueil : mes points et mon niveau', (t) async {
    await _pump(t, const InnovationsScreen(), overrides: [
      myPointsProvider.overrideWith((ref) async => {'total': 55, 'level': 'bronze', 'next_at': 150, 'events': []}),
    ]);
    expect(find.text('55 points · Aidant Bronze'), findsOneWidget);
  });

  testWidgets('points : progression, derniers points, classement', (t) async {
    await _pump(t, const PointsScreen(), overrides: [
      myPointsProvider.overrideWith((ref) async => {
            'total': 55,
            'level': 'bronze',
            'next_at': 150,
            'events': [
              {'kind': 'challenge_win', 'points': 50},
              {'kind': 'sos_first', 'points': 15}
            ]
          }),
      topHelpersProvider.overrideWith((ref) async => [
            {'user_id': 'a', 'name': 'Awa A.', 'total': 55, 'level': 'bronze'}
          ]),
    ]);
    expect(find.text('55 points'), findsOneWidget);
    expect(find.text('Aidant Bronze'), findsWidgets);
    expect(find.text('Encore 95 points pour le niveau suivant.'), findsOneWidget);
    expect(find.text('Victoire à un défi'), findsOneWidget);
    expect(find.text('+50'), findsOneWidget);
    expect(find.text('Awa A.'), findsOneWidget);
  });

  testWidgets('SOS : mes SOS avec réponses, SOS de ma filière', (t) async {
    await _pump(t, const SosScreen(), overrides: [
      sosProvider('mine').overrideWith((ref) async => [
            {
              'id': '1',
              'subject': 'TP de réseaux',
              'status': 'open',
              'answers': [
                {'id': 'a', 'body': 'Regarde le routage statique', 'author': 'Paul E.', 'accepted': false}
              ]
            }
          ]),
      sosProvider('filiere').overrideWith((ref) async => [
            {'id': '2', 'subject': 'Algo : arbres', 'details': 'Je ne comprends pas', 'author': 'Cora C.', 'status': 'open', 'answers': []}
          ]),
    ]);
    expect(find.text('TP de réseaux'), findsOneWidget);
    expect(find.text('Cette réponse m’a aidé'), findsOneWidget);
    expect(find.text('Algo : arbres'), findsOneWidget);
    expect(find.textContaining('soyez le premier : +15 points'), findsOneWidget);
    expect(find.text('Je peux aider'), findsOneWidget);
  });

  testWidgets('défis : gagnant mis en avant, votes affichés', (t) async {
    await _pump(t, const ChallengesScreen(), overrides: [
      challengesProvider.overrideWith((ref) async => [
            {
              'id': 'c',
              'title': 'Défi Design',
              'description': 'Refais le logo',
              'kind': 'design',
              'ends_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
              'ended': true,
              'my_vote': null,
              'i_entered': true,
              'entries': [
                {'id': 'e1', 'title': 'Logo orange', 'author': 'Awa A.', 'url': '', 'votes': 2, 'winner': true, 'mine': false},
                {'id': 'e2', 'title': 'Logo bleu', 'author': 'Paul E.', 'url': '', 'votes': 0, 'winner': false, 'mine': false},
              ]
            }
          ]),
    ]);
    expect(find.text('Défi Design'), findsOneWidget);
    expect(find.text('🏆 Logo orange'), findsOneWidget);
    expect(find.text('2 votes'), findsOneWidget);
    expect(find.text('Participer'), findsNothing, reason: 'défi terminé');
  });

  testWidgets('compétences : annonces avec prix et échange, vide clair', (t) async {
    await _pump(t, const SkillsScreen(), overrides: [
      skillsProvider('').overrideWith((ref) async => [
            {'id': '1', 'kind': 'seek', 'title': 'Un poster pour mon projet', 'description': '', 'price': 5000, 'swap_for': '', 'author': 'Paul E.', 'mine': false, 'responded': false},
            {'id': '2', 'kind': 'swap', 'title': 'Je t’aide en maths', 'description': '', 'price': null, 'swap_for': 'Aide en anglais', 'author': 'Awa A.', 'mine': true, 'responses': 2, 'responded': false},
          ]),
    ]);
    expect(find.text('Un poster pour mon projet'), findsOneWidget);
    expect(find.textContaining('contre : Aide en anglais'), findsOneWidget);
    expect(find.textContaining('2 réponses'), findsOneWidget);
    expect(find.text('Répondre'), findsOneWidget);
    expect(find.text('Clôturer mon annonce'), findsOneWidget);
  });

  testWidgets('mur des victoires : vide clair', (t) async {
    await _pump(t, const VictoriesScreen(), overrides: [victoriesProvider.overrideWith((ref) async => <Map<String, dynamic>>[])]);
    expect(find.textContaining('Le mur est vide'), findsOneWidget);
  });

  testWidgets('mur des victoires : réussites et félicitations', (t) async {
    await _pump(t, const VictoriesScreen(), overrides: [
      victoriesProvider.overrideWith((ref) async => [
            {'id': 'v', 'kind': 'internship', 'body': 'J’ai eu mon stage chez Orange', 'author': 'Awa A.', 'cheers': 3, 'cheered': false}
          ]),
    ]);
    expect(find.text('J’ai eu mon stage chez Orange'), findsOneWidget);
    expect(find.text('3 félicitations'), findsOneWidget);
    expect(find.text('Stage obtenu · Awa A.'), findsOneWidget);
  });
}
