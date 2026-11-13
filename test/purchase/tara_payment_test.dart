import 'package:boutik_ecole/figma/live/tara_payment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('numéro Mobile Money : formats acceptés et refusés', () {
    expect(taraPhone('699123456'), '237699123456');
    expect(taraPhone('+237 699 12 34 56'), '237699123456');
    expect(taraPhone('237677123456'), '237677123456');
    expect(taraPhone('799123456'), isNull);
    expect(taraPhone('69912345'), isNull);
    expect(taraPhone(''), isNull);
  });

  test('réseau conseillé d’après le préfixe', () {
    expect(guessNetwork('237677123456'), 'MTN');
    expect(guessNetwork('237681123456'), 'MTN');
    expect(guessNetwork('237651123456'), 'MTN');
    expect(guessNetwork('237699123456'), 'ORANGE');
    expect(guessNetwork('237655123456'), 'ORANGE');
    expect(guessNetwork(''), 'ORANGE');
  });
}
