import 'package:boutik_ecole/figma/g/g_105.dart';
import 'package:boutik_ecole/figma/g/g_107.dart';
import 'package:boutik_ecole/figma/g/g_237.dart';
import 'package:boutik_ecole/figma/g/g_238.dart';
import 'package:boutik_ecole/figma/g/g_239.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

/// Écrans d'impact et de sponsoring : aucune source de données n'existe encore sur le serveur. Connecté, un message honnête
/// remplace les chiffres et listes de la maquette ; hors connexion, la démonstration reste affichée.
void main() {
  setUpAll(loadAppFonts);
  setUp(() => GScreen.mockupFrame = false);
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = false;
  });

  final cas = <(String, Widget, String, String, Size)>[
    ('105', const G_105(), 'Tablette solaire', 'autres établissements', Size(393, 852)),
    ('107', const G_107(), '48 kg', 'pas encore calculé', Size(393, 852)),
    ('238', const G_238(), 'Ensemble, nous faisons grandir le Cameroun', 'impact de la plateforme', Size(393, 852)),
    ('237', const G_237(), '48,2 M F', 'impact par territoire', Size(1280, 820)),
    ('239', const G_239(), 'Serre intelligente', 'rapport de sponsoring', Size(1280, 866)),
  ];

  for (final c in cas) {
    testWidgets('${c.$1} connecté : aucun chiffre ni nom de maquette, message honnête', (t) async {
      Backend.ready = true;
      GAnim.enabled = false;
      t.view.physicalSize = c.$5;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(ProviderScope(child: MaterialApp(home: c.$2)));
      await t.pumpAndSettle();
      expect(find.text(c.$3), findsNothing);
      expect(find.textContaining(c.$4), findsOneWidget);
    });

    testWidgets('${c.$1} hors connexion : la démonstration reste affichée', (t) async {
      Backend.ready = false;
      GAnim.enabled = false;
      t.view.physicalSize = c.$5;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(ProviderScope(child: MaterialApp(home: c.$2)));
      await t.pumpAndSettle();
      expect(find.text(c.$3), findsOneWidget);
    });
  }
}
