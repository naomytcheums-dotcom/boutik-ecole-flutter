import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';
import '../helpers/screen_texts.dart';

void main() {
  expectScreenTexts(const {
    '21': ['Recherche avancée', 'Disponible uniquement', 'développeur web'],
    '22': ['Catalogue de produits', '128 produits', '150 000 FCFA'],
    '22b': ['Services et prestations', '46 services', 'Un service sur mesure ?'],
    '22c': ['Tendances et nouveautés', 'Coups de cœur de la semaine', 'Ajouté hier · 15 000 FCFA'],
    '22d': ['Pour vous', 'Recommandé pour vous', 'Brice Ndoumbe'],
    '23': ['Filtres', 'Type d’offre', 'Disponible bientôt'],
    '24': ['Atelier Krea’Tech', 'Produits phares', '8 000 FCFA'],
    '25': ['Mes favoris', 'Logo & identité visuelle', '150 000 FCFA'],
    '25b': ['Mes collections', 'Cadeaux d’anniversaire', 'Créer une collection'],
    '26': ['Comparer des offres', '32 000 FCFA', 'Cuir synthétique'],
    '27': ['Mes adresses', 'Adresse par défaut', 'Ajouter une adresse'],
    '28': ['Mes commandes', '#BE-2026-0127', '45 000 FCFA'],
    '29': ['Détail de la commande', '7 500 FCFA', '32 500 FCFA'],
    '30': ['Commande reçue !', 'Évaluer la commande', 'Contacter le support'],
    '31': ['Avis et évaluations', '(24 avis)', 'Kouassi T.'],
  });

  testWidgets('22 : le filtre « Art » ne garde que le tableau', (tester) async {
    await pumpScreen(tester, '22');
    await tester.ensureVisible(find.text('Art'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Art'));
    await tester.pumpAndSettle();
    expect(find.text('1 produit'), findsOneWidget);
    expect(find.text('Tableau décoratif'), findsOneWidget);
  });

  testWidgets('25 : retirer un favori l’enlève de la liste', (tester) async {
    await pumpScreen(tester, '25');
    await tester.tap(find.bySemanticsLabel('Retirer Drone éducatif des favoris'));
    await tester.pumpAndSettle();
    expect(find.text('Drone éducatif'), findsNothing);
  });

  testWidgets('28 : l’onglet Annulées ne garde que la commande annulée', (tester) async {
    await pumpScreen(tester, '28');
    await tester.tap(find.text('Annulées'));
    await tester.pumpAndSettle();
    expect(find.text('#BE-2026-0119'), findsOneWidget);
    expect(find.text('#BE-2026-0142'), findsNothing);
  });
}
