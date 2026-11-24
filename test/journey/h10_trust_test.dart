import 'package:boutik_ecole/core/router/app_router.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/verify_public.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/render.dart';

/// H10 · Confiance : page PUBLIQUE de vérification (certificat, QR, passeport partagé, registre d'innovation), visiteur anonyme, faux serveur local.
/// Un état « valide » n'apparaît que si le serveur le confirme ; panne, 404 ou limite de débit ne sont jamais présentées comme valides.
const _code = 'BE-CERT-1A2B3C4D5E6F7A8B';
const _token = 'abcdefghijklmnopqrstuvwxyz012345';
const _proj = '33333333-3333-4333-8333-333333333333';

Map<String, dynamic> _cert({String statut = 'valide', String sig = 'valide', bool consent = false, String titulaire = 'A. N.', Map<String, dynamic> extra = const {}}) => {
      'code': _code, 'statut': statut, 'valide': statut == 'valide', 'objet': 'Initiation à Flutter', 'emetteur': 'Département Informatique', 'departement': 'Génie informatique',
      'delivre_le': '12/11/2026', 'titulaire': titulaire, 'titulaire_nom_public': consent, 'empreinte': 'ab' * 32, 'empreinte_algo': 'SHA-256', 'empreinte_recalculable': true,
      'signature': sig, 'signature_algo': sig == 'non_signe' ? null : 'HMAC-SHA256', ...extra,
    };

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
    await t.pumpWidget(ProviderScope(child: MaterialApp(home: child)));
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

  Future<void> verifier(WidgetTester t, String saisie, Finder attendu) async {
    await t.enterText(find.byKey(const ValueKey('verify_input')), saisie);
    await t.tap(find.text('Vérifier'));
    await attendre(t, attendu);
  }

  int appels(String fn) => srv.calls.where((c) => c.kind == 'rpc' && c.name == fn).length;

  group('Certificat', () {
    testWidgets('valide et signé : champs du serveur, initiales sans consentement, aucun texte de maquette', (t) async {
      srv.rpc['verify_certificate_public'] = (_) => _cert();
      await host(t, const VerifyPublicScreen());
      await verifier(t, 'be-cert-1a2b 3c4d5e6f7a8b', find.text('Certificat authentique'));
      expect(find.text('Certificat authentique'), findsOneWidget);
      expect(find.textContaining('Initiation à Flutter'), findsOneWidget);
      expect(find.textContaining('Signature numérique (HMAC-SHA256) vérifiée'), findsOneWidget);
      expect(find.textContaining('seules ses initiales sont montrées'), findsOneWidget);
      final call = srv.calls.lastWhere((c) => c.name == 'verify_certificate_public');
      expect(call.args['p_code'], _code);
      expect(call.args.containsKey('p_holder'), isFalse);
      await fin(t);
    });

    testWidgets('lien /verifier/:code : vérification immédiate, sans saisie', (t) async {
      srv.rpc['verify_certificate_public'] = (_) => _cert(consent: true, titulaire: 'Alice Ngono');
      await host(t, const VerifyPublicScreen(code: _code));
      await attendre(t, find.text('Certificat authentique'));
      expect(find.textContaining('Alice Ngono'), findsOneWidget);
      expect(find.textContaining('seules ses initiales'), findsNothing);
      await fin(t);
    });

    testWidgets('non signé : dit « non signé », jamais « authentique »', (t) async {
      srv.rpc['verify_certificate_public'] = (_) => _cert(sig: 'non_signe');
      await host(t, const VerifyPublicScreen(code: _code));
      await attendre(t, find.textContaining('non signé'));
      expect(find.text('Certificat enregistré · non signé'), findsOneWidget);
      expect(find.text('Certificat authentique'), findsNothing);
      expect(find.textContaining('Non signé :'), findsOneWidget);
      await fin(t);
    });

    testWidgets('signature invalide : alerte, pas de « authentique »', (t) async {
      srv.rpc['verify_certificate_public'] = (_) => _cert(sig: 'invalide');
      await host(t, const VerifyPublicScreen(code: _code));
      await attendre(t, find.textContaining('Anomalie'));
      expect(find.textContaining('Anomalie : ne pas se fier'), findsOneWidget);
      expect(find.text('Certificat authentique'), findsNothing);
      await fin(t);
    });

    testWidgets('révoqué : motif du serveur, pas de comparaison de nom', (t) async {
      srv.rpc['verify_certificate_public'] = (_) => _cert(statut: 'revoque', extra: {'motif_revocation': 'Erreur d’émission'});
      await host(t, const VerifyPublicScreen(code: _code));
      await attendre(t, find.text('Certificat révoqué'));
      expect(find.textContaining('Erreur d’émission'), findsOneWidget);
      expect(find.text('Certificat authentique'), findsNothing);
      expect(find.text('Comparer'), findsNothing);
      await fin(t);
    });

    testWidgets('inconnu et limite de débit : états distincts, jamais valides', (t) async {
      srv.rpc['verify_certificate_public'] = (_) => {'code': _code, 'statut': 'inconnu', 'valide': false, 'introuvable': true};
      await host(t, const VerifyPublicScreen(code: _code));
      await attendre(t, find.text('Certificat inconnu'));
      expect(find.text('Certificat inconnu'), findsOneWidget);
      srv.rpc['verify_certificate_public'] = (_) => {'code': _code, 'statut': 'limite', 'valide': false, 'limite': true};
      await t.tap(find.text('Vérifier'));
      await attendre(t, find.text('Trop de tentatives'));
      expect(find.text('Trop de tentatives'), findsOneWidget);
      expect(find.text('Certificat inconnu'), findsNothing);
      await fin(t);
    });

    testWidgets('panne serveur (500) et serveur muet (404) : « Vérification impossible », jamais valide ; réessai possible', (t) async {
      srv.failRpc.add('verify_certificate_public');
      await host(t, const VerifyPublicScreen(code: _code));
      await attendre(t, find.text('Vérification impossible'));
      expect(find.text('Vérification impossible'), findsOneWidget);
      expect(find.textContaining('authentique'), findsNothing);
      srv.failRpc.clear();
      srv.rpc['verify_certificate_public'] = (_) => _cert();
      await t.tap(find.text('Réessayer'));
      await attendre(t, find.text('Certificat authentique'));
      expect(find.text('Certificat authentique'), findsOneWidget);
      srv.rpc.clear();
      srv.unknownIsError = true;
      await t.tap(find.text('Vérifier'));
      await attendre(t, find.text('Vérification impossible'));
      expect(find.text('Vérification impossible'), findsOneWidget);
      expect(find.text('Certificat authentique'), findsNothing);
      await fin(t);
    });

    testWidgets('réponse illisible : erreur, pas de « valide »', (t) async {
      srv.rpc['verify_certificate_public'] = (_) => 'ok';
      await host(t, const VerifyPublicScreen(code: _code));
      await attendre(t, find.text('Vérification impossible'));
      expect(find.textContaining('authentique'), findsNothing);
      await fin(t);
    });

    testWidgets('code mal formé : message, aucun appel serveur', (t) async {
      await host(t, const VerifyPublicScreen());
      await verifier(t, 'n’importe quoi', find.text('Code non reconnu'));
      expect(find.text('Code non reconnu'), findsOneWidget);
      expect(srv.calls.where((c) => c.kind == 'rpc'), isEmpty);
      await fin(t);
    });

    testWidgets('comparaison du nom : le nom saisi part au serveur, le verdict vient du serveur', (t) async {
      srv.rpc['verify_certificate_public'] = (a) => _cert(extra: a.containsKey('p_holder') ? {'titulaire_concordant': a['p_holder'] == 'Alice Ngono'} : {});
      await host(t, const VerifyPublicScreen(code: _code));
      await attendre(t, find.text('Comparer'));
      await t.enterText(find.byKey(const ValueKey('verify_holder')), 'Bob Faux');
      await t.tap(find.text('Comparer'));
      await attendre(t, find.textContaining('ne correspond pas'));
      expect(find.textContaining('ne correspond pas'), findsOneWidget);
      await t.enterText(find.byKey(const ValueKey('verify_holder')), 'Alice Ngono');
      await t.tap(find.text('Comparer'));
      await attendre(t, find.textContaining('correspond au titulaire'));
      expect(srv.calls.where((c) => c.name == 'verify_certificate_public').last.args['p_holder'], 'Alice Ngono');
      expect(find.text('Le nom saisi correspond au titulaire de ce certificat.'), findsOneWidget);
      await fin(t);
    });

    testWidgets('QR : le jeton est résolu par qr_resolve_public puis le certificat vérifié ; QR non public refusé', (t) async {
      srv.rpc['qr_resolve_public'] = (a) => a['p_token'] == _token ? {'valid': true, 'kind': 'certificate', 'code': _code} : {'valid': false, 'reason': 'login_required'};
      srv.rpc['verify_certificate_public'] = (_) => _cert();
      await host(t, const VerifyPublicScreen(code: 'https://boutik.example/?qr=$_token'));
      await attendre(t, find.text('Certificat authentique'));
      expect(appels('qr_resolve_public'), 1);
      expect(srv.calls.lastWhere((c) => c.name == 'verify_certificate_public').args['p_code'], _code);
      await t.enterText(find.byKey(const ValueKey('verify_input')), 'ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ');
      await t.tap(find.text('Vérifier'));
      await attendre(t, find.text('QR non vérifiable ici'));
      expect(find.text('QR non vérifiable ici'), findsOneWidget);
      expect(find.text('Certificat authentique'), findsNothing);
      await fin(t);
    });
  });

  group('Passeport partagé', () {
    Map<String, dynamic> ok() => {
          'valid': true, 'name': 'A. N.', 'expires_at': '2026-12-01T10:00:00Z', 'shared_sections': ['competences', 'certificats'],
          'sections': {
            'competences': [{'skill': 'Flutter', 'level': 'avance', 'years': 2, 'proof_verified': true}],
            'certificats': [{'code': _code, 'title': 'Initiation à Flutter', 'issued_at': '2026-11-12'}],
          },
        };

    testWidgets('jeton valide : seules les rubriques renvoyées par le serveur, nom en initiales', (t) async {
      srv.rpc['passport_token_verify'] = (_) => ok();
      await host(t, const VerifyPublicScreen(kind: VerifyKind.passeport, code: _token));
      await attendre(t, find.text('Passeport partagé par son titulaire'));
      expect(find.textContaining('Flutter · avance · 2 an(s) · preuve vérifiée'), findsOneWidget);
      expect(find.textContaining('Initiation à Flutter · $_code'), findsOneWidget);
      expect(find.text('Identité'), findsNothing);
      expect(find.text('Missions menées'), findsNothing);
      expect(srv.calls.lastWhere((c) => c.name == 'passport_token_verify').args['p_token'], _token);
      await fin(t);
    });

    for (final (reason, titre) in [('revoked', 'Lien révoqué'), ('expired', 'Lien expiré'), ('unknown', 'Lien inconnu'), ('limit', 'Trop de tentatives')]) {
      testWidgets('$reason : « $titre », aucune donnée de passeport', (t) async {
        srv.rpc['passport_token_verify'] = (_) => {'valid': false, 'reason': reason};
        await host(t, const VerifyPublicScreen(kind: VerifyKind.passeport, code: 'https://boutik.example/verifier/passeport/$_token'));
        await attendre(t, find.text(titre));
        expect(find.text(titre), findsOneWidget);
        expect(find.text('Passeport partagé par son titulaire'), findsNothing);
        await fin(t);
      });
    }

    testWidgets('panne serveur : erreur, aucune donnée', (t) async {
      srv.failRpc.add('passport_token_verify');
      await host(t, const VerifyPublicScreen(kind: VerifyKind.passeport, code: _token));
      await attendre(t, find.text('Vérification impossible'));
      expect(find.text('Passeport partagé par son titulaire'), findsNothing);
      await fin(t);
    });
  });

  group('Registre d’innovation', () {
    Map<String, dynamic> reg({bool intact = true, String sig = 'non_signe'}) => {
          'statut': 'enregistre', 'valide': intact, 'projet': 'Station solaire', 'auteur': 'A. N.',
          'versions': [
            {'version': 2, 'horodatage': '2026-11-20T09:00:00Z', 'empreinte': 'cd' * 32, 'precedente': 'ab' * 32, 'integre': intact, 'signature': sig, 'note': 'Ajout du prototype'},
            {'version': 1, 'horodatage': '2026-11-10T09:00:00Z', 'empreinte': 'ab' * 32, 'precedente': null, 'integre': true, 'signature': sig, 'note': ''},
          ],
        };

    testWidgets('chaîne intègre : versions, empreintes, « non signé » et avertissement obligatoire', (t) async {
      srv.rpc['project_proof_verify'] = (_) => reg();
      await host(t, const VerifyPublicScreen(kind: VerifyKind.projet, code: _proj));
      await attendre(t, find.text('Preuves enregistrées et intègres'));
      expect(find.text('Preuves enregistrées et intègres'), findsOneWidget);
      expect(find.textContaining('Station solaire'), findsOneWidget);
      expect(find.text('Version 2'), findsOneWidget);
      expect(find.textContaining('Non signé :'), findsNWidgets(2));
      expect(find.text(proofDisclaimer), findsOneWidget);
      expect(proofDisclaimer, contains('ce n’est pas un brevet ni un titre de propriété intellectuelle'));
      expect(srv.calls.lastWhere((c) => c.name == 'project_proof_verify').args['p_project'], _proj);
      await fin(t);
    });

    testWidgets('chaîne rompue : anomalie, jamais « intègre »', (t) async {
      srv.rpc['project_proof_verify'] = (_) => reg(intact: false);
      await host(t, const VerifyPublicScreen(kind: VerifyKind.projet, code: 'https://boutik.example/verifier/projet/$_proj'));
      await attendre(t, find.textContaining('Anomalie'));
      expect(find.textContaining('Anomalie : la chaîne'), findsOneWidget);
      expect(find.text('Preuves enregistrées et intègres'), findsNothing);
      expect(find.textContaining('INTÉGRITÉ NON CONFIRMÉE'), findsWidgets);
      await fin(t);
    });

    testWidgets('inconnu, limite, panne, identifiant invalide', (t) async {
      srv.rpc['project_proof_verify'] = (_) => {'statut': 'inconnu', 'valide': false};
      await host(t, const VerifyPublicScreen(kind: VerifyKind.projet, code: _proj));
      await attendre(t, find.text('Aucune preuve vérifiable'));
      expect(find.text(proofDisclaimer), findsNothing);
      srv.rpc['project_proof_verify'] = (_) => {'statut': 'limite', 'valide': false};
      await t.tap(find.text('Vérifier'));
      await attendre(t, find.text('Trop de tentatives'));
      srv.rpc.clear();
      srv.failRpc.add('project_proof_verify');
      await t.tap(find.text('Vérifier'));
      await attendre(t, find.text('Vérification impossible'));
      expect(find.textContaining('intègres'), findsNothing);
      final avant = appels('project_proof_verify');
      await t.enterText(find.byKey(const ValueKey('verify_input')), 'pas-un-uuid');
      await t.tap(find.text('Vérifier'));
      await attendre(t, find.text('Code non reconnu'));
      expect(appels('project_proof_verify'), avant);
      await fin(t);
    });
  });

  testWidgets('routes publiques : /verifier/:code, /verifier/passeport/:token et /verifier/projet/:id s’ouvrent sans connexion', (t) async {
    srv.rpc['verify_certificate_public'] = (_) => _cert();
    srv.rpc['passport_token_verify'] = (_) => {'valid': false, 'reason': 'revoked'};
    srv.rpc['project_proof_verify'] = (_) => {'statut': 'inconnu', 'valide': false};
    t.view.physicalSize = const Size(420, 3200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final router = buildRouter(initial: '/verifier/$_code');
    await t.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: router)));
    await attendre(t, find.text('Certificat authentique'));
    expect(find.text('Certificat authentique'), findsOneWidget);
    router.go('/verifier/passeport/$_token');
    await attendre(t, find.text('Lien révoqué'));
    expect(find.text('Lien révoqué'), findsOneWidget);
    router.go('/verifier/projet/$_proj');
    await attendre(t, find.text('Aucune preuve vérifiable'));
    expect(find.text('Aucune preuve vérifiable'), findsOneWidget);
    router.go('/verifier?qr=$_code');
    await attendre(t, find.text('Certificat authentique'));
    expect(find.text('Certificat authentique'), findsOneWidget);
    await fin(t);
  });
}
