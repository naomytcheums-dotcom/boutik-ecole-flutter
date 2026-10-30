import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    await t.enterText(fields.at(0), 'Étudiante en design, je crée des logos.');
    await t.enterText(fields.at(1), 'Design, Figma ,  ,Logo');
    await t.enterText(fields.at(2), 'Yaoundé');
    await t.tap(find.text('Enregistrer'));
    await t.pumpAndSettle();
    final a = container.read(authProvider).current!;
    expect(a.bio, 'Étudiante en design, je crée des logos.');
    expect(a.skills, 'Design, Figma, Logo');
    expect(a.city, 'Yaoundé');
    expect(a.certification, 'pending'); // la certification n'est pas modifiable depuis le profil
    expect(a.certified, isFalse);
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
    await t.enterText(find.byType(TextField).first, 'après');
    await t.tap(find.text('Annuler'));
    await t.pumpAndSettle();
    expect(container.read(authProvider).current!.bio, 'avant');
  });
}
