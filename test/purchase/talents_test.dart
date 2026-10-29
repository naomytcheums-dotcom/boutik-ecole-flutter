import 'package:boutik_ecole/figma/live/talents.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('talents : filtre par domaine et recherche', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(visibleTalentsProvider).length, talents.length);
    c.read(talentTabProvider.notifier).set(2); // Design
    expect(c.read(visibleTalentsProvider).every((t) => t.category == 'Design'), isTrue);
    c.read(talentTabProvider.notifier).set(0);
    c.read(talentQueryProvider.notifier).set('iot');
    expect(c.read(visibleTalentsProvider).single.name, 'Brice Ndoumbe');
    c.read(talentRequestsProvider.notifier).send('Brice Ndoumbe', 'Prototype de capteur');
    expect(c.read(talentRequestsProvider).containsKey('Brice Ndoumbe'), isTrue);
  });

  test('projets : filtre par étape et ajout', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(visibleProjectsProvider).length, 4);
    c.read(projectTabProvider.notifier).set(3); // Financement
    expect(c.read(visibleProjectsProvider).map((p) => p.title), ['Serre intelligente']);
    c.read(projectTabProvider.notifier).set(0);
    c.read(projectsProvider.notifier).add(const Project('Four solaire', 'Génie civil', 10, 'Prototype'));
    c.read(projectTabProvider.notifier).set(1); // Prototypes
    expect(c.read(visibleProjectsProvider).first.title, 'Four solaire');
    c.read(selectedProjectProvider.notifier).set('Four solaire');
    expect(c.read(currentProjectProvider).dept, 'Génie civil');
  });

  test('opportunités : onglets et candidatures', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(visibleOpportunities75).every((o) => o.kind == 'Stage'), isTrue);
    c.read(oppTabProvider.notifier).set(1);
    expect(c.read(visibleOpportunities75).every((o) => o.kind == 'Emploi'), isTrue);
    c.read(oppHubTabProvider.notifier).set(5);
    expect(c.read(visibleOpportunities151).single.title, 'Hackathon Orange Digital');
    expect(c.read(applicationsProvider).containsKey('Stage développeur web'), isFalse);
    c.read(applicationsProvider.notifier).apply('Stage développeur web', 'Je suis très motivée pour ce stage.');
    expect(c.read(applicationsProvider).containsKey('Stage développeur web'), isTrue);
  });
}
