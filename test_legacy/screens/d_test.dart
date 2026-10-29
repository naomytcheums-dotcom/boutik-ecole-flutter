import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';
import '../helpers/screen_texts.dart';

void main() {
  expectScreenTexts(const {
    '32': ['Détail du produit', 'Caractéristiques', '25 000 FCFA · En stock'],
    '33': ['Histoire du produit', 'De la chute de bois à la lumière', 'Étapes de fabrication'],
    '34': ['Galerie', 'Photos (12)', 'Vidéo de présentation'],
    '35': ['Disponibilité', 'Informations de stock', '25 000 FCFA · 15 unités au total'],
    '36': ['Détail du service', 'Formules', '150 000 FCFA'],
    '38': ['Réputation', 'Badges de confiance', '38 avis · 98 % de recommandations'],
    '39': ['Demande de renseignements', 'Votre téléphone (facultatif)', '25 000 FCFA · Yannick M.'],
    '40': ['Demande de devis', 'Description du besoin', '50 000 – 80 000 FCFA'],
  });

  testWidgets('32 : les onglets changent le texte affiché', (tester) async {
    await pumpScreen(tester, '32');
    expect(find.textContaining('Lampe décorative'), findsOneWidget);
    await tester.tap(find.text('Livraison'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Lampe décorative'), findsNothing);
    expect(find.textContaining('Retrait gratuit au kiosque'), findsOneWidget);
  });

  testWidgets('39 : la question est obligatoire et le téléphone validé', (tester) async {
    await pumpScreen(tester, '39');
    await tester.enterText(find.byType(TextField).first, '');
    await tester.enterText(find.byType(TextField).at(1), '12345');
    await tester.tap(find.text('Envoyer la question'));
    await tester.pumpAndSettle();
    expect(find.text('Écrivez votre question (10 caractères minimum).'), findsOneWidget);
    expect(find.text('Numéro invalide : 9 chiffres commençant par 6.'), findsOneWidget);
    // Un sujet réécrit le modèle de question vidé.
    await tester.tap(find.text('Délai'));
    await tester.enterText(find.byType(TextField).at(1), '699001122');
    await tester.tap(find.text('Envoyer la question'));
    await tester.pumpAndSettle();
    expect(find.text('Question envoyée'), findsOneWidget);
  });

  testWidgets('40 : le besoin est obligatoire, le budget se choisit', (tester) async {
    await pumpScreen(tester, '40');
    await tester.tap(find.text('Envoyer la demande'));
    await tester.pumpAndSettle();
    expect(find.text('Décrivez votre besoin en 20 caractères minimum.'), findsOneWidget);
    await tester.tap(find.text('50\u00A0000 – 80\u00A0000\u00A0FCFA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('80\u00A0000 – 150\u00A0000\u00A0FCFA'));
    await tester.pumpAndSettle();
    expect(find.textContaining('150\u00A0000\u00A0FCFA'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), 'Un site vitrine de cinq pages pour notre club.');
    await tester.tap(find.text('Envoyer la demande'));
    await tester.pumpAndSettle();
    expect(find.text('Décrivez votre besoin en 20 caractères minimum.'), findsNothing);
    expect(find.text('Demande envoyée'), findsOneWidget);
  });
}
