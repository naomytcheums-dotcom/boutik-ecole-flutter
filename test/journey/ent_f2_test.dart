import 'package:boutik_ecole/figma/live/access.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/company_home.dart';
import 'package:boutik_ecole/figma/live/company_screens.dart';
import 'package:boutik_ecole/figma/live/company_team.dart';
import 'package:boutik_ecole/figma/live/concours_screens.dart' show defaultOrganizerKind;
import 'package:boutik_ecole/figma/live/legal.dart' show termsSections;
import 'package:boutik_ecole/figma/live/notifs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester t, Widget w, {List<Override> overrides = const []}) async {
  t.view.physicalSize = const Size(420, 3600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: w)));
  await t.pumpAndSettle();
}

const _other = Account(name: 'ONG Verte', phone: '690000000', email: 'ong@t.cm', password: 'Boutik2026', role: 3);
const _company = Account(name: 'Orange', phone: '690000000', email: 'o@t.cm', password: 'Boutik2026', role: 2);
const _client = Account(name: 'Cli Ent', phone: '690000000', email: 'c@t.cm', password: 'Boutik2026', role: 0);

void main() {
  group('fiche entreprise : interlocuteur, validation et envoi (E4-1)', () {
    test('les champs obligatoires manquants avant l’envoi sont listés comme le fait le serveur', () {
      final m = companyMissingForSubmit(sector: '', city: ' ', contact: '', phone: '', documents: 0);
      expect(m, ['le secteur d’activité', 'la ville', 'l’interlocuteur', 'le téléphone', 'au moins une pièce justificative']);
      expect(companyMissingMessage(m), contains('l’interlocuteur'));
      expect(companyMissingForSubmit(sector: 'Télécoms', city: 'Douala', contact: 'Mme Ndongo', phone: '699000000', documents: 1), isEmpty);
    });

    test('interlocuteur et fonction : 80 caractères au plus, année et site contrôlés', () {
      String? err({String name = 'Orange', String contact = 'Mme N', String role = 'DRH', String site = '', String year = ''}) => companyFieldError(name: name, contact: contact, role: role, website: site, year: year);
      expect(err(), isNull);
      expect(err(contact: 'x' * 81), contains('80 caractères'));
      expect(err(role: 'x' * 81), contains('80 caractères'));
      expect(err(name: ' '), contains('nom de l’entreprise'));
      expect(err(site: 'orange.cm'), contains('https://'));
      expect(err(year: '1850'), contains('1900'));
      expect(err(year: '2005'), isNull);
    });

    test('le contenu envoyé à company_save porte l’interlocuteur et la fonction ; le logo seulement s’il vient d’être choisi', () {
      final p = companySavePayload(
        name: ' Orange Cameroun ', sector: 'Télécoms', size: '1000+', city: 'Douala', website: '', phone: '699000000', contact: ' Mme Ndongo ', role: 'DRH', description: '', year: '1999', registration: 'RC/1',
      );
      expect(p['contact_name'], 'Mme Ndongo');
      expect(p['contact_role'], 'DRH');
      expect(p['company_name'], 'Orange Cameroun');
      expect(p['founded_year'], 1999);
      expect(p.containsKey('logo_path'), isFalse);
      expect(companySavePayload(name: 'O', sector: '', size: '', city: '', website: '', phone: '', contact: '', role: '', description: '', year: '', registration: '', newLogoPath: 'u/logo.png')['logo_path'], 'u/logo.png');
    });

    testWidgets('l’écran affiche Interlocuteur et Fonction, ne préremplit pas le téléphone et explique les champs manquants avant l’envoi', (t) async {
      await _pump(t, const CompanyProfileScreen(showNav: false), overrides: [companyProvider.overrideWith((ref) async => null)]);
      expect(find.text('Interlocuteur'), findsOneWidget);
      expect(find.text('Fonction'), findsOneWidget);
      expect(find.text('Téléphone de l’entreprise'), findsOneWidget);
      expect(find.textContaining('administrateurs de votre entreprise, de l’administration de la plateforme et de l’équipe d’assistance'), findsOneWidget);
      await t.tap(find.text('Enregistrer et envoyer pour vérification'));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('Pour envoyer la demande, renseignez : le secteur d’activité, la ville, l’interlocuteur, le téléphone, au moins une pièce justificative'), findsOneWidget);
      await t.enterText(find.widgetWithText(TextField, 'Interlocuteur'), 'Mme Ndongo');
      await t.enterText(find.widgetWithText(TextField, 'Téléphone de l’entreprise'), '699000000');
      await t.tap(find.text('Enregistrer et envoyer pour vérification'));
      await t.pump(const Duration(milliseconds: 400));
      // l'interlocuteur et le téléphone sont saisis : ils ne sont plus réclamés
      expect(find.textContaining('l’interlocuteur, le téléphone'), findsNothing);
      expect(find.textContaining('Pour envoyer la demande, renseignez : le secteur d’activité, la ville, au moins une pièce justificative'), findsOneWidget);
    });

    testWidgets('fiche approuvée : les pièces envoyées ne se suppriment plus', (t) async {
      await _pump(t, const CompanyProfileScreen(showNav: false), overrides: [
        companyProvider.overrideWith((ref) async => {
              'company_name': 'Orange', 'status': 'approved', 'my_role': 'owner',
              'documents': [{'id': 'd1', 'kind': 'registration', 'name': 'RCCM.pdf', 'path': 'u/company/1.pdf'}],
            }),
      ]);
      expect(find.text('RCCM.pdf'), findsOneWidget);
      expect(find.byTooltip('Supprimer'), findsNothing);
      expect(find.textContaining('ne peuvent plus être supprimées'), findsOneWidget);
    });

    testWidgets('lecteur : coordonnées sensibles non affichées, lecture seule expliquée', (t) async {
      await _pump(t, const CompanyProfileScreen(showNav: false), overrides: [
        companyProvider.overrideWith((ref) async => {'company_name': 'Orange', 'status': 'approved', 'my_role': 'viewer', 'documents': []}),
      ]);
      expect(find.textContaining('Lecture seule'), findsOneWidget);
      expect(find.textContaining('réservés au propriétaire et aux administrateurs'), findsOneWidget);
      expect(find.text('Pièces justificatives'), findsNothing);
    });
  });

  group('équipe : actions permises (E4-14, E5-9)', () {
    test('un administrateur ne touche ni aux administrateurs ni à lui-même ; le propriétaire gère tout', () {
      expect(canChangeMemberRole('owner', 'admin', isMe: false), isTrue);
      expect(canChangeMemberRole('admin', 'admin', isMe: false), isFalse);
      expect(canChangeMemberRole('admin', 'viewer', isMe: false), isTrue);
      expect(canChangeMemberRole('admin', 'viewer', isMe: true), isFalse);
      expect(canChangeMemberRole('finance', 'viewer', isMe: false), isFalse);
      expect(canRemoveMember('admin', 'admin', isMe: false), isFalse);
      expect(canRemoveMember('admin', 'finance', isMe: false), isTrue);
      expect(canRemoveMember('viewer', 'viewer', isMe: true), isTrue);
      expect(canRemoveMember('viewer', 'finance', isMe: false), isFalse);
      expect(assignableCompanyRoles('owner').keys, ['admin', 'finance', 'viewer']);
      expect(assignableCompanyRoles('admin').keys, ['finance', 'viewer']);
    });

    testWidgets('administrateur d’équipe : pas de « Retirer » ni de rôle modifiable sur un autre administrateur', (t) async {
      await _pump(t, const CompanyMembersScreen(), overrides: [
        companyMembersProvider.overrideWith((ref) async => {
              'my_role': 'admin',
              'owner': {'user_id': 'o', 'name': 'Orange C.'},
              'members': [
                {'user_id': 'a2', 'name': 'Adam A.', 'email': 'adam@orange.cm', 'role': 'admin', 'status': 'active', 'account_role': 'client', 'certified': false},
                {'user_id': 'v', 'name': 'Vero V.', 'email': 'vero@orange.cm', 'role': 'viewer', 'status': 'active', 'account_role': 'student', 'certified': true},
                {'user_id': 'x', 'name': 'Invitation en attente', 'email': null, 'role': 'viewer', 'status': 'invited'},
              ],
            }),
      ]);
      expect(find.text('Retirer'), findsOneWidget); // seulement Vero
      expect(find.text('Compte : Client · profil non certifié'), findsOneWidget);
      expect(find.text('Compte : Étudiant-vendeur · profil certifié'), findsOneWidget);
      expect(find.text('Invitation en attente'), findsOneWidget);
    });
  });

  group('accueil entreprise : erreur, en-tête, forfaits (E4-11, E4-19, E5-23)', () {
    testWidgets('en cas d’erreur : en-tête, menu et cloche restent, bouton Réessayer, message sans « marketplace »', (t) async {
      await _pump(t, const CompanyHomeScreen(), overrides: [companyDashboardProvider.overrideWith((ref) async => throw Exception('offline'))]);
      expect(find.text('Mon entreprise'), findsOneWidget);
      expect(find.byTooltip('Menu du compte'), findsOneWidget);
      expect(find.byTooltip('Notifications'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.textContaining('marketplace'), findsNothing);
    });

    test('messages : erreur, date et paiement manuel honnête', () {
      expect(companyLoadErrorText('offline'), isNot(contains('marketplace')));
      expect(frDate('2026-11-17T10:00:00Z'), anyOf('17/11/2026', '18/11/2026'));
      expect(frDate('n’importe quoi'), '');
      final sans = manualPlanPaymentMessage(planName: 'Entreprise', reference: 'PAY-12', amount: 25000);
      expect(sans, contains('pas encore communiqué'));
      expect(sans, contains('PAY-12'));
      final avec = manualPlanPaymentMessage(planName: 'Entreprise', reference: 'PAY-12', amount: 25000, number: '699 00 00 00', operator: 'Orange Money');
      expect(avec, contains('699 00 00 00'));
      expect(avec, contains('Orange Money'));
      expect(avec, contains('25 000 FCFA'));
      expect(avec, isNot(contains('pas encore communiqué')));
    });

    testWidgets('« Compléter » seulement en brouillon ou refusée ; date lisible ; membre sans droit informé', (t) async {
      await _pump(t, const CompanyHomeScreen(), overrides: [
        companyDashboardProvider.overrideWith((ref) async => {
              'company_name': 'Orange', 'my_role': 'viewer', 'status': 'pending', 'plan_name': 'Entreprise', 'plan_ends_at': '2026-12-31T12:00:00+00:00', 'members': 2,
              'needs_open': 0, 'proposals_new': 0, 'offers_active': 0, 'applications_new': 0, 'contests_active': 0, 'recruits': 0,
            }),
      ]);
      expect(find.text('Compléter'), findsNothing);
      expect(find.textContaining('31/12/2026'), findsOneWidget);
      expect(find.textContaining('Seuls le propriétaire, les administrateurs et la finance'), findsOneWidget);
    });
  });

  group('rôle other : mêmes écrans et menus entreprise (décision 2)', () {
    test('écrans 88-99, 187-190, 262 et 285', () {
      for (final id in ['88', '90', '93', '99', '187', '189', '190', '262', '285']) {
        expect(canOpen(_other, id), isTrue, reason: 'other doit ouvrir $id');
        expect(canOpen(_company, id), isTrue);
        expect(canOpen(_client, id), isFalse, reason: 'client ne doit pas ouvrir $id');
      }
      expect(isCompanyAccount(_other), isTrue);
      expect(isCompanyAccount(_company), isTrue);
      expect(isCompanyAccount(_client), isFalse);
      expect(isCompanyAccount(null), isFalse);
    });

    test('organisateur de concours par défaut selon le rôle (E6-13)', () {
      expect(defaultOrganizerKind('company'), 'company');
      expect(defaultOrganizerKind('other'), 'ngo');
      expect(defaultOrganizerKind('dept'), 'university');
      expect(defaultOrganizerKind('client'), 'other');
    });
  });

  group('notifications d’entreprise : destinations (E4-10, E6-6)', () {
    test('libellés d’action pour forfait, équipe, vérification, contact de talent et CV reçu', () {
      NotificationItem n(String kind) => NotificationItem(id: '1', kind: kind, title: 't', body: 'b', createdAt: DateTime(2026, 11, 17), read: false);
      for (final k in ['company_plan', 'company_team', 'company_review', 'talent_contact', 'cv_shared']) {
        expect(notificationActionLabel(n(k)), isNotNull, reason: k);
      }
    });
  });

  test('CGU : clause entreprise marquée texte de travail', () {
    final cgu = termsSections[0].map((s) => '${s.$1} ${s.$2}').join('\n');
    expect(cgu, contains('Entreprises et organisations'));
    expect(cgu, contains('texte de travail'));
  });
}
