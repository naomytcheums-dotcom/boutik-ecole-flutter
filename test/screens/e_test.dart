import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';
import '../helpers/screen_texts.dart';

void main() {
  expectScreenTexts(const {
    '41': ['Adresse de livraison', 'Nom du destinataire', 'Enregistrer cette adresse dans mon carnet'],
    '42': ['Récapitulatif', 'Retrait sur campus', '330 000 FCFA'],
    '43': ['Instructions de paiement', 'Numéro marchand', '330 000 FCFA'],
    '44': ['Commande confirmée', 'Merci pour votre commande !', '330 000 FCFA'],
    '45': ['Mes commandes', '12 commandes', '32 500 FCFA'],
    '46': ['Suivi de livraison', 'En route vers le kiosque', '482 915'],
    '47': ['Annuler la commande', 'Motif de l’annulation', '25 000 FCFA'],
    '48': ['Réclamation', 'Article non reçu', '17 000 FCFA'],
    '49': ['Aide et support', 'Questions fréquentes', 'Besoin d’aide ?'],
  });

  testWidgets('41 : le téléphone est obligatoire et validé', (tester) async {
    await pumpScreen(tester, '41');
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    expect(find.text('Numéro invalide : 9 chiffres commençant par 6.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(1), '699001122');
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    expect(find.text('Numéro invalide : 9 chiffres commençant par 6.'), findsNothing);
    expect(find.text('Nom du destinataire'), findsNothing);
  });

  testWidgets('45 : les filtres et la recherche réduisent la liste', (tester) async {
    await pumpScreen(tester, '45');
    expect(find.text('#BE-2026-0142'), findsOneWidget);
    await tester.tap(find.text('Annulées'));
    await tester.pumpAndSettle();
    expect(find.text('1 commande'), findsOneWidget);
    expect(find.text('#BE-2026-0119'), findsOneWidget);
    expect(find.text('#BE-2026-0142'), findsNothing);
    await tester.tap(find.text('Toutes'));
    await tester.enterText(find.byType(TextField).first, '9999');
    await tester.pumpAndSettle();
    expect(find.text('Aucune commande trouvée'), findsOneWidget);
  });

  testWidgets('48 : une réclamation exige des détails', (tester) async {
    await pumpScreen(tester, '48');
    await tester.tap(find.text('Envoyer la demande'));
    await tester.pumpAndSettle();
    expect(find.text('Décrivez le problème en 20 caractères minimum.'), findsOneWidget);
    await tester.tap(find.text('Article endommagé ou non conforme'));
    await tester.enterText(find.byType(TextFormField).first, 'Le sac est arrivé avec une bretelle déchirée.');
    await tester.tap(find.text('Envoyer la demande'));
    await tester.pumpAndSettle();
    expect(find.text('Décrivez le problème en 20 caractères minimum.'), findsNothing);
  });
}
