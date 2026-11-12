import 'package:boutik_ecole/figma/live/communities.dart';
import 'package:boutik_ecole/figma/live/community_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _row({String kind = 'interest', Object? official = false, int members = 3, int postsWeek = 0, DateTime? created, DateTime? last}) => {
      'id': '1',
      'name': 'Dev Flutter',
      'description': 'Entraide autour de Flutter',
      'privacy': 'public',
      'members': members,
      'status': 'active',
      'kind': kind,
      'promo_year': kind == 'promo' ? 'Promo 2026' : null,
      'interest': kind == 'interest' ? 'Flutter' : null,
      'official': official,
      'created_at': (created ?? DateTime(2026, 1, 1)).toIso8601String(),
      'last_activity': last?.toIso8601String(),
      'posts_week': postsWeek,
      'owner_kind': 'student',
    };

void main() {
  final now = DateTime(2026, 11, 14, 12);

  test('type et libellés', () {
    expect(Community.fromRow(_row(kind: 'filiere')).kindLabel, 'Filière');
    expect(Community.fromRow(_row(kind: 'promo')).kindLabel, 'Promo 2026');
    expect(Community.fromRow(_row(kind: 'alumni')).kindLabel, 'Alumni');
    expect(Community.fromRow(_row(kind: 'project')).kindLabel, 'Projet');
    expect(Community.fromRow(_row()).kindLabel, 'Flutter');
    expect(Community.fromRow(_row()).adminLabel, 'Étudiant');
  });

  test('badges : Officiel IUT, Populaire, Nouveau', () {
    expect(Community.fromRow(_row()).badges(now), isEmpty);
    expect(Community.fromRow(_row(official: true)).badges(now), ['Officiel IUT']);
    expect(Community.fromRow(_row(members: 80)).badges(now), ['Populaire']);
    expect(Community.fromRow(_row(postsWeek: 12)).badges(now), ['Populaire']);
    expect(Community.fromRow(_row(created: DateTime(2026, 11, 10))).badges(now), ['Nouveau']);
    expect(Community.fromRow(_row(official: true, members: 60, created: DateTime(2026, 11, 13))).badges(now), ['Officiel IUT', 'Populaire', 'Nouveau']);
  });

  test('dernière activité', () {
    expect(Community.fromRow(_row()).activityLabel(now), 'Aucune publication');
    expect(Community.fromRow(_row(last: now.subtract(const Duration(minutes: 5)))).activityLabel(now), 'Dernière publication il y a 5 min');
    expect(Community.fromRow(_row(last: now.subtract(const Duration(hours: 3)))).activityLabel(now), 'Dernière publication il y a 3 h');
    expect(Community.fromRow(_row(last: now.subtract(const Duration(days: 2)))).activityLabel(now), 'Dernière publication il y a 2 j');
  });

  testWidgets('carte : nom, type, membres, responsable, activité et badge', (t) async {
    final c = Community.fromRow(_row(official: true, last: now.subtract(const Duration(minutes: 5))));
    await t.pumpWidget(MaterialApp(home: Scaffold(body: Padding(padding: const EdgeInsets.all(12), child: CommunityCard(c: c, now: now)))));
    expect(find.text('Dev Flutter'), findsOneWidget);
    expect(find.text('Officiel IUT'), findsOneWidget);
    expect(find.textContaining('Flutter · 3 membres · Publique'), findsOneWidget);
    expect(find.textContaining('Administrateur : Étudiant · Dernière publication il y a 5 min'), findsOneWidget);
    expect(find.text('Rejoindre'), findsOneWidget);
  });

  testWidgets('fond design : gros texte centré ; sans fond, texte normal', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: Column(children: [StyledPostText('Qui a fait le TP ?', style: PostStyle('x', 'X', [Color(0xFF000000), Color(0xFF111111)], dark: true)), StyledPostText('Texte simple')]))));
    expect(find.text('Qui a fait le TP ?'), findsOneWidget);
    expect(find.text('Texte simple'), findsOneWidget);
    final big = t.widget<Text>(find.text('Qui a fait le TP ?'));
    expect(big.textAlign, TextAlign.center);
    expect(big.style!.fontSize, 24, reason: 'texte court : grande taille');
  });

  test('catalogue de fonds : 9 fonds, clés uniques, recherche par clé', () {
    expect(postStyles.length, 9);
    expect({for (final s in postStyles) s.key}.length, 9);
    expect(postStyleOf('ocean')!.label, 'Océan');
    expect(postStyleOf(null), isNull);
    expect(postStyleOf('inconnu'), isNull);
  });

  testWidgets('sondage : barres, votes, mon choix, vote par touche', (t) async {
    int? voted;
    await t.pumpWidget(MaterialApp(home: Scaffold(body: PollView(question: 'Quel jour ?', poll: const {'options': [{'label': 'Lundi', 'votes': 1}, {'label': 'Mardi', 'votes': 3}], 'total': 4, 'mine': 1}, onVote: (i) => voted = i))));
    expect(find.text('Quel jour ?'), findsOneWidget);
    expect(find.text('Lundi'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('4 votes'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget, reason: 'mon choix est marqué');
    await t.tap(find.text('Lundi'));
    expect(voted, 0);
  });
}
