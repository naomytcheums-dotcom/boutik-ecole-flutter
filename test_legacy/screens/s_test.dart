import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';
import '../helpers/screen_texts.dart';

void main() {
  expectScreenTexts(const {
    '151': ['Opportunités', 'Assistant Opportunités', 'Prix de 500 000 FCFA'],
    '152': ['Kéla te recommande', 'Projet : application de covoiturage', '58 %'],
    '153': ['Pourquoi cette offre ?', 'Compatibilité 92 %', 'Points à améliorer'],
    '154': ['Mon dossier', 'Dossier complet à 78 %', 'Numéro Mobile Money'],
    '155': ['Alertes', 'Dossier incomplet', 'Invitation d’équipe'],
    '156': ['Préférences d’alertes', 'Résultats de candidature', 'Enregistrer les préférences'],
    '157': ['Résumé de Kéla', 'Résumé de la semaine par Kéla', 'À examiner en priorité'],
    '158': ['Candidatures classées', 'Kouassi Tagne', 'Comparer la sélection'],
    '159': ['Merci pour votre candidature !', 'Technicien électronique', 'Autres offres'],
  });

  testWidgets('151 : le filtre « Défis » garde 2 opportunités', (tester) async {
    await pumpScreen(tester, '151');
    await tester.ensureVisible(find.text('Défis'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Défis'));
    await tester.pumpAndSettle();
    expect(find.text('Hackathon Orange Digital Center'), findsOneWidget);
    expect(find.text('Stage développeur web'), findsNothing);
  });

  testWidgets('158 : comparer exige 2 sélections', (tester) async {
    await pumpScreen(tester, '158');
    await tester.tap(find.text('Mariam Essono'));
    await tester.pump();
    await tester.tap(find.text('Aminata Bello'));
    await tester.pump();
    expect(find.text('Comparer la sélection (2)'), findsOneWidget);
  });
}
