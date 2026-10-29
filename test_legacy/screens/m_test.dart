import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';
import '../helpers/screen_texts.dart';

void main() {
  expectScreenTexts(const {
    '117': ['Tableau de bord institutionnel', '48 700 000 FCFA', 'Départements les plus actifs'],
    '118': ['Établissement et identité visuelle', 'contact@iut-douala.cm', 'Enregistrer les modifications'],
    '119': ['Départements et filières', 'Bâtiment, Travaux publics', 'En création'],
    '120': ['Utilisateurs et affectations', 'Aujourd’hui 09:12', 'Suspendu'],
    '121': ['Responsables et encadreurs', 'Mentors externes', '18 projets'],
    '122': ['Circuits de validation', '2. Contrôle du département', 'Notification de l’étudiant'],
    '123': ['Ventes et activité', '28 400 000 FCFA', '19 160 FCFA'],
    '124': ['Événements et campagnes', 'Salon des créations étudiantes', 'Inscriptions ouvertes'],
    '125': ['Rapports consolidés', 'Rapports planifiés', '1er janv. 2027'],
    '126': ['Journal d’audit', 'Export des données', '197.15.x.x'],
  });

  testWidgets('126 : l’onglet « Validations » ne garde qu’une entrée', (tester) async {
    await pumpScreen(tester, '126', size: const Size(1280, 900));
    await tester.tap(find.text('Validations'));
    await tester.pumpAndSettle();
    expect(find.text('Annonce validée'), findsOneWidget);
    expect(find.text('Compte suspendu'), findsNothing);
  });

  testWidgets('120 : l’onglet « Suspendus » ne garde que Carine', (tester) async {
    await pumpScreen(tester, '120', size: const Size(1280, 900));
    await tester.tap(find.text('Suspendus'));
    await tester.pumpAndSettle();
    expect(find.text('Carine Mbarga'), findsOneWidget);
    expect(find.text('Mariam Essono'), findsNothing);
  });
}
