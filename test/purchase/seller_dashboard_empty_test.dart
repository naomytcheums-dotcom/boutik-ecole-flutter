import 'package:boutik_ecole/figma/g/g_57.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/seller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('tableau de bord vendeur : un compte sans aucune commande ne plante pas', (tester) async {
    GAnim.enabled = false;
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [sellerOrdersProvider.overrideWithValue(const [])],
      child: const MaterialApp(home: Scaffold(body: G_57())),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Réclamations ›'), findsOneWidget);
    expect(find.text('Demandes de devis ›'), findsOneWidget);
  });
}
