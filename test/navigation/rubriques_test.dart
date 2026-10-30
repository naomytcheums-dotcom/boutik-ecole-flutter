import 'package:boutik_ecole/features/screens.dart';
import 'package:boutik_ecole/figma/live/access.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/espace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Set<String> ids(Account? a) => {for (final l in rubriquesPour(a).values) for (final e in l) e.$1};

  test('chaque écran est rattaché à exactement une rubrique', () {
    final seen = <String>{};
    for (final s in allScreens) {
      expect(seen.add(s.id), isTrue, reason: 'identifiant en double ${s.id}');
      expect(rubriqueDe(s.id), isNotNull);
    }
    expect(seen.length, allScreens.length);
  });

  test('un visiteur ne voit que les écrans ouverts à tous', () {
    final v = ids(null);
    expect(v, isNotEmpty);
    for (final id in v) {
      expect(canOpen(null, id), isTrue, reason: id);
    }
    expect(v.contains('57'), isFalse); // espace vendeur
    expect(v.contains('127'), isFalse); // administration globale
  });

  test('chaque rôle voit exactement les écrans que le routeur lui autorise', () {
    final accounts = <String, Account?>{
      'visiteur': null,
      'client': const Account(name: 'C', phone: '', email: 'c@x.cm', password: '', role: 0),
      'étudiant': const Account(name: 'E', phone: '', email: 'e@x.cm', password: '', role: 1),
      'entreprise': const Account(name: 'N', phone: '', email: 'n@x.cm', password: '', role: 2),
      'département': const Account(name: 'D', phone: '', email: 'd@x.cm', password: '', role: 3, staff: 'Resp. département'),
      'finance': const Account(name: 'F', phone: '', email: 'f@x.cm', password: '', role: 3, staff: 'Finance'),
      'admin': const Account(name: 'A', phone: '', email: 'a@x.cm', password: '', role: 3, staff: 'Admin global'),
    };
    for (final e in accounts.entries) {
      final visible = ids(e.value);
      for (final s in allScreens) {
        expect(visible.contains(s.id), canOpen(e.value, s.id), reason: '${e.key} · ${s.id}');
      }
    }
    // l'étudiant accède à son espace vendeur, pas à l'administration ; l'administrateur voit tout
    expect(ids(accounts['étudiant']).contains('57'), isTrue);
    expect(ids(accounts['étudiant']).contains('127'), isFalse);
    expect(ids(accounts['admin']).length, allScreens.length);
  });

  test('la recherche filtre par titre ou numéro', () {
    final r = rubriquesPour(null, filtre: 'favoris');
    expect(r.values.expand((l) => l).every((e) => e.$2.toLowerCase().contains('favoris') || e.$1.contains('favoris')), isTrue);
    expect(rubriquesPour(null, filtre: 'zzzz-inexistant'), isEmpty);
  });
}
