import 'package:boutik_ecole/figma/live/company_home.dart';
import 'package:boutik_ecole/figma/live/company_screens.dart';
import 'package:boutik_ecole/figma/live/company_team.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester t, Widget w, {List<Override> overrides = const []}) async {
  t.view.physicalSize = const Size(420, 3000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: w)));
  await t.pumpAndSettle();
}

Map<String, dynamic> _team(String myRole) => {
      'my_role': myRole,
      'owner': {'user_id': 'o', 'name': 'Orange C.'},
      'members': [
        {'user_id': 'a', 'name': 'Alice A.', 'email': myRole == 'viewer' ? null : 'alice@orange.cm', 'role': 'admin', 'status': 'active'},
        {'user_id': 'f', 'name': 'Fabrice F.', 'email': myRole == 'viewer' ? null : 'fabrice@orange.cm', 'role': 'finance', 'status': 'active'},
        {'user_id': 'x', 'name': 'Xavier X.', 'email': myRole == 'viewer' ? null : 'xavier@orange.cm', 'role': 'viewer', 'status': 'invited'},
      ],
    };

void main() {
  test('droits par rôle : modifier/gérer, payer', () {
    expect(roleCanManage('owner'), isTrue);
    expect(roleCanManage('admin'), isTrue);
    expect(roleCanManage('finance'), isFalse);
    expect(roleCanManage('viewer'), isFalse);
    expect(roleCanPay('finance'), isTrue);
    expect(roleCanPay('viewer'), isFalse);
    expect(companyRoleLabels.keys, ['owner', 'admin', 'finance', 'viewer']);
    expect(companyRoleHelp.keys, ['admin', 'finance', 'viewer']);
  });

  testWidgets('équipe (propriétaire) : membres, rôles, e-mails, invitation', (t) async {
    await _pump(t, const CompanyMembersScreen(), overrides: [companyMembersProvider.overrideWith((ref) async => _team('owner'))]);
    expect(find.text('Équipe de l’entreprise'), findsOneWidget);
    expect(find.text('Orange C.'), findsOneWidget);
    expect(find.text('Alice A.'), findsOneWidget);
    expect(find.text('alice@orange.cm'), findsOneWidget);
    expect(find.text('Invitation envoyée'), findsOneWidget);
    expect(find.text('Inviter un collègue'), findsOneWidget);
    expect(find.text('Envoyer l’invitation'), findsOneWidget);
  });

  testWidgets('équipe (lecteur) : consultation seule, aucun e-mail, aucune invitation', (t) async {
    await _pump(t, const CompanyMembersScreen(), overrides: [companyMembersProvider.overrideWith((ref) async => _team('viewer'))]);
    expect(find.text('Alice A.'), findsOneWidget);
    expect(find.text('alice@orange.cm'), findsNothing);
    expect(find.text('Inviter un collègue'), findsNothing);
    expect(find.text('Retirer'), findsNothing);
  });

  testWidgets('mes entreprises : invitation à accepter et entreprise rejointe', (t) async {
    await _pump(t, const MyCompaniesScreen(), overrides: [
      myCompaniesProvider.overrideWith((ref) async => [
            {'owner_id': 'o1', 'company_name': 'Orange Cameroun', 'role': 'admin', 'status': 'invited', 'verified': true},
            {'owner_id': 'o2', 'company_name': 'MTN Cameroun', 'role': 'viewer', 'status': 'active', 'verified': false},
          ]),
    ]);
    expect(find.text('Orange Cameroun'), findsOneWidget);
    expect(find.text('Rejoindre'), findsOneWidget);
    expect(find.text('Décliner'), findsOneWidget);
    expect(find.text('Ouvrir l’espace entreprise'), findsOneWidget);
    expect(find.text('Rôle : Administrateur'), findsOneWidget);
    expect(find.text('Rôle : Lecteur'), findsOneWidget);
  });

  testWidgets('mes entreprises : message clair quand il n’y en a aucune', (t) async {
    await _pump(t, const MyCompaniesScreen(), overrides: [myCompaniesProvider.overrideWith((ref) async => <Map<String, dynamic>>[])]);
    expect(find.textContaining('Vous n’êtes membre d’aucune entreprise'), findsOneWidget);
  });

  testWidgets('accueil partagé : rôle affiché, équipe visible, pas de publication', (t) async {
    await _pump(t, const CompanyHomeScreen(shared: true), overrides: [
      companyDashboardProvider.overrideWith((ref) async => {
            'company_name': 'Orange Cameroun', 'my_role': 'viewer', 'status': 'approved', 'plan_name': 'Entreprise', 'members': 4,
            'needs_open': 2, 'proposals_new': 1, 'offers_active': 0, 'applications_new': 0, 'contests_active': 0, 'recruits': 0,
          }),
    ]);
    expect(find.text('Vous êtes Lecteur de cette entreprise.'), findsOneWidget);
    expect(find.text('Équipe de l’entreprise · 4 personnes'), findsOneWidget);
    expect(find.text('Publier un besoin'), findsNothing);
    expect(find.text('Rechercher des talents'), findsNothing);
  });

  testWidgets('accueil du propriétaire : publication et équipe', (t) async {
    await _pump(t, const CompanyHomeScreen(), overrides: [
      companyDashboardProvider.overrideWith((ref) async => {
            'company_name': 'Orange Cameroun', 'my_role': 'owner', 'status': 'approved', 'plan_name': 'Entreprise', 'members': 1,
            'needs_open': 0, 'proposals_new': 0, 'offers_active': 0, 'applications_new': 0, 'contests_active': 0, 'recruits': 0,
          }),
    ]);
    expect(find.text('Équipe de l’entreprise · 1 personne'), findsOneWidget);
    expect(find.text('Publier un besoin'), findsOneWidget);
  });
}
