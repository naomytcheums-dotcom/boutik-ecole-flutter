import 'package:boutik_ecole/figma/g/g_273.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/engage.dart' show myDeletionProvider;
import 'package:boutik_ecole/figma/live/legal.dart';
import 'package:boutik_ecole/figma/live/verification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

/// Lot G1 (étudiant : inscription, vérification, compte, CGU/CGV, suppression) : textes juridiques fidèles à la règle en base,
/// nouvelle version des CGU redemandée, état de vérification lisible à 390 px, suppression gelée expliquée.
void main() {
  setUpAll(loadAppFonts);
  setUp(() => GScreen.mockupFrame = false);
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = false;
  });

  group('CGV et conditions', () {
    final all = [for (final tab in termsSections) for (final (t, b) in tab) '$t\n$b'];

    test('la répartition n\'est pas écrite en dur : renvoi à la règle en base, base hors livraison, texte à valider', () {
      final s = all.firstWhere((e) => e.startsWith('Répartition du prix'));
      expect(s, contains('selon la règle en vigueur'));
      expect(s, contains('prix des articles hors livraison'));
      expect(s, contains('texte de travail à valider par le propriétaire'));
      expect(s, isNot(contains('70')));
      expect(s, isNot(contains('20 %')));
    });

    test('la conservation décrit le gel de la suppression quand de l\'argent est en jeu', () {
      final s = all.firstWhere((e) => e.startsWith('Conservation'));
      expect(s, contains('séquestre'));
      expect(s, contains('réclamation'));
    });

    test('une version antérieure ou absente des CGU est redemandée, la version courante non', () {
      expect(termsOutdated(null), isTrue);
      expect(termsOutdated(''), isTrue);
      expect(termsOutdated('cgu-2026-01'), isTrue);
      expect(termsOutdated(kTermsVersion), isFalse);
      expect(termsOutdated('cgu-2099-01'), isFalse);
    });

    test('le message de refus de suppression (argent en jeu) parvient tel quel à la personne', () {
      const m = 'La suppression du compte est impossible pour le moment : 7000 FCFA gardés en séquestre jusqu\'à la livraison ; 5000 FCFA de solde disponible à retirer. Terminez ces opérations (livraison, retrait de votre solde, clôture des réclamations) puis refaites la demande.';
      expect(Backend.userMessage(m), m);
    });

    test('hors serveur, aucune acceptation n\'est réclamée', () async {
      Backend.ready = false;
      expect(await termsNeedAcceptance(), isFalse);
    });
  });

  group('carte de vérification étudiant', () {
    Future<void> monter(WidgetTester t, Map<String, dynamic> statut) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(ProviderScope(
        overrides: [myStudentStatusProvider.overrideWith((ref) async => statut)],
        child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(padding: EdgeInsets.all(24), child: StudentVerificationCard(width: 342)))),
      ));
      await t.pumpAndSettle();
    }

    testWidgets('étudiant non vérifié : dit ce qui est fermé et ce qui manque, sans débordement', (t) async {
      await monter(t, {
        'verified': false,
        'certification': 'none',
        'can_request_certification': true,
        'has_identity_document': false,
        'has_phone': true,
        'phone_verified': false,
        'has_department': false,
        'rejected_documents': [{'kind': 'student_card', 'note': 'Photo illisible'}],
      });
      expect(find.text('Vérification à compléter'), findsOneWidget);
      expect(find.textContaining('annuaire des talents, les invitations d’organisations'), findsOneWidget);
      expect(find.textContaining('Choisissez votre établissement et votre département'), findsOneWidget);
      expect(find.textContaining('Photo illisible'), findsOneWidget);
      expect(find.textContaining('Vérifiez votre numéro de téléphone'), findsOneWidget);
      expect(find.text('Vérifier mon numéro'), findsOneWidget);
      expect(find.text('Déposer une pièce'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('étudiant vérifié, numéro vérifié : aucune restriction affichée', (t) async {
      await monter(t, {
        'verified': true,
        'certification': 'approved',
        'can_request_certification': false,
        'has_identity_document': true,
        'has_phone': true,
        'phone_verified': true,
        'has_department': true,
        'rejected_documents': <dynamic>[],
      });
      expect(find.text('Étudiant vérifié'), findsOneWidget);
      expect(find.textContaining('Tant que vous n’êtes pas vérifié'), findsNothing);
      expect(find.text('Vérifier mon numéro'), findsNothing);
      expect(find.text('Déposer une pièce'), findsNothing);
      expect(t.takeException(), isNull);
    });
  });

  testWidgets('conditions de vente : la règle de répartition en vigueur vient de la base, sans débordement à 390 px', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(
      overrides: [splitRuleLineProvider.overrideWith((ref) async => 'Règle en vigueur aujourd’hui : 60 % pour l’étudiant-vendeur, 25 % pour le fonds, 15 % pour la plateforme, sur le prix des articles hors livraison.')],
      child: const MaterialApp(home: Scaffold(body: TermsReader(width: 342, height: 700))),
    ));
    final c = t.element(find.byType(TermsReader));
    ProviderScope.containerOf(c).read(termsTabProvider.notifier).set(1);
    await t.pumpAndSettle();
    expect(find.textContaining('Règle en vigueur aujourd’hui : 60 %'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('273 : une suppression gelée par de l\'argent en jeu est expliquée', (t) async {
    Backend.ready = true;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(
      overrides: [
        myDeletionProvider.overrideWith((ref) async => {'status': 'pending', 'scheduled_for': '2026-12-20T10:00:00Z', 'blocked': true, 'blocked_reason': '7000 FCFA gardés en séquestre jusqu\'à la livraison'}),
      ],
      child: const MaterialApp(home: G_273()),
    ));
    await t.pumpAndSettle();
    expect(find.textContaining('suspendue tant que : 7000 FCFA gardés en séquestre'), findsOneWidget);
    expect(find.text('Annuler la demande'), findsOneWidget);
  });
}
