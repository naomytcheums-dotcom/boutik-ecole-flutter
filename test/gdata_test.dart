import 'package:boutik_ecole/figma/gdata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    GData.saver = true;
    GData.lowImages = true;
    GData.wifiVideo = true;
    GData.wifiSync = true;
    GData.syncNever = false;
    GData.cellular = false;
  });

  test('mode économie activé en Wi-Fi : images en haute qualité, vidéos jamais lancées seules', () {
    GData.saver = true;
    GData.cellular = false;
    expect(GData.reduceImages, isFalse, reason: 'haute qualité sur Wi-Fi');
    expect(GData.imageWidth, isNull);
    expect(GData.blockVideo, isTrue);
  });

  test('mode économie activé sur réseau mobile : images en basse qualité, 480 px au plus', () {
    GData.saver = true;
    GData.cellular = true;
    expect(GData.reduceImages, isTrue);
    expect(GData.imageWidth, 480);
  });

  test('mode économie coupé : tout redevient normal, même sur réseau mobile', () {
    GData.saver = false;
    GData.cellular = true;
    GData.wifiVideo = false;
    GData.wifiSync = false;
    expect(GData.reduceImages, isFalse);
    expect(GData.imageWidth, isNull);
    expect(GData.blockVideo, isFalse);
    expect(GData.blockSync, isFalse);
    expect(GData.blockDownload, isFalse);
  });

  test('images basse qualité coupé : haute qualité même sur réseau mobile', () {
    GData.saver = true;
    GData.cellular = true;
    GData.lowImages = false;
    expect(GData.reduceImages, isFalse);
  });

  test('téléchargement des vidéos : « Wi-Fi uniquement » refusé sur mobile, autorisé sur Wi-Fi ; « Wi-Fi + mobile » toujours autorisé', () {
    GData.wifiVideo = true;
    GData.cellular = true;
    expect(GData.blockDownload, isTrue);
    GData.cellular = false;
    expect(GData.blockDownload, isFalse);
    GData.wifiVideo = false;
    GData.cellular = true;
    expect(GData.blockDownload, isFalse);
  });

  test('synchronisation « Wi-Fi uniquement » : suspendue seulement sur données mobiles', () {
    GData.syncNever = false;
    GData.wifiSync = true;
    GData.cellular = true;
    expect(GData.blockSync, isTrue);
    GData.cellular = false;
    expect(GData.blockSync, isFalse);
  });

  test('synchronisation « Jamais » : refusée sur Wi-Fi comme sur mobile, sans même vérifier le réseau', () async {
    GData.syncNever = true;
    GData.cellular = false;
    expect(GData.blockSync, isTrue);
    GData.cellular = true;
    expect(GData.blockSync, isTrue);
    expect(await GData.syncAllowed(), isFalse);
  });

  test('synchronisation autorisée : le réseau est revérifié à chaque fois', () async {
    GData.syncNever = false;
    GData.wifiSync = true;
    GData.cellular = true; // valeur périmée : la vérification la remet à jour (aucune interface mobile dans les tests)
    expect(await GData.syncAllowed(), isTrue);
    expect(GData.cellular, isFalse);
  });
}
