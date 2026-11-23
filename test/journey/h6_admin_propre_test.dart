import 'dart:convert';
import 'dart:io';

import 'package:boutik_ecole/app.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/registry.dart' show gWidths;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/render.dart';

/// H6 · L2 : ESPACE ADMIN PROPRE (écrans globaux 127-138, 145, 146-1/2, 147-1/2/3, 180, 181, 264-269, 277, 280-283).
/// Connecté (`Backend.ready`, session ouverte sur un faux serveur Supabase local), avec un compte « Admin global » :
///  (i)   aucun jeton de maquette (personnages, entités : tool/maquette_tokens.json) ;
///  (ii)  aucun texte à chiffres affiché en ÉTAT VIDE (serveur muet) : un chiffre visible sans donnée est une fausse donnée ;
///  (iii) aucune photo de maquette (`gIsMockPhoto`) ;
///  (iv)  menu du bas = menu reconstruit à cinq onglets sur les écrans 390 px ;
///  (v)   aucun débordement.
/// Volet statique : un texte littéral à chiffres ou à nom de maquette doit être gardé par `demoContent` (ternaire ou `show:`).
const ecransAdmin = [
  '127', '128', '129', '130', '131', '132', '133', '134', '135', '136', '137', '138', //
  '145', '146-1', '146-2', '147-1', '147-2', '147-3', '180', '181',
  '264', '265', '266', '267', '268', '269', '277', '280', '281', '282', '283',
];

final _tokens = jsonDecode(File('tool/maquette_tokens.json').readAsStringSync()) as Map<String, dynamic>;
final _noms = <String>{...(_tokens['personas'] as List).cast<String>(), ...(_tokens['entities'] as List).cast<String>(), ...(_tokens['self'] as List).cast<String>()}.where((e) => e.length >= 4).toList();

/// Seuls libellés structurels tolérés avec chiffres (aucune donnée) : les nombres isolés de pagination ne le sont PAS (compteurs, badges).
final _structurel = RegExp(r'^\+237$|^Étape \d|^Version \d');

String _fichier(String id) => 'lib/figma/g/g_${id.replaceAll('-', '_')}.dart';

void main() {
  test('statique : aucun texte à chiffres ou à nom de maquette hors demoContent dans les écrans admin du lot L2', () {
    final re = RegExp(r"gText\(\s*'((?:[^'\\$]|\\.)*)'\s*,\s*([0-9.]+)");
    final fautes = <String>[];
    for (final id in ecransAdmin) {
      final lignes = File(_fichier(id)).readAsLinesSync();
      for (var n = 0; n < lignes.length; n++) {
        final l = lignes[n];
        final garde = l.contains('show: demoContent') || l.contains('if (demoContent)') || l.contains('demoContent ?');
        for (final m in re.allMatches(l)) {
          final t = m.group(1)!.trim();
          if (t.isEmpty || garde) continue;
          final chiffres = RegExp(r'\d').hasMatch(t) && !_structurel.hasMatch(t);
          final nom = _noms.any(t.contains);
          if (chiffres || nom) fautes.add('$id:${n + 1}: $t');
        }
      }
    }
    expect(fautes, isEmpty, reason: 'Texte de maquette non gardé dans l’espace admin :\n${fautes.join('\n')}');
  });

  late FakeSupabase srv;
  setUpAll(() async {
    await loadAppFonts();
    srv = await FakeSupabase.start();
    await srv.initSupabase();
  });
  tearDownAll(() => srv.close());

  // Deux états vides : « muet » (le serveur ne répond rien : aucun chiffre admis) et « listes vides » (le serveur répond des listes vides :
  // seul un compteur réel de zéro est admis, jamais un chiffre non nul ni un pourcentage, un montant ou une date).
  for (final muet in [true, false]) {
    group('dynamique : administrateur global connecté, ${muet ? 'serveur muet' : 'listes vides'}', () {
    final trouves = <String, List<String>>{};
    final textes = StringBuffer();

    setUp(() {
      GScreen.mockupFrame = false; // comportement réel de l'application (la configuration de test force le cadre de maquette)
      GAnim.enabled = false;
      srv.unknownIsError = muet;
      srv.calls.clear();
    });
    tearDown(() {
      GScreen.mockupFrame = true;
      Backend.ready = true;
    });
    tearDownAll(() {
      final b = StringBuffer();
      for (final e in trouves.entries) {
        b.writeln('${e.key}: ${e.value.join(' | ')}');
      }
      b.writeln('TOTAL ${trouves.length}');
      Directory('build').createSync(recursive: true);
      File('build/h6_admin_propre_${muet ? 'muet' : 'vide'}.txt').writeAsStringSync(b.toString());
      File('build/h6_admin_textes_${muet ? 'muet' : 'vide'}.txt').writeAsStringSync(textes.toString());
      expect(trouves, isEmpty, reason: 'Écrans admin avec fausses données :\n$b');
    });

    final admin = Account(
      name: 'Compte Administrateur',
      phone: '690000999',
      email: 'admin.test@example.test',
      password: '',
      role: 3,
      staff: 'Admin global',
      institution: 'Plateforme',
      serverId: FakeSupabase.userId,
    );

    for (final id in ecransAdmin) {
      testWidgets('admin connecté $id', (tester) async {
        final w = gWidths[id] ?? 390;
        tester.view.physicalSize = w >= 1000 ? const Size(1280, 900) : const Size(390, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(ProviderScope(overrides: [initialAccountProvider.overrideWithValue(admin)], child: BoutikEcoleApp(initialLocation: '/s/$id')));
        await settleReal(tester);
        final hits = <String>{};
        final err = tester.takeException();
        if (err != null) hits.add('exception/débordement : ${'$err'.split('\n').first}');
        textes.writeln('== $id');
        for (final t in tester.widgetList<RichText>(find.byType(RichText))) {
          final txt = t.text.toPlainText().trim();
          if (txt.isEmpty) continue;
          textes.writeln('  $txt');
          final nombres = RegExp(r'\d+').allMatches(txt).map((m) => m.group(0)!);
          final zeroReel = !muet && nombres.isNotEmpty && nombres.every((n) => int.parse(n) == 0) && !txt.contains('%') && !txt.contains(':');
          if (nombres.isNotEmpty && !_structurel.hasMatch(txt) && !zeroReel) hits.add('chiffre « $txt »');
          for (final n in _noms) {
            if (txt.contains(n)) hits.add('maquette « $n »');
          }
          if (txt.contains('9:41')) hits.add('heure 9:41');
        }
        void photo(ImageProvider p) {
          if (p is AssetImage && gIsMockPhoto(p.assetName)) hits.add('photo ${p.assetName.split('/').last}');
        }

        for (final i in tester.widgetList<Image>(find.byType(Image))) {
          photo(i.image);
        }
        for (final d in tester.widgetList<DecoratedBox>(find.byType(DecoratedBox))) {
          final dec = d.decoration;
          if (dec is BoxDecoration && dec.image != null) photo(dec.image!.image);
        }
        if (w < 700) {
          final ecrans = tester.widgetList<GScreen>(find.byType(GScreen)).where((s) => s.w < 700);
          if (ecrans.isNotEmpty && ecrans.any(_barreDuBas) && find.byKey(gMenuKey).evaluate().isEmpty) hits.add('ancien menu du bas');
        }
        if (hits.isNotEmpty) trouves[id] = hits.toList();
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 60));
      });
    }
    });
  }
}

/// Rangée d'icônes de pied d'écran de la maquette (au moins quatre éléments alignés dans les 130 derniers px).
bool _barreDuBas(GScreen s) {
  final rects = [for (final c in s.children) if (c is GPos && !c.tap) c.rect];
  final bas = [for (final r in rects) if (r.width >= 14 && r.width <= 70 && r.height >= 14 && r.height <= 70 && r.top > s.h - 130 && r.bottom <= s.h + 1) r];
  for (final a in bas) {
    final rang = bas.where((r) => (r.center.dy - a.center.dy).abs() < 8).toList();
    if ({for (final r in rang) (r.center.dx / 40).floor()}.length >= 4) return true;
  }
  return false;
}

