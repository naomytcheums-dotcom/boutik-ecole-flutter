import 'package:boutik_ecole/figma/gdata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    GData.saver = true;
    GData.lowImages = true;
    GData.wifiVideo = true;
    GData.wifiSync = false;
    GData.cellular = false;
  });

  test('mode économie : images réduites et vidéos jamais lancées seules, même en Wi-Fi', () {
    GData.saver = true;
    GData.cellular = false;
    expect(GData.reduceImages, isTrue);
    expect(GData.blockVideo, isTrue);
    expect(GData.imageWidth, 480);
  });

  test('mode économie coupé, Wi-Fi : rien n’est réduit ni bloqué', () {
    GData.saver = false;
    GData.cellular = false;
    expect(GData.reduceImages, isFalse);
    expect(GData.blockVideo, isFalse);
    expect(GData.blockSync, isFalse);
    expect(GData.imageWidth, isNull);
  });

  test('données mobiles : images basse qualité et vidéos en Wi-Fi uniquement s’appliquent', () {
    GData.saver = false;
    GData.cellular = true;
    expect(GData.reduceImages, isTrue);
    expect(GData.blockVideo, isTrue);
    GData.lowImages = false;
    GData.wifiVideo = false;
    expect(GData.reduceImages, isFalse);
    expect(GData.blockVideo, isFalse);
  });

  test('synchronisation en Wi-Fi uniquement : suspendue seulement sur données mobiles', () {
    GData.saver = false;
    GData.wifiSync = true;
    GData.cellular = true;
    expect(GData.blockSync, isTrue);
    GData.cellular = false;
    expect(GData.blockSync, isFalse);
    GData.wifiSync = false;
    GData.cellular = true;
    expect(GData.blockSync, isFalse);
  });
}
