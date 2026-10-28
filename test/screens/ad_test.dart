import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';
import '../helpers/screen_texts.dart';

void main() {
  expectScreenTexts(const {
    '216': ['Marché des vœux', 'Lampe en bois recyclé', '156 / 200 précommandes', '25 000 FCFA'],
    '217': ['Si 200 personnes la veulent, on la fabrique', 'Encore 44 précommandes', 'Précommander · 25 000 FCFA'],
    '218': [
      'Publier un vœu',
      'Seuil minimum de précommandes',
      'Votre département valide le vœu avant sa mise en ligne.',
    ],
    '219': ['Nouveau duel', 'Combien de propositions ?', '75 000 FCFA'],
    '220': ['Duel de talents', 'Reste 02:14:09', 'Voter pour la lampe', 'Classement de la semaine'],
    '221': ['Aminata Bello remporte le duel', '60 000 FCFA', 'Gagnante'],
    '222': ['Atelier en direct', 'EN DIRECT', '25 000 FCFA', 'Magnifique, quelle finition !'],
    '223': ['Ateliers en direct', 'Monter un kit solaire', 'Rappel'],
    '224': ['Validation des vœux', 'Sac en pagne recyclé', '12 000 FCFA'],
    '225': ['Jumeau 3D', 'Glissez pour tourner', 'Voir chez moi en réalité augmentée'],
    '226': ['Modération des duels', 'Affiche Festival IUT', '415 000 FCFA'],
    '227': ['Régie des ateliers en direct', 'Spectateurs cette semaine', '1 120 000 FCFA'],
    '228': ['Partager mon CV', 'boutik-ecole.cm/cv/mariam-essono', 'Régénérer le lien'],
    '229': ['Mariam Essono', 'Réalisations vérifiées', 'Proposer un stage'],
  });

  testWidgets('216 : le filtre « Presque atteints » ne garde que les vœux proches du seuil', (tester) async {
    await pumpScreen(tester, '216');
    await tester.tap(find.text('Presque atteints'));
    await tester.pumpAndSettle();
    expect(find.text('Lampe en bois recyclé'), findsOneWidget);
    expect(find.text('Kit solaire de poche'), findsNothing);
  });

  testWidgets('218 : un prix trop bas affiche le message d’erreur', (tester) async {
    await pumpScreen(tester, '218');
    await tester.enterText(find.byType(TextFormField).at(2), '500');
    await tester.tap(find.text('Publier'));
    await tester.pumpAndSettle();
    expect(find.text('Entrez un prix d’au moins 1 000 FCFA.'), findsOneWidget);
    expect(find.text('Décrivez le produit : 10 caractères minimum.'), findsOneWidget);
  });

  testWidgets('220 : voter met à jour le bouton et les votes', (tester) async {
    await pumpScreen(tester, '220');
    await tester.tap(find.text('Voter pour la lampe'));
    await tester.pumpAndSettle();
    expect(find.text('Vote enregistré'), findsOneWidget);
    expect(find.text('1\u00A0241 votes'), findsOneWidget);
  });
}
