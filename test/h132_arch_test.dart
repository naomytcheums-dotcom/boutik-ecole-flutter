import 'package:boutik_ecole/figma/live/account_reset.dart' show resetAccountScopedState;
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/marche/marche_data.dart' show mFcfa;
import 'package:boutik_ecole/figma/live/media_access.dart';
import 'package:boutik_ecole/figma/live/store.dart' show fcfa, statusLabel;
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_supabase.dart';

/// H13.2 · architecture : un seul format de montant FCFA et un état de compte qui ne survit pas à la déconnexion.
void main() {
  late FakeSupabase srv;
  setUpAll(() async {
    srv = await FakeSupabase.start();
    await srv.initSupabase();
  });
  tearDownAll(() => srv.close());

  test('FCFA : le formateur du marché suit celui du panier, y compris pour un montant négatif', () {
    for (final n in [0, 5, 999, 1000, 25000, 1234567, -150, -1500, -1234567]) {
      expect(mFcfa(n), fcfa(n), reason: '$n');
    }
    expect(fcfa(25000), '25\u202F000 FCFA');
    expect(fcfa(-150), '-150 FCFA');
    expect(fcfa(-1500), '-1\u202F500 FCFA');
    expect(statusLabel(2), 'Expédiée');
  });

  test('déconnexion : les URL signées des médias privés du compte précédent sont oubliées', () async {
    Backend.ready = true;
    MediaAccess.reset();
    final p = '${FakeSupabase.userId}/private/1.jpg';
    await MediaAccess.warm([p]);
    expect(MediaAccess.cached(p), isNotNull, reason: 'précondition : une URL signée est en cache');
    resetAccountScopedState();
    expect(MediaAccess.cached(p), isNull);
    expect(MediaAccess.bucketOf(p), 'post-media-private', reason: 'le repère /private/ du chemin reste suffisant');
  });
}
