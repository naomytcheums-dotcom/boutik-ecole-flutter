import 'package:boutik_ecole/figma/g/g_103.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/communities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

/// Écran 103 « Communauté » : annuaire réel des communautés (serveur simulé ici ; la logique serveur est testée sur la base locale
/// isolée par supabase/tests/communautes_local.sql, 62 contrôles).

class _Liste extends CommunitiesNotifier {
  _Liste(this.items);
  final List<Community>? items;
  @override
  List<Community>? build() => items;
}

class _Erreur extends CommunitiesMessage {
  @override
  String build() => 'Les communautés ne peuvent pas être chargées pour le moment.';
}

const _publique = Community(id: '1', name: 'Développeurs du Cameroun', description: '', category: 'tech', privacy: 'public', members: 12);
const _approbation = Community(id: '2', name: 'Designers et créatifs', description: '', category: 'design', privacy: 'approval', members: 1, myStatus: 'pending');
const _membre = Community(id: '3', name: 'Entrepreneurs étudiants', description: '', category: 'business', privacy: 'public', members: 40, myStatus: 'active', myRole: 'member');

void main() {
  setUpAll(loadAppFonts);
  tearDown(() => Backend.ready = false);

  test('libellés selon l\'état et la confidentialité', () {
    expect(_publique.actionLabel, 'Rejoindre');
    expect(_publique.privacyLabel, 'Publique');
    expect(_publique.membersLabel, '12 membres');
    expect(_approbation.actionLabel, 'Demande envoyée');
    expect(_approbation.membersLabel, '1 membre');
    expect(_membre.actionLabel, 'Membre');
    expect(_membre.isMember, isTrue);
    expect(const Community(id: '4', name: 'Fermée', description: '', category: '', privacy: 'approval', members: 3).actionLabel, 'Demander à rejoindre');
    expect(const Community(id: '5', name: 'Cercle', description: '', category: '', privacy: 'invite', members: 3, myStatus: 'invited').actionLabel, 'Accepter l’invitation');
    expect(const Community(id: '6', name: 'X', description: '', category: '', privacy: 'public', members: 3, myStatus: 'banned').actionLabel, 'Accès refusé');
  });

  test('lecture d\'une ligne du serveur', () {
    final c = Community.fromRow({'id': 'u1', 'name': 'Test', 'privacy': 'invite', 'members': 5, 'my_status': 'active', 'my_role': 'owner'});
    expect([c.id, c.privacy, c.members, c.myStatus, c.myRole], ['u1', 'invite', 5, 'active', 'owner']);
    final vide = Community.fromRow({'id': 'u2', 'name': 'Sans lien'});
    expect([vide.members, vide.myStatus, vide.privacy], [0, null, 'public']);
  });

  Future<void> monter(WidgetTester t, List<Override> overrides) async {
    Backend.ready = true;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(390, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: overrides, child: const MaterialApp(home: Scaffold(body: G_103()))));
    await t.pumpAndSettle();
  }

  testWidgets('103 connecté : les communautés viennent du serveur, aucun nom ni chiffre de maquette', (t) async {
    await monter(t, [communitiesProvider.overrideWith(() => _Liste(const [_publique, _approbation, _membre]))]);
    expect(find.text('Développeurs du Cameroun'), findsOneWidget);
    expect(find.text('12 membres · Publique'), findsOneWidget);
    expect(find.text('Rejoindre'), findsOneWidget);
    expect(find.text('Demande envoyée'), findsOneWidget);
    expect(find.text('Membre'), findsOneWidget);
    expect(find.text('Créer une communauté'), findsOneWidget);
    for (final faux in ['Rodrigue Fotso', 'Carine Mbarga', 'Landry Essomba', 'Entrepreneurs de l’IUT', '124 membres', '86 membres', 'Innovation et prototypes']) {
      expect(find.text(faux), findsNothing, reason: faux);
    }
  });

  testWidgets('103 connecté : état vide et erreur lisibles', (t) async {
    await monter(t, [communitiesProvider.overrideWith(() => _Liste(const []))]);
    expect(find.textContaining('Aucune communauté pour le moment'), findsOneWidget);
  });

  testWidgets('103 connecté : une erreur de lecture ne montre aucun texte technique', (t) async {
    await monter(t, [communitiesProvider.overrideWith(() => _Liste(const [])), communitiesErrorProvider.overrideWith(_Erreur.new)]);
    expect(find.text('Les communautés ne peuvent pas être chargées pour le moment.'), findsOneWidget);
    expect(find.textContaining('permission'), findsNothing);
  });

  testWidgets('103 hors connexion : la démonstration de la maquette reste affichée', (t) async {
    GAnim.enabled = false;
    t.view.physicalSize = const Size(390, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(const ProviderScope(child: MaterialApp(home: Scaffold(body: G_103()))));
    await t.pumpAndSettle();
    expect(find.text('Entrepreneurs de l’IUT'), findsOneWidget);
    expect(find.text('Créer une communauté'), findsNothing);
  });
}
