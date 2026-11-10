import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/render.dart';

/// Les quatre écrans de la rubrique « Applications connectées » (271, 280, P3, P5) et leurs sous-écrans, hors connexion au serveur :
/// aucune connexion n'est simulée, l'état « connecté » n'apparaît jamais sans compte réel.
void main() {
  setUpAll(loadAppFonts);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Backend.ready = false;
  });
  tearDown(() => GScreen.mockupFrame = true);

  Future<void> descendre(WidgetTester t, Finder f) => t.dragUntilVisible(f, find.byType(ListView).first, const Offset(0, -300));

  testWidgets('P5 : toutes les familles, aucune fausse connexion', (t) async {
    await pumpScreen(t, 'P5');
    expect(find.text('Connecter mes outils'), findsOneWidget);
    expect(find.text('Facebook'), findsOneWidget);
    expect(find.text('Connecté'), findsNothing);
    expect(find.text('Mes contenus connectés'), findsOneWidget);
    expect(find.text('Publier sur mes réseaux'), findsOneWidget);
    await descendre(t, find.text('Slack'));
    expect(find.text('Slack'), findsOneWidget);
    await descendre(t, find.text('MTN Mobile Money'));
    expect(find.text('MTN Mobile Money'), findsOneWidget);
    expect(find.text('Aucun numéro'), findsWidgets);
  });

  testWidgets('P5 : la recherche filtre les fournisseurs', (t) async {
    await pumpScreen(t, 'P5');
    await t.enterText(find.byType(TextField).first, 'git');
    await t.pumpAndSettle();
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('Facebook'), findsNothing);
    await t.enterText(find.byType(TextField).first, 'zzzz');
    await t.pumpAndSettle();
    expect(find.text('Aucun résultat pour cette recherche.'), findsOneWidget);
  });

  testWidgets('fiche d’un fournisseur : permissions, limites officielles, alternative, bouton désactivé tant que non configuré', (t) async {
    await pumpScreen(t, 'P5');
    await t.tap(find.text('Facebook'));
    await t.pumpAndSettle();
    expect(find.text('Permissions demandées'), findsOneWidget);
    expect(find.text('Publier sur vos Pages'), findsOneWidget);
    expect(find.text('Limites de l’API officielle'), findsOneWidget);
    expect(find.textContaining('que les Pages Facebook'), findsOneWidget);
    expect(find.textContaining('Alternative'), findsOneWidget);
    // Administrateur (compte des tests) : liste de ce que le propriétaire doit fournir.
    final liste = find.byType(ListView).last;
    await t.dragUntilVisible(find.text('À fournir par le propriétaire'), liste, const Offset(0, -200));
    expect(find.textContaining('FACEBOOK_CLIENT_ID'), findsOneWidget);
    // Hors connexion / non configuré : la connexion est impossible et le message le dit.
    await t.dragUntilVisible(find.text('Connecter Facebook'), liste, const Offset(0, -200));
    expect(find.text('Connecter Facebook'), findsOneWidget);
    await t.drag(liste, const Offset(0, -300));
    await t.pumpAndSettle();
    expect(find.textContaining('ne répond pas pour le moment'), findsOneWidget);
  });

  testWidgets('Behance : aucun OAuth, adresse publique du portfolio', (t) async {
    await pumpScreen(t, 'P5');
    await descendre(t, find.text('Behance'));
    await t.tap(find.text('Behance'));
    await t.pumpAndSettle();
    expect(find.text('Adresse publique de votre portfolio'), findsOneWidget);
    expect(find.text('Enregistrer le lien'), findsOneWidget);
    expect(find.textContaining('n’ouvre plus de nouvelles clés'), findsOneWidget);
  });

  testWidgets('271 : réseaux du profil + autres liens conservés', (t) async {
    await pumpScreen(t, '271');
    expect(find.text('Mes liens et réseaux'), findsOneWidget);
    expect(find.text('Instagram'), findsOneWidget);
    expect(find.text('Slack'), findsNothing);
    expect(find.text('Autres liens du profil'), findsOneWidget);
    expect(find.text('+ Ajouter un autre lien'), findsOneWidget);
  });

  testWidgets('P3 : sans compte relié, un message clair', (t) async {
    await pumpScreen(t, 'P3');
    expect(find.text('Avis et outils connectés'), findsOneWidget);
    expect(find.textContaining('Aucun compte relié'), findsOneWidget);
  });

  testWidgets('280 : état des connecteurs et accès à l’API publique existante', (t) async {
    await pumpScreen(t, '280');
    expect(find.text('Intégrations'), findsOneWidget);
    expect(find.text('YouTube'), findsOneWidget);
    await descendre(t, find.text('API publique, clés d’intégration, webhooks'));
    expect(find.text('API publique, clés d’intégration, webhooks'), findsOneWidget);
  });

  testWidgets('Mes contenus connectés et Publier : états vides honnêtes', (t) async {
    await pumpScreen(t, 'P5');
    await t.tap(find.text('Mes contenus connectés'));
    await t.pumpAndSettle();
    expect(find.textContaining('Rien n’est importé'), findsOneWidget);
    await t.tap(find.byIcon(Icons.arrow_back));
    await t.pumpAndSettle();
    await t.tap(find.text('Publier sur mes réseaux'));
    await t.pumpAndSettle();
    expect(find.textContaining('Aucune destination disponible'), findsOneWidget);
    expect(find.text('Choisissez une destination'), findsOneWidget);
  });

  testWidgets('Mobile Money : aucun envoi possible sans numéro vérifié, envois non activés dits clairement', (t) async {
    await pumpScreen(t, 'P5');
    await t.tap(find.text('Mobile Money').first);
    await t.pumpAndSettle();
    expect(find.text('Envois pas encore activés'), findsOneWidget);
    expect(find.textContaining('Aucun numéro enregistré'), findsOneWidget);
    await t.tap(find.text('Envoyer'));
    await t.pumpAndSettle();
    expect(find.text('Aucun numéro vérifié'), findsOneWidget);
  });
}
