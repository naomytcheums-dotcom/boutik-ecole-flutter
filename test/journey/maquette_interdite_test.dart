import 'dart:convert';
import 'dart:io';

import 'package:boutik_ecole/app.dart';
import 'package:boutik_ecole/core/router/app_router.dart';
import 'package:boutik_ecole/figma/gen.dart' show gIsMockPhoto;
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/registry.dart' show gWidths;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/render.dart';

/// GARDE ANTI-MAQUETTE : ce test échoue dès qu'une donnée de maquette (personne, produit, montant, date, appareil, photo…) réapparaît
/// dans un parcours connecté. Il a deux volets :
///  1. statique : aucun texte littéral de `lib/figma/g/*.dart` ne décrit une donnée sans être gardé par `gm(...)`, `gSelf(...)`,
///     `demoContent` ou `show: demoContent` (même classification que `tool/demo_guard.py`, listes dans `tool/maquette_tokens.json`) ;
///  2. dynamique : chaque écran ouvert connecté avec un compte neuf (serveur muet) n'affiche ni nom, ni produit, ni photo de maquette.
/// Pour un nouvel écran : `python tool/demo_guard.py` applique les gardes ; le contenu réel vient de requêtes filtrées par titulaire.
final _tokens = jsonDecode(File('tool/maquette_tokens.json').readAsStringSync()) as Map<String, dynamic>;
final _personas = (_tokens['personas'] as List).cast<String>();
final _entities = (_tokens['entities'] as List).cast<String>();
final _keep = RegExp(_tokens['keep_digits'] as String);
final _self = (_tokens['self'] as List).cast<String>();

/// Réimplémentation de `classify` (tool/demo_guard.py).
bool _estDonnee(String lit, double size) {
  final t = lit.trim();
  if (t.isEmpty || t == '—' || t == '–' || t == '●') return false;
  if (_self.contains(t)) return true;
  if (_tokens['self_inst'].contains(t)) return true;
  for (final p in _personas) {
    if (t.contains(p)) return true;
  }
  for (final e in _entities) {
    if (t.contains(e)) return true;
  }
  if (RegExp(r'\d').hasMatch(t)) {
    if (_keep.hasMatch(t)) return RegExp(r'^\d{1,2}$').hasMatch(t) && size >= 16;
    return true;
  }
  return false;
}

void main() {
  test('statique : aucun texte de maquette non gardé dans lib/figma/g', () {
    final re = RegExp(r"gText\(\s*'((?:[^'\\$]|\\.)*)'\s*,\s*([0-9.]+)");
    final fautes = <String>[];
    final fichiers = Directory('lib/figma/g').listSync().whereType<File>().where((f) => f.path.endsWith('.dart'));
    for (final f in fichiers) {
      final src = f.readAsStringSync();
      // pastilles de choix : ni nom d'exemple ni compteur « (248) » sans garde `if (demoContent)`
      for (final l in src.split(RegExp(r'\r?\n'))) {
        if (!l.contains('Positioned.fill(child: GChoiceGroup(chips:') || l.contains('if (demoContent)')) continue;
        for (final m in RegExp(r"GChip\([^']*'((?:[^'\\]|\\.)*)'").allMatches(l)) {
          final lab = m.group(1)!;
          if (lab.contains(r'$')) continue;
          if ((_estDonnee(lab, 0) && !RegExp(r'\d').hasMatch(lab)) || RegExp(r'\(\d[\d ]*\)').hasMatch(lab)) {
            fautes.add('${f.uri.pathSegments.last} (pastille): $lab');
          }
        }
      }
      for (final m in re.allMatches(src)) {
        if (_estDonnee(m.group(1)!, double.parse(m.group(2)!))) {
          fautes.add('${f.uri.pathSegments.last}: ${m.group(1)}');
        }
      }
    }
    expect(fautes, isEmpty, reason: 'Texte de maquette non gardé (lancer `python tool/demo_guard.py`) :\n${fautes.take(40).join('\n')}');
  });

  group('dynamique : compte neuf connecté', () {
    final trouves = <String, List<String>>{};
    setUpAll(() async {
      await loadAppFonts();
      SharedPreferences.setMockInitialValues({});
      await Supabase.initialize(
        url: 'http://127.0.0.1:9',
        publishableKey: 'sb_publishable_test',
        authOptions: const FlutterAuthClientOptions(localStorage: EmptyLocalStorage(), autoRefreshToken: false),
      );
    });
    setUp(() {
      GAnim.enabled = false;
      Backend.ready = true;
    });
    tearDown(() => Backend.ready = false);
    tearDownAll(() {
      final b = StringBuffer();
      for (final e in trouves.entries) {
        b.writeln('${e.key}: ${e.value.join(' | ')}');
      }
      b.writeln('TOTAL ${trouves.length}');
      File('build/audit_maquette.txt').writeAsStringSync(b.toString());
      expect(trouves, isEmpty, reason: 'Données de maquette affichées en mode connecté :\n$b');
    });

    const neuf = Account(
      name: 'Nouveau Titulaire',
      phone: '690000000',
      email: 'nouveau@example.test',
      password: '',
      verified: false,
      institution: '',
      department: '',
      city: '',
      serverId: '00000000-0000-0000-0000-000000000001',
    );
    // jetons propres aux écrans, à ne jamais voir connecté
    final interdits = {..._personas, ..._entities}.where((e) => e.length >= 5 && !e.startsWith('Mme')).toList();

    for (final s in screensById.values) {
      testWidgets('compte neuf ${s.id}', (tester) async {
        final w = gWidths[s.id] ?? 390;
        tester.view.physicalSize = w >= 1000 ? const Size(1280, 900) : (w == 720 ? const Size(720, 1280) : const Size(390, 900));
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(ProviderScope(overrides: [initialAccountProvider.overrideWithValue(neuf)], child: BoutikEcoleApp(initialLocation: '/s/${s.id}')));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));
        final hits = <String>{};
        for (final t in tester.widgetList<Text>(find.byType(Text))) {
          final txt = t.data ?? t.textSpan?.toPlainText() ?? '';
          if (txt.startsWith('Ex.')) continue; // exemples de saisie (placeholders)
          for (final m in interdits) {
            if (txt.contains(m)) hits.add(m);
          }
        }
        for (final i in tester.widgetList<Image>(find.byType(Image))) {
          final p = i.image;
          if (p is AssetImage && gIsMockPhoto(p.assetName) && !['cbf050b9', '4ca68f79', '768cf16e', '46d80b34'].any(p.assetName.contains)) hits.add('photo ${p.assetName.split('/').last}');
        }
        for (final d in tester.widgetList<DecoratedBox>(find.byType(DecoratedBox))) {
          final dec = d.decoration;
          if (dec is BoxDecoration && dec.image != null) {
            final p = dec.image!.image;
            if (p is AssetImage && gIsMockPhoto(p.assetName) && !['cbf050b9', '4ca68f79', '768cf16e', '46d80b34'].any(p.assetName.contains)) hits.add('photo ${p.assetName.split('/').last}');
          }
        }
        if (hits.isNotEmpty) trouves[s.id] = hits.toList();
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 60)); // minuteries de rafraîchissement (hub d'intégrations : 45 s)
      });
    }
  });
}
