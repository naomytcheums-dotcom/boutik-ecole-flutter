import 'package:boutik_ecole/figma/live/opportunites_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget w) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: w)));

void main() {
  const base = {'id': 'o1', 'org': 'Orange', 'kind': 'stage', 'title': 'Stage développeur', 'location': 'Douala', 'mode': 'onsite', 'pay_kind': 'paid', 'deadline': null, 'skills': [], 'verified': true};

  testWidgets('offre avec vidéo : bandeau de présentation et bouton de lecture', (t) async {
    await t.pumpWidget(_wrap(OpportunityCard(o: {...base, 'media_path': 'u1/v.mp4', 'media_kind': 'video'})));
    expect(find.text('Vidéo de présentation'), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);
    expect(find.text('Stage développeur'), findsOneWidget);
  });

  testWidgets('offre sans média : aucun bandeau', (t) async {
    await t.pumpWidget(_wrap(OpportunityCard(o: {...base})));
    expect(find.text('Vidéo de présentation'), findsNothing);
    expect(find.byIcon(Icons.play_circle_fill), findsNothing);
    expect(find.text('Stage développeur'), findsOneWidget);
  });

  statsTests();
  matchTests();
  inviteTests();

  testWidgets('valeur « null » du serveur : traitée comme absente', (t) async {
    await t.pumpWidget(_wrap(OpportunityCard(o: {...base, 'media_path': null, 'media_kind': null})));
    expect(find.byIcon(Icons.play_circle_fill), findsNothing);
  });
}

void statsTests() {
  testWidgets('Mes opportunités : chiffres par offre (vues, favoris, candidatures, réponses, recrutés)', (t) async {
    t.view.physicalSize = const Size(420, 3000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(
      overrides: [
        oppMyPostedProvider.overrideWith((ref) async => [
              {'id': 'o1', 'org': 'Orange', 'title': 'Stage développeur', 'status': 'published', 'applications': 4}
            ]),
        oppMyApplicationsProvider.overrideWith((ref) async => <Map<String, dynamic>>[]),
        oppsProvider.overrideWith((ref, q) async => <Map<String, dynamic>>[]),
        oppStatsProvider.overrideWith((ref) async => {
              'o1': {'id': 'o1', 'views': 120, 'saves': 9, 'applications': 4, 'response_rate': 75, 'hired': 1}
            }),
      ],
      child: const MaterialApp(home: MyOpportunitiesScreen()),
    ));
    await t.pumpAndSettle();
    expect(find.text('120'), findsOneWidget);
    expect(find.text('Vues'), findsOneWidget);
    expect(find.text('75 %'), findsOneWidget);
    expect(find.text('Réponses'), findsOneWidget);
    expect(find.text('Recrutés'), findsOneWidget);
  });
}

void matchTests() {
  testWidgets('score de correspondance : pourcentage et détail lisible', (t) async {
    await t.pumpWidget(_wrap(matchBadge({'score': 82, 'skills': 50, 'skills_found': 2, 'skills_wanted': 2, 'department': 25, 'availability': 15, 'profile': 5})));
    expect(find.text('Correspondance 82 %'), findsOneWidget);
    expect(find.textContaining('Compétences 2/2'), findsOneWidget);
    expect(find.textContaining('Filière ✓'), findsOneWidget);
    expect(find.textContaining('Disponible'), findsOneWidget);
  });

  testWidgets('score absent : aucune pastille affichée', (t) async {
    await t.pumpWidget(_wrap(matchBadge(null)));
    expect(find.textContaining('Correspondance'), findsNothing);
  });
}

void inviteTests() {
  Future<void> pumpDetail(WidgetTester t, Map<String, dynamic>? invite) async {
    t.view.physicalSize = const Size(420, 3000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(
      overrides: [
        oppDetailProvider.overrideWith((ref, id) async => {'id': 'o1', 'org': 'Orange', 'kind': 'stage', 'title': 'Stage Flutter', 'status': 'published', 'mine': false, 'skills': [], 'missions': [], 'gains': [], 'mode': 'onsite', 'pay_kind': 'paid'}),
        oppInviteProvider.overrideWith((ref, id) async => invite),
      ],
      child: const MaterialApp(home: OpportunityDetailScreen(id: 'o1')),
    ));
    await t.pumpAndSettle();
  }

  testWidgets('étudiant invité : bandeau avec le mot de l’entreprise', (t) async {
    await pumpDetail(t, {'status': 'invited', 'org': 'Orange', 'message': 'Venez !'});
    expect(find.text('Orange vous invite à postuler'), findsOneWidget);
    expect(find.textContaining('Venez !'), findsOneWidget);
    expect(find.text('Non merci'), findsOneWidget);
  });

  testWidgets('sans invitation, ou déjà postulé : aucun bandeau', (t) async {
    await pumpDetail(t, null);
    expect(find.textContaining('vous invite à postuler'), findsNothing);
    await pumpDetail(t, {'status': 'applied', 'org': 'Orange', 'message': ''});
    expect(find.textContaining('vous invite à postuler'), findsNothing);
  });
}
