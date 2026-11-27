import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> openEditProfile(WidgetTester t) async {
  const compte = Account(name: 'Nina Test', phone: '690000001', email: 'nina@example.com', password: '');
  await t.pumpWidget(ProviderScope(
    overrides: [initialAccountProvider.overrideWithValue(compte)],
    child: MaterialApp(
      home: Consumer(builder: (context, ref, _) => Scaffold(body: Center(child: TextButton(onPressed: () => editProfileDialog(context, ref), child: const Text('modifier'))))),
    ),
  ));
  await t.tap(find.text('modifier'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('nom vide : message dans la fenêtre, saisie conservée', (t) async {
    await openEditProfile(t);
    await t.enterText(find.byType(TextField).at(0), '');
    await t.tap(find.text('Enregistrer'));
    await t.pump();
    expect(find.text('Indiquez votre nom (2 lettres au minimum).'), findsOneWidget);
    expect(find.text('Enregistrer'), findsOneWidget);
  });

  testWidgets('modifier mon profil : description, compétences et ville enregistrées sur le compte connecté, sans toucher à la certification', (t) async {
    const compte = Account(name: 'Nina Test', phone: '690000001', email: 'nina@example.com', password: '', verified: true, certification: 'pending');
    late ProviderContainer container;
    await t.pumpWidget(ProviderScope(
      overrides: [initialAccountProvider.overrideWithValue(compte)],
      child: MaterialApp(
        home: Consumer(builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          return Scaffold(body: Center(child: TextButton(onPressed: () => editProfileDialog(context, ref), child: const Text('modifier'))));
        }),
      ),
    ));
    await t.tap(find.text('modifier'));
    await t.pumpAndSettle();
    expect(find.text('Modifier mon profil'), findsOneWidget);
    final fields = find.byType(TextField);
    await t.enterText(fields.at(1), 'Étudiante en design, je crée des logos.');
    await t.enterText(fields.at(2), 'Design, Figma ,  ,Logo');
    await t.enterText(fields.at(3), 'Yaoundé');
    await t.tap(find.text('Enregistrer'));
    await t.pumpAndSettle();
    final a = container.read(authProvider).current!;
    expect(a.bio, 'Étudiante en design, je crée des logos.');
    expect(a.skills, 'Design, Figma, Logo');
    expect(a.city, 'Yaoundé');
    expect(a.certification, 'pending'); // la certification n'est pas modifiable depuis le profil
    expect(a.certified, isFalse);
  });

  testWidgets('la ville peut être effacée (S2-3)', (t) async {
    const compte = Account(name: 'Nina Test', phone: '690000001', email: 'nina@example.com', password: '', city: 'Douala');
    late ProviderContainer container;
    await t.pumpWidget(ProviderScope(
      overrides: [initialAccountProvider.overrideWithValue(compte)],
      child: MaterialApp(
        home: Consumer(builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          return Scaffold(body: Center(child: TextButton(onPressed: () => editProfileDialog(context, ref), child: const Text('modifier'))));
        }),
      ),
    ));
    await t.tap(find.text('modifier'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).at(3), '');
    await t.tap(find.text('Enregistrer'));
    await t.pumpAndSettle();
    expect(container.read(authProvider).current!.city, '');
  });

  test('fusion des compétences : le texte libre est conservé, celles du Passport sont ajoutées sans doublon (S2-1)', () {
    expect(mergeSkillLists(['Python', 'React'], ['react', 'Flutter', 'Python']), ['Python', 'React', 'Flutter']);
    expect(mergeSkillLists([], ['Logo']), ['Logo']);
    expect(mergeSkillLists(['', ' '], []), isEmpty);
  });

  testWidgets('annuler ne change rien', (t) async {
    const compte = Account(name: 'Nina Test', phone: '690000001', email: 'nina@example.com', password: '', bio: 'avant');
    late ProviderContainer container;
    await t.pumpWidget(ProviderScope(
      overrides: [initialAccountProvider.overrideWithValue(compte)],
      child: MaterialApp(
        home: Consumer(builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          return Scaffold(body: Center(child: TextButton(onPressed: () => editProfileDialog(context, ref), child: const Text('modifier'))));
        }),
      ),
    ));
    await t.tap(find.text('modifier'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).at(1), 'après');
    await t.tap(find.text('Annuler'));
    await t.pumpAndSettle();
    expect(container.read(authProvider).current!.bio, 'avant');
  });
}
