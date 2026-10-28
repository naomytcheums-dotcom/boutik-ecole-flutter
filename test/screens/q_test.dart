import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';
import '../helpers/screen_texts.dart';

void main() {
  expectScreenTexts(const {
    '148-1': ['Paramètres', 'mariam@iut-douala.cm', 'Données de démonstration'],
    '148-2': ['Centre de sécurité', 'Compte bien protégé', 'Se déconnecter de tous les appareils'],
    '149': ['Langue et affichage', 'English (Cameroon)', 'Taille du texte'],
    '150-1': ['Synchronisation', '72%', 'Aujourd’hui 10:24'],
    '150-2': ['Votre session a expiré', 'Se reconnecter', 'Erreur 403 · Droits insuffisants'],
    '150-3': ['Connexion impossible', 'Réessayer', 'Voir le mode hors ligne'],
    '150-4': ['Aucune commande pour le moment', 'Découvrir la boutique', 'Annulées'],
  });

  testWidgets('149 : choisir « Grand » agrandit le texte de l’application', (tester) async {
    await pumpScreen(tester, '149');
    final before = tester.getSize(find.text('Taille du texte')).height;
    await tester.tap(find.text('Grand'));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.text('Taille du texte')).height, greaterThan(before));
  });

  testWidgets('148-2 : déconnecter un appareil le retire de la liste', (tester) async {
    await pumpScreen(tester, '148-2');
    await tester.tap(find.text('Déconnecter'));
    await tester.pumpAndSettle();
    expect(find.text('Chrome • Windows'), findsNothing);
    expect(find.text('1 actif'), findsOneWidget);
  });
}
