import 'package:boutik_ecole/figma/live/ops.dart';
import 'package:boutik_ecole/figma/live/seller.dart';
import 'package:boutik_ecole/figma/live/store.dart';
import 'package:boutik_ecole/figma/live/talents.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('signalements : création, compteurs, traitement', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(reportCounters(c.read(allReportsProvider)).open, 27);
    c.read(reportsProvider.notifier).add(const Report('Annonce « Lampe en bois recyclé »', 'Fraude', 'À l’instant', 'Non assigné', 'Ouvert', listing: 'Lampe en bois recyclé'));
    expect(c.read(allReportsProvider).first.status, 'Ouvert');
    expect(reportCounters(c.read(allReportsProvider)).open, 28);

    // traitement d'un signalement de démonstration
    c.read(reportEditsProvider.notifier).set('Annonce frauduleuse', 'Résolu', 'Support 01');
    final r = c.read(allReportsProvider);
    expect(r.firstWhere((x) => x.title == 'Annonce frauduleuse').status, 'Résolu');
    final k = reportCounters(r);
    expect(k.done, 143);
    expect(k.open, 27); // 28 - l'urgent résolu... +0 : 27 + (2 ouverts) - (1 ouvert + 1 urgent)

    // retrait du contenu signalé : l'annonce sort du catalogue acheteur
    c.read(searchQueryProvider.notifier).set('lampe');
    expect(c.read(filteredProductsProvider).isNotEmpty, isTrue);
    c.read(listingsProvider.notifier).review('Lampe en bois recyclé', false);
    expect(c.read(listingsProvider).firstWhere((l) => l.title == 'Lampe en bois recyclé').label, 'Brouillon');
  });

  test('commissions : règles modifiables', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(rulesConfigProvider).product, 5);
    c.read(rulesConfigProvider.notifier).set(const Rules(product: 8, service: 9, financing: 3, threshold: 15000, updated: '29 oct. 2026'));
    expect(c.read(rulesConfigProvider).product, 8);
    expect(c.read(rulesConfigProvider).threshold, 15000);
  });

  test('supervision des commandes et validation des projets', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(orderRowsProvider).length, 4);
    final o = c.read(ordersProvider.notifier).place();
    expect(c.read(orderRowsProvider).first.id, o.id);
    expect(c.read(orderRowsProvider).first.real, isTrue);
    c.read(ordersProvider.notifier).advance(o.id);
    expect(c.read(orderRowsProvider).first.status, 'En préparation');

    c.read(projectsProvider.notifier).add(const Project('Four solaire', 'Génie civil', 10, 'Prototype', review: 'À valider'));
    expect(c.read(projectQueueProvider).first.title, 'Four solaire');
    expect(c.read(visibleProjectsProvider).any((p) => p.title == 'Four solaire'), isFalse);
    c.read(projectsProvider.notifier).setReview('Four solaire', 'À corriger');
    expect(c.read(projectQueueProvider).first.review, 'À corriger');
    c.read(projectsProvider.notifier).setReview('Four solaire', 'Validé');
    c.read(projectTabProvider.notifier).set(1);
    expect(c.read(visibleProjectsProvider).any((p) => p.title == 'Four solaire'), isTrue);
  });
}
