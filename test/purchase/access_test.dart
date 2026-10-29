import 'package:boutik_ecole/figma/live/access.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:flutter_test/flutter_test.dart';

Account _by(String staff) => seedAccounts.firstWhere((a) => a.staff == staff);

void main() {
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
    // espace vendeur
    expect(canOpen(student, '58'), isTrue);
    expect(canOpen(null, '58'), isFalse);
    expect(canOpen(finance, '58'), isFalse);
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
