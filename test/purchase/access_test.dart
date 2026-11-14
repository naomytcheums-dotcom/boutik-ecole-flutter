import 'package:boutik_ecole/figma/live/access.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Account _by(String staff) => seedAccounts.firstWhere((a) => a.staff == staff);

Future<ProviderContainer> _monter(WidgetTester t, Widget child, {Account? compte}) async {
  final c = ProviderContainer();
  addTearDown(c.dispose);
  if (compte != null) c.read(authProvider.notifier).login(compte);
  await t.pumpWidget(UncontrolledProviderScope(container: c, child: MaterialApp(home: child)));
  await t.pump();
  return c;
}

void main() {
  tearDown(() => Backend.ready = false);

  testWidgets('RouteGuard : seuls les rôles listés voient l’écran, les autres la page introuvable', (t) async {
    const garde = RouteGuard(name: '/admin/test', roles: {'admin'}, child: Text('CONTENU'));
    await _monter(t, garde);
    expect(find.text('CONTENU'), findsNothing);
    expect(find.text('Page introuvable'), findsOneWidget);
    await _monter(t, garde, compte: demoAccount);
    expect(find.text('CONTENU'), findsNothing);
    await _monter(t, garde, compte: _by('Admin global'));
    expect(find.text('CONTENU'), findsOneWidget);
  });

  testWidgets('LoginGuard : « Connexion requise » pour un visiteur avec le serveur, écran ouvert sinon', (t) async {
    const garde = LoginGuard(child: Text('CONTENU'));
    Backend.ready = true;
    await _monter(t, garde);
    expect(find.text('CONTENU'), findsNothing);
    expect(find.text('Connexion requise'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    await _monter(t, garde, compte: demoAccount);
    expect(find.text('CONTENU'), findsOneWidget);
    Backend.ready = false;
    await _monter(t, garde);
    expect(find.text('CONTENU'), findsOneWidget);
  });

  test('chaque rôle n\'ouvre que ses écrans', () {
    final student = demoAccount;
    final dept = _by('Resp. département');
    final finance = _by('Finance');
    final support = _by('Support');
    final direction = _by('Direction');
    final admin = _by('Admin global');

    expect(roleKey(student), 'student');
    expect(roleKey(null), 'visitor');

    // écrans ouverts à tous
    for (final id in ['03', '05', '06', '11', '22', '25', '206', '212', '237']) {
      expect(canOpen(null, id), isTrue, reason: 'écran $id');
    }
    // demande de devis : réservée aux comptes connectés, mais pas seulement aux entreprises
    expect(canOpen(null, '95b'), isFalse);
    expect(canOpen(student, '95b'), isTrue);
    expect(canOpen(student, '95'), isFalse);
    // espace vendeur
    expect(canOpen(student, '58'), isTrue);
    expect(canOpen(null, '58'), isFalse);
    expect(canOpen(finance, '58'), isFalse);
    // tableau de bord du studio (D1)
    expect(canOpen(null, 'D1'), isFalse);
    expect(canOpen(student, 'D1'), isTrue);
    expect(canOpen(dept, 'D1'), isTrue);
    expect(canOpen(finance, 'D1'), isFalse);
    expect(canOpen(admin, 'D1'), isTrue);
    // console du département
    expect(canOpen(dept, '110'), isTrue);
    expect(canOpen(student, '110'), isFalse);
    expect(canOpen(support, '111'), isFalse);
    // institution et administration globale
    expect(canOpen(direction, '126'), isTrue);
    expect(canOpen(dept, '126'), isFalse);
    expect(canOpen(admin, '137'), isTrue);
    expect(canOpen(direction, '137'), isFalse);
    expect(canOpen(support, '133'), isTrue);
    expect(canOpen(support, '128'), isFalse);
    // finance
    expect(canOpen(finance, '139'), isTrue);
    expect(canOpen(student, '139'), isFalse);
    expect(canOpen(finance, '135'), isTrue);
    // entreprise
    final company = seedAccounts.firstWhere((a) => a.role == 2);
    expect(canOpen(company, '90'), isTrue);
    expect(canOpen(student, '90'), isFalse);
    // l'administrateur global ouvre tout
    for (final id in ['58', '90', '110', '126', '128', '139', '145', '213']) {
      expect(canOpen(admin, id), isTrue, reason: 'écran $id');
    }
  });
}
