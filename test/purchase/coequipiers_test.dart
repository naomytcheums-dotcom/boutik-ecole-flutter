import 'package:boutik_ecole/figma/live/coequipiers_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester t, Widget w, {List<Override> overrides = const []}) async {
  t.view.physicalSize = const Size(420, 1800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: w)));
  await t.pumpAndSettle();
}

const _cats = [
  MateCategory(id: 'c1', label: 'Développeurs', keywords: ['flutter', 'web']),
  MateCategory(id: 'c2', label: 'Designers', keywords: ['figma']),
  MateCategory(id: 'c3', label: 'Masquée', keywords: ['x'], active: false),
];

Map<String, dynamic> _mate(String id, String name, {String invite = '', String dept = 'Génie informatique', String skills = 'Flutter, Python'}) =>
    {'id': id, 'name': name, 'department': dept, 'skills': skills, 'avatar_url': null, 'certified': false, 'invite': invite.isEmpty ? null : invite};

void main() {
  test('libellés : invitation et compteur', () {
    expect(mateInviteLabel(null), 'Inviter');
    expect(mateInviteLabel('pending'), 'En attente');
    expect(mateInviteLabel('accepted'), 'Dans l’équipe');
    expect(mateInviteLabel('declined'), 'Réinviter');
    expect(mateCountLabel(0), 'Aucun talent trouvé');
    expect(mateCountLabel(1), '1 talent disponible');
    expect(mateCountLabel(5), '5 talents disponibles');
  });

  test('requête : paramètres envoyés au serveur', () {
    const q = MateQuery();
    expect(q.params, {'p_query': '', 'p_limit': 40});
    expect(q.filtered, isFalse);
    final f = q.copy(q: ' flutter ', category: 'c1', department: ' Gestion ');
    expect(f.params['p_query'], 'flutter');
    expect(f.params['p_category'], 'c1');
    expect(f.params['p_department'], 'Gestion');
    expect(f.filtered, isTrue);
    expect(const MateQuery(q: 'a') == const MateQuery(q: 'a'), isTrue);
    expect(const MateQuery(q: 'a') == const MateQuery(q: 'b'), isFalse);
  });

  test('catégorie : lue depuis le serveur', () {
    final k = MateCategory.fromJson({'id': 'x', 'label': 'IA et data', 'keywords': ['ia', 'data'], 'active': false});
    expect(k.label, 'IA et data');
    expect(k.keywords, ['ia', 'data']);
    expect(k.active, isFalse);
  });

  testWidgets('page : menu du bas, recherche, filtres, catégories de l’admin, talents', (t) async {
    final asked = <MateQuery>[];
    await _pump(t, const TeammatesScreen(), overrides: [
      mateCategoriesProvider.overrideWith((ref) async => _cats.where((c) => c.active).toList()),
      matesSearchProvider.overrideWith((ref, q) async {
        asked.add(q);
        return [_mate('1', 'Awa E.'), _mate('2', 'Boris E.', invite: 'pending', skills: 'Figma')];
      }),
    ]);
    expect(find.text('Trouver des coéquipiers'), findsOneWidget);
    expect(find.byType(MateNavPill), findsOneWidget, reason: 'le menu du bas doit être là');
    expect(find.text('2 talents disponibles'), findsOneWidget);
    expect(find.text('Awa E.'), findsOneWidget);
    expect(find.text('Génie informatique · Flutter, Python'), findsNWidgets(1));
    expect(find.text('Inviter'), findsOneWidget);
    expect(find.text('En attente'), findsOneWidget);
    expect(find.text('Tous'), findsOneWidget);
    expect(find.text('Développeurs'), findsOneWidget);
    expect(find.text('Designers'), findsOneWidget);
    expect(find.text('Masquée'), findsNothing);
    expect(find.text('Gérer les catégories'), findsNothing, reason: 'réservé à l’administrateur');
    expect(find.textContaining('SMS'), findsNothing, reason: 'on ne promet pas des canaux qui n’existent pas');
    // la loupe cherche sur la page, sans changer d’écran
    await t.enterText(find.byType(TextField), 'figma');
    await t.tap(find.byIcon(Icons.search));
    await t.pumpAndSettle();
    expect(asked.last.q, 'figma');
    expect(find.text('Trouver des coéquipiers'), findsOneWidget);
    // une catégorie filtre côté serveur
    await t.tap(find.text('Designers'));
    await t.pumpAndSettle();
    expect(asked.last.category, 'c2');
    // le bouton réglages ouvre un vrai panneau de filtres
    await t.tap(find.byIcon(Icons.tune));
    await t.pumpAndSettle();
    expect(find.text('Filtrer les talents'), findsOneWidget);
    expect(find.text('Appliquer'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextField, 'Filière'), 'Gestion');
    await t.tap(find.text('Appliquer'));
    await t.pumpAndSettle();
    expect(asked.last.department, 'Gestion');
    expect(asked.last.category, 'c2');
  });

  testWidgets('page : liste vide claire', (t) async {
    await _pump(t, const TeammatesScreen(), overrides: [
      mateCategoriesProvider.overrideWith((ref) async => <MateCategory>[]),
      matesSearchProvider.overrideWith((ref, q) async => <Map<String, dynamic>>[]),
    ]);
    expect(find.text('Aucun talent trouvé'), findsOneWidget);
    expect(find.textContaining('Aucun étudiant ne correspond'), findsOneWidget);
    expect(find.byType(MateNavPill), findsOneWidget);
  });

  testWidgets('administrateur : ajouter, modifier, supprimer des catégories', (t) async {
    await _pump(t, const Scaffold(body: MateCategoriesAdminSheet()), overrides: [
      mateCategoriesProvider.overrideWith((ref) async => _cats),
    ]);
    expect(find.text('Catégories de coéquipiers'), findsOneWidget);
    expect(find.text('Développeurs'), findsOneWidget);
    expect(find.textContaining('Masquée · x'), findsOneWidget);
    expect(find.text('Ajouter une catégorie'), findsOneWidget);
    await t.tap(find.text('Ajouter une catégorie'));
    await t.pumpAndSettle();
    expect(find.text('Nouvelle catégorie'), findsOneWidget);
    expect(find.text('Mots-clés de compétence'), findsOneWidget);
    await t.tap(find.text('Annuler'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Supprimer').first);
    await t.pumpAndSettle();
    expect(find.textContaining('Supprimer « Développeurs »'), findsOneWidget);
    await t.tap(find.text('Annuler'));
    await t.pumpAndSettle();
  });

  testWidgets('invitations : reçues à accepter ou refuser, envoyées avec leur état', (t) async {
    await _pump(t, const Scaffold(body: MateInvitesSheet()), overrides: [
      myMateInvitesProvider('received').overrideWith((ref) async => [
            {'id': 'i1', 'status': 'pending', 'message': 'Hackathon Orange', 'other': 'Awa E.'},
            {'id': 'i2', 'status': 'declined', 'message': '', 'other': 'Cora E.'},
          ]),
      myMateInvitesProvider('sent').overrideWith((ref) async => [
            {'id': 'i3', 'status': 'accepted', 'message': '', 'other': 'Boris E.'},
          ]),
    ]);
    expect(find.text('Awa E. vous invite'), findsOneWidget);
    expect(find.text('Hackathon Orange'), findsOneWidget);
    expect(find.text('Accepter'), findsOneWidget);
    expect(find.text('Refuser'), findsOneWidget);
    expect(find.text('Déclinée'), findsOneWidget);
    expect(find.text('Boris E.'), findsOneWidget);
    expect(find.text('Acceptée'), findsOneWidget);
  });
}
