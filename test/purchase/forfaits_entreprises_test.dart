import 'package:boutik_ecole/figma/live/company_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester t, Widget w, {List<Override> overrides = const []}) async {
  t.view.physicalSize = const Size(420, 2600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: w)));
  await t.pumpAndSettle();
}

const _plans = [
  {'code': 'free', 'name': 'Découverte', 'price_fcfa': 0, 'period_days': 0, 'max_needs': 1, 'max_offers': 1, 'max_contests': 0, 'perks': 'Un besoin et une offre actifs.', 'position': 1, 'active': true},
  {'code': 'pro', 'name': 'Entreprise', 'price_fcfa': 25000, 'period_days': 30, 'max_needs': 10, 'max_offers': 10, 'max_contests': 2, 'perks': 'Jusqu’à 10 besoins.', 'position': 2, 'active': true},
  {'code': 'partner', 'name': 'Partenaire', 'price_fcfa': 75000, 'period_days': 30, 'max_needs': 999, 'max_offers': 999, 'max_contests': 20, 'perks': 'Illimité.', 'position': 3, 'active': true},
];

void main() {
  test('prix et quotas lisibles', () {
    expect(planPriceLabel({'price_fcfa': 0, 'period_days': 0}), 'Gratuit');
    expect(planPriceLabel({'price_fcfa': 25000, 'period_days': 30}), '25 000 FCFA / mois');
    expect(planPriceLabel({'price_fcfa': 1250000, 'period_days': 90}), '1 250 000 FCFA / 90 jours');
    expect(quotaLabel(3, 10), '3 sur 10');
    expect(quotaLabel(4, 999), '4 (illimité)');
  });

  testWidgets('accueil entreprise : vérification, forfait et chiffres clés', (t) async {
    await _pump(t, const CompanyHomeScreen(), overrides: [
      companyDashboardProvider.overrideWith((ref) async => {
            'company_name': 'Orange Cameroun',
            'status': 'approved',
            'plan_name': 'Entreprise',
            'plan_ends_at': '2026-12-14T10:00:00Z',
            'needs_open': 3,
            'proposals_new': 5,
            'offers_active': 2,
            'applications_new': 7,
            'contests_active': 1,
            'recruits': 4,
          }),
    ]);
    expect(find.text('Orange Cameroun'), findsOneWidget);
    expect(find.text('Entreprise vérifiée'), findsOneWidget);
    expect(find.text('Forfait Entreprise'), findsOneWidget);
    expect(find.text('Actif jusqu’au 2026-12-14'), findsOneWidget);
    expect(find.text('Propositions à traiter'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('Publier un besoin'), findsOneWidget);
    expect(find.text('Rechercher des talents'), findsOneWidget);
  });

  testWidgets('accueil entreprise non vérifiée : appel à compléter la fiche', (t) async {
    await _pump(t, const CompanyHomeScreen(), overrides: [
      companyDashboardProvider.overrideWith((ref) async => {'company_name': null, 'status': 'none', 'plan_name': 'Découverte', 'needs_open': 0, 'proposals_new': 0, 'offers_active': 0, 'applications_new': 0, 'contests_active': 0, 'recruits': 0}),
    ]);
    expect(find.textContaining('Brouillon'), findsOneWidget);
    expect(find.text('Compléter'), findsOneWidget);
    expect(find.text('Sans date de fin'), findsOneWidget);
  });

  testWidgets('forfaits : actuel, demande en attente, demandable', (t) async {
    await _pump(t, const Scaffold(body: CompanyPlansSheet()), overrides: [
      companyPlansProvider.overrideWith((ref) async => [for (final p in _plans) Map<String, dynamic>.from(p)]),
      companyPlanStatusProvider.overrideWith((ref) async => {'plan': _plans[0], 'requested': 'pro', 'used_needs': 1, 'used_offers': 0, 'used_contests': 0}),
    ]);
    expect(find.text('Forfaits entreprise'), findsOneWidget);
    expect(find.text('Votre forfait actuel'), findsOneWidget);
    expect(find.textContaining('Demande envoyée'), findsOneWidget);
    expect(find.text('Payer par Mobile Money'), findsNWidgets(2), reason: 'Entreprise et Partenaire sont payables en ligne');
    expect(find.textContaining('Payer autrement'), findsNWidgets(1), reason: 'Entreprise : demande déjà envoyée, plus de second envoi');
    expect(find.text('25 000 FCFA / mois'), findsOneWidget);
    expect(find.text('75 000 FCFA / mois'), findsOneWidget);
  });

  testWidgets('administrateur : demandes à activer et forfaits modifiables', (t) async {
    await _pump(t, const CompanyPlansAdminScreen(), overrides: [
      companyPendingPlansProvider.overrideWith((ref) async => [
            {'owner_id': 'o1', 'company_name': 'Orange Cameroun', 'plan_code': 'pro', 'plan_name': 'Entreprise', 'price_fcfa': 25000, 'period_days': 30, 'phone': '699000000', 'email': 'rh@orange.cm'}
          ]),
      companyPlansProvider.overrideWith((ref) async => [for (final p in _plans) Map<String, dynamic>.from(p)]),
    ]);
    expect(find.text('Demandes à activer'), findsOneWidget);
    expect(find.text('Orange Cameroun'), findsOneWidget);
    expect(find.text('Paiement reçu : activer'), findsOneWidget);
    expect(find.text('Forfaits (prix et quotas)'), findsOneWidget);
    expect(find.byTooltip('Modifier'), findsNWidgets(3));
  });
}
