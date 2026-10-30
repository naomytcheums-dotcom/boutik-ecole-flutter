import 'dart:io';

import 'package:boutik_ecole/core/router/app_router.dart';
import 'package:boutik_ecole/figma/live/access.dart';
import 'package:boutik_ecole/figma/live/account_menu.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:flutter_test/flutter_test.dart';

/// Liens de parcours : chaque cible existe, la casse des identifiants du studio est tolérée,
/// le menu du compte ne propose que des écrans que le rôle peut ouvrir.
void main() {
  test("les identifiants du studio créateur s'ouvrent quelle que soit la casse", () {
    for (final id in ['p3', 'P3', 'l1', 'L1', 'a3', 'd1', 'p5']) {
      expect(screenById(id), isNotNull, reason: id);
    }
    expect(screenById('p3')!.id, 'P3');
    expect(screenById('146_1'), isNotNull);
    expect(screenById('inexistant'), isNull);
  });

  test('chaque lien gOpen/gTab des écrans désigne un écran existant', () {
    final call = RegExp(r"""\bg(?:Open|Tab)\(context,\s*'([^']+)'\)""");
    final bad = <String>[];
    var n = 0;
    for (final f in Directory('lib/figma/g').listSync().whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      for (final m in call.allMatches(f.readAsStringSync())) {
        n++;
        if (screenById(m.group(1)) == null) bad.add('${f.uri.pathSegments.last} -> ${m.group(1)}');
      }
    }
    expect(n, greaterThan(400));
    expect(bad, isEmpty);
  });

  test('les liens métier ajoutés à la reprise sont présents et ciblent des écrans existants', () {
    final mark = RegExp(r"gOpen\(context, '([^']+)'\); \}\), // lien métier");
    final targets = <String>{};
    for (final f in Directory('lib/figma/g').listSync().whereType<File>()) {
      targets.addAll(mark.allMatches(f.readAsStringSync()).map((m) => m.group(1)!));
    }
    expect(targets.length, greaterThan(50));
    for (final t in targets) {
      expect(screenById(t), isNotNull, reason: t);
    }
    expect(targets, containsAll(['32', '38', '39', '211', '255', '199', '283', '284', '23']));
  });

  test('le menu du compte ne propose à chaque rôle que des écrans qu’il peut ouvrir', () {
    const accounts = <String, Account>{
      'client': Account(name: 'C', phone: '', email: 'c@x.cm', password: '', role: 0),
      'student': Account(name: 'E', phone: '', email: 'e@x.cm', password: '', role: 1),
      'company': Account(name: 'N', phone: '', email: 'n@x.cm', password: '', role: 2),
      'dept': Account(name: 'D', phone: '', email: 'd@x.cm', password: '', role: 3, staff: 'Resp. département'),
      'finance': Account(name: 'F', phone: '', email: 'f@x.cm', password: '', role: 3, staff: 'Finance'),
      'support': Account(name: 'S', phone: '', email: 's@x.cm', password: '', role: 3, staff: 'Support'),
      'admin': Account(name: 'A', phone: '', email: 'a@x.cm', password: '', role: 3, staff: 'Admin global'),
    };
    for (final e in accounts.entries) {
      expect(roleKey(e.value), e.key);
      for (final (label, screen) in accountMenuEntries(e.key)) {
        if (screen == null) continue;
        expect(screenById(screen), isNotNull, reason: '$label ($screen)');
        expect(canOpen(e.value, screenById(screen)!.id), isTrue, reason: '${e.key} : $label ($screen)');
      }
    }
    final client = accountMenuEntries('client').map((x) => x.$1).toList();
    expect(client, containsAll(['Préférences d’alertes', 'Centre de sécurité']));
    expect(client, isNot(contains('Rôles et permissions')));
    expect(client, isNot(contains('Aller en direct')));
    expect(accountMenuEntries('student').map((x) => x.$1), containsAll(['Aller en direct', 'Publier un vœu', 'Lancer une campagne de financement']));
    expect(accountMenuEntries('company').map((x) => x.$1), containsAll(['Espace projet', 'Historique des besoins']));
    expect(accountMenuEntries('admin').map((x) => x.$1), containsAll(['Rôles et permissions', 'Intégrations', 'Supervision des bornes']));
  });

  test('la gestion des rôles (180, 181) est réservée à l’administration', () {
    expect(allowedRoles('180'), {'admin'});
    expect(allowedRoles('181'), {'admin'});
    expect(canOpen(null, '180'), isFalse);
  });
}
