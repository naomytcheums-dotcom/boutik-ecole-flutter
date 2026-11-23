import 'dart:io';

import 'package:boutik_ecole/app.dart';
import 'package:boutik_ecole/core/router/app_router.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/store.dart';
import 'package:boutik_ecole/figma/registry.dart' show gWidths;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/render.dart';

/// H6 · L1 : parcourt TOUS les écrans du registre en 390 px (hors connexion avec le compte administrateur, puis connecté) et échoue si
///  1. une barre du bas de maquette (rangée d'icônes en pied d'écran) n'a pas été remplacée par le menu reconstruit à cinq onglets
///     (repère `gMenuKey`, voir `GScreen._phone`) ;
///  2. l'icône d'IA générique de la maquette (étincelle blanche sur pastille sombre : `d177b28382093d.svg`, `6fd6a3c35cbbc1.svg`,
///     `sparkle*.svg`, `Icons.auto_awesome*`) apparaît à la place de l'orbe orange de Kéla ;
///  3. un texte présente une analyse ou un conseil « IA » (la seule IA de l'application est Kéla).
const _orbe = '2b51b5d6469cca917952ac344a2ddf9cc1440830';
const _svgIa = ['d177b28382093d.svg', '6fd6a3c35cbbc1.svg', 'sparkle.svg', 'sparkle-filled.svg', 'sparkles.svg'];
final _texteIa = RegExp(r'Conseil de l.IA|Analyse IA|analyse IA|Assistant IA|Recommandé par l.IA|Compat\. IA|Propositions classées par IA');

/// Rangée d'icônes de pied d'écran : au moins quatre pictogrammes (sans texte) de 14 à 70 px alignés dans les 110 derniers px de la
/// maquette, dans une barre large d'au moins 300 px.
bool _barreDuBas(GScreen s) {
  final cs = [for (final c in s.children) if (c is GPos) c];
  final barres = [for (final c in cs) if (c.rect.width >= 300 && c.rect.height >= 40 && c.rect.height <= 90 && c.rect.top > s.h - 130 && c.rect.bottom <= s.h + 1) c.rect];
  final bas = [for (final c in cs) if (c.label == null && c.rect.width >= 14 && c.rect.width <= 70 && c.rect.height >= 14 && c.rect.height <= 70 && c.rect.top > s.h - 110 && c.rect.bottom <= s.h + 1) c.rect];
  for (final b in barres) {
    final dedans = [for (final r in bas) if (b.contains(r.center)) r];
    final colonnes = <int>{for (final r in dedans) (r.center.dx / 40).floor()};
    if (colonnes.length >= 4) return true;
  }
  return false;
}

void main() {
  final trouve = <String, List<String>>{};
  final menus = <String>[];

  setUpAll(() async {
    await loadAppFonts();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      publishableKey: 'sb_publishable_test',
      authOptions: const FlutterAuthClientOptions(localStorage: EmptyLocalStorage(), autoRefreshToken: false),
    );
  });
  tearDown(() {
    Backend.ready = false;
    GScreen.mockupFrame = true;
  });
  tearDownAll(() {
    final b = StringBuffer();
    for (final e in trouve.entries) {
      b.writeln('${e.key}: ${e.value.join(' | ')}');
    }
    b.writeln('TOTAL ${trouve.length} ; menus reconstruits : ${menus.length}');
    Directory('build').createSync(recursive: true);
    File('build/h6_menu_kela.txt').writeAsStringSync(b.toString());
  });

  List<String> inspecter(WidgetTester tester, String mode, String id) {
    final hits = <String>[];
    final ecrans = tester.widgetList<GScreen>(find.byType(GScreen)).where((s) => s.w < 700).toList();
    final menu = find.byKey(gMenuKey);
    if (menu.evaluate().isNotEmpty) {
      menus.add(id);
      final orbe = find.descendant(of: menu, matching: find.byWidgetPredicate((w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName.contains(_orbe)));
      if (orbe.evaluate().length != 1) hits.add('menu reconstruit sans l\'orbe de Kéla ($mode)');
      final cibles = find.descendant(of: menu, matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == 'GPress'));
      if (cibles.evaluate().length < 5) hits.add('menu reconstruit : ${cibles.evaluate().length} cibles au lieu d\'au moins 5 ($mode)');
    } else if (ecrans.any(_barreDuBas)) {
      hits.add('ancien menu du bas ($mode)');
    }
    for (final v in tester.widgetList<SvgPicture>(find.byType(SvgPicture))) {
      final l = v.bytesLoader;
      if (l is SvgAssetLoader && _svgIa.any(l.assetName.endsWith)) hits.add('icône IA générique ${l.assetName.split('/').last} ($mode)');
    }
    for (final i in tester.widgetList<Icon>(find.byType(Icon))) {
      final d = i.icon;
      if (d == Icons.auto_awesome || d == Icons.auto_awesome_outlined || d == Icons.auto_awesome_rounded || d == Icons.psychology) hits.add('Icons.auto_awesome ($mode)');
    }
    for (final t in tester.widgetList<RichText>(find.byType(RichText))) {
      final txt = t.text.toPlainText();
      if (_texteIa.hasMatch(txt)) hits.add('texte IA « ${_texteIa.firstMatch(txt)!.group(0)} » ($mode)');
    }
    final u = hits.toSet().toList();
    if (u.isNotEmpty) trouve.putIfAbsent(id, () => []).addAll(u);
    return u;
  }

  for (final connecte in [false, true]) {
    final mode = connecte ? 'connecté' : 'démo';
    group('390 px · $mode', () {
      setUp(() {
        GAnim.enabled = false;
        GScreen.mockupFrame = false;
        Backend.ready = connecte;
      });
      for (final s in screensById.values) {
        final natif = gWidths[s.id] ?? 390;
        for (final taille in [const Size(390, 900), if (natif >= 700) Size(natif, 900)]) {
          testWidgets('${s.id} ${taille.width.round()} px', (tester) async {
            tester.view.physicalSize = taille;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            await tester.pumpWidget(ProviderScope(
              overrides: [initialAccountProvider.overrideWithValue(seedAccounts.last), nowProvider.overrideWithValue(DateTime(2026, 10, 27, 10, 42))],
              child: BoutikEcoleApp(initialLocation: '/s/${s.id}'),
            ));
            await tester.pump(const Duration(milliseconds: 100));
            await tester.pump(const Duration(milliseconds: 100));
            final hits = inspecter(tester, mode, s.id);
            await tester.pumpWidget(const SizedBox());
            await tester.pump(const Duration(seconds: 60));
            expect(hits, isEmpty, reason: 'écran ${s.id} : ${hits.join(' | ')}');
          });
        }
      }
    });
  }

  test('le menu reconstruit est bien présent sur les écrans principaux', () {
    expect(menus, containsAll(['03', '10', '52', '231', '244']));
  });

  test('statique : aucune icône IA générique de maquette dans lib/', () {
    final fautes = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final src = f.readAsStringSync();
      if (src.contains('d177b28382093d') || src.contains('6fd6a3c35cbbc1')) fautes.add(f.path);
    }
    expect(fautes, isEmpty, reason: 'Icône IA générique (étincelle) encore référencée : remplacer par kelaOrb');
  });
}
