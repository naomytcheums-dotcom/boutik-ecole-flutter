import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';
import '../helpers/screen_texts.dart';

void main() {
  expectScreenTexts(const {
    '78': ['Projets innovants', 'Drone éducatif connecté', 'Projets à découvrir'],
    '79': ['Système de filtration d’eau', '72 %', 'Soutenir le projet'],
    '80': ['Soumettre un projet', 'Stade d’avancement', 'Ajouter des membres'],
    '81': ['Équipe du projet', 'Kouassi Tagne', 'Répartition des responsabilités'],
    '82': ['Journal du projet', 'Tests en laboratoire', 'Ajouter une étape'],
    '83': ['Médias et preuves', 'Résultats des tests.xlsx', 'Téléverser'],
    '84': ['Nouvelle campagne', 'Financement participatif', 'Ajouter des contreparties'],
    '84b': ['Financement', '1 250 000 FCFA', '2 000 000 FCFA'],
    '85': ['Objectifs et jalons', 'Objectif : 2 000 000 FCFA', 'Utilisation des fonds'],
    '86': ['Résultats de campagne', '26 000 FCFA', 'Derniers contributeurs'],
    '87': ['Registre des innovations', 'Filtre à sable modulaire', 'Déclarer une innovation'],
  });

  testWidgets('78 : le filtre « Terminés » ne garde que le projet terminé', (tester) async {
    await pumpScreen(tester, '78');
    await tester.ensureVisible(find.text('Terminés'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terminés'));
    await tester.pumpAndSettle();
    expect(find.text('Application covoiturage'), findsOneWidget);
    expect(find.text('Serre intelligente'), findsNothing);
  });

  testWidgets('87 : la recherche filtre le registre', (tester) async {
    await pumpScreen(tester, '87');
    await tester.enterText(find.byType(TextField).first, 'serre');
    await tester.pumpAndSettle();
    expect(find.text('Serre intelligente'), findsOneWidget);
    expect(find.text('Support de téléphone'), findsNothing);
  });

  testWidgets('80 : un titre vide bloque la soumission', (tester) async {
    await pumpScreen(tester, '80');
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    expect(find.text('Le titre est obligatoire (3 à 80 caractères).'), findsOneWidget);
  });
}

