import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('validations des formulaires', () {
    expect(validPhone('690112233'), isNull);
    expect(validPhone('+237 6 90 11 22 33'), isNull);
    expect(validPhone('12345'), isNotNull);
    expect(validPhone('590112233'), isNotNull);
    expect(validEmail('mariam@iut-douala.cm'), isNull);
    expect(validEmail('mariam@'), isNotNull);
    expect(validPassword('Boutik2026'), isNull);
    expect(validPassword('boutik2026'), 'Ajoutez une lettre majuscule.');
    expect(validPassword('Boutiquee'), 'Ajoutez un chiffre.');
    expect(validPassword('Bt1'), '8 caractères minimum.');
    expect(validName('Al'), isNotNull);
    expect(normPhone('+237 690 11 22 33'), '690112233');
  });

  test('inscription, vérification et mise à jour du profil', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(authProvider.notifier);
    expect(c.read(authProvider).current, isNull);

    final a = Account(name: 'Paul Nkoa', phone: '677000111', email: 'paul@mail.cm', password: 'Secret123', verified: false);
    n.register(a);
    expect(c.read(authProvider).accounts.length, seedAccounts.length + 1);
    expect(c.read(authProvider).pending?.verified, isFalse);

    final v = a.copyWith(verified: true, role: 2);
    n.update(v);
    n.login(v);
    expect(c.read(authProvider).current?.role, 2);
    expect(c.read(profileAccountProvider).name, 'Paul Nkoa');

    n.update(v.copyWith(name: 'Paul Nkoa Mbarga', city: 'Yaoundé'));
    expect(c.read(profileAccountProvider).lastName, 'Nkoa Mbarga');
    expect(c.read(profileAccountProvider).city, 'Yaoundé');

    n.logout();
    expect(c.read(authProvider).current, isNull);
  });
}
