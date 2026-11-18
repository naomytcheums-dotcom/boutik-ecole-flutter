import 'package:boutik_ecole/figma/g/g_13.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/access.dart';
import 'package:boutik_ecole/figma/live/admin.dart' show staffRoleKeys, staffRoles;
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/company_screens.dart';
import 'package:boutik_ecole/figma/live/legal.dart' show termsSections;
import 'package:boutik_ecole/figma/live/marche/marche_widgets.dart' show MDropdown;
import 'package:boutik_ecole/figma/live/org_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

/// Lot H1 (Organisation) : types d'organisation, inscription (écran 13), fiche adaptée au type, pièces par type, fusion du rôle « autre ».

class _Role2 extends SignupRole {
  @override
  int build() => 2;
}

class _Role0 extends SignupRole {
  @override
  int build() => 0;
}

Map<String, dynamic> _fiche(String type, {List<Map<String, dynamic>> docs = const [], String status = 'draft'}) => {
      'owner_id': 'o1', 'company_name': 'Association Espoir', 'status': status, 'my_role': 'owner', 'org_type': type,
      'sector': '', 'city': '', 'phone': '', 'contact_name': '', 'registration_number': '', 'tax_number': '', 'mission': '', 'documents': docs,
    };

void main() {
  setUpAll(loadAppFonts);
  setUp(() => GScreen.mockupFrame = false);
  tearDown(() => GScreen.mockupFrame = true);

  Future<void> monter(WidgetTester t, Widget page, {double h = 1800, List<Override> overrides = const []}) async {
    GAnim.enabled = false;
    t.view.physicalSize = Size(390, h);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: page)));
    await t.pumpAndSettle();
  }

  group('référentiel des types d’organisation', () {
    test('huit types, dont un seul commercial ; chacun exige au moins une pièce', () {
      expect(orgTypes.map((t) => t.code), ['entreprise_commerciale', 'association', 'ong', 'cooperative', 'fondation', 'institution', 'structure_partenaire', 'autre_reconnue']);
      expect(orgTypes.where((t) => t.commercial).map((t) => t.code), ['entreprise_commerciale']);
      for (final t in orgTypes) {
        expect(t.requirementGroups, isNotEmpty, reason: t.code);
        expect(t.docs.last.kind, 'other', reason: '${t.code} garde « autre pièce »');
      }
    });

    test('justificatifs par type : association (récépissé + statuts), ONG (agrément + statuts), commerciale (RCCM ou NIU)', () {
      final a = orgTypeOf('association');
      expect(a.requirementGroups.keys, [1, 2]);
      expect(a.unmetGroups(const []), [1, 2]);
      expect(a.unmetGroups(['receipt']), [2]);
      expect(a.unmetGroups(['receipt', 'statutes']), isEmpty);
      expect(a.allows('tax'), isFalse, reason: 'le NIU n’est pas une pièce d’association');
      expect(a.allows('other'), isTrue);
      final o = orgTypeOf('ong');
      expect(o.unmetGroups(['receipt']), [1, 2], reason: 'le récépissé ne remplace pas l’agrément');
      expect(o.unmetGroups(['authorization', 'statutes']), isEmpty);
      final c = orgTypeOf('entreprise_commerciale');
      expect(c.requirementGroups.keys, [1]);
      expect(c.unmetGroups(['tax']), isEmpty, reason: 'RCCM ou NIU suffit (comportement historique)');
      expect(c.unmetGroups(['statutes']), [1]);
      expect(c.allows('statutes'), isFalse);
      expect(c.groupLabel(1), 'RCCM ou NIU');
    });

    test('la configuration renvoyée par le serveur (company_get / org_types_list) est lue telle quelle', () {
      final t = OrgType.fromJson({
        'code': 'association', 'label': 'Association', 'description': 'd', 'commercial': false, 'sector_label': 'Domaine d’action',
        'registration_label': 'Numéro du récépissé', 'registration_required': true, 'tax_required': false, 'mission_required': true,
        'docs': [
          {'kind': 'receipt', 'label': 'Récépissé', 'hint': '', 'group': 1, 'required': true},
          {'kind': 'other', 'label': 'Autre pièce', 'hint': '', 'group': null, 'required': false},
        ],
      })!;
      expect(t.registrationLabel, 'Numéro du récépissé');
      expect(t.missionRequired, isTrue);
      expect(t.unmetGroups(const []), [1]);
      expect(OrgType.fromJson('x'), isNull);
    });

    test('champs et pièces manquants avant l’envoi, par type', () {
      final a = companyMissingForSubmit(sector: 'Éducation', city: 'Douala', contact: 'Mme N', phone: '699000000', documents: 0, type: orgTypeOf('association'), docKinds: const []);
      expect(a, [
        'le champ « Numéro du récépissé de déclaration »',
        'la mission de l’organisation',
        'la pièce justificative « Récépissé de déclaration »',
        'la pièce justificative « Statuts »',
      ]);
      expect(
        companyMissingForSubmit(sector: 'x', city: 'x', contact: 'x', phone: 'x', documents: 2, type: orgTypeOf('association'), registration: 'N°1', mission: 'm', docKinds: ['receipt', 'statutes']),
        isEmpty,
      );
      expect(companyMissingForSubmit(sector: '', city: 'x', contact: 'x', phone: 'x', documents: 1, type: orgTypeOf('institution'), docKinds: ['decree', 'mandate']), ['le domaine de compétence']);
    });

    test('company_save reçoit le type, le NIU et la mission', () {
      final p = companySavePayload(
        name: 'Espoir', sector: 'Éducation', size: '', city: 'Douala', website: '', phone: '699000000', contact: 'N', role: '', description: '', year: '', registration: 'R1', orgType: 'association', tax: ' ', mission: ' Insertion ',
      );
      expect(p['org_type'], 'association');
      expect(p['mission'], 'Insertion');
      expect(p['tax_number'], '');
      expect(companySavePayload(name: 'O', sector: '', size: '', city: '', website: '', phone: '', contact: '', role: '', description: '', year: '', registration: '')['org_type'], 'entreprise_commerciale');
    });
  });

  group('fusion du rôle « autre » dans Organisation (libellés et accès)', () {
    test('un compte sans rôle interne et sans type connu est un client ; l’organisation est le rôle company', () {
      const legacy = Account(name: 'X', phone: '', email: 'x@t.cm', password: '', role: 3);
      const org = Account(name: 'ONG', phone: '', email: 'o@t.cm', password: '', role: 2);
      expect(roleKey(legacy), 'client');
      expect(roleKey(org), 'company');
      expect(isCompanyAccount(org), isTrue);
      expect(isCompanyAccount(legacy), isFalse);
      expect(org.roleLabel, 'Organisation');
      expect(roleNames['company'], 'Organisation');
      expect(roleNames['other'], 'Organisation', reason: 'un profil hérité « other » s’affiche comme Organisation');
      expect(isOrgRole('other'), isTrue);
      expect(isOrgRole('company'), isTrue);
      expect(isOrgRole('client'), isFalse);
    });

    test('plus de choix « Autre rôle » : inscription à trois profils, attribution de rôles par l’administrateur sans « other »', () {
      expect(selfServiceRoles, 3);
      expect(staffRoles.where((r) => r.contains('Autre')), isEmpty);
      expect(staffRoleKeys, isNot(contains('other')));
      expect(staffRoles.length, staffRoleKeys.length);
      expect(staffRoles[staffRoleKeys.indexOf('company')], 'Organisation');
    });

    test('les écrans de l’organisation restent réservés aux organisations et à l’administrateur', () {
      const org = Account(name: 'ONG', phone: '', email: 'o@t.cm', password: '', role: 2);
      const client = Account(name: 'C', phone: '', email: 'c@t.cm', password: '', role: 0);
      for (final id in ['88', '90', '93', '99', '187', '189', '190', '262', '285']) {
        expect(canOpen(org, id), isTrue, reason: id);
        expect(canOpen(client, id), isFalse, reason: id);
        expect(canOpen(null, id), isFalse, reason: 'visiteur $id');
      }
    });

    test('CGU : la clause Organisations décrit les types et les pièces par type', () {
      final cgu = termsSections[0].map((s) => '${s.$1} ${s.$2}').join('\n');
      expect(cgu, contains('7. Organisations'));
      expect(cgu, contains('association, ONG, coopérative, fondation, institution, structure partenaire'));
      expect(cgu, isNot(contains('Autre rôle')));
    });
  });

  group('inscription : écran 13 sans « Autre rôle », avec le choix du type d’organisation', () {
    testWidgets('trois profils seulement ; « Organisation » ouvre la liste des huit types et mémorise le choix', (t) async {
      await monter(t, const G_13(), h: 900, overrides: [signupRoleProvider.overrideWith(_Role2.new)]);
      expect(find.text('Autre rôle autorisé'), findsNothing);
      expect(find.text('Organisation'), findsOneWidget);
      expect(find.text('Entreprise'), findsNothing);
      expect(find.text('Type d’organisation'), findsOneWidget);
      expect(find.text('Choisir le type…'), findsOneWidget);
      await t.tapAt(t.getCenter(find.text('Choisir le type…')));
      await t.pumpAndSettle();
      for (final type in orgTypes) {
        await t.scrollUntilVisible(find.text(type.label), 120, scrollable: find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first);
        expect(find.text(type.label), findsOneWidget, reason: type.code);
      }
      await t.scrollUntilVisible(find.text('Association'), -120, scrollable: find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first);
      await t.tap(find.text('Association'));
      await t.pumpAndSettle();
      expect(find.text('Association'), findsOneWidget);
      final c = ProviderScope.containerOf(t.element(find.byType(G_13)));
      expect(c.read(signupOrgTypeProvider), 'association');
      expect(t.takeException(), isNull, reason: 'aucun débordement à 390 px');
    });

    testWidgets('profil Client : pas de sélecteur de type', (t) async {
      await monter(t, const G_13(), h: 900, overrides: [signupRoleProvider.overrideWith(_Role0.new)]);
      expect(find.text('Type d’organisation'), findsNothing);
      expect(find.text('Autre rôle autorisé'), findsNothing);
      expect(t.takeException(), isNull);
    });
  });

  group('fiche d’organisation adaptée au type (390 px)', () {
    testWidgets('association : domaine d’action, récépissé, mission, pas de NIU ; pièces requises et message du serveur', (t) async {
      await monter(t, const CompanyProfileScreen(showNav: false), h: 3600, overrides: [companyProvider.overrideWith((ref) async => _fiche('association'))]);
      expect(find.byWidgetPredicate((w) => w is MDropdown && w.label == 'Type d’organisation' && w.value == 'association'), findsOneWidget);
      expect(find.text('Association'), findsWidgets);
      expect(find.widgetWithText(TextField, 'Nom de l’organisation'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Domaine d’action'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Numéro du récépissé de déclaration'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Mission et activités'), findsOneWidget);
      expect(find.textContaining('NIU'), findsNothing);
      expect(find.textContaining('Pour association, il faut : Récépissé de déclaration ET Statuts'), findsOneWidget);
      expect(find.text('Statuts'), findsOneWidget);
      await t.tap(find.text('Enregistrer et envoyer pour vérification'));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('le champ « Numéro du récépissé de déclaration »'), findsOneWidget);
      expect(find.textContaining('la mission de l’organisation'), findsOneWidget);
      expect(find.textContaining('la pièce justificative « Statuts »'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('entreprise commerciale : secteur en liste, NIU, RCCM ; aucune mission obligatoire', (t) async {
      await monter(t, const CompanyProfileScreen(showNav: false), overrides: [companyProvider.overrideWith((ref) async => _fiche('entreprise_commerciale'))]);
      expect(find.widgetWithText(TextField, 'Nom de l’entreprise'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'NIU (numéro d’identifiant unique, facultatif)'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'RCCM / numéro d’immatriculation (facultatif)'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Mission et activités'), findsNothing);
      expect(find.textContaining('Pour entreprise commerciale, il faut : RCCM ou NIU'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('pièces déposées : les exigences satisfaites sont cochées et les pièces listées avec leur nature', (t) async {
      await monter(t, const CompanyProfileScreen(showNav: false), overrides: [
        companyProvider.overrideWith((ref) async => _fiche('ong', docs: [
              {'id': 'd1', 'kind': 'authorization', 'name': 'agrement.pdf', 'path': 'u/company/1.pdf'},
            ])),
      ]);
      expect(find.text('agrement.pdf'), findsOneWidget);
      expect(find.text('Agrément ou autorisation'), findsOneWidget, reason: 'nature de la pièce');
      expect(find.byIcon(Icons.check_circle), findsOneWidget, reason: 'agrément déposé, statuts encore manquants');
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('lecteur d’équipe : lecture seule, aucune pièce affichée (confidentialité inchangée)', (t) async {
      await monter(t, const CompanyProfileScreen(showNav: false), overrides: [
        companyProvider.overrideWith((ref) async => {..._fiche('association', status: 'approved'), 'my_role': 'viewer'}),
      ]);
      expect(find.textContaining('Lecture seule'), findsOneWidget);
      expect(find.text('Pièces justificatives'), findsNothing);
      expect(t.takeException(), isNull);
    });
  });
}
