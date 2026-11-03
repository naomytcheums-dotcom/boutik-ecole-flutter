import 'dart:async';

import 'package:boutik_ecole/figma/gen.dart';

/// Configuration commune à tous les tests : les écrans sont rendus dans le cadre exact de la maquette Figma
/// (rendus de référence, appuis aux coordonnées de la maquette). Le rendu plein écran des téléphones est testé
/// explicitement dans test/journey/plein_ecran_telephone_test.dart.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GScreen.mockupFrame = true;
  await testMain();
}
