import 'dart:convert';
import 'dart:io';

import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/i18n.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/top100_public.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_supabase.dart';
import 'helpers/render.dart';

/// H13.1 · lot G : catalogue anglais (assets/i18n/en.json). Seule la langue anglaise est prise en charge (aucun autre catalogue).
/// Prouve : JSON valide, aucun doublon, modèles « § » aux {n} identiques dans la valeur, aucune valeur vide, et que les textes à interpolations
/// imbriquées de H12/H13 (extraits par tool/i18n/extract_dart.cjs) se traduisent via I18n.tr avec leurs valeurs, y compris les pluriels conditionnels.
final _keyLine = RegExp(r'^\s*("(?:[^"\\]|\\.)*")\s*:');
final _ph = RegExp(r'\{(\d)\}');

String _phs(String s) => (_ph.allMatches(s).map((m) => m.group(1)!).toList()..sort()).join(',');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> en;
  late List<String> rawKeys;

  setUpAll(() async {
    await loadAppFonts();
    final raw = await File('assets/i18n/en.json').readAsString();
    en = Map<String, String>.from(jsonDecode(raw) as Map);
    rawKeys = [for (final l in const LineSplitter().convert(raw)) if (_keyLine.hasMatch(l)) jsonDecode(_keyLine.firstMatch(l)!.group(1)!) as String];
    await I18n.available();
  });
  tearDown(() => I18n.setLang('fr', save: false));

  group('catalogue en.json', () {
    test('JSON valide, aucun doublon de clé, aucune valeur vide', () {
      expect(rawKeys.length, en.length, reason: 'une clé apparaît deux fois dans le fichier');
      expect(en.entries.where((e) => e.value.trim().isEmpty).map((e) => e.key), isEmpty);
    });

    test('tout modèle « § » a les mêmes {n} dans la valeur, sans répétition', () {
      final bad = <String>[];
      for (final e in en.entries.where((e) => e.key.startsWith('§'))) {
        final k = e.key.substring(1);
        final nk = _ph.allMatches(k).length;
        if (_phs(k) != _phs(e.value) || _ph.allMatches(e.value).length != nk || nk != _phs(k).split(',').where((x) => x.isNotEmpty).toSet().length) bad.add(e.key);
      }
      expect(bad, isEmpty);
    });

    test('les nouveaux modèles H13.1 : de {0} à {3} seulement (I18n ne remplace que ces valeurs)', () {
      final fixtures = (jsonDecode(File('test/fixtures/i18n_h131_fixtures.json').readAsStringSync()) as List).cast<Map>();
      final over = [for (final f in fixtures) if ((f['key'] as String).startsWith('§') && RegExp(r'\{[4-9]\}').hasMatch(f['key'] as String)) f['key']];
      expect(over, isEmpty);
    });
  });

  group('textes à interpolations imbriquées de H12/H13', () {
    final fixtures = (jsonDecode(File('test/fixtures/i18n_h131_fixtures.json').readAsStringSync()) as List).cast<Map>();

    test('${fixtures.length} chaînes recensées : chacune est dans le catalogue et se traduit avec ses valeurs', () async {
      await I18n.setLang('en', save: false);
      final wrong = <String>[];
      for (final f in fixtures) {
        if (!en.containsKey(f['key'])) wrong.add('absente : ${f['key']}');
        final got = I18n.tr(f['sample'] as String);
        if (got != f['expected']) wrong.add('${f['sample']} -> $got (attendu ${f['expected']})');
      }
      expect(wrong, isEmpty);
    });

    test('modèles à plus de 4 valeurs ({4}, {5}) : toutes les valeurs sont remplacées', () async {
      await I18n.setLang('en', save: false);
      const buyer = 'Awa N.';
      expect(I18n.tr('Client : $buyer\nVendeur(s) : Wax Tailor\nMontant : 12 500\nPaiement : Orange Money (payé)\nÉtat : ZZs\nPassée le 12/11/2026'),
          'Customer: Awa N.\nSeller(s): Wax Tailor\nAmount: 12 500\nPayment: Orange Money (paid)\nStatus: ZZs\nPlaced on 12/11/2026');
      expect(I18n.tr('Client : $buyer\nVendeur(s) : Wax Tailor\nMontant : 12 500\nPaiement : Orange Money (non payé)\nÉtat : ZZs\nPassée le 12/11/2026'), contains('Payment: Orange Money (unpaid)'));
      for (final n in [1, 5]) {
        final bal = 100;
        final total = n * 8;
        expect(
          I18n.tr('Offrir $n × Rose 🌹 pour $total crédit${total > 1 ? 's' : ''} ?\nVotre solde passera de $bal à ${bal - total} crédits. Un cadeau envoyé n’est pas remboursable.'),
          'Give $n × Rose 🌹 for $total credits?\nYour balance will go from $bal to ${bal - total} credits. A gift once sent cannot be refunded.',
        );
      }
      expect(I18n.tr('Offrir 1 × Rose 🌹 pour 1 crédit ?\nVotre solde passera de 100 à 99 crédits. Un cadeau envoyé n’est pas remboursable.'),
          'Give 1 × Rose 🌹 for 1 credit?\nYour balance will go from 100 to 99 credits. A gift once sent cannot be refunded.');
      expect(I18n.tr('ZZ1 · ZZ2 · 50 % · ZZ3 · facture ZZ4'), 'ZZ1 · ZZ2 · 50 % · ZZ3 · invoice ZZ4');
    });

    test('en français rien ne change', () {
      for (final f in fixtures.take(60)) {
        expect(I18n.tr(f['sample'] as String), f['sample']);
      }
    });

    test('interpolations Dart réelles : crochets et guillemets imbriqués, valeurs conservées', () async {
      await I18n.setLang('en', save: false);
      final x = {'title': 'Atelier IA', 'host': 'Awa N.'};
      final orgs = ['Orange', 'MTN'];
      expect(I18n.tr('Ouvrir le live ${x['title']}'), 'Open the live Atelier IA');
      expect(I18n.tr('Autres lives de ${x['host']}'), 'More lives from Awa N.');
      expect(I18n.tr('Avec : ${orgs.join(', ')}'), 'With: Orange, MTN');
      expect(I18n.tr('${x['host']} sur Boutik-École : https://boutik.example/live/1'), 'Awa N. on Boutik-École: https://boutik.example/live/1');
      expect(I18n.tr('Aucun étudiant ne correspond à « ${x['title']} ».'), 'No student matches "Atelier IA".');
      expect(I18n.tr('Promotion « Atelier IA » appliquée automatiquement : −10 % (−500 F)'), 'Promotion "Atelier IA" applied automatically: −10 % (−500 F)');
    });

    test('pluriels conditionnels : singulier et pluriel, jamais « (s) » cassé ni valeur vide', () async {
      await I18n.setLang('en', save: false);
      for (final n in [1, 2, 7]) {
        expect(I18n.tr('$n publication${n > 1 ? 's' : ''} en attente de validation'), n > 1 ? '$n posts awaiting approval' : '1 post awaiting approval');
        expect(I18n.tr('$n abonné${n > 1 ? 's' : ''}'), n > 1 ? '$n followers' : '1 follower');
        expect(I18n.tr('Série de $n jour${n > 1 ? 's' : ''}'), '$n-day streak');
        expect(I18n.tr('$n crédit${n > 1 ? 's' : ''}'), n > 1 ? '$n credits' : '1 credit');
      }
      expect(I18n.tr('3 compte${3 > 1 ? 's' : ''} en attente de rattachement'), '3 accounts awaiting linking');
      expect(I18n.tr('1 compte en attente de rattachement'), '1 account awaiting linking');
    });

    test('valeurs traduites à l’intérieur d’un modèle (statuts, repli)', () async {
      await I18n.setLang('en', save: false);
      expect(I18n.tr('Partiel · demandé'), 'Partial · requested');
      expect(I18n.tr('Partiel · versé · 5 000'), 'Partial · paid out · 5 000');
      expect(I18n.tr('Complet · refusé'), 'Full · declined');
      expect(I18n.tr('Réponse le 12/11/2026 (en 2 j) : D’accord'), 'Reply on 12/11/2026 (in 2 j): D’accord');
    });

    test('accents, apostrophes typographiques et retours à la ligne conservés', () async {
      await I18n.setLang('en', save: false);
      const panier = 'Un article de votre panier pose problème : aucune commande n’a été créée.\n';
      expect(I18n.tr('${panier}Maillot « Wax » : stock épuisé'), 'One item in your cart has a problem: no order was created.\nMaillot « Wax » : stock épuisé');
      expect(I18n.tr('Le budget ne peut pas dépasser 500 000.'), 'The budget cannot exceed 500 000.');
    });
  });

  group('écran H13 en anglais', () {
    late FakeSupabase srv;
    setUpAll(() async {
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
      srv.unknownIsError = false;
    });
    tearDown(() {
      GScreen.mockupFrame = true;
      I18n.lang = 'fr';
    });

    Map<String, dynamic> profile() => {
          'found': true, 'user_id': 'u9', 'name': 'Awa N.', 'photo': null, 'institution': 'IUT de Douala', 'program': 'Génie informatique', 'department': 'Informatique', 'promotion': '2026',
          'affiliation_verified': true, 'shared_sections': ['rank', 'score', 'skills'], 'contact': 'login_required',
          'ranking': [{'scope': 'national', 'scope_ref': null, 'scope_label': 'National', 'rank': 3, 'cohort_size': 40, 'period': '2026-10'}],
          'score': 210,
          'evolution': [{'period': '2026-10', 'rank': 3, 'delta_rank': 2, 'month_points': 30}],
          'skills': null, 'badges': null, 'projects': null, 'passport': null, 'availability': null,
        };

    testWidgets('profil public d’un talent : textes à valeurs et crochets traduits sans erreur, français intact', (t) async {
      srv.rpc['talent_public_profile'] = (a) => profile();
      t.view.physicalSize = const Size(420, 3600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);

      Future<void> ouvrir(String lang) async {
        I18n.lang = lang;
        await t.pumpWidget(ProviderScope(key: UniqueKey(), child: MaterialApp(home: I18nScope(lang: lang, child: const TalentPublicProfileScreen(userId: 'u9')))));
        for (var i = 0; i < 60 && find.text('Awa N.').evaluate().isEmpty; i++) {
          await settleReal(t, rounds: 2, ms: 100);
        }
      }

      await ouvrir('en');
      expect(t.takeException(), isNull);
      expect(find.text('rank 3 of 40'), findsOneWidget);
      expect(find.text('rang 3 sur 40'), findsNothing);
      expect(find.text('Graduating class 2026'), findsOneWidget);
      expect(find.text('rank 3 (▲ 2) · +30 pts'), findsOneWidget);

      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 60));

      await ouvrir('fr');
      expect(t.takeException(), isNull);
      expect(find.text('rang 3 sur 40'), findsOneWidget);
      expect(find.text('Promotion 2026'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 60));
    });
  });
}
