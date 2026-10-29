import 'package:boutik_ecole/figma/live/admin.dart';
import 'package:boutik_ecole/figma/live/audit.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('le journal d\'audit garde les actions et se filtre par onglet et recherche', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(globalAuditProvider).length, 8); // exemples seuls
    c.read(auditProvider.notifier).log('Mariam Essono', 'Connexion réussie', 'Application', 'Connexions');
    c.read(auditProvider.notifier).log('Finance', 'Paiement vérifié', 'TX-0143', 'Finances');
    expect(c.read(globalAuditProvider).first.action, 'Paiement vérifié'); // le plus récent d'abord

    c.read(auditTabProvider.notifier).set(2); // Finances (vue globale)
    expect(c.read(globalAuditProvider).every((e) => e.cat == 'Finances'), isTrue);
    expect(c.read(globalAuditProvider).length, 2);

    c.read(auditTabProvider.notifier).set(1); // Connexions (vue institution)
    expect(c.read(institutionAuditProvider).map((e) => e.action), ['Connexion réussie']);

    c.read(auditTabProvider.notifier).set(0);
    c.read(auditQueryProvider.notifier).set('lampe');
    expect(c.read(globalAuditProvider).single.target, 'Lampe en bois recyclé');
  });

  test('administration des comptes : suspension, rôle, ordre d\'affichage', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(authProvider.notifier);
    expect(c.read(adminUsersProvider).first.name, 'Mariam Essono');
    expect(c.read(adminUsersProvider).any((a) => a.suspended), isTrue);

    final nouveau = Account(name: 'Paul Nkoa', phone: '677000111', email: 'paul@mail.cm', password: 'Secret123');
    n.register(nouveau);
    expect(c.read(adminUsersProvider).first.name, 'Paul Nkoa'); // inscriptions récentes d'abord

    final mbarga = c.read(adminUsersProvider).firstWhere((a) => a.name == 'Dr Mbarga');
    expect(mbarga.roleLabel, 'Resp. département');
    n.update(mbarga.copyWith(suspended: true, staff: 'Finance'));
    final m2 = c.read(authProvider).accounts.firstWhere((a) => a.name == 'Dr Mbarga');
    expect(m2.suspended, isTrue);
    expect(m2.roleLabel, 'Finance');
  });
}
