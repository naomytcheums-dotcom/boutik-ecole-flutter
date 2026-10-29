import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';
import '../helpers/screen_texts.dart';

void main() {
  expectScreenTexts(const {
    '100': ['Événements', 'Cette semaine', 'Salon des créations étudiantes'],
    '101': ['Exposition des innovations', '86 / 150', 'Programme'],
    '102': ['Vitrine', 'Collection « Recyclé & Design »', 'Pièces à l’honneur'],
    '103': ['Communauté', 'Rodrigue Fotso', 'Groupes populaires'],
    '104': ['Carte de l’innovation', 'Atelier Génie civil', 'Kiosque de retrait – Bloc A'],
    '105': ['Inter-établissements', 'Créations des autres IUT', '45 000 FCFA'],
    '106': ['Économie circulaire', 'Seconde vie, premier choix', '6 000 FCFA'],
    '107': ['Mon impact', '48 kg', 'Objectif de l’année'],
    '237': ['Impact par territoire', 'Régions les plus actives', 'Voir la région'],
    '238': ['Impact de Boutik-École', '48 M', 'Par région'],
    '239': ['Rapport sponsors · T3 2026', '2 400 000 FCFA', 'Hackathon Orange 2026'],
  });

  testWidgets('101 : s’inscrire réserve une place', (tester) async {
    await pumpScreen(tester, '101');
    await tester.tap(find.text('S’inscrire'));
    await tester.pumpAndSettle();
    expect(find.text('85 / 150'), findsOneWidget);
    expect(find.text('Inscription confirmée'), findsOneWidget);
  });

  testWidgets('103 : se connecter à un ancien', (tester) async {
    await pumpScreen(tester, '103');
    expect(find.text('Connecté'), findsOneWidget);
    await tester.tap(find.text('Se connecter').first);
    await tester.pumpAndSettle();
    expect(find.text('Connecté'), findsNWidgets(2));
  });

  testWidgets('100 : le filtre « Ateliers » ne garde que l’atelier', (tester) async {
    await pumpScreen(tester, '100');
    await tester.tap(find.text('Ateliers'));
    await tester.pumpAndSettle();
    expect(find.text('Atelier : lancer sa micro-entreprise'), findsOneWidget);
    expect(find.text('Exposition des innovations'), findsNothing);
  });
}
