import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';
import '../helpers/screen_texts.dart';

void main() {
  expectScreenTexts(const {
    '108': ['Tableau de bord du département', '4 820 000 FCFA', 'Validations en attente'],
    '109': ['Étudiants et vendeurs', '1 245 000', 'Suspendu'],
    '110': ['Validation des annonces', 'Indicateurs de validation', '92 %'],
    '111': ['Validation des projets', 'Système de filtration d’eau', 'Panneaux solaires mobiles'],
    '112': ['Statistiques du département', '15 450 FCFA', 'Projets financés'],
    '113': ['Suivi des productions', 'Lot de 50 lampes recyclées', 'En retard'],
    '114': ['Mentors et encadreurs', 'Dr Paul Tchoupo', 'Ajouter un mentor'],
    '115': ['Événements et initiatives', 'Créer un événement', 'Budget utilisé'],
    '116': ['Rapports et exports', 'Historique des décisions', 'Pots non conformes'],
    '214': ['Départements', 'Technologies du Tertiaire · MTT', 'GLT · Logistique et transport'],
    '215': ['Génie Informatique · GI', 'Dès 150 000 FCFA · mentor inclus', 'Déposer un brief au département'],
  });

  testWidgets('109 : l’onglet « En attente » ne garde que Kouassi', (tester) async {
    await pumpScreen(tester, '109', size: const Size(1280, 900));
    await tester.tap(find.text('En attente (6)'));
    await tester.pumpAndSettle();
    expect(find.text('Kouassi Tagne'), findsOneWidget);
    expect(find.text('Mariam Essono'), findsNothing);
  });

  testWidgets('111 : valider un projet change la décision', (tester) async {
    await pumpScreen(tester, '111', size: const Size(1280, 900));
    await tester.tap(find.text('À valider').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(find.text('À valider'), findsNWidgets(2));
    expect(find.text('Validé'), findsNWidgets(2));
  });

  testWidgets('214 : le filtre « Numérique » ne garde que la famille MTIN', (tester) async {
    await pumpScreen(tester, '214');
    await tester.tap(find.text('Numérique'));
    await tester.pumpAndSettle();
    expect(find.text('Information et Numérique · MTIN'), findsOneWidget);
    expect(find.text('Technologies du Tertiaire · MTT'), findsNothing);
  });
}
