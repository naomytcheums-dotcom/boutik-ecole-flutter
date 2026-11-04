import 'package:boutik_ecole/core/router/app_router.dart';
import 'package:boutik_ecole/core/router/screen_entry.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

/// Contrôle de composition de CHAQUE écran du registre (315) aux largeurs réelles d'un téléphone, d'une tablette et d'un
/// ordinateur, hors cadre de maquette : aucune exception de rendu (débordement, contrainte non satisfaite), écran affiché,
/// aucune fausse barre d'état sur les écrans de format mobile, pas de défilement horizontal.
/// Ce test prouve que l'écran se compose sans erreur ; il ne prouve ni la fidélité visuelle ni le fonctionnement.
void main() {
  setUpAll(loadAppFonts);
  setUp(() => GScreen.mockupFrame = false);
  tearDown(() => GScreen.mockupFrame = true);

  const tailles = [Size(360, 740), Size(768, 1024), Size(1280, 800)];

  for (final s in screensById.values) {
    for (final size in tailles) {
      testWidgets('écran ${s.id} · ${s.title} à ${size.width.toInt()}×${size.height.toInt()}', (tester) async {
        await pumpScreen(tester, s.id, size: size);
        final erreur = tester.takeException();
        expect(erreur, isNull, reason: 'exception de rendu sur ${s.id}');
        expect(find.byType(Scaffold), findsWidgets);
        if (s.format == ScreenFormat.mobile) {
          expect(find.text('9:41'), findsNothing, reason: 'fausse barre d’état sur ${s.id}');
          expect(find.text('9:41 AM'), findsNothing);
        }
        // pas de défilement horizontal : aucune zone défilante horizontale dans l'écran
        // exception assumée : les consoles web sur écran étroit gardent une échelle lisible (60 % au moins) et défilent
        // horizontalement pour le contenu large (tableaux), avec menu en tiroir (voir consoles_web_adaptatives_test).
        final consoleEtroite = s.format == ScreenFormat.web && size.width < 1000;
        final horizontaux = find.byWidgetPredicate((w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal);
        if (!consoleEtroite) expect(horizontaux, findsNothing, reason: 'défilement horizontal sur ${s.id}');
      });
    }
  }
}
