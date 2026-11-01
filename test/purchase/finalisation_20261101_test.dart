import 'package:boutik_ecole/figma/g/g_164.dart';
import 'package:boutik_ecole/figma/g/g_165.dart';
import 'package:boutik_ecole/figma/g/g_167.dart';
import 'package:boutik_ecole/figma/g/g_192.dart';
import 'package:boutik_ecole/figma/g/g_64.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/drafts.dart';
import 'package:boutik_ecole/figma/live/hackathons.dart';
import 'package:boutik_ecole/figma/live/missions.dart';
import 'package:boutik_ecole/figma/live/ops.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/render.dart';

/// Finalisation du 01/11/2026 : plus aucun succès affiché sans réalité (serveur ou appareil), brouillons réellement enregistrés,
/// parcours de mission et de concours qui ne simulent plus rien quand le serveur est joignable.
void main() {
  setUpAll(loadAppFonts);
  setUp(() {
    Backend.ready = false;
    Backend.recovery.value = false;
    Drafts.values = {};
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    Backend.ready = false;
    Backend.recovery.value = false;
  });

  Future<ProviderContainer> pump(WidgetTester tester, Widget screen, {Size size = const Size(390, 900)}) async {
    GAnim.enabled = false;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: MaterialApp(home: Scaffold(body: screen))));
    await tester.pumpAndSettle();
    return c;
  }

  /// Bouton minimal qui appelle une action métier : évite de construire un écran complet quand le serveur est « joignable ».
  Future<ProviderContainer> pumpAction(WidgetTester tester, void Function(WidgetRef ref, BuildContext context) action) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        home: Scaffold(body: Consumer(builder: (context, ref, _) => Center(child: TextButton(onPressed: () => action(ref, context), child: const Text('agir'))))),
      ),
    ));
    await tester.tap(find.text('agir'));
    await tester.pumpAndSettle();
    return c;
  }

  group('brouillons sur l’appareil', () {
    test('enregistrés, rechargés au démarrage, repris par le formulaire puis effacés', () async {
      expect(await Drafts.save('165', {'dp_title': 'Four solaire', 'dp_desc': 'Cuisson sans bois pour les marchés ruraux'}), isTrue);
      Drafts.values = {};
      await Drafts.load();
      expect(draftValue('dp_title', 'maquette'), 'Four solaire');
      expect(draftValue('dp_link', 'maquette'), 'maquette');
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(formProvider)['dp_desc'], 'Cuisson sans bois pour les marchés ruraux');
      await Drafts.clear('165', const ['dp_title', 'dp_desc']);
      expect(draftValue('dp_title', 'maquette'), 'maquette');
      await Drafts.load();
      expect(Drafts.values, isEmpty);
    });

    test('effacés à la déconnexion : l’utilisateur suivant ne les voit pas', () async {
      await Drafts.save('195', {'ms_proof': 'Trois pistes de logo livrées'});
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(authProvider.notifier).logout();
      await Future<void>.delayed(Duration.zero);
      await Drafts.load();
      expect(Drafts.values, isEmpty);
    });

    testWidgets('écran 165 : « Enregistrer » enregistre vraiment le brouillon sur l’appareil', (tester) async {
      final c = await pump(tester, const G_165());
      c.read(formProvider.notifier).put('dp_title', 'Four solaire');
      await tester.tap(find.text('Enregistrer'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.textContaining('Brouillon enregistré sur cet appareil'), findsOneWidget);
      final p = await SharedPreferences.getInstance();
      expect(p.getString('boutik.draft.165'), contains('Four solaire'));
    });

    testWidgets('écran 165 : sans saisie, rien n’est annoncé comme enregistré', (tester) async {
      await pump(tester, const G_165());
      await tester.tap(find.text('Enregistrer'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.textContaining('Rien à enregistrer'), findsOneWidget);
      expect(find.textContaining('Brouillon enregistré'), findsNothing);
    });
  });

  group('plus de faux succès', () {
    testWidgets('écran 167 : les notes ne sont pas présentées comme enregistrées', (tester) async {
      await pump(tester, const G_167());
      await tester.tap(find.text('Enregistrer'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.textContaining('rien n’est transmis'), findsOneWidget);
      expect(find.textContaining('Note enregistrée'), findsNothing);
    });

    testWidgets('écran 164 : aucun « Message envoyé au mentor »', (tester) async {
      await pump(tester, const G_164());
      await tester.tap(find.text('Message'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Messagerie des mentors'), findsOneWidget);
      expect(find.textContaining('Message envoyé au mentor'), findsNothing);
    });

    testWidgets('écran 192 : « Poser une question » ouvre la vraie messagerie de mission (hors connexion : expliqué)', (tester) async {
      await pump(tester, const G_192());
      await tester.tap(find.text('Poser une question'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Hors connexion'), findsOneWidget);
      expect(find.textContaining('Question envoyée'), findsNothing);
    });

    testWidgets('écran 64 : « Signaler un souci » écrit à l’acheteur (hors connexion : expliqué)', (tester) async {
      await pump(tester, const G_64());
      await tester.tap(find.text('Signaler un souci'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.textContaining('nécessite la connexion au serveur'), findsOneWidget);
      expect(find.textContaining('Signalement envoyé au département'), findsNothing);
    });
  });

  group('serveur joignable : rien n’est simulé', () {
    testWidgets('jalon de mission : aucun paiement « bloqué en séquestre » sans paiement réel', (tester) async {
      Backend.ready = true;
      final c = await pumpAction(tester, (ref, context) => payNextMilestone(ref, context));
      expect(find.text('Paiement du jalon indisponible'), findsOneWidget);
      expect(find.textContaining('bloqué en séquestre'), findsNothing);
      expect(c.read(missionProvider).funded, 2); // la mission d'exemple n'est pas modifiée
    });

    testWidgets('concours : dépôt et notation expliqués, aucun envoi simulé', (tester) async {
      Backend.ready = true;
      final c = await pumpAction(tester, (ref, context) => submitDeposit(ref, context));
      expect(find.text('Dépôt non disponible'), findsOneWidget);
      expect(c.read(submissionProvider), isNull);
      await tester.tap(find.text('Compris').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('agir'));
      await tester.pumpAndSettle();
    });

    testWidgets('jury : aucune note annoncée comme enregistrée', (tester) async {
      Backend.ready = true;
      await pumpAction(tester, (ref, context) => validateJury(ref, context));
      expect(find.text('Notation non disponible'), findsOneWidget);
      expect(find.textContaining('Note validée'), findsNothing);
    });

    test('classement : aucune équipe fictive quand le serveur est joignable', () {
      Backend.ready = true;
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(rankingProvider), isEmpty);
      Backend.ready = false;
      final d = ProviderContainer();
      addTearDown(d.dispose);
      expect(d.read(rankingProvider), isNotEmpty); // hors connexion : exemples de la maquette (tests, aperçu)
    });

    test('signalements : compteurs exacts, sans les chiffres de la maquette', () {
      Backend.ready = true;
      const l = [
        Report('Annonce « A »', 'Fraude', '', 'Non assigné', 'Ouvert', id: '1'),
        Report('Annonce « B »', 'Prix', '', 'Non assigné', 'En traitement', id: '2'),
      ];
      final k = reportCounters(l);
      expect((k.open, k.work, k.done), (1, 1, 0));
    });

    testWidgets('mot de passe oublié : un numéro de téléphone est refusé (réinitialisation par e-mail uniquement)', (tester) async {
      Backend.ready = true;
      final c = await pumpAction(tester, (ref, context) {
        ref.read(formProvider.notifier).put('fg_id', '+237 699 99 99 99');
        submitForgot(ref, context);
      });
      expect(c.read(errorsProvider)['fg_id'], contains('réinitialisation par SMS'));
      expect(find.textContaining('démonstration'), findsNothing);
    });

    testWidgets('nouveau mot de passe : refusé sans lien de réinitialisation ouvert, jamais « modifié »', (tester) async {
      Backend.ready = true;
      await pumpAction(tester, (ref, context) {
        ref.read(formProvider.notifier).put('rs_pw', 'Nouveau-Mot2Passe!');
        ref.read(formProvider.notifier).put('rs_pw2', 'Nouveau-Mot2Passe!');
        submitReset(ref, context);
      });
      expect(find.text('Mot de passe non modifié'), findsOneWidget);
      expect(find.textContaining('Mot de passe modifié'), findsNothing);
    });
  });
}
