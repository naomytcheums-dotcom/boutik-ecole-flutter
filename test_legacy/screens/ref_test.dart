import 'package:boutik_ecole/features/ref_echantillons/ref_widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';
import '../helpers/screen_texts.dart';

void main() {
  expectScreenTexts(const {
    'A1': ['Assistante vocale Kéla', 'À l’écoute', 'pour mon parfum, avant fin novembre ?'],
    'A2': ['Bonjour Mariam', 'Que fait-on aujourd’hui ?', 'Parle à Kéla', 'Déposer un besoin'],
    'A3': ['Voix en texte', 'Crée la mission pour moi', '200 000 FCFA'],
    'P1': ['Aminata Bello', '2 695 Abonnés', 'Amis qui suivent'],
    'P2': ['S’abonner', '28 avis · Recommandée', 'Réseaux connectés'],
    'P3': ['28 avis vérifiés', 'Recommandée par 9 clients et 3 entreprises', 'Avis des clients'],
    'P4': ['Nouvelle publication', 'Publier aussi sur mes réseaux', 'Propulser ce post'],
    'V1': ['Vitrine', 'Lampe en bois recyclé', '25 000 FCFA', 'En direct maintenant'],
    'P5': ['Connecter mes outils', 'Réseaux sociaux', 'Enregistrer mes outils'],
    'L1': ['Aller en direct', 'Tu peux lancer ce live', 'Lancer le live'],
    'S1': ['Boutik-École', 'Chargement…'],
    'D1': ['Aperçu des performances', '1 245 000 FCFA', 'Performance des produits', '25 000 F'],
  });

  testWidgets('P4 · les interrupteurs de réseaux basculent', (tester) async {
    await pumpScreen(tester, 'P4');
    final instagram = find.byKey(const Key('ref-switch-2'));
    expect(tester.widget<RefSwitch>(instagram).value, isFalse);
    await tester.tap(instagram);
    await tester.pumpAndSettle();
    expect(tester.widget<RefSwitch>(instagram).value, isTrue);
  });

  testWidgets('L1 · un titre trop court bloque le lancement du live', (tester) async {
    await pumpScreen(tester, 'L1');
    await tester.enterText(find.byKey(const Key('ref-live-title')), 'Live');
    await tester.tap(find.byKey(const Key('ref-launch-live')));
    await tester.pumpAndSettle();
    expect(find.text('Le titre doit faire au moins 10 caractères.'), findsOneWidget);
  });

  testWidgets('P5 · connecter un outil met à jour le compteur', (tester) async {
    await pumpScreen(tester, 'P5', size: const Size(390, 1800));
    expect(find.text('3 outils connectés'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Connecter Instagram'));
    await tester.pumpAndSettle();
    expect(find.text('4 outils connectés'), findsOneWidget);
    expect(find.text('4 / 5'), findsOneWidget);
  });

  testWidgets('D1 · le tableau de bord tient en 390 de large', (tester) async {
    await pumpScreen(tester, 'D1', size: const Size(390, 900));
    expect(tester.takeException(), isNull);
    expect(find.text('Aperçu des performances'), findsOneWidget);
  });
}
