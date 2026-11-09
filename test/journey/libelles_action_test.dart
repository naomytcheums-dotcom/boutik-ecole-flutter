import 'dart:convert';
import 'dart:io';

import 'package:boutik_ecole/app.dart';
import 'package:boutik_ecole/core/router/app_router.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/store.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChannels;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/render.dart';

/// Appuie sur chaque libellé d'action visible (« Voir tout », « Valider », « Exporter »…) de chaque écran et observe
/// un effet : changement d'écran, boîte de dialogue, message, panneau, champ activé ou contenu modifié.
/// Un libellé sans aucun effet est « inerte ». Rapport : build/libelles_action.csv.
void main() {
  final sizes = <String, (double, double)>{
    for (final e in jsonDecode(File('docs/screens.json').readAsStringSync()) as List)
      e['id'] as String: ((e['w'] as num).toDouble(), (e['h'] as num).toDouble()),
  };
  final cta = RegExp(r"^(Voir tout|Voir plus|Tout voir|Continuer|Valider|Envoyer|Suivant|Commander|Ajouter.*|Réserver|Contacter|Postuler|Payer|Payer .*|S’inscrire|Se connecter|Enregistrer.*|Télécharger.*|Partager|Exporter|Filtrer|Annuler|Confirmer|Publier|Modifier|Supprimer|Acheter|Retirer|Démarrer|Participer|Soutenir.*|Voter|Candidater|Suivre|S’abonner|Rejoindre|Commencer|Passer|Ignorer|Fermer|Signaler|Noter|Évaluer|Inviter|Copier.*|Générer.*|Accepter|Refuser|Approuver|Rejeter|Qualifier|Attribuer|Actualiser|Personnaliser la vue|Créer.*|Nouvelle .*|Nouveau .*|Nouveau)$");
  final line = RegExp(r"gP\(\s*([-\d.]+),\s*([-\d.]+),\s*([\d.]+),\s*([\d.]+),\s*gText\('([^']+)'");
  // Libellés qui ne sont pas des boutons dans les maquettes : titres de page, badges « Nouveau », puces descriptives,
  // en-têtes de colonne, intitulé de case à cocher, onglet courant.
  const pasBoutons = {
    '279>Ajouter des fichiers', '281>Valider', '286>Valider', '250b>Nouvelle publication', '12>Créer un compte',
    '16>Nouveau mot de passe', '22c>Nouveau', '173>Partager', '174>Payer en sécurité par Mobile Money', '176>Payer en sécurité',
    '41>Enregistrer cette adresse dans mon carnet', '50>Nouveau', '58>Nouveau produit', '59>Nouveau service', '60>Modifier',
    '72>Ajouter à mon profil', '84>Nouvelle campagne', '249>Créer', '250>Nouvelle publication', '219>Nouveau duel',
    '195>Ajouter une preuve', '198>Nouveau', 'P4>Nouvelle publication', '43>Payer par messagerie (WhatsApp, Dikalo)',
  };
  final rows = <String>['ecran;libelle;x;y;effet'];
  var actifs = 0, inertes = 0;

  setUpAll(loadAppFonts);
  setUp(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (_) async => null));
  tearDownAll(() {
    File('build/libelles_action.csv')
      ..createSync(recursive: true)
      ..writeAsStringSync('${rows.join('\n')}\n');
    // ignore: avoid_print
    print('LIBELLÉS D’ACTION : $actifs actifs, $inertes inertes, total ${actifs + inertes}');
  });

  String snapshot(WidgetTester tester) => [
        for (final e in find.byType(Text).evaluate()) (e.widget as Text).data ?? '',
        for (final e in find.byType(EditableText).evaluate()) '${(e.widget as EditableText).focusNode.hasFocus}',
      ].join('|');

  for (final s in screensById.values) {
    // 271, 280, P3, P5 : remplacés par le hub d'intégrations (test/integrations), plus d'éléments à coordonnées fixes.
    if (const {'271', '280', 'P3', 'P5'}.contains(s.id)) continue;
    final file = File('lib/figma/g/g_${s.id.replaceAll('-', '_')}.dart');
    if (!file.existsSync()) continue;
    final labels = <(double, double, String)>[
      for (final m in line.allMatches(file.readAsStringSync()))
        if (cta.hasMatch(m.group(5)!.replaceAll(r'\n', ' ').trim()))
          (double.parse(m.group(1)!) + double.parse(m.group(3)!) / 2, double.parse(m.group(2)!) + double.parse(m.group(4)!) / 2, m.group(5)!.replaceAll(r'\n', ' ')),
    ];
    if (labels.isEmpty) continue;
    testWidgets('libellés ${s.id} (${labels.length})', (tester) async {
      GAnim.enabled = false;
      final (w, h) = sizes[s.id] ?? (390.0, 900.0);
      tester.view.physicalSize = Size(w, h.ceilToDouble());
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          initialAccountProvider.overrideWithValue(seedAccounts.last),
          nowProvider.overrideWithValue(DateTime(2026, 10, 27, 10, 42)),
        ],
        child: BoutikEcoleApp(initialLocation: '/s/${s.id}'),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      final router = GoRouter.of(tester.element(find.byType(Overlay).first));
      for (final (x, y, label) in labels) {
        // écran rechargé à neuf avant chaque appui
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpWidget(ProviderScope(
          overrides: [
            initialAccountProvider.overrideWithValue(seedAccounts.last),
            nowProvider.overrideWithValue(DateTime(2026, 10, 27, 10, 42)),
          ],
          child: BoutikEcoleApp(initialLocation: '/s/${s.id}'),
        ));
        await tester.pump(const Duration(milliseconds: 400));
        final r = GoRouter.of(tester.element(find.byType(Overlay).first));
        final before = snapshot(tester);
        final path = r.state.uri.toString();
        await tester.tapAt(Offset(x, y + (h.ceilToDouble() - h) / 2), kind: PointerDeviceKind.touch);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        String effet;
        if (r.state.uri.toString() != path) {
          effet = 'écran ${r.state.uri.path}';
        } else if (find.byType(Dialog).evaluate().isNotEmpty || find.byType(AlertDialog).evaluate().isNotEmpty) {
          effet = 'dialogue';
        } else if (find.byType(SnackBar).evaluate().isNotEmpty) {
          effet = 'message';
        } else if (find.byType(BottomSheet).evaluate().isNotEmpty) {
          effet = 'panneau';
        } else if (snapshot(tester) != before) {
          effet = 'contenu modifié';
        } else {
          effet = 'INERTE';
        }
        effet == 'INERTE' ? inertes++ : actifs++;
        if (effet == 'INERTE') expect(pasBoutons, contains('${s.id}>$label'), reason: '${s.id} : « $label » ne fait rien');
        rows.add('${s.id};$label;${x.toStringAsFixed(0)};${y.toStringAsFixed(0)};$effet');
      }
      expect(router, isNotNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
