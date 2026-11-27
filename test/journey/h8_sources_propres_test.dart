import 'dart:convert';
import 'dart:io';

import 'package:boutik_ecole/app.dart';
import 'package:boutik_ecole/data/repositories/repositories.dart' show CartLine, cartProvider;
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/decouverte_screens.dart' show recentSearchesProvider;
import 'package:boutik_ecole/figma/live/drafts.dart';
import 'package:boutik_ecole/figma/live/hackathons.dart' show ordinal, provisionalRank;
import 'package:boutik_ecole/figma/live/seller.dart' show Listing, platformProduct;
import 'package:boutik_ecole/figma/live/store.dart' as store;
import 'package:boutik_ecole/figma/live/talents.dart' show applicationsProvider, talentProposalBlock, talentProposalRecord;
import 'package:boutik_ecole/main.dart' show AppRoot;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/render.dart';

/// H8 · SOURCES PROPRES. Volet statique : aucune source de données métier de lib/figma/live (constante `_seed…`, `_demo…`, comptes initiaux,
/// catalogue d'exemple) n'est lue sans garde `Backend.ready` / `demoContent`. Volet dynamique : un compte neuf, la déconnexion, l'expiration de
/// session et le changement de compte ne laissent aucun état (mémoire ni stockage local) du compte précédent.
const _uidA = '11111111-1111-4111-8111-111111111111';
const _uidB = '22222222-2222-4222-8222-222222222222';

Map<String, dynamic> _session(String uid, String email) {
  final exp = DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000;
  String b64(Map m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return {
    'access_token': '${b64({'alg': 'HS256', 'typ': 'JWT'})}.${b64({'sub': uid, 'role': 'authenticated', 'exp': exp})}.signature',
    'token_type': 'bearer',
    'expires_in': 7200,
    'expires_at': exp,
    'refresh_token': 'refresh-$uid',
    'user': {'id': uid, 'aud': 'authenticated', 'role': 'authenticated', 'email': email, 'app_metadata': <String, dynamic>{}, 'user_metadata': <String, dynamic>{}, 'created_at': '2026-01-01T00:00:00Z'},
  };
}

Account _compte(String uid, String email, {String institution = '', String avatar = ''}) =>
    Account(name: 'Titulaire ${uid.substring(0, 2)}', phone: '690000000', email: email, password: '', verified: false, institution: institution, department: '', city: '', serverId: uid, avatarUrl: avatar);

/// Sources de données d'exemple : jeu initial, comptes ou lignes écrits en dur dans lib/figma/live. Chaque lecture doit être gardée.
final _seedDecl = RegExp(r'^\s*(?:static\s+)?(?:const|final)\s+(?:[\w<>?,() ]+\s+)?(_seed\w+|_demo\w+|seedAccounts|demoAccount)\s*=', multiLine: true);

void main() {
  test('statique : toute source d’exemple de lib/figma/live est lue derrière Backend.ready / demoContent', () {
    final fautes = <String>[];
    final fichiers = Directory('lib/figma/live').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();
    final noms = <String>{};
    for (final f in fichiers) {
      for (final m in _seedDecl.allMatches(f.readAsStringSync())) {
        noms.add(m.group(1)!);
      }
    }
    expect(noms, containsAll(['_seedAudit', '_seedReports', '_seedFlows', '_seedOrders', '_seedOrderRows', '_seedRanking', '_demoListings', 'seedAccounts']), reason: 'la détection des sources d’exemple ne fonctionne plus');
    for (final f in fichiers) {
      final lignes = f.readAsLinesSync();
      for (var i = 0; i < lignes.length; i++) {
        for (final n in noms) {
          if (!RegExp('\\b$n\\b').hasMatch(lignes[i]) || _seedDecl.hasMatch(lignes[i])) continue;
          // définitions : entrée de la liste des comptes de démonstration et valeur par défaut de l'état local (lue seulement par les chemins hors connexion ci-dessous)
          if (RegExp(r'^\s*demoAccount,\s*$').hasMatch(lignes[i]) || lignes[i].contains('this.accounts = seedAccounts')) continue;
          final debut = i < 40 ? 0 : i - 40;
          final fenetre = lignes.sublist(debut, i + 1).join('\n');
          if (!fenetre.contains('Backend.ready') && !fenetre.contains('demoContent')) {
            fautes.add('${f.uri.pathSegments.last}:${i + 1} $n lu sans garde');
          }
        }
      }
    }
    expect(fautes, isEmpty, reason: fautes.join('\n'));
  });

  test('statique : la réinitialisation des états hors providers couvre les jetons et caches du compte', () {
    final src = File('lib/figma/live/account_reset.dart').readAsStringSync();
    for (final t in ['Backend.promoCode', 'Backend.packLines.clear()', 'store.extraProducts', 'store.platformProducts', 'Listing.lowStock', 'gSelfAvatarUrl', 'gSelfInstitution', 'clearAdminReturnToken()']) {
      expect(src.contains(t), isTrue, reason: 'account_reset.dart ne remet pas $t à zéro');
    }
    final expire = File('lib/main.dart').readAsStringSync();
    expect(expire.contains('appSessionExpired = () {') && expire.contains('resetAccountScopedState();'), isTrue, reason: 'l’expiration de session doit remettre les états à zéro');
  });

  test('statique (H13 admin) : santé des services et exports d’administration ne lisent que le serveur, sans exemple ni état par défaut « en service »', () {
    for (final f in ['admin_sante.dart', 'admin_exports.dart']) {
      final src = File('lib/figma/live/$f').readAsStringSync();
      expect(_seedDecl.hasMatch(src), isFalse, reason: '$f ne doit déclarer aucune source d’exemple');
      expect(src.contains('demoContent'), isFalse, reason: '$f : aucune donnée de maquette');
    }
    final sante = File('lib/figma/live/admin_sante.dart').readAsStringSync();
    expect(sante.contains("Backend.rpc('admin_service_health'"), isTrue);
    expect(sante.contains('if (!Backend.ready) return const []'), isTrue, reason: 'hors connexion, aucun état n’est affirmé');
    expect(RegExp(r"\?\?\s*'ok'").hasMatch(sante), isFalse, reason: 'un statut absent ne vaut jamais « ok »');
    final exports = File('lib/figma/live/admin_exports.dart').readAsStringSync();
    expect(exports.contains("Backend.rpc('admin_export_csv'"), isTrue);
    expect(exports.contains('if (!Backend.ready)'), isTrue);
    // les trois listes exportables sont branchées sur l’écran qui les affiche
    expect(File('lib/figma/live/admin_consoles.dart').readAsStringSync().contains("exportAdminCsv(context, 'audit'"), isTrue);
    expect(File('lib/figma/live/dept_space.dart').readAsStringSync().contains("exportAdminCsv(context, 'rattachements'"), isTrue);
    expect(File('lib/figma/live/top100_admin_moderation.dart').readAsStringSync().contains("exportAdminCsv(context, 'contestations'"), isTrue);
    expect(File('lib/figma/live/admin_centre.dart').readAsStringSync().contains('ServiceHealthSection'), isTrue);
  });

  group('connecté : aucune donnée d’exemple dans les sources partagées', () {
    setUp(() => Backend.ready = true);
    tearDown(() => Backend.ready = false);

    test('catalogue : un titre du catalogue d’exemple ne ramène ni vendeur ni description fictifs', () {
      store.extraProducts = const [];
      store.platformProducts = const [];
      final p = store.productByTitle(store.liveCatalog.first.title);
      expect(p.description, isNot(store.liveCatalog.first.description));
      expect(p.seller, isNot(store.liveCatalog.first.seller));
      final l = Listing(title: store.liveCatalog.first.title, category: 'Maison', price: 1000, stock: 5);
      final pp = platformProduct(l);
      expect(pp.description, isEmpty, reason: 'la description d’une vraie annonce vide ne vient pas du catalogue d’exemple');
    });

    test('rang provisoire du jury : aucune équipe fictive, « — » tant que le classement réel n’existe pas', () {
      expect(provisionalRank(const [10, 10, 10, 10]), 0);
      expect(ordinal(0), '—');
    });

    test('candidatures d’exemple absentes', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(applicationsProvider), isEmpty);
    });
  });

  late FakeSupabase srv;
  setUpAll(() async {
    await loadAppFonts();
    srv = await FakeSupabase.start();
    await srv.initSupabase();
  });
  tearDownAll(() => srv.close());

  setUp(() async {
    GScreen.mockupFrame = false;
    GAnim.enabled = false;
    srv.unknownIsError = false;
    srv.rpc.clear();
    srv.tables.clear();
    srv.calls.clear();
    SharedPreferences.setMockInitialValues({});
    await Supabase.instance.client.auth.recoverSession(jsonEncode(_session(_uidA, 'a@example.test')));
    store.extraProducts = const [];
    Listing.lowStock = 30;
    Backend.promoCode = '';
    Backend.packLines.clear();
    Drafts.values = {};
  });
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = true;
  });

  Future<void> fermer(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 60));
  }

  ProviderContainer containerOf(WidgetTester t) => ProviderScope.containerOf(t.element(find.byType(BoutikEcoleApp)));

  Future<void> ouvrir(WidgetTester t, Account a) async {
    t.view.physicalSize = const Size(390, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(AppRoot(remembered: a, firstRun: false));
    await settleReal(t);
  }

  Future<ProviderContainer> ouvrirSession(WidgetTester t, {required String uid, required String email, required Account compte}) async {
    await Supabase.instance.client.auth.recoverSession(jsonEncode(_session(uid, email)));
    final c = containerOf(t);
    expect(c.read(authProvider).current, isNull, reason: 'après la sortie de A, aucun compte dans le nouvel arbre de providers');
    c.read(authProvider.notifier).login(compte);
    await settleReal(t, rounds: 8);
    return c;
  }

  Future<void> remplirEtatDeA(WidgetTester t, ProviderContainer c) async {
    await saveRemembered('a@example.test');
    c.read(cartProvider);
    await settleReal(t);
    c.read(cartProvider.notifier).add(const CartLine('Article de A', '', 1000, 'placeholder'));
    await c.read(recentSearchesProvider.notifier).add('recherche de A');
    await talentProposalRecord(_uidA, 'talent-1');
    await Drafts.adoptOwner(_uidA);
    await Drafts.save('np', {'np_title': 'Brouillon de A'});
    store.extraProducts = const [store.LiveProduct('Annonce de A', 'Dept', 1000, 'A', 'd', 'placeholder', sellerId: _uidA)];
    await settleReal(t);
    expect(c.read(recentSearchesProvider), ['recherche de A'], reason: 'préalable');
    expect(gSelfAvatarUrl, 'https://example.test/a.png', reason: 'préalable');
    expect(gSelfInstitution, 'IUT de A', reason: 'préalable');
  }

  /// Rien du compte A, ni en mémoire ni dans le stockage local lisible par B.
  Future<void> verifierPropre(WidgetTester t, ProviderContainer c, {required bool courrielEfface}) async {
    final prefs = await SharedPreferences.getInstance();
    expect(c.read(authProvider).current?.serverId, _uidB);
    expect(c.read(cartProvider).map((l) => l.title), isNot(contains('Article de A')));
    expect(c.read(recentSearchesProvider), isEmpty, reason: 'historique de recherche de A visible par B');
    expect(await talentProposalBlock(_uidB, 'talent-1'), isNull, reason: 'quota de propositions de A appliqué à B');
    expect(Drafts.values, isEmpty, reason: 'brouillon de A visible par B');
    expect(prefs.getKeys().where((k) => k.startsWith('boutik.draft.')), isEmpty);
    if (courrielEfface) expect(prefs.getKeys().where((k) => k.contains('remember')), isEmpty, reason: 'courriel de A mémorisé pour le prochain visiteur');
    expect(gSelfAvatarUrl, isEmpty, reason: 'photo de A affichée pour B');
    expect(gSelfInstitution, isEmpty, reason: 'établissement de A affiché pour B');
    expect(store.extraProducts, isEmpty);
    expect(Backend.promoCode, isEmpty);
    expect(Backend.packLines, isEmpty);
  }

  testWidgets('déconnexion de A puis connexion d’un compte neuf B : aucun état ni stockage hérité', (t) async {
    final a = _compte(_uidA, 'a@example.test', institution: 'IUT de A', avatar: 'https://example.test/a.png');
    final b = _compte(_uidB, 'b@example.test');
    await ouvrir(t, a);
    var c = containerOf(t);
    await remplirEtatDeA(t, c);

    c.read(authProvider.notifier).logout();
    await settleReal(t);
    expect(Supabase.instance.client.auth.currentUser, isNull, reason: 'la session de A doit être fermée');
    c = await ouvrirSession(t, uid: _uidB, email: 'b@example.test', compte: b);
    await verifierPropre(t, c, courrielEfface: true);
    await fermer(t);
  });

  testWidgets('session expirée sans déconnexion, puis compte neuf B : aucun état ni stockage hérité', (t) async {
    final a = _compte(_uidA, 'a@example.test', institution: 'IUT de A', avatar: 'https://example.test/a.png');
    final b = _compte(_uidB, 'b@example.test');
    await ouvrir(t, a);
    var c = containerOf(t);
    await remplirEtatDeA(t, c);

    appSessionExpired?.call();
    await settleReal(t);
    expect(gSelfAvatarUrl, isEmpty, reason: 'photo de A encore en mémoire sur l’écran « Session expirée »');
    expect(gSelfInstitution, isEmpty);
    c = await ouvrirSession(t, uid: _uidB, email: 'b@example.test', compte: b);
    // l'expiration ne ferme pas la session locale : les clés propres à A restent à A, mais B n'y accède pas
    await verifierPropre(t, c, courrielEfface: false);
    await fermer(t);
  });
}
