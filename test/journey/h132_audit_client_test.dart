import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_supabase.dart';

/// H13.2 : le client ne journalise que les catégories non sensibles ; finances, comptes, paramètres et modération
/// sont écrits par la fonction serveur qui exécute l'action (le serveur ignore de toute façon ces catégories).
void main() {
  late FakeSupabase srv;
  setUpAll(() async {
    srv = await FakeSupabase.start();
    await srv.initSupabase();
  });
  tearDownAll(() => srv.close());
  setUp(() {
    srv.calls.clear();
    Backend.ready = true;
  });
  tearDown(() => Backend.ready = false);

  test('Backend.audit : Connexions et Validations partent au serveur, les catégories sensibles non', () async {
    for (final cat in ['Finances', 'Comptes', 'Paramètres', 'Modération', 'Sécurité', 'Finance']) {
      await Backend.audit('Client', 'Action $cat', 'cible', cat, 'Critique');
    }
    expect(srv.callsOf('log_audit'), isEmpty, reason: 'aucune ligne sensible ne doit être émise par le client');
    await Backend.audit('Client', 'Accès refusé', 'Écran 1', 'Connexions', 'Sensible');
    await Backend.audit('Client', 'Annonce soumise', 'Lampe', 'Validations', 'Normal');
    final calls = srv.callsOf('log_audit');
    expect(calls.map((c) => c.args['p_category']), ['Connexions', 'Validations']);
    expect(calls.first.args.containsKey('p_actor'), isFalse, reason: 'l\'acteur est déterminé par le serveur');
  });
}
