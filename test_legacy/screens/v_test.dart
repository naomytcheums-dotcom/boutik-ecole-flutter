import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';
import '../helpers/screen_texts.dart';

void main() {
  expectScreenTexts(const {
    '175': ['Bienvenue, étudiant', 'Exposez vos talents', 'Participer aux hackathons'],
    '176': ['Bienvenue', 'Trouvez ce qui vous inspire', 'Retirer au kiosque'],
    '177': ['Bienvenue, entreprise', 'Trouvez vos futurs talents', 'Propositions classées par IA'],
    '178': ['Bienvenue, jury', 'Un espace de notation simple', 'Commencer'],
    '179': ['Guide d’utilisation', 'Prendre en main Boutik-École', 'Lancer la visite'],
    '180': ['Rôles et permissions', 'Règles du rôle Jury', '28 comptes'],
    '181': ['Matrice des permissions', 'Voir les finances', 'Resp. dép.'],
  });

  testWidgets('179 : la recherche filtre les guides', (tester) async {
    await pumpScreen(tester, '179');
    await tester.enterText(find.byType(TextField).first, 'hackathon');
    await tester.pumpAndSettle();
    expect(find.text('S’inscrire à un hackathon'), findsOneWidget);
    expect(find.text('Créer et publier une annonce'), findsNothing);
    await tester.enterText(find.byType(TextField).first, 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Aucun guide ne correspond à votre recherche.'), findsOneWidget);
  });

  testWidgets('180 : choisir un rôle affiche ses règles', (tester) async {
    await pumpScreen(tester, '180', size: const Size(1280, 900));
    await tester.tap(find.text('Entreprise'));
    await tester.pumpAndSettle();
    expect(find.text('Règles du rôle Entreprise'), findsOneWidget);
  });
}
