import 'dart:io';

import 'package:boutik_ecole/app.dart';
import 'package:boutik_ecole/core/router/app_router.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/access.dart';
import 'package:boutik_ecole/figma/live/admin_access.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/registry.dart' show gWidths;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show MethodChannel, SystemChannels;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/render.dart';

/// H8 · LOT ACT : « aucune action qui a l'air opérationnelle mais ne fait rien », en mode connecté (Backend.ready, faux serveur Supabase local,
/// mockupFrame = false) pour chaque acteur. Pour chaque écran accessible à l'acteur, l'outil énumère les éléments interactifs réellement montés
/// (zones GPress, GestureDetector, InkWell, boutons, interrupteurs, menus), appuie au centre de chacun (après vérification que le toucher l'atteint)
/// et exige un effet observable : changement de route, appel serveur (RPC, table, écriture), appel plateforme (presse-papiers, partage, lien),
/// changement de contenu (textes, champs, nombre d'éléments : boîte de dialogue, panneau, message, état). Sinon l'élément est « INERTE ».
/// Rapports : `build/h8_act_ACTEUR.csv` (tous les gestes) et `build/h8_act_ACTEUR_inertes.txt`. Les faux positifs expliqués sont dans [_attendus].
///
/// Variables : H8_ACTOR (un acteur), H8_SCREENS (liste d'écrans séparés par des virgules), H8_FULL=1 (tous les écrans pour tous les acteurs).
const _orgTypes = ['entreprise_commerciale', 'association', 'ong', 'cooperative', 'fondation', 'institution', 'structure_partenaire', 'autre_reconnue'];

class Actor {
  Actor(this.key, this.account, {this.rpc = const {}, this.only, this.shared = false});
  final String key;
  final Account? account;
  final Map<String, Object? Function(Map<String, dynamic>)> rpc;

  /// Restreint aux écrans listés (acteurs dont seuls les écrans réservés diffèrent).
  final List<String>? only;

  /// Parcourt aussi les écrans ouverts à tous.
  final bool shared;
}

Account _acc(String name, int role, [String staff = '']) => Account(
      name: name,
      phone: '690000777',
      email: 'h8.test@example.test',
      password: '',
      role: role,
      staff: staff,
      institution: 'Établissement de test',
      department: 'Département de test',
      serverId: FakeSupabase.userId,
    );

Map<String, dynamic> _access(String role, Map<String, List<String>> teams, {bool admin = false}) => {'role': role, 'is_admin': admin, 'teams': teams};

final _allPerms = {
  'finance': ['finance.read', 'finance.payments', 'finance.payouts', 'finance.refunds', 'finance.transfers', 'finance.split'],
  'support': ['support.tickets', 'support.claims', 'support.disputes', 'support.orders', 'support.requests', 'support.refunds'],
  'security': ['security.moderation', 'security.reports', 'security.accounts', 'security.audit'],
  'tech': ['tech.config', 'tech.integrations', 'tech.logs', 'tech.maintenance'],
};

List<Actor> _actors() => [
      Actor('visiteur', null, shared: true),
      Actor('client', _acc('Compte Client', 0), shared: true),
      Actor('etudiant', _acc('Compte Étudiant', 1), shared: true, rpc: {
        'my_seller_capability': (_) => {'can_sell': true, 'can_publish': true, 'role': 'student', 'paused': false, 'conditions': []},
      }),
      Actor('etudiant_non_vendeur', _acc('Compte Étudiant', 1), only: ['57', '58', '59'], rpc: {
        'my_seller_capability': (_) => {'can_sell': false, 'can_publish': false, 'role': 'student', 'conditions': [{'key': 'verified', 'label': 'Étudiant vérifié', 'ok': false}]},
      }),
      for (final t in _orgTypes)
        Actor('org_$t', _acc('Compte Organisation', 2), shared: t == 'entreprise_commerciale', rpc: {
          'company_get': (_) => {'org_type': t, 'company_name': 'Organisation de test', 'status': 'approved', 'owner_id': FakeSupabase.userId},
        }),
      Actor('departement', _acc('Compte Département', 3, 'Resp. département'), shared: true),
      Actor('direction', _acc('Compte Direction', 3, 'Direction')),
      Actor('admin', _acc('Compte Administrateur', 3, 'Admin global'), shared: true, rpc: {
        'my_admin_access': (_) => _access('admin', _allPerms, admin: true),
      }),
      Actor('finance', _acc('Compte Finance', 3, 'Finance'), rpc: {'my_admin_access': (_) => _access('finance', {'finance': _allPerms['finance']!})}),
      Actor('support', _acc('Compte Support', 3, 'Support'), rpc: {'my_admin_access': (_) => _access('support', {'support': _allPerms['support']!})}),
      Actor('securite', _acc('Compte Sécurité', 3, 'Support'), rpc: {'my_admin_access': (_) => _access('support', {'security': _allPerms['security']!})}),
      Actor('technique', _acc('Compte Technique', 3, 'Finance'), rpc: {'my_admin_access': (_) => _access('finance', {'tech': _allPerms['tech']!})}),
    ];

/// Gestes sans effet observable, expliqués : `écran>libellé`, `écran@x,y` (ou préfixés de `acteur>`). Ne jamais y ajouter un geste sans l'avoir examiné.
const _attendus = <String>{
  // onglet courant du menu du bas : on reste sur l'écran
  '03@195,1368', '10@332,1368',
  // pastille déjà sélectionnée
  '04>Tous', '11>E-mail',
};

/// Classes de gestes sans effet observable dans ce banc, expliquées (examinées une à une le 21 novembre 2026) :
/// retour sans historique (l'écran est ouvert directement), pastille ou onglet déjà sélectionné, nouvelle tentative qui retombe sur la même erreur
/// du faux serveur, sélecteur de fichier ou de photo (non simulable). Tout autre geste inerte reste signalé.
final _classesBenignes = <RegExp>[
  RegExp(r'^[\s-]*$'),
  RegExp(r'Réessayer|Retry|ne peuvent pas être chargées|cannot be loaded'),
  RegExp(r'^(Tous|Toutes|Tout|All|Everything|Anciens|Elders|Cette semaine|This week|Produits|Products|Ventes|Sales|Pour toi|For you|FR|EN)'),
  RegExp(r'téléverser|upload|Ajouter (un|une|des)|Add (a|an|CV)|Photos? ou vidéos?|Photos? or videos?|Publication|Image de couverture|Cover image'),
];

bool _permis(Actor a, String id) {
  final f = a.rpc['my_admin_access'];
  return f == null || screenAllowedByAccess(a.account, id, AdminAccess.fromJson(f(const {}) as Map));
}

String _sizeKey(String id) => id.toLowerCase();

class _El {
  _El(this.kind, this.rect, this.label, this.element);
  final String kind;
  final Rect rect;
  final String label;
  final Element element;
  String get sig => '$kind@${rect.center.dx.round()},${rect.center.dy.round()}';
}

void main() {
  late FakeSupabase srv;
  final channelCalls = <String>[];
  final filtreActeur = Platform.environment['H8_ACTOR'] ?? '';
  final filtreEcrans = (Platform.environment['H8_SCREENS'] ?? '').split(',').where((e) => e.isNotEmpty).toList();
  final full = Platform.environment['H8_FULL'] == '1';

  setUpAll(() async {
    await loadAppFonts();
    srv = await FakeSupabase.start();
    await srv.initSupabase();
  });
  tearDownAll(() => srv.close());

  setUp(() {
    GScreen.mockupFrame = false;
    GAnim.enabled = false;
    channelCalls.clear();
    for (final ch in ['plugins.flutter.io/url_launcher', 'dev.fluttercommunity.plus/share', 'plugins.flutter.io/share_plus', 'dev.flutter.pigeon.url_launcher_android.UrlLauncherApi.launchUrl']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(MethodChannel(ch), (c) async {
        channelCalls.add(c.method);
        return null;
      });
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (c) async {
      if (c.method == 'Clipboard.setData' || c.method == 'Share.invoke' || c.method == 'SystemNavigator.pop') channelCalls.add(c.method);
      return null;
    });
  });
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = true;
  });

  /// Éléments interactifs montés, dédoublonnés par position, dont le centre reçoit réellement le toucher.
  List<_El> enumerate(WidgetTester tester, Size view) {
    final found = <_El>[];
    final seen = <String>{};
    final paragraphs = <(Rect, String)>[];
    void collect(Element e, bool inPress) {
      final w = e.widget;
      String? kind;
      var pressNow = inPress;
      if (w is GPress) {
        kind = 'gpress';
        pressNow = true;
      } else if (w is GestureDetector && w.onTap != null && !inPress) {
        kind = 'tap';
      } else if (w is InkResponse && w.onTap != null && !inPress) {
        kind = 'ink';
      } else if (w is ButtonStyleButton && w.onPressed != null && !inPress) {
        kind = 'button';
      } else if (w is Switch && w.onChanged != null) {
        kind = 'switch';
      } else if (w is Checkbox && w.onChanged != null) {
        kind = 'checkbox';
      } else if (w is PopupMenuButton) {
        kind = 'menu';
      } else if (w is GMic) {
        kind = 'mic';
      }
      if (w is RichText) {
        final ro = e.renderObject;
        if (ro is RenderBox && ro.hasSize && ro.attached) {
          final t = w.text.toPlainText().trim();
          if (t.isNotEmpty) paragraphs.add((ro.localToGlobal(Offset.zero) & ro.size, t));
        }
      }
      if (kind != null) {
        final ro = e.renderObject;
        if (ro is RenderBox && ro.hasSize && ro.attached) {
          final rect = ro.localToGlobal(Offset.zero) & ro.size;
          if (!rect.isEmpty && Offset.zero.dx <= rect.center.dx && rect.center.dx < view.width && rect.center.dy >= 0 && rect.center.dy < view.height) {
            final c = rect.center;
            final key = '${(c.dx / 3).round()},${(c.dy / 3).round()}';
            if (seen.add(key)) {
              final hit = HitTestResult();
              tester.binding.hitTestInView(hit, c, tester.view.viewId);
              if (hit.path.any((h) => identical(h.target, ro))) found.add(_El(kind, rect, '', e));
            }
          }
        }
      }
      e.visitChildren((c) => collect(c, pressNow));
    }

    tester.binding.rootElement!.visitChildren((c) => collect(c, false));
    // bandes de toucher ajoutées autour d'une zone (cibles d'accessibilité) : même geste que la zone voisine, comptées une fois
    final press = [for (final e in found) if (e.kind == 'gpress') e.rect];
    found.removeWhere((e) => e.kind != 'gpress' && press.any((p) {
          final i = p.inflate(30).intersect(e.rect);
          return i.width > 0 && i.height > 0 && i.width * i.height >= 0.9 * e.rect.width * e.rect.height && e.rect.width * e.rect.height < 3 * p.width * p.height;
        }));
    // libellé : textes contenus dans la zone, sinon le texte le plus proche
    String labelOf(Rect r) {
      final inside = [for (final p in paragraphs) if (r.inflate(2).overlaps(p.$1) && p.$1.height > 0 && r.inflate(6).contains(p.$1.center)) p.$2];
      if (inside.isNotEmpty) return inside.take(3).join(' / ').replaceAll('\n', ' ');
      (Rect, String)? best;
      var d = 1e9;
      for (final p in paragraphs) {
        final dd = (p.$1.center - r.center).distance;
        if (dd < d) {
          d = dd;
          best = p;
        }
      }
      return best == null || d > 80 ? '(sans libellé)' : '~${best.$2.replaceAll('\n', ' ')}';
    }

    return [for (final e in found) _El(e.kind, e.rect, labelOf(e.rect), e.element)];
  }

  String snapshot(WidgetTester tester) {
    final b = StringBuffer();
    var n = 0;
    void walk(Element e) {
      n++;
      final w = e.widget;
      if (w is RichText) b.write('${w.text.toPlainText()}${w.text.style?.color}${w.text.style?.fontWeight}|');
      if (w is DecoratedBox) b.write('d${w.decoration.hashCode}');
      if (w is Opacity) b.write('o${w.opacity}');
      if (w is EditableText) b.write('[${w.controller.text}${w.focusNode.hasFocus}${w.obscureText}]');
      if (w is Icon) b.write('i${w.icon?.codePoint}');
      if (w is Switch) b.write(w.value ? 'S1' : 'S0');
      if (w is Checkbox) b.write('${w.value}');
      e.visitChildren(walk);
    }

    tester.binding.rootElement!.visitChildren(walk);
    return '$n#${b.toString().hashCode}';
  }

  Size sizeFor(String id) {
    final w = gWidths[id] ?? gWidths[_sizeKey(id)] ?? 390;
    return w >= 1000 ? const Size(1280, 900) : (w == 720 ? const Size(720, 1280) : const Size(390, 1400));
  }

  // Garde-fou toujours exécuté : l'outil couvre bien les sept acteurs (les parcours longs se lancent à la demande, voir ci-dessus).
  testWidgets('l’outil de détection des gestes inertes couvre tous les acteurs', (tester) async {
    expect(_actors().map((a) => a.key), containsAll(['visiteur', 'client', 'etudiant', 'departement', 'direction', 'admin', 'finance', 'support']));
    expect(_actors().length, greaterThanOrEqualTo(12));
  });

  for (final actor in _actors()) {
    // Outil de découverte long (plusieurs dizaines de minutes) : exécuté seulement à la demande (H8_ACTOR, H8_SCREENS ou H8_FULL), jamais dans la suite courante,
    // car il liste des gestes « sans effet observable » encore à trier (faux positifs : puces de filtre, retour sans historique, sélecteurs de fichier…).
    if (filtreActeur.isEmpty && filtreEcrans.isEmpty && !full) continue;
    if (filtreActeur.isNotEmpty && filtreActeur != actor.key) continue;
    final ids = <String>[
      for (final s in screensById.values)
        if ((filtreEcrans.isEmpty || filtreEcrans.contains(s.id)) &&
            (actor.only?.contains(s.id) ?? true) &&
            (canOpen(actor.account, s.id) && _permis(actor, s.id) || actor.only != null) &&
            (full || actor.shared || allowedRoles(s.id) != null || actor.only != null))
          s.id,
    ];
    group('h8 ${actor.key}', () {
      final rows = <String>['acteur;ecran;kind;x;y;libelle;effet'];
      final inertes = <String>[];
      tearDownAll(() {
        Directory('build').createSync(recursive: true);
        File('build/h8_act_${actor.key}.csv').writeAsStringSync('${rows.join('\n')}\n');
        File('build/h8_act_${actor.key}_inertes.txt').writeAsStringSync('${inertes.join('\n')}\nTOTAL ${inertes.length}\n');
        bool attendu(String i) {
          final p = i.split(' | ');
          final ecran = p.first.split('>')[1];
          final pos = p[1].split('@').last;
          final lab = p.first.split('>').skip(2).join('>');
          if (_classesBenignes.any((r) => r.hasMatch(lab.trim()))) return true;
          return _attendus.contains('$ecran@$pos') || _attendus.contains('$ecran>$lab') || _attendus.contains('${actor.key}>$ecran@$pos') || _attendus.contains('${actor.key}>$ecran>$lab');
        }

        final bad = [for (final i in inertes) if (!attendu(i)) i];
        expect(bad, isEmpty, reason: 'Gestes sans effet (${actor.key}) :\n${bad.join('\n')}');
      });

      for (final id in ids) {
        testWidgets('${actor.key} écran $id', (tester) async {
          final size = sizeFor(id);
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          Future<void> mount() async {
            Backend.ready = true;
            await tester.pumpWidget(const SizedBox());
            srv.unknownIsError = false;
            srv.rpc
              ..clear()
              ..addAll(actor.rpc);
            srv.tables.clear();
            srv.tables['profiles'] = [
              if (actor.account != null)
                {'id': FakeSupabase.userId, 'name': actor.account!.name, 'role': ['client', 'student', 'company', 'admin'][actor.account!.role.clamp(0, 3)], 'email': 'h8.test@example.test', 'suspended': false, 'created_at': '2026-01-01T00:00:00Z'},
            ];
            await tester.pumpWidget(ProviderScope(
              overrides: [if (actor.account != null) initialAccountProvider.overrideWithValue(actor.account)],
              child: BoutikEcoleApp(initialLocation: '/s/$id'),
            ));
            await settleReal(tester, rounds: 4, ms: 25);
            tester.takeException();
          }

          await mount();
          final router = GoRouter.of(tester.element(find.byType(Overlay).first));
          final start = router.state.uri.toString();
          final base = enumerate(tester, size);
          final sigs = [for (final e in base) (e.sig, e.label, e.kind, e.rect)];
          for (var i = 0; i < sigs.length; i++) {
            final (sig, label, kind, rect) = sigs[i];
            final els = enumerate(tester, size);
            _El? target;
            for (final e in els) {
              if (e.sig == sig) target = e;
            }
            if (target == null) {
              await mount();
              for (final e in enumerate(tester, size)) {
                if (e.sig == sig) target = e;
              }
            }
            String effet;
            if (target == null) {
              effet = 'INTROUVABLE';
            } else {
              final r = GoRouter.of(tester.element(find.byType(Overlay).first));
              final path = r.state.uri.toString();
              final before = snapshot(tester);
              final nCalls = srv.calls.length;
              final nChan = channelCalls.length;
              await tester.tapAt(target.rect.center, kind: PointerDeviceKind.touch);
              await tester.pump(const Duration(milliseconds: 300));
              await settleReal(tester, rounds: 2, ms: 30);
              await tester.pump(const Duration(milliseconds: 300));
              final exc = tester.takeException();
              if (r.state.uri.toString() != path) {
                effet = 'écran ${r.state.uri.path}';
              } else if (srv.calls.length > nCalls) {
                effet = 'serveur ${srv.calls.skip(nCalls).map((c) => '${c.kind}:${c.name}').toSet().take(3).join(',')}';
              } else if (channelCalls.length > nChan) {
                effet = 'plateforme ${channelCalls.last}';
              } else if (snapshot(tester) != before) {
                effet = 'contenu modifié';
              } else if (exc != null && !'$exc'.contains('overflowed')) {
                effet = 'EXCEPTION ${'$exc'.split('\n').first}';
              } else {
                effet = 'INERTE';
              }
              if (effet != 'INERTE' && !effet.startsWith('EXC')) {
                await mount();
              }
            }
            rows.add('${actor.key};$id;$kind;${rect.center.dx.round()};${rect.center.dy.round()};${label.replaceAll(';', ',')};$effet');
            if (effet == 'INERTE' || effet == 'INTROUVABLE' || effet.startsWith('EXC')) inertes.add('${actor.key}>$id>$label | $kind @${rect.center.dx.round()},${rect.center.dy.round()} | $effet');
          }
          expect(start, isNotEmpty);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 60));
        });
      }
    });
  }
}
