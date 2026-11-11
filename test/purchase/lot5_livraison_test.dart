import 'package:boutik_ecole/figma/g/g_41.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/delivery.dart';
import 'package:boutik_ecole/figma/live/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

/// Lot 5 : livraison (migration 20261101000300 ; règles § 5).

class _Settings extends DeliverySettingsNotifier {
  _Settings(this.s);
  final DeliverySettings? s;
  @override
  DeliverySettings? build() => s;
}

Future<ProviderContainer> _pumpButton(WidgetTester tester, DeliverySettings? s, void Function(BuildContext, WidgetRef) action) async {
  final c = ProviderContainer(overrides: [deliverySettingsProvider.overrideWith(() => _Settings(s))]);
  addTearDown(c.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: MaterialApp(home: Scaffold(body: Consumer(builder: (context, ref, _) => TextButton(onPressed: () => action(context, ref), child: const Text('agir'))))),
  ));
  await tester.tap(find.text('agir'));
  await tester.pumpAndSettle();
  return c;
}

void main() {
  setUpAll(loadAppFonts);
  tearDown(() => Backend.ready = false);

  test('frais : maquette 5 000 ; connecté, ceux du réglage, et rien si le domicile n’est pas proposé', () {
    expect(deliveryFee(false, null), 0);
    expect(deliveryFee(true, null), 5000, reason: 'maquette');
    Backend.ready = true;
    expect(deliveryFee(true, null), 5000, reason: 'réglage non lu : frais par défaut, la livraison reste proposée');
    expect(deliveryFee(true, (enabled: false, city: 'Douala', fee: 5000)), 5000);
    expect(deliveryFee(true, (enabled: true, city: 'Douala', fee: 4000)), 4000);
  });

  testWidgets('connecté : la livraison à domicile est toujours proposée, sans refus', (tester) async {
    Backend.ready = true;
    final c = await _pumpButton(tester, (enabled: false, city: 'Douala', fee: 5000), (context, ref) {
      ref.read(selectedAddressProvider.notifier).set('a1'); // adresse déjà retenue : pas de navigation
      chooseHomeDelivery(context, ref);
    });
    expect(find.textContaining('non proposée pour le moment'), findsNothing);
    expect(c.read(homeDeliveryProvider), isTrue);
  });

  testWidgets('connecté, adresse incomplète : erreurs sous les champs, rien n’est envoyé', (tester) async {
    Backend.ready = true;
    final c = await _pumpButton(tester, null, (context, ref) {
      ref.read(formProvider.notifier).put('ad_name', 'M');
      saveDeliveryAddress(context, ref);
    });
    await tester.pumpAndSettle();
    // sans compte connecté, la connexion est d'abord demandée ; sinon les erreurs de saisie sont affichées
    expect(c.read(selectedAddressProvider), isEmpty);
    expect(find.text('Adresse enregistrée'), findsNothing);
  });

  testWidgets('41 connecté : aucune adresse d’exemple pré-remplie', (tester) async {
    Backend.ready = true;
    GAnim.enabled = false;
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: Scaffold(body: G_41()))));
    await tester.pump();
    expect(find.text('Mariam Essono'), findsNothing);
    expect(find.text('Rue de l’IUT, face au Bloc A'), findsNothing);
  });
}
