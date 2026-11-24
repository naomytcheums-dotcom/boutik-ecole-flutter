import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/passport_360.dart';
import 'package:boutik_ecole/figma/live/talent_pool.dart';
import 'package:boutik_ecole/figma/live/talent_pool_org.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/render.dart';

/// H10 · Talent : vivier rattaché à l'organisation (muet / vide / liste, notes réellement envoyées au serveur, panne 500 sans confirmation)
/// et Passeport Talent 360° (rubriques partagées ou non, partage envoyé au serveur, panne 500). Faux serveur local, aucun talent d'exemple.
const _st1 = '22222222-2222-4222-8222-222222222222';

Map<String, dynamic> _talent(String id, String name, {String? stage, List<String> tags = const [], bool available = false}) =>
    {'id': id, 'name': name, 'department': 'Génie informatique', 'stage': stage, 'tags': tags, 'available': available, 'skills': 'Flutter'};

Map<String, dynamic> _overview({int total = 0, String role = 'owner'}) => {
      'total': total, 'by_stage': const {}, 'lists': 1, 'available': 0, 'reminders_open': 0, 'reminders_due': 0, 'alerts': 0, 'contacts_30d': 0, 'my_role': role,
    };

Account _compte() => Account(name: 'Org Test', phone: '690000001', email: 'org@example.com', password: '', bio: '', serverId: FakeSupabase.userId);

void main() {
  late FakeSupabase srv;
  setUpAll(() async {
    await loadAppFonts();
    srv = await FakeSupabase.start();
    await srv.initSupabase();
  });
  tearDownAll(() => srv.close());

  setUp(() {
    GScreen.mockupFrame = false;
    GAnim.enabled = false;
    Backend.ready = true;
    srv.rpc.clear();
    srv.tables.clear();
    srv.calls.clear();
    srv.failRpc.clear();
    srv.failWrites = false;
    srv.unknownIsError = false;
  });
  tearDown(() => GScreen.mockupFrame = true);

  Future<void> host(WidgetTester t, Widget child) async {
    t.view.physicalSize = const Size(420, 3200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: [initialAccountProvider.overrideWithValue(_compte())], child: MaterialApp(home: child)));
    await t.pump(const Duration(milliseconds: 200));
  }

  Future<void> attendre(WidgetTester t, Finder f) async {
    for (var i = 0; i < 60 && f.evaluate().isEmpty; i++) {
      await settleReal(t, rounds: 2, ms: 100);
    }
  }

  Future<void> fin(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 60));
  }

  group('Vivier de l’organisation', () {
    testWidgets('serveur muet (404) : message honnête, jamais « vivier vide » ni zéro talent', (t) async {
      srv.unknownIsError = true;
      await host(t, const TalentPoolOrgScreen());
      await attendre(t, find.text('Réessayer'));
      expect(find.text('Réessayer'), findsWidgets);
      expect(find.textContaining('Votre vivier est vide'), findsNothing);
      await fin(t);
    });

    testWidgets('vivier vide : état vide dit clairement, indicateurs lus sur le serveur', (t) async {
      srv.rpc['pool_overview'] = (_) => _overview();
      srv.rpc['pool_search'] = (_) => <Object?>[];
      await host(t, const TalentPoolOrgScreen());
      await attendre(t, find.textContaining('Votre vivier est vide'));
      expect(find.textContaining('Votre vivier est vide'), findsOneWidget);
      expect(find.text('Aucun rappel ouvert.'), findsOneWidget);
      await fin(t);
    });

    testWidgets('liste : talents, étape et étiquettes du serveur ; le filtre « Disponibles » est envoyé', (t) async {
      srv.rpc['pool_overview'] = (_) => _overview(total: 2);
      srv.rpc['pool_search'] = (_) => [_talent(_st1, 'Alice N.', stage: 'preselectionne', tags: ['Mobile'], available: true), _talent('b', 'Bob E.')];
      await host(t, const TalentPoolOrgScreen());
      await attendre(t, find.text('Alice N.'));
      expect(find.text('Alice N.'), findsOneWidget);
      expect(find.text('Bob E.'), findsOneWidget);
      expect(find.textContaining('Présélectionné · Disponible · Mobile'), findsOneWidget);
      await t.tap(find.text('Disponibles'));
      await settleReal(t, rounds: 6, ms: 60);
      expect(srv.callsOf('pool_search').any((c) => c.args['p_available'] == true), isTrue);
      await fin(t);
    });

    testWidgets('notes : le texte saisi est envoyé au serveur (p_body), relu depuis le serveur', (t) async {
      final notes = <Map<String, dynamic>>[];
      srv.rpc['pool_overview'] = (_) => _overview(total: 1);
      srv.rpc['pool_search'] = (_) => [_talent(_st1, 'Alice N.')];
      srv.rpc['pool_notes_get'] = (_) => notes;
      srv.rpc['pool_note_add'] = (a) {
        notes.add({'id': 'n1', 'body': a['p_body'], 'author': 'Mem A.', 'created_at': '2026-11-24T09:00:00Z', 'can_delete': true});
        return 'n1';
      };
      await host(t, const TalentPoolOrgScreen());
      await attendre(t, find.text('Alice N.'));
      await t.tap(find.text('Alice N.'));
      await attendre(t, find.text('Aucune note pour ce talent.'));
      await t.enterText(find.widgetWithText(TextField, 'Nouvelle note interne'), 'Entretien téléphonique positif');
      await t.tap(find.text('Ajouter la note'));
      // le texte saisi est déjà dans le champ : on attend l'appel serveur, puis la note relue (deux occurrences : champ + liste)
      for (var i = 0; i < 60 && srv.callsOf('pool_note_add').isEmpty; i++) {
        await settleReal(t, rounds: 2, ms: 100);
      }
      await settleReal(t, rounds: 6, ms: 100);
      final call = srv.callsOf('pool_note_add').single;
      expect(call.args['p_body'], 'Entretien téléphonique positif');
      expect(call.args['p_student'], _st1);
      expect(find.text('Entretien téléphonique positif'), findsOneWidget);
      await fin(t);
    });

    testWidgets('notes : panne serveur (500) → erreur lisible, aucune confirmation, aucune note affichée', (t) async {
      srv.rpc['pool_overview'] = (_) => _overview(total: 1);
      srv.rpc['pool_search'] = (_) => [_talent(_st1, 'Alice N.')];
      srv.rpc['pool_notes_get'] = (_) => <Object?>[];
      srv.failRpc.add('pool_note_add');
      await host(t, const TalentPoolOrgScreen());
      await attendre(t, find.text('Alice N.'));
      await t.tap(find.text('Alice N.'));
      await attendre(t, find.text('Aucune note pour ce talent.'));
      await t.enterText(find.widgetWithText(TextField, 'Nouvelle note interne'), 'Note perdue');
      await t.tap(find.text('Ajouter la note'));
      await attendre(t, find.text('Note non enregistrée'));
      expect(find.text('Note non enregistrée'), findsOneWidget);
      expect(find.text('Note enregistrée.'), findsNothing);
      expect(find.text('Aucune note pour ce talent.'), findsOneWidget);
      await fin(t);
    });

    testWidgets('lecteur d’équipe : lecture seule, aucun formulaire d’écriture', (t) async {
      srv.rpc['pool_overview'] = (_) => _overview(total: 1, role: 'viewer');
      srv.rpc['pool_search'] = (_) => [_talent(_st1, 'Alice N.')];
      srv.rpc['pool_notes_get'] = (_) => <Object?>[];
      await host(t, const TalentPoolOrgScreen());
      await attendre(t, find.text('Alice N.'));
      await t.tap(find.text('Alice N.'));
      await attendre(t, find.textContaining('Lecture seule'));
      expect(find.textContaining('Lecture seule'), findsOneWidget);
      expect(find.text('Ajouter la note'), findsNothing);
      await fin(t);
    });

    testWidgets('fenêtre « Enregistrer dans… » : la note interne est envoyée avec l’ajout (p_note)', (t) async {
      srv.rpc['pool_lists_get'] = (_) => [
            {'id': 'fav', 'name': 'Favoris', 'count': 0, 'has': false},
          ];
      srv.rpc['pool_list_add'] = (_) => null;
      await host(t, Consumer(builder: (c, ref, _) => TextButton(onPressed: () => showTalentListsSheet(c, ref, studentId: _st1, studentName: 'Alice N.'), child: const Text('ouvrir'))));
      await t.tap(find.text('ouvrir'));
      await attendre(t, find.text('Favoris'));
      await t.enterText(find.widgetWithText(TextField, 'Note interne (facultative)'), 'Très bon profil mobile');
      await t.tap(find.byType(CheckboxListTile));
      await settleReal(t, rounds: 6, ms: 60);
      final call = srv.callsOf('pool_list_add').single;
      expect(call.args['p_note'], 'Très bon profil mobile');
      expect(call.args['p_list'], 'fav');
      await fin(t);
    });

    testWidgets('fenêtre « Enregistrer dans… » : panne 500 sur la lecture des listes → erreur et bouton Réessayer', (t) async {
      srv.failRpc.add('pool_lists_get');
      await host(t, Consumer(builder: (c, ref, _) => TextButton(onPressed: () => showTalentListsSheet(c, ref, studentId: _st1, studentName: 'Alice N.'), child: const Text('ouvrir'))));
      await t.tap(find.text('ouvrir'));
      await attendre(t, find.text('Réessayer'));
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNothing);
      await fin(t);
    });
  });

  group('Passeport Talent 360°', () {
    Map<String, dynamic> passeport({bool own = true, Map<String, dynamic>? sections}) => {
          'user_id': _st1,
          'own': own,
          'name': 'Alice Ngo',
          'shares': own ? {'identite': 'prive', 'competences': 'organisations', 'realisations': 'prive', 'certificats': 'prive', 'missions': 'prive', 'disponibilites': 'prive'} : null,
          'sections': sections ??
              {
                'identite': {'shared': true, 'headline': 'Développeuse mobile', 'summary': 'Flutter', 'department': 'Génie informatique', 'institution': '', 'city': 'Douala'},
                'competences': {
                  'shared': true,
                  'items': [
                    {'skill': 'Flutter', 'level': 'avance', 'years': 3, 'has_proof': true, 'proof_verified': true},
                  ],
                },
                'realisations': {'shared': true, 'items': <Object?>[]},
                'certificats': {'shared': true, 'items': <Object?>[]},
                'missions': {'shared': true, 'items': <Object?>[]},
                'disponibilites': {'shared': true, 'availability': null, 'languages': <Object?>[]},
              },
        };

    testWidgets('serveur muet : message honnête et Réessayer, aucune rubrique inventée', (t) async {
      srv.unknownIsError = true;
      await host(t, const Passport360Screen());
      await attendre(t, find.text('Réessayer'));
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('Compétences'), findsNothing);
      await fin(t);
    });

    testWidgets('mon passeport : rubriques lues sur le serveur, rubriques vides dites vides', (t) async {
      srv.rpc['talent_passport_360'] = (_) => passeport();
      await host(t, const Passport360Screen());
      await attendre(t, find.text('Compétences'));
      expect(find.textContaining('Flutter · Avancé · 3 an(s) · justificatif vérifié'), findsOneWidget);
      expect(find.text('Aucune réalisation publiée.'), findsOneWidget);
      expect(find.text('Aucun certificat vérifiable.'), findsOneWidget);
      expect(find.text('Aucune disponibilité indiquée.'), findsOneWidget);
      await fin(t);
    });

    testWidgets('passeport d’un tiers : une rubrique non partagée n’est pas révélée', (t) async {
      srv.rpc['talent_passport_360'] = (a) => passeport(own: false, sections: {
            'identite': {'shared': false},
            'competences': {'shared': false},
            'realisations': {'shared': false},
            'certificats': {'shared': false},
            'missions': {'shared': false},
            'disponibilites': {'shared': false},
          });
      await host(t, const Passport360Screen(userId: _st1));
      await attendre(t, find.text('Compétences'));
      expect(find.text('Rubrique non partagée par la personne.'), findsNWidgets(6));
      expect(srv.callsOf('talent_passport_360').single.args['p_user'], _st1);
      expect(find.text('Enregistrer'), findsNothing);
      await fin(t);
    });

    testWidgets('partage : le choix du propriétaire est envoyé au serveur, confirmation seulement après succès', (t) async {
      srv.rpc['talent_passport_360'] = (_) => passeport();
      srv.rpc['talent_passport_share_set'] = (a) => {'ok': true};
      await host(t, const Passport360Screen());
      await attendre(t, find.text('Certificats vérifiables'));
      await t.tap(find.byType(DropdownButton<String>).at(3));
      await settleReal(t, rounds: 4, ms: 60);
      await t.tap(find.text('Comptes connectés').last);
      await settleReal(t, rounds: 6, ms: 60);
      final call = srv.callsOf('talent_passport_share_set').single;
      expect(call.args, {'p_section': 'certificats', 'p_audience': 'connectes'});
      await fin(t);
    });

    testWidgets('partage : panne 500 → « Partage non modifié », aucune confirmation', (t) async {
      srv.rpc['talent_passport_360'] = (_) => passeport();
      srv.failRpc.add('talent_passport_share_set');
      await host(t, const Passport360Screen());
      await attendre(t, find.text('Certificats vérifiables'));
      await t.tap(find.byType(DropdownButton<String>).at(3));
      await settleReal(t, rounds: 4, ms: 60);
      await t.tap(find.text('Comptes connectés').last);
      await attendre(t, find.text('Partage non modifié'));
      expect(find.text('Partage non modifié'), findsOneWidget);
      expect(find.textContaining('Partage mis à jour'), findsNothing);
      await fin(t);
    });
  });
}
