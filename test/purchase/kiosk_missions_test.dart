import 'package:boutik_ecole/data/repositories/repositories.dart' show cartProvider;
import 'package:boutik_ecole/figma/live/missions.dart';
import 'package:boutik_ecole/figma/live/store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('borne : code signé, 5 minutes, usage unique', () {
    final t = DateTime(2026, 10, 29, 10, 0, 0);
    final a = signToken('Lampe en bois recyclé', t);
    expect(a.length, 8);
    expect(signToken('Lampe en bois recyclé', t), a); // déterministe
    expect(signToken('Drone éducatif', t), isNot(a)); // dépend du produit
    expect(signToken('Lampe en bois recyclé', t.add(const Duration(seconds: 1))), isNot(a)); // dépend de l'heure

    final p = liveCatalog.first;
    final fresh = QrSession(a, p, DateTime.now());
    expect(fresh.expired, isFalse);
    expect(fresh.secondsLeft(), inInclusiveRange(298, 300));
    expect(fresh.tracking, matches(RegExp(r'^BE-\d{4}-[0-9A-F]{4}$')));
    final old = QrSession(a, p, DateTime.now().subtract(const Duration(minutes: 6)));
    expect(old.expired, isTrue);
    expect(old.secondsLeft(), 0);

    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(kioskSessionProvider), isNull);
    c.read(kioskSessionProvider.notifier).start(p);
    expect(c.read(kioskSessionProvider)!.used, isFalse);
    c.read(kioskSessionProvider.notifier).use();
    expect(c.read(kioskSessionProvider)!.used, isTrue); // un second scan serait refusé
    // le produit part dans le panier du téléphone
    c.read(cartProvider.notifier).add(p.toLine());
    expect(c.read(cartProvider).any((l) => l.title == p.title), isTrue);

    c.read(kioskQueryProvider.notifier).set('drone');
    expect(c.read(kioskProductsProvider).first.title, 'Drone éducatif');
  });

  test('missions : jalons, séquestre, libération et revenus', () {
    const m = Mission(id: '#BR-0001', kind: 'Prototype', desc: 'Prototype de support', total: 180000, date: '29 oct. 2026');
    expect(m.amountOf(0), 54000);
    expect(m.amountOf(1), 72000);
    expect(m.amountOf(2), 54000);
    expect(m.fee, 18000);
    expect(m.pct, 0);

    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(missionProvider.notifier);
    var s = c.read(missionProvider); // mission de démonstration : 2 jalons financés, 1 libéré, 1 preuve en attente
    expect((s.funded, s.proof, s.released), (2, 1, 1));
    expect(s.studentEarned, 37800); // 70 % de 54 000
    expect(s.pendingAmount, 0); // la preuve du jalon 1 est déjà validée

    n.create(m);
    n.accept();
    n.fund();
    expect(c.read(missionProvider).funded, 1);
    n.sendProof();
    expect(c.read(missionProvider).pendingAmount, 54000);
    n.release();
    s = c.read(missionProvider);
    expect(s.released, 1);
    expect(s.studentEarned, 37800);
    n.fund();
    n.sendProof();
    expect(c.read(missionProvider).pendingAmount, 72000);
    n.retractProof();
    expect(c.read(missionProvider).pendingAmount, 0);
    n.sendProof();
    n.release();
    expect(c.read(missionProvider).studentEarned, (54000 + 72000) * 70 ~/ 100);
    expect(c.read(missionProvider).pct, greaterThan(40));
  });
}
