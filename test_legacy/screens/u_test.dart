import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';
import '../helpers/screen_texts.dart';

void main() {
  expectScreenTexts(const {
    '170': ['Signaler une annonce', 'Motif du signalement', '25 000 FCFA · Vendeur : Y. Mouanga'],
    '171': ['Paiement sécurisé', 'Vérifiez avant de payer', 'Non reconnu'],
    '172': ['Confiance du vendeur', 'Yannick Mouanga', 'Badges de confiance'],
    '173': ['Partager', 'Partager via', '25 000 FCFA · boutik-ecole.cm/p/lampe-0142'],
    '174': ['Centre de confiance', 'Achetez en confiance', 'Payer en sécurité par Mobile Money'],
    '211': ['Passeport du produit', 'Origine', 'BE-CERT-0021'],
    '212': ['Vérifier un certificat', 'Authentique', 'Résultat de la vérification'],
    '213': ['Registre des certificats', '1 286', 'Kit solaire'],
  });

  testWidgets('170 : un motif est obligatoire', (tester) async {
    await pumpScreen(tester, '170');
    await tester.tap(find.text('Annonce frauduleuse ou trompeuse'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Envoyer le signalement'));
    await tester.pumpAndSettle();
    expect(find.text('Choisissez au moins un motif.'), findsOneWidget);
  });

  testWidgets('213 : un identifiant ouvre la vérification du certificat', (tester) async {
    await pumpScreen(tester, '213', size: const Size(1280, 900));
    await tester.tap(find.text('BE-CERT-0021'));
    await tester.pumpAndSettle();
    expect(find.text('Vérifier un certificat'), findsWidgets);
  });
}
