import 'dart:convert';
import 'dart:io';

import 'package:boutik_ecole/app.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/staff_portal.dart' show staffPortalPath;
import 'package:boutik_ecole/figma/registry.dart' show gWidths;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/render.dart';

/// H7 · LOT ORG (volet administrateur) : écrans et routes de l'administrateur global et des équipes internes (Finance, Support, Sécurité, Technique)
/// NON couverts par `h6_admin_propre_test.dart` ni `h6_centre_test.dart` (H6 : 127-138, 145-147, 180, 181, 264-283, 300-306).
/// Connecté (`Backend.ready`, faux serveur Supabase), trois contrôles : serveur muet (jamais un chiffre, une erreur n'est pas un zéro), listes vides
/// (seul un zéro réel est admis) et jetons de maquette (tool/maquette_tokens.json), plus champs de saisie pré-remplis.
const ecransFinance = ['139', '140', '141', '142', '143', '144', '284'];
// `/catalogue` et `/design` (revue de maquette de l'équipe de conception : ids d'écrans et références Figma) ne sont pas des écrans métier : exclus.
final routesAdmin = [staffPortalPath(),
  '/admin/entreprises', '/admin/forfaits', '/admin/sequestre', '/campagnes/validation', '/marche/promotions', '/departement/rattachements',
  '/marche/livraison?plateforme=1', '/comptes-test', '/support/boite', '/moderation/reseau', '/marche/moderation',
  '/integrations/api', '/evenements/gerer', '/offres', '/campagnes',
];
const routesEquipe = ['/support/boite', '/moderation/reseau', '/marche/moderation', '/admin/sequestre', '/integrations/api'];

final _tokens = jsonDecode(File('tool/maquette_tokens.json').readAsStringSync()) as Map<String, dynamic>;
final _noms = <String>{...(_tokens['personas'] as List).cast<String>(), ...(_tokens['entities'] as List).cast<String>(), ...(_tokens['self'] as List).cast<String>()}.where((e) => e.length >= 4).toList();
final _structurel = RegExp(r'^\+237$|^Étape \d|^Version \d|^Ex\. |^h7\.test@example\.test$|^Accueil B2B$');

/// Libellés fixes qui contiennent un chiffre sans être une donnée (périodes, filtres).
String _sansLibelle(String t) => t.replaceAll(RegExp(r'sous 7 jours|B2B|(sur|derniers?) \d+ (jours|j|mois)|\d+ derniers (jours|mois)'), '');

String _fichier(String id) => 'lib/figma/g/g_${id.replaceAll('-', '_').toLowerCase()}.dart';

Account _compte(String nom, String staff) => Account(
      name: nom,
      phone: '690000888',
      email: 'h7.test@example.test',
      password: '',
      role: 3,
      staff: staff,
      institution: 'Plateforme',
      serverId: FakeSupabase.userId,
    );

void main() {
  test('statique : aucun texte à chiffres ou à nom de maquette hors demoContent dans les écrans Finance restants', () {
    final re = RegExp(r"gText\(\s*'((?:[^'\\$]|\\.)*)'\s*,\s*([0-9.]+)");
    final fautes = <String>[];
    for (final id in ecransFinance) {
      final lignes = File(_fichier(id)).readAsLinesSync();
      for (var n = 0; n < lignes.length; n++) {
        final l = lignes[n];
        final garde = l.contains('show: demoContent') || l.contains('if (demoContent)') || l.contains('demoContent ?');
        for (final m in re.allMatches(l)) {
          final t = m.group(1)!.trim();
          if (t.isEmpty || garde) continue;
          if ((RegExp(r'\d').hasMatch(t) && !_structurel.hasMatch(t)) || _noms.any(t.contains)) fautes.add('$id:${n + 1}: $t');
        }
      }
    }
    expect(fautes, isEmpty, reason: 'Texte de maquette non gardé :\n${fautes.join('\n')}');
  });

  late FakeSupabase srv;
  setUpAll(() async {
    await loadAppFonts();
    srv = await FakeSupabase.start();
    await srv.initSupabase();
  });
  tearDownAll(() => srv.close());

  final profils = <String, ({Account compte, List<String> ids, List<String> routes})>{
    'admin': (compte: _compte('Compte Administrateur', 'Admin global'), ids: ecransFinance, routes: routesAdmin),
    'finance': (compte: _compte('Compte Finance', 'Finance'), ids: ecransFinance, routes: routesEquipe),
    'support': (compte: _compte('Compte Support', 'Support'), ids: const ['139', '142', '284'], routes: routesEquipe),
  };
  final filtre = Platform.environment['H7_PROFIL'];

  for (final e in profils.entries) {
    if (filtre != null && filtre.isNotEmpty && filtre != e.key) continue;
    for (final muet in [true, false]) {
      group('dynamique : ${e.key} connecté, ${muet ? 'serveur muet' : 'listes vides'}', () {
        final trouves = <String, List<String>>{};
        final textes = StringBuffer();

        setUp(() {
          GScreen.mockupFrame = false;
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
          for (final x in trouves.entries) {
            b.writeln('${x.key}: ${x.value.join(' | ')}');
          }
          b.writeln('TOTAL ${trouves.length}');
          Directory('build').createSync(recursive: true);
          File('build/h7a_${e.key}_${muet ? 'muet' : 'vide'}.txt').writeAsStringSync(b.toString());
          File('build/h7a_${e.key}_textes_${muet ? 'muet' : 'vide'}.txt').writeAsStringSync(textes.toString());
          expect(trouves, isEmpty, reason: 'Écrans ${e.key} avec fausses données :\n$b');
        });

        // Les écrans de console (toile large) sont aussi ouverts sur téléphone (390 px) : c'est ce que voit un responsable mobile (« @390 »).
        final cibles = [for (final id in e.value.ids) '/s/$id', for (final id in e.value.ids) if ((gWidths[id] ?? gWidths[id.toLowerCase()] ?? 390) >= 700) '/s/$id@390', ...e.value.routes];
        for (final cible in cibles) {
          testWidgets('${e.key} $cible', (tester) async {
            final tel = cible.endsWith('@390');
            final lieu = tel ? cible.substring(0, cible.length - 4) : cible;
            final id = lieu.startsWith('/s/') ? lieu.substring(3) : '';
            final w = tel || id.isEmpty ? 390 : (gWidths[id] ?? gWidths[id.toLowerCase()] ?? 390);
            tester.view.physicalSize = w >= 1000 ? const Size(1280, 900) : const Size(390, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            await tester.pumpWidget(ProviderScope(overrides: [initialAccountProvider.overrideWithValue(e.value.compte)], child: BoutikEcoleApp(initialLocation: lieu)));
            await settleReal(tester);
            final hits = <String>{};
            final err = tester.takeException();
            if (err != null) hits.add('exception/débordement : ${'$err'.split('\n').first}');
            textes.writeln('== $cible');
            for (final t in tester.widgetList<RichText>(find.byType(RichText))) {
              final txt = t.text.toPlainText().trim();
              if (txt.isEmpty) continue;
              textes.writeln('  $txt');
              final nombres = RegExp(r'\d+').allMatches(_sansLibelle(txt)).map((m) => m.group(0)!);
              final zeroReel = !muet && nombres.isNotEmpty && nombres.every((n) => int.parse(n) == 0) && !txt.contains('%') && !RegExp(r'\d:\d').hasMatch(txt);
              if (nombres.isNotEmpty && !_structurel.hasMatch(txt) && !zeroReel) hits.add('chiffre « $txt »');
              for (final n in _noms) {
                if (txt.contains(n)) hits.add('maquette « $n »');
              }
              if (txt.contains('9:41')) hits.add('heure 9:41');
            }
            for (final ed in tester.widgetList<EditableText>(find.byType(EditableText))) {
              final v = ed.controller.text.trim();
              if (v.isEmpty) continue;
              textes.writeln('  [champ] $v');
              if (RegExp(r'\d').hasMatch(v) || _noms.any(v.contains)) hits.add('champ pré-rempli « $v »');
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
            if (hits.isNotEmpty) trouves[cible] = hits.toList();
            await tester.pumpWidget(const SizedBox());
            await tester.pump(const Duration(seconds: 60));
          });
        }
      });
    }
  }
}
