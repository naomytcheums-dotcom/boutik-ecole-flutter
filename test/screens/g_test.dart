import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';
import '../helpers/screen_texts.dart';

void main() {
  expectScreenTexts(const {
    '57': ['Tableau de bord', '1 245 000', 'Commandes à préparer'],
    '58': ['Nouveau produit', 'Ajouter des photos', 'Quantité en stock'],
    '59': ['Nouveau service', 'Tarif à partir de (FCFA)', 'Mode de prestation'],
    '60': ['Modifier l’annonce', '25 000 FCFA · Aperçu client', 'Kiosque IUT – Bloc A'],
    '61': ['Mon catalogue', 'Tous (14)', 'Support téléphone'],
    '62': ['Stocks', '128 unités', 'Articles à surveiller'],
    '63': ['Commandes reçues', 'À préparer (4)', '#BE-2026-0139'],
    '64': ['Préparer #BE-2026-0142', 'Liste de contrôle', 'Marquer prête'],
    '65': ['Vente #BE-2026-0142', '23 750 FCFA', '– 1 250 FCFA'],
    '66': ['Revenus', '845 000 FCFA', 'Relevé octobre 2026'],
    '67': ['Statistiques', '4 280', 'Annonces les plus performantes'],
    '69': ['Validations', '85%', '3 justificatifs sur 4 validés'],
  });

  testWidgets('61 : l’onglet Rupture ne garde que les articles épuisés', (tester) async {
    await pumpScreen(tester, '61');
    await tester.ensureVisible(find.text('Rupture').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rupture').first);
    await tester.pumpAndSettle();
    expect(find.text('Tableau décoratif'), findsOneWidget);
    expect(find.text('Sac à dos design'), findsNothing);
  });

  testWidgets('67 : changer de période met à jour les indicateurs', (tester) async {
    await pumpScreen(tester, '67');
    await tester.tap(find.text('12 mois'));
    await tester.pumpAndSettle();
    expect(find.text('38 950'), findsOneWidget);
  });

  testWidgets('64 : impossible de marquer prête tant que la liste n’est pas cochée', (tester) async {
    await pumpScreen(tester, '64');
    await tester.tap(find.text('Marquer prête'));
    await tester.pump();
    expect(find.text('Cochez tous les points de la liste de contrôle.'), findsOneWidget);
  });

  testWidgets('58 : un titre vide est refusé', (tester) async {
    await pumpScreen(tester, '58');
    await tester.tap(find.text('Publier'));
    await tester.pumpAndSettle();
    expect(find.text('Le titre est obligatoire (3 à 80 caractères).'), findsOneWidget);
    expect(find.byType(TextFormField), findsWidgets);
  });
}
