import 'package:boutik_ecole/figma/live/kela.dart';
import 'package:boutik_ecole/figma/live/kiosk_mode.dart';
import 'package:boutik_ecole/figma/live/qr.dart';
import 'package:boutik_ecole/figma/live/store.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lot S9/S10 de l'étudiant-vendeur : mode borne, code QR d'ouverture, Kéla sans clé, textes de retrait.
void main() {
  group('mode borne (S9-40)', () {
    tearDown(() => KioskTerminal.configure(Uri.parse('https://x.test/')));

    test('un terminal exige l\'identifiant de borne ET son jeton', () {
      final tok = 'a' * 40;
      KioskTerminal.configure(Uri.parse('https://x.test/?kiosk=borne-2&kt=$tok'));
      expect(KioskTerminal.active, isTrue);
      expect(KioskTerminal.id, 'borne-2');
      expect(KioskTerminal.label, 'Borne n°2');
      KioskTerminal.configure(Uri.parse('https://x.test/?kiosk=borne-2'));
      expect(KioskTerminal.active, isFalse);
      KioskTerminal.configure(Uri.parse('https://x.test/?kiosk=maison&kt=$tok'));
      expect(KioskTerminal.active, isFalse);
      KioskTerminal.configure(Uri.parse('https://x.test/?kiosk=borne-2&kt=court'));
      expect(KioskTerminal.active, isFalse);
      expect(KioskTerminal.label, 'Borne');
    });
  });

  group('code QR ouvert par l\'appareil photo (S9-39)', () {
    tearDown(() => pendingQrToken = null);

    test('le jeton de l\'adresse d\'ouverture est mémorisé', () {
      final t = 'Ab3_-' * 6 + 'xy';
      capturePendingQr(Uri.parse('https://boutik-ecole.vercel.app/?qr=$t'));
      expect(pendingQrToken, t);
      expect(qrTokenOf(qrPayload(t)), t);
    });

    test('un jeton mal formé est ignoré', () {
      capturePendingQr(Uri.parse('https://boutik-ecole.vercel.app/?qr=court'));
      expect(pendingQrToken, isNull);
      capturePendingQr(Uri.parse('https://boutik-ecole.vercel.app/?ref=ABC'));
      expect(pendingQrToken, isNull);
    });
  });

  test('S9-20 : sans connexion au serveur, Kéla n\'est pas déclarée indisponible à tort', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(await c.read(kelaAvailableProvider.future), isTrue);
  });

  test('S10-26 : l\'écran 44 sans commande réelle est redirigé', () {
    expect(orderDetailScreens, contains('44'));
    expect(redirectOrderDetail(ready: true, loaded: true, orders: const [], screen: '44'), isTrue);
  });

  test('S10-13 : le lieu de retrait suit l\'établissement du compte', () {
    gSelfInstitution = 'IUT de Bandjoun';
    expect(campusPlace(), 'à IUT de Bandjoun');
    gSelfInstitution = '';
    expect(campusPlace(), 'sur votre campus');
  });
}
