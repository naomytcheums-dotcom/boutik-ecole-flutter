import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';
import '../helpers/screen_texts.dart';

void main() {
  expectScreenTexts(const {
    '70': ['Talents étudiants', '32 talents disponibles', 'Mariam Essono'],
    '72': ['Ajouter à mon profil', 'Titre de la réalisation', 'Ajouter à mon portfolio'],
    '73': ['Mes documents', 'CV_Mariam_Essono.pdf', 'Téléverser un document'],
    '75': ['Opportunités', '12 offres disponibles', 'Profil à compléter'],
    '76': ['Ma candidature', 'Entretien à planifier', 'Stage de 6 mois'],
    '77': ['Profil de mentor', 'Dr Mbarga', 'Demander un accompagnement'],
  });

  setUpAll(loadAppFonts);

  testWidgets('70 : le filtre Design ne garde que les talents de la catégorie', (tester) async {
    await pumpScreen(tester, '70');
    await tester.tap(find.text('Design'));
    await tester.pumpAndSettle();
    expect(find.text('Aminata Bello'), findsOneWidget);
    expect(find.text('Mariam Essono'), findsNothing);
    expect(find.text('1 talent trouvé'), findsOneWidget);
  });

  testWidgets('72 : une description trop courte est refusée', (tester) async {
    await pumpScreen(tester, '72');
    await tester.tap(find.text('Ajouter à mon portfolio'));
    await tester.pumpAndSettle();
    expect(find.text('Décrivez en au moins 20 caractères (contexte, rôle, résultats).'), findsOneWidget);
    expect(find.byType(TextFormField), findsWidgets);
  });

  testWidgets('75 : postuler à une offre affiche « Postulé »', (tester) async {
    await pumpScreen(tester, '75');
    expect(find.text('Postulé'), findsOneWidget);
    await tester.tap(find.text('Postuler').first);
    await tester.pumpAndSettle();
    expect(find.text('Postulé'), findsNWidgets(2));
  });
}
