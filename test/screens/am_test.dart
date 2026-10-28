import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';
import '../helpers/screen_texts.dart';

void main() {
  expectScreenTexts(const {
    '240': ['Parrainer et gagner', 'boutik-ecole.cm/r/mariam24', 'Mes gains · 12 500 FCFA'],
    '241': ['Mes contacts', 'Autoriser l’accès aux contacts', 'Envoyer via WhatsApp (3)'],
    '242': ['Kit à partager', 'Gagne à chaque publication validée', '+ 500 F'],
    '243': ['Mes gains', '12 500 FCFA', 'Retirer vers Orange Money'],
    '244': ['Cercle', 'Lampe en bois recyclé', 'Voir l’article · 25 000 F'],
    '244b': ['Cercle', '249', 'S’abonner'],
    '245': ['Reels', 'Son original · Brice N.', '2,6 k'],
    '246': ['Lives', 'En direct maintenant', 'Montage d’un kit solaire en direct'],
    '247': ['@aminata.studio', 'Aminata Bello', 'Mes réseaux'],
    '248': ['Boutique d’Aminata', 'Ajouter un article', 'À partir de 80 000 F'],
    '249': ['Créer', 'Article de boutique', '2 publications non terminées'],
    '250': ['Nouvelle publication', 'Publier aussi sur mes réseaux', 'Connecter ce compte'],
    '251': ['Découvrir', 'Tendances', 'Talents à suivre'],
    '252': ['Lampe en bois recyclé', '25 000 FCFA', '12 avis vérifiés'],
    '253': ['Défis et récompenses', 'Série de 5 jours', 'Récupérer'],
    '253b': ['Série de 6 jours', 'Récupérée ✓', 'Défis de la semaine'],
    '254': ['Activité', 'Kéla · rappel intelligent', 'Mme Mbella a vu ta boutique'],
  });

  testWidgets('253 : récupérer la récompense prolonge la série', (tester) async {
    await pumpScreen(tester, '253');
    await tester.tap(find.text('Récupérer'));
    await tester.pumpAndSettle();
    expect(find.text('Récupérée ✓'), findsOneWidget);
    expect(find.text('Série de 6 jours'), findsOneWidget);
  });

  testWidgets('241 : décocher un contact met à jour le bouton d’envoi', (tester) async {
    await pumpScreen(tester, '241');
    await tester.tap(find.text('Brice Ndoumbe'));
    await tester.pumpAndSettle();
    expect(find.text('Envoyer via WhatsApp (2)'), findsOneWidget);
  });

  testWidgets('250 : une légende vide bloque la publication', (tester) async {
    await pumpScreen(tester, '250');
    await tester.enterText(find.byType(TextField).first, '');
    await tester.tap(find.text('Publier'));
    await tester.pumpAndSettle();
    expect(find.text('Ajoute une légende avant de publier.'), findsOneWidget);
  });
}
