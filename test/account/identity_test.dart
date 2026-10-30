import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/seller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    Backend.ready = false;
    appReset = null;
  });

  test('connecté au serveur : un profil sans compte est vierge, jamais le compte de démonstration', () {
    Backend.ready = true;
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final a = c.read(profileAccountProvider);
    expect(a.name, isEmpty);
    expect(a.email, isEmpty);
    expect(a.bio, isEmpty);
    expect(a.avatarUrl, isEmpty);
    expect(a.certified, isFalse);
    expect(a.certification, 'none');
  });

  test('un nouveau compte n\'hérite ni du nom, ni de la description, ni de la photo, ni du badge d\'un autre', () {
    Backend.ready = true;
    final c = ProviderContainer();
    addTearDown(c.dispose);
    const neuf = Account(name: 'Nina Test', phone: '690000001', email: 'nina@example.com', password: '', verified: false);
    c.read(authProvider.notifier).login(neuf);
    final a = c.read(profileAccountProvider);
    expect(a.name, 'Nina Test');
    expect(a.bio, isEmpty);
    expect(a.skills, isEmpty);
    expect(a.avatarUrl, isEmpty);
    expect(a.certified, isFalse);
    expect(a.email, isNot(demoAccount.email));
  });

  test('le badge bleu n\'existe que pour une certification approuvée', () {
    for (final s in ['none', 'pending', 'review', 'rejected', 'revoked']) {
      expect(Account(name: 'X', phone: '', email: '', password: '', certification: s).certified, isFalse, reason: s);
    }
    expect(const Account(name: 'X', phone: '', email: '', password: '', certification: 'approved').certified, isTrue);
    // modifier le profil ne change jamais la certification
    const pending = Account(name: 'X', phone: '', email: '', password: '', certification: 'pending');
    expect(pending.copyWith(name: 'Y', bio: 'bio', verified: true).certification, 'pending');
    expect(pending.copyWith(role: 3).certified, isFalse);
  });

  test('la déconnexion jette tout l\'état de l\'application', () {
    var resets = 0;
    appReset = () => resets++;
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(authProvider.notifier).login(demoAccount);
    c.read(authProvider.notifier).logout();
    expect(resets, 1);
    expect(c.read(authProvider).current, isNull);
  });

  test('connecté au serveur : le vendeur démarre sans annonce d\'exemple', () {
    Backend.ready = true;
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(listingsProvider), isEmpty);
  });
}
