import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/dept_space.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

/// Lot H2 (espace du département) : pages réelles à 390 px de large (aucun débordement : une erreur de mise en page fait échouer le test), états
/// vide / erreur / non rattaché / lecture seule, et export CSV. Les lectures serveur sont simulées par surcharge de `deptCallProvider`.

typedef _Handler = Object? Function(DeptCall c);

Override _calls(Map<String, _Handler> m) => deptCallProvider.overrideWith((ref, c) async {
      final f = m[c.fn];
      if (f == null) throw 'Fonction inattendue : ${c.fn}';
      return f(c);
    });

Map<String, dynamic> _me({bool attached = true, String role = 'dept'}) => {
      'role': role,
      'attached': attached,
      'department_id': 'd1',
      'department': 'Génie logiciel',
      'institution': 'IUT test',
      'title': 'Chef de département',
      'name': 'Dr Mbarga',
    };

final _overview = {
  'department_id': 'd1',
  'department': 'Génie logiciel',
  'institution': 'IUT test',
  'students': 42,
  'students_verified': 30,
  'students_certified': 8,
  'sellers': 5,
  'listings': 12,
  'projects': {'total': 9, 'approved': 4, 'submitted': 3, 'draft': 1, 'rejected': 1},
  'innovations': {'total': 3, 'approved': 1, 'submitted': 1, 'draft': 1, 'rejected': 0},
  'skills': {'total': 77, 'students': 31, 'advanced': 20},
  'opportunities': {'published': 6, 'applications': 14, 'hired': 2},
  'partnerships': {'total': 4, 'actif': 2, 'negociation': 1, 'prospect': 1, 'termine': 0},
  'sales': {'revenue': 1250000, 'orders': 18},
  'validations': {'total': 3, 'certifications': 1, 'projects': 2},
};

void main() {
  setUpAll(loadAppFonts);
  setUp(() => GScreen.mockupFrame = false);
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = false;
  });

  Future<void> monter(WidgetTester t, Widget screen, List<Override> overrides, {String staff = 'Resp. département'}) async {
    Backend.ready = true;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(
      overrides: [initialAccountProvider.overrideWithValue(demoAccount.copyWith(staff: staff)), ...overrides],
      child: MaterialApp(home: screen),
    ));
    await t.pumpAndSettle();
  }

  final base = <String, _Handler>{
    'my_department': (_) => _me(),
    'dept_overview': (_) => _overview,
    'dept_activity': (_) => [
          {'kind': 'project', 'title': 'Projet : Appli de gestion de stock', 'who': 'Awa Mballa', 'at': '2026-11-10T10:00:00Z'},
        ],
    'admin_departments': (_) => [
          {'id': 'd1', 'name': 'Génie logiciel', 'institution': 'IUT test'},
          {'id': 'd2', 'name': 'Gestion', 'institution': 'IUT test'},
        ],
  };

  test('export CSV : en-têtes, guillemets doublés et cellules de formule neutralisées', () {
    final csv = deptReportCsv({
      'columns': [
        {'key': 'nom', 'label': 'Nom'},
        {'key': 'note', 'label': 'Note'},
      ],
      'rows': [
        {'nom': 'Awa "la grande"', 'note': '=SOMME(A1:A9)'},
        {'nom': '+237 699', 'note': null},
      ],
    });
    final lines = csv.replaceFirst('\uFEFF', '').trim().split('\n');
    expect(lines[0], '"Nom";"Note"');
    expect(lines[1], '"Awa ""la grande""";"\'=SOMME(A1:A9)"');
    expect(lines[2], '"\'+237 699";""');
  });

  testWidgets('tableau de bord : département, chiffres réels, validations en attente et accès aux sections (390 px)', (t) async {
    await monter(t, const DepartmentHubScreen(), [_calls(base)]);
    expect(find.text('Mon département'), findsOneWidget);
    expect(find.text('Génie logiciel'), findsWidgets);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('À valider'), findsOneWidget);
    expect(find.text('Identité du département'), findsOneWidget);
    expect(find.text('Rattachement des comptes'), findsNothing);
    expect(find.text('Lecture seule'), findsNothing);
  });

  testWidgets('compte non rattaché : message clair, aucune donnée', (t) async {
    await monter(t, const DepartmentHubScreen(), [
      _calls({...base, 'my_department': (_) => _me(attached: false)}),
    ]);
    expect(find.text('Compte non rattaché'), findsOneWidget);
    expect(find.text('42'), findsNothing);
  });

  testWidgets('lecture serveur en échec : message et « Réessayer »', (t) async {
    await monter(t, const DepartmentHubScreen(), [
      _calls({...base, 'dept_overview': (_) => throw 'Votre compte n’est rattaché à aucun département'}),
    ]);
    expect(find.text('Lecture impossible'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('direction : lecture seule, choix du département, pas de bouton d’enregistrement', (t) async {
    await monter(t, const DepartmentIdentityScreen(), [
      _calls({
        ...base,
        'my_department': (_) => _me(role: 'direction'),
        'dept_identity_get': (_) => {'department_id': 'd1', 'name': 'Génie logiciel', 'institution': 'IUT test', 'description': 'Formation', 'programs': ['Licence'], 'accounts': []},
      }),
    ], staff: 'Direction');
    expect(find.text('Département'), findsOneWidget);
    expect(find.text('Choisir un département'), findsOneWidget);
  });

  testWidgets('identité : formulaire du département rattaché avec bouton Enregistrer', (t) async {
    await monter(t, const DepartmentIdentityScreen(), [
      _calls({
        ...base,
        'dept_identity_get': (_) => {
              'department_id': 'd1',
              'name': 'Génie logiciel',
              'institution': 'IUT test',
              'description': 'Formation en génie logiciel',
              'mission': '',
              'programs': ['Licence pro', 'Master'],
              'head_name': 'Dr Mbarga',
              'contact_email': 'gl@iut.cm',
              'contact_phone': '',
              'address': '',
              'website': '',
              'contact_public': false,
              'accounts': [
                {'name': 'Dr Mbarga', 'title': 'Chef de département'}
              ],
            },
      }),
    ]);
    expect(find.text('Identité du département'), findsOneWidget);
    expect(find.text('Formation en génie logiciel'), findsOneWidget);
    expect(find.text('Licence pro, Master'), findsOneWidget);
    expect(find.text('Enregistrer'), findsOneWidget);
  });

  testWidgets('étudiants : état vide', (t) async {
    await monter(t, const DepartmentStudentsScreen(), [
      _calls({...base, 'dept_students_list': (_) => {'total': 0, 'rows': []}}),
    ]);
    expect(find.text('Aucun étudiant'), findsOneWidget);
  });

  testWidgets('étudiants : liste du département (nom long, suspendu, non vérifié)', (t) async {
    await monter(t, const DepartmentStudentsScreen(), [
      _calls({
        ...base,
        'dept_students_list': (_) => {
              'total': 2,
              'rows': [
                {'id': 'u1', 'name': 'Awa Mballa', 'level': 'Licence 2', 'verified_student': true, 'certified': true, 'suspended': false, 'projects': 2, 'skills': 4},
                {'id': 'u2', 'name': 'Brice Nkoa Ngoumou Essomba Longnom', 'level': '', 'verified_student': false, 'certified': false, 'suspended': true, 'projects': 0, 'skills': 0},
              ],
            },
      }),
    ]);
    expect(find.text('Awa Mballa'), findsOneWidget);
    expect(find.text('Vérifié'), findsOneWidget);
    expect(find.text('Suspendu'), findsOneWidget);
  });

  testWidgets('projets et innovations : liste, statut et mise en avant d’un projet validé et public', (t) async {
    await monter(t, const DepartmentProjectsScreen(), [
      _calls({
        ...base,
        'dept_projects': (_) => [
              {'id': 'p1', 'title': 'Appli de gestion de stock pour les petites boutiques de quartier', 'kind': 'projet', 'status': 'approved', 'summary': 'Une application mobile.', 'owner': 'Awa Mballa', 'visibility': 'public', 'members': 2, 'featured': false},
              {'id': 'p2', 'title': 'Capteur solaire', 'kind': 'innovation', 'status': 'submitted', 'summary': '', 'owner': 'Brice', 'visibility': 'public', 'members': 0, 'featured': false},
            ],
      }),
    ]);
    expect(find.text('Mettre en avant'), findsOneWidget);
    expect(find.text('À valider'), findsWidgets);
    expect(find.text('Innovation · Brice'), findsOneWidget);
  });

  testWidgets('compétences : état vide', (t) async {
    await monter(t, const DepartmentSkillsScreen(), [
      _calls({...base, 'dept_skills': (_) => {'total': 0, 'students_with_skills': 0, 'skills': [], 'domains': []}}),
    ]);
    expect(find.text('Aucune compétence déclarée'), findsOneWidget);
  });

  testWidgets('compétences : agrégats du département', (t) async {
    await monter(t, const DepartmentSkillsScreen(), [
      _calls({
        ...base,
        'dept_skills': (_) => {
              'total': 5,
              'students_with_skills': 3,
              'skills': [
                {'skill': 'flutter', 'domain': 'Développement', 'students': 3, 'advanced': 1}
              ],
              'domains': [
                {'domain': 'Développement', 'count': 5}
              ],
            },
      }),
    ]);
    expect(find.text('flutter'), findsOneWidget);
  });

  testWidgets('opportunités : offre ciblée en attente avec Valider / Refuser, candidats du département seulement', (t) async {
    await monter(t, const DepartmentOpportunitiesScreen(), [
      _calls({
        ...base,
        'dept_opportunities': (_) => [
              {'id': 'o1', 'title': 'Stage développeur mobile', 'org': 'Entreprise Z', 'kind': 'stage', 'status': 'pending', 'targeted': true, 'applications': 0, 'hired': 0},
              {'id': 'o2', 'title': 'Emploi publié', 'org': 'Entreprise Z', 'kind': 'emploi', 'status': 'published', 'targeted': false, 'applications': 3, 'hired': 1},
            ],
      }),
    ]);
    expect(find.text('Valider'), findsOneWidget);
    expect(find.text('Refuser'), findsOneWidget);
    expect(find.text('3 candidature(s) du département'), findsOneWidget);
  });

  testWidgets('partenariats : liste, sponsorings en lecture seule et bouton de création', (t) async {
    await monter(t, const DepartmentPartnershipsScreen(), [
      _calls({
        ...base,
        'dept_partnerships': (_) => {
              'partnerships': [
                {'id': 'a1', 'partner_name': 'Orange Cameroun', 'kind': 'stage', 'status': 'actif', 'description': 'Stages de fin d’études', 'amount': 500000, 'students': 12}
              ],
              'sponsorships': [
                {'sponsor': 'MTN', 'title': 'Bourses', 'amount': 200000, 'students': 5, 'status': 'en_cours', 'year': 2026}
              ],
            },
      }),
    ]);
    expect(find.text('Nouveau partenariat'), findsOneWidget);
    expect(find.text('Orange Cameroun'), findsOneWidget);
    expect(find.text('Sponsorings enregistrés'), findsOneWidget);
  });

  testWidgets('validations : compteurs du département et mentors à valider', (t) async {
    await monter(t, const DepartmentValidationsScreen(), [
      _calls({
        ...base,
        'dept_validations': (_) => {'certifications': 2, 'documents': 0, 'listings': 1, 'projects': 0, 'campaigns': 0, 'milestones': 0, 'support_requests': 0, 'wishes': 0, 'mentors': 1, 'opportunities': 0, 'announcements': 0, 'total': 4},
        'mentors_pending': (_) => [
              {'user_id': 'm1', 'name': 'Marc Mentor', 'works_at': 'Orange'}
            ],
      }),
    ]);
    expect(find.text('Certifications'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Marc Mentor'), findsOneWidget);
    expect(find.text('Rien à valider'), findsWidgets);
  });

  testWidgets('rapports : choix du rapport et bouton de génération', (t) async {
    await monter(t, const DepartmentReportsScreen(), [_calls(base)]);
    expect(find.text('Synthèse'), findsOneWidget);
    expect(find.text('Générer le rapport'), findsOneWidget);
    expect(find.text('Exporter en CSV'), findsNothing);
  });

  testWidgets('registre des certificats : émission, révocation et mise en avant pour le département', (t) async {
    await monter(t, const DepartmentCertificatesScreen(), [
      _calls({
        ...base,
        'dept_certificates': (_) => [
              {'id': 'c1', 'code': 'BE-CERT-0001ABCD', 'kind': 'talent', 'subject': 'Talent Flutter', 'holder': 'Awa Mballa', 'department': 'Génie logiciel', 'revoked': false, 'featured': false},
              {'id': 'c2', 'code': 'BE-CERT-0002ABCD', 'kind': 'talent', 'subject': 'Talent SQL', 'holder': 'Brice', 'department': 'Génie logiciel', 'revoked': true, 'revoked_reason': 'Erreur de saisie', 'featured': false},
            ],
      }),
    ]);
    expect(find.text('Émettre'), findsOneWidget);
    expect(find.text('Valide'), findsOneWidget);
    expect(find.text('Révoqué'), findsOneWidget);
    expect(find.text('Mettre en avant'), findsOneWidget);
  });

  testWidgets('rattachement (administrateur) : comptes rattachés et non rattachés', (t) async {
    await monter(t, const DepartmentAttachScreen(), [
      _calls({
        ...base,
        'admin_dept_accounts': (_) => [
              {'id': 'c1', 'name': 'Dr Mbarga', 'attached': true, 'department': 'Génie logiciel', 'institution': 'IUT test', 'suspended': false},
              {'id': 'c2', 'name': 'Mme Ndongo', 'attached': false, 'suspended': false},
            ],
      }),
    ], staff: 'Admin global');
    expect(find.text('Rattaché'), findsOneWidget);
    expect(find.text('Non rattaché'), findsOneWidget);
    expect(find.text('Rattacher'), findsOneWidget);
    expect(find.text('Retirer'), findsOneWidget);
  });
}

