import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';
import '../helpers/screen_texts.dart';

void main() {
  expectScreenTexts(const {
    '191': ['Votre besoin', 'Que voulez-vous faire créer ?', '150 000 – 300 000 FCFA'],
    '192': ['Votre devis', 'Étapes de validation', '180 000 FCFA'],
    '193': ['Paiement sécurisé', 'Jalon 2 · Propositions', 'Payer 54 000 FCFA'],
    '194': ['Ma mission', 'Étape 3 sur 5', 'Propositions de logo'],
    '195': ['Ajouter une preuve', 'Prendre une photo', 'Envoyer pour validation'],
    '196': ['Dossier #BR-0412', 'Moodboard_Mbella.pdf', 'Jalon 1 · 54 000 FCFA'],
    '197': ['Valider le jalon 2', 'Libération du paiement', '50 400 FCFA'],
    '198': ['Briefs reçus', 'Boîte de réception', 'Savonnerie Kamga'],
    '199': ['Attribuer : Identité visuelle · Parfums Mbella', 'Étudiants qualifiés', 'Score 94'],
    '200': ['Missions et encaissement', '12 480 000', '54 000 FCFA bloqués'],
    '201': ['Mes missions', 'Emballage savons Kamga', '50 400 FCFA'],
    '202': ['Pack Lancement de marque', 'Fabrication du produit', '420 000 FCFA'],
    '203': ['Mes compétences', 'Community management', 'Respect des délais'],
    '204': ['Coup de pouce startup', 'Projets accompagnés', 'Borne solaire mobile'],
    '205': ['Soumettre mon projet', 'Aide demandée', 'Besoin de financement'],
  });

  testWidgets('191 : le besoin doit être décrit avant l’envoi', (tester) async {
    await pumpScreen(tester, '191');
    await tester.tap(find.text('Envoyer mon besoin'));
    await tester.pumpAndSettle();
    expect(find.text('Décrivez votre besoin pour recevoir un devis.'), findsOneWidget);
  });

  testWidgets('199 : choisir un étudiant l’ajoute à l’équipe', (tester) async {
    await pumpScreen(tester, '199', size: const Size(1280, 900));
    expect(find.text('Sélectionné'), findsNWidgets(3));
    await tester.tap(find.text('Choisir').first);
    await tester.pumpAndSettle();
    expect(find.text('Sélectionné'), findsNWidgets(4));
  });

  testWidgets('201 : l’onglet Terminées affiche les missions terminées', (tester) async {
    await pumpScreen(tester, '201');
    await tester.tap(find.text('Terminées'));
    await tester.pumpAndSettle();
    expect(find.text('Prototype Atelier Tchoupo'), findsOneWidget);
    expect(find.text('Identité visuelle Mbella'), findsNothing);
  });
}
