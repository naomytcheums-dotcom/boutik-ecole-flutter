import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';
import '../helpers/screen_texts.dart';

void main() {
  expectScreenTexts(const {
    '160': ['Hackathons et concours', 'Orange Digital Challenge', 'Pas encore d’équipe ?'],
    '161': ['Orange Digital Challenge', '5 M', 'Pitch final et jury'],
    '162': ['Inscription', 'Brice Ndoumbe', 'J’accepte le règlement du concours.'],
    '163': ['Trouver des coéquipiers', '12 talents disponibles', 'Landry Essomba'],
    '164': ['Team Innov’', 'Avancement du prototype', 'Dr Paul Tchoupo'],
    '165': ['Dépôt du projet', 'Vidéo de démonstration', 'Je certifie que le projet est original.'],
    '166': ['Team Innov’ · 1er prix', '2 000 000 FCFA', 'Voir le certificat'],
    '167': ['Noter : Serre intelligente', '30 / 40', 'Commentaire du jury'],
    '168': ['Publier un concours', 'Dr Paul Tchoupo', 'Soumettre pour validation'],
    '169': ['Modération des concours et des offres', 'Offre sans description', '91 %'],
  });

  testWidgets('162 : le règlement doit être accepté', (tester) async {
    await pumpScreen(tester, '162');
    await tester.tap(find.text('Valider l’inscription'));
    await tester.pumpAndSettle();
    expect(find.text('Vous devez accepter le règlement pour vous inscrire.'), findsOneWidget);
  });

  testWidgets('169 : valider un concours met à jour la décision', (tester) async {
    await pumpScreen(tester, '169', size: const Size(1280, 900));
    await tester.tap(find.text('À valider').first);
    await tester.pumpAndSettle();
    expect(find.text('À valider'), findsOneWidget);
    expect(find.text('Validé'), findsNWidgets(2));
  });
}
