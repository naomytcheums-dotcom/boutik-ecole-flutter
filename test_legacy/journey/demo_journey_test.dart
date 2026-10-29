import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';
import 'demo_journey.dart';

/// Parcours de soutenance exécuté sans appareil (`flutter test`), à chaque intégration.
/// La même fonction est lancée sur appareil par integration_test/demo_journey_test.dart.
void main() {
  testWidgets('Parcours de démonstration de bout en bout', (tester) async {
    await loadAppFonts();
    final visited = await runDemoJourney(tester);
    expect(visited, demoJourney);
  });
}
