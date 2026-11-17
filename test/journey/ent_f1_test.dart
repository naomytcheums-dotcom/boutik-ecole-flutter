import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lot F1 : enveloppes serveur de la recherche de talents et de la porte de publication (règles appliquées par le serveur).
void main() {
  setUp(() => Backend.ready = false);

  test('hors connexion : la recherche de talents ne renvoie rien et le dit', () async {
    final r = await Backend.talentsSearch(query: 'flutter', filiere: 'GL', skills: const ['SQL'], limit: 10, offset: 20);
    expect(r.items, isEmpty);
    expect(r.total, 0);
    expect(r.locked, isFalse);
    expect(r.error, 'Connexion requise.');
  });

  test('hors connexion : l’état de publication n’est jamais simulé', () async {
    final r = await Backend.companyPublishStatus(owner: '00000000-0000-0000-0000-000000000001');
    expect(r.status, isNull);
    expect(r.error, 'Connexion requise.');
  });
}
