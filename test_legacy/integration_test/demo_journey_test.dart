import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/journey/demo_journey.dart';

/// Parcours de soutenance sur appareil réel, émulateur ou navigateur :
///   `flutter test integration_test/demo_journey_test.dart -d ID_APPAREIL`
/// Sur le Web (chromedriver lancé sur le port 4444) :
///   `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/demo_journey_test.dart
///   -d web-server --browser-name=chrome --profile`
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Parcours de démonstration de bout en bout', (tester) async {
    final report = <String, Object?>{};
    // Saisie simulée : sur le Web, le clavier de test n'est pas branché par défaut.
    tester.testTextInput.register();
    try {
      final visited = await runDemoJourney(tester, onStep: (v) => binding.reportData = report..['visited'] = [...v]);
      expect(visited, demoJourney);
    } catch (e) {
      // Le Web ne transmet pas le message d'échec : on le renvoie au pilote avec les étapes atteintes.
      binding.reportData = report..['error'] = '$e';
      rethrow;
    }
  });
}
