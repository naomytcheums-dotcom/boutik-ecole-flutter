import 'package:boutik_ecole/app.dart';
import 'package:boutik_ecole/core/widgets/widgets.dart' show SearchField;
import 'package:boutik_ecole/features/aa_borne/kiosk_qr.dart';
import 'package:boutik_ecole/features/c_decouverte/c_widgets.dart' show CProductTile;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Parcours de démonstration de la soutenance :
/// 03 → 19 → 22 → 05 → 33 → 10 → 40 → 06 → 07 → 08 → 257 → 259 → 260 → 44 → 09
/// → 111 → 213 → 212 → 206 → 207 → 208 → 209 → 210 → 237.
///
/// Chaque étape touche l'élément réel de l'écran (bouton, carte, champ). Les trois passages
/// marqués « changement d'appareil » (mobile → console web du département, borne → web)
/// ouvrent directement l'écran, comme le ferait la personne sur l'autre appareil.
/// Renvoie la liste des écrans visités.
Future<List<String>> runDemoJourney(WidgetTester tester, {void Function(List<String> visited)? onStep}) async {
  const mobile = Size(390, 900);
  const web = Size(1280, 900);
  const kiosk = Size(720, 1280);
  final visited = <String>[];

  void size(Size s) {
    tester.view.physicalSize = s;
    tester.view.devicePixelRatio = 1;
  }

  GoRouter router() => GoRouter.of(tester.element(find.byType(Scaffold).last));

  Future<void> expectAt(String id) async {
    await tester.pumpAndSettle();
    expect(router().state.uri.path, '/s/$id', reason: 'écran attendu : $id');
    visited.add(id);
    onStep?.call(visited);
  }

  Future<void> tap(Finder f) async {
    if (f.hitTestable().evaluate().isEmpty && find.byType(SnackBar).evaluate().isNotEmpty) {
      // Un message bref masque le bas de l'écran : on attend sa disparition, comme l'utilisateur.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }
    if (f.hitTestable().evaluate().isEmpty) {
      await Scrollable.ensureVisible(tester.element(f.first), alignment: .5);
      await tester.pumpAndSettle();
    }
    await tester.tap(f.hitTestable().first);
  }

  /// Changement d'appareil : on ouvre l'écran comme sur le nouvel appareil.
  Future<void> switchDevice(String id, Size s) async {
    size(s);
    router().go('/s/$id');
    await expectAt(id);
  }

  addTearDown(tester.view.reset);
  size(mobile);
  await tester.pumpWidget(const ProviderScope(child: BoutikEcoleApp(initialLocation: '/s/03')));
  await expectAt('03');

  // Découverte et achat (mobile).
  await tap(find.byType(SearchField));
  await expectAt('19');
  await tap(find.byType(SearchField));
  await expectAt('22');
  await tap(find.byType(CProductTile));
  await expectAt('05');
  await tap(find.text('Créée par'));
  await expectAt('33');
  await tap(find.bySemanticsLabel(RegExp('^Voir le profil de ')));
  await expectAt('10');
  await tap(find.text('3 Services'));
  await expectAt('40');
  await tester.enterText(find.byType(TextField).at(1), 'Un site vitrine de cinq pages pour notre association.');
  await tap(find.text('Envoyer la demande'));
  await tester.pumpAndSettle();
  await tap(find.text('Voir mon panier'));
  await expectAt('06');
  await tap(find.text('Passer la commande'));
  await expectAt('07');
  await tap(find.text('Continuer'));
  await expectAt('08');
  await tap(find.text('Payer maintenant'));
  await expectAt('257');
  await tap(find.text('Vérifier le statut'));
  await expectAt('259');
  await tap(find.text('Voir la facture'));
  await expectAt('260');
  await tap(find.text('Télécharger la facture (PDF)'));
  await expectAt('44');
  await tap(find.text('Suivre ma commande'));
  await expectAt('09');

  // Changement d'appareil : console web du département, puis registre des certificats.
  await switchDevice('111', web);
  await switchDevice('213', web);
  await tap(find.text('BE-CERT-0021'));
  await expectAt('212');

  // Vérification sur mobile puis borne phygitale.
  size(mobile);
  await tester.pumpAndSettle();
  await tap(find.text('Scanner un autre QR'));
  size(kiosk);
  await expectAt('206');
  await tap(find.text('Touchez pour commencer'));
  await expectAt('207');
  await tap(find.text('Lampe en bois recyclé'));
  await expectAt('208');
  await tap(find.text('Sur mon téléphone'));
  await expectAt('209');
  await tap(find.byType(KioskQr));
  await expectAt('210');

  // Changement d'appareil : page web d'impact.
  await switchDevice('237', web);
  return visited;
}

const demoJourney = [
  '03', '19', '22', '05', '33', '10', '40', '06', '07', '08', '257', '259', '260', '44', '09', //
  '111', '213', '212', '206', '207', '208', '209', '210', '237',
];
