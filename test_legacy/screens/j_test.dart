import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';
import '../helpers/screen_texts.dart';

void main() {
  expectScreenTexts(const {
    '88': ['Espace entreprise', 'Propositions reçues par mois', 'Stage développeur web'],
    '89': ['Orange Cameroun', 'Télécommunications · Douala', 'Publier un besoin'],
    '90': ['Publier un besoin', 'Joindre le cahier des charges', '300 000 – 500 000 FCFA'],
    '91': ['Rechercher des talents', '48 profils correspondent', 'Équipe Team Innov’'],
    '93': ['Propositions reçues', '80 000 FCFA · 7 jours', 'Comparer la sélection'],
    '93b': ['Proposition', '80 000 FCFA', 'Tests et livraison'],
    '94': ['Comparer les propositions', '120 000', 'Choisir une proposition'],
    '95': ['Devis et négociations', 'Team Innov’ · 450 000 FCFA', 'Dernier échange'],
    '95b': ['Demande de devis', 'Budget maximal', 'Envoyer la demande'],
    '96': ['Défis d’innovation', 'Gestion des déchets', '500 000'],
    '97': ['Recrutement', 'Stage marketing digital', 'Publier une offre'],
    '98': ['Collaborations', 'Contrat signé · 450 000 FCFA', 'Suivi du contrat actif'],
    '99': ['Historique', 'Borne de recharge solaire', 'Projets réalisés'],
  });

  testWidgets('91 : le filtre « Audiovisuel » ne garde que Kouassi Tagne', (tester) async {
    await pumpScreen(tester, '91');
    await tester.ensureVisible(find.text('Audiovisuel').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Audiovisuel').first);
    await tester.pumpAndSettle();
    expect(find.text('Kouassi Tagne'), findsOneWidget);
    expect(find.text('Mariam Essono'), findsNothing);
    expect(find.text('1 profil correspond'), findsOneWidget);
  });

  testWidgets('90 : un titre vide bloque la publication', (tester) async {
    await pumpScreen(tester, '90');
    await tester.tap(find.text('Publier'));
    await tester.pumpAndSettle();
    expect(find.text('Le titre est obligatoire.'), findsOneWidget);
  });

  testWidgets('93 : l’onglet « Refusées » affiche l’état vide', (tester) async {
    await pumpScreen(tester, '93');
    await tester.tap(find.text('Refusées'));
    await tester.pumpAndSettle();
    expect(find.text('Aucune proposition dans cet onglet.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
}
