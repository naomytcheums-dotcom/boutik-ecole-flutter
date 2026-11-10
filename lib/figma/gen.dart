import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'gsound.dart';
import 'nav.dart';
import 'live/backend.dart' show Backend;
import 'live/geo_stub.dart' if (dart.library.js_interop) 'live/geo_web.dart' as geo;
import 'live/lfav.dart' show GHeartLive;

export 'gsound.dart';

/// Visuels de marque ou décoratifs conservés connecté (logo, formes 3D, avion, logos de paiement, fonds d'accueil) ; toute autre
/// image de `assets/figma/img/` est une photo de maquette (personnes, produits, lieux) : connecté, elle est remplacée par un aplat neutre.
const _decorImg = {
  '080dae98', '2b51b5d6', '2e8548b8', '73da21b1', '75d62324', 'aa1a076f', 'b896412c', 'c64e9a62', 'c7764301', 'dcc189ec',
  '6baf8125', 'a30d4e56', 'e48f8827', 'neutre',
};
/// Photo du compte connecté : elle remplace la photo de maquette de « Mariam » partout où l'écran dessine l'avatar du titulaire.
String gSelfAvatarUrl = '';
const _selfMockPhoto = 'assets/figma/img/d902a4aa';
String _selfPhoto(String a) => Backend.ready && gSelfAvatarUrl.isNotEmpty && a.startsWith(_selfMockPhoto) ? gSelfAvatarUrl : a;
bool gIsMockPhoto(String a) =>
    Backend.ready && a.startsWith('assets/figma/img/') && !_decorImg.any((k) => a.startsWith('assets/figma/img/$k'));

/// Primitives utilisées par le code généré depuis Figma (tool/figma_export/convert.py).
/// Ne pas éditer à la main les fichiers lib/figma/g/*.dart : ils sont régénérés.
const _jakarta = 'PlusJakartaSans';
const _inter = 'Inter';

class GScreen extends StatelessWidget {
  const GScreen({super.key, required this.w, required this.h, required List<Widget> children, this.radius = 0, this.bg, this.color}) : _source = children;
  final double w, h, radius;
  final Gradient? bg;
  final Color? color;
  final List<Widget> _source;

  /// Accessibilité des écrans de format mobile (qualification Android / WCAG 2.2 AA) : chaque zone tactile reçoit un nœud TalkBack
  /// « bouton » dont le libellé est le texte qu'elle recouvre ou qui la jouxte, et une zone de toucher d'au moins 48 × 48 dp
  /// (anneau invisible autour de la zone dessinée, jamais au-dessus d'une autre zone tactile située plus bas dans la pile).
  /// L'apparence ne change pas. Désactivable pour comparer avant / après.
  static bool a11y = true;
  static const minTarget = 48.0;
  static final _enhanced = Expando<List<Widget>>();

  /// Éléments de l'écran, avec l'accessibilité ajoutée pour les écrans de format mobile.
  List<Widget> get children => _enhanced[this] ??= (a11y ? _withA11y(_source, w, h, rings: w < 700) : _source);

  static String _nearestLabel(Rect r, List<GPos> texts) {
    GPos? best;
    var bestScore = double.infinity;
    for (final t in texts) {
      final tr = t.rect;
      final inside = r.contains(tr.center);
      final near = r.inflate(10).overlaps(tr);
      if (!inside && !near) continue;
      final score = (tr.center - r.center).distance + (inside ? 0 : 40);
      if (score < bestScore) {
        bestScore = score;
        best = t;
      }
    }
    return (best?.label ?? '').trim();
  }

  /// Texte le plus proche dans un rayon plus large (carte, vignette, icône sans texte propre) : même ligne d'abord, puis au-dessus / en dessous.
  static String _wideLabel(Rect r, List<GPos> texts) {
    GPos? best;
    var bestScore = 170.0;
    for (final t in texts) {
      final tr = t.rect;
      final sameRow = (tr.center.dy - r.center.dy).abs() < math.max(24.0, r.height / 2 + 8);
      final dx = tr.center.dx < r.left ? r.left - tr.center.dx : (tr.center.dx > r.right ? tr.center.dx - r.right : 0.0);
      final dy = tr.center.dy < r.top ? r.top - tr.center.dy : (tr.center.dy > r.bottom ? tr.center.dy - r.bottom : 0.0);
      final score = sameRow ? dx : dx + dy * 1.4 + 30;
      if (score < bestScore) {
        bestScore = score;
        best = t;
      }
    }
    return (best?.label ?? '').trim();
  }

  /// Rôle d'une zone d'après sa place dans l'écran (en-tête, barre du bas) quand aucun texte ne la décrit.
  static String _roleLabel(Rect r, double w, double h, List<Rect> bottomTaps) {
    if (r.top < 120 && r.left < 90) return 'Retour';
    if (r.top < 120 && r.right > w - 90) return r.width < 60 ? 'Options de l’écran' : 'Action de l’en-tête';
    if (r.top > h - 120) {
      final i = bottomTaps.indexWhere((q) => q == r);
      return 'Onglet de navigation ${i + 1} sur ${bottomTaps.length}';
    }
    return '';
  }

  static List<Widget> _withA11y(List<Widget> src, double w, double h, {bool rings = true}) {
    final texts = <GPos>[
      for (final c in src)
        if (c is GPos && !c.tap && c.kind == null && RegExp(r'[A-Za-zÀ-ÿ0-9]{2}').hasMatch(c.label ?? '')) c
    ];
    final taps = [for (final c in src) if (c is GPos && c.tap) c.rect];
    final bottomTaps = [for (final r in taps) if (r.top > h - 120) r]..sort((a, b) => a.left.compareTo(b.left));
    // Libellés précis : texte de la zone, texte voisin, rôle selon la place, texte le plus proche ; jamais un « Bouton » générique.
    final labels = <String>[];
    for (final c in src) {
      if (c is! GPos || !c.tap) continue;
      final r = c.rect;
      var l = (c.label ?? '').trim();
      if (l.isEmpty) l = _nearestLabel(r, texts);
      if (l.isEmpty) l = _roleLabel(r, w, h, bottomTaps);
      if (l.isEmpty) {
        final near = _wideLabel(r, texts);
        l = near.isEmpty ? 'Zone interactive de l’écran' : 'Ouvrir : $near';
      }
      labels.add(l);
    }
    // Libellés identiques sur un même écran : numérotés pour que TalkBack les distingue.
    final totals = <String, int>{};
    for (final l in labels) {
      totals[l] = (totals[l] ?? 0) + 1;
    }
    final seen = <String, int>{};
    for (var i = 0; i < labels.length; i++) {
      final l = labels[i];
      if ((totals[l] ?? 0) > 1 && !l.startsWith('Onglet de navigation')) {
        seen[l] = (seen[l] ?? 0) + 1;
        labels[i] = '$l, ${seen[l]} sur ${totals[l]}';
      }
    }
    final out = <Widget>[];
    var k = 0;
    for (final c in src) {
      if (c is GPos && c.kind != null && !c.tap) {
        // Interrupteur, case ou champ : libellé TalkBack = texte voisin (ou intitulé du champ).
        var l = (c.label ?? '').trim();
        if (l.isEmpty) l = _nearestLabel(c.rect.inflate(30), texts);
        if (l.isEmpty) l = _wideLabel(c.rect, texts);
        if (l.isEmpty) l = c.kind == 'field' ? 'Champ de saisie' : c.kind == 'toggle' ? 'Interrupteur' : 'Case à cocher';
        out.add(GPos(x: c.left!, y: c.top!, gw: c.gw, gh: c.gh, label: c.label, kind: c.kind, child: c.kind == 'field' ? Semantics(label: l, child: c.child) : MergeSemantics(child: Semantics(label: l, child: c.child))));
        continue;
      }
      if (c is! GPos || !c.tap) {
        out.add(c);
        continue;
      }
      final r = c.rect;
      final label = labels[k++];
      var e = r;
      if (rings && c.onTap != null) {
        final needW = math.max(0.0, minTarget - r.width), needH = math.max(0.0, minTarget - r.height);
        if (needW > 0 || needH > 0) {
          bool nested(Rect q) => (q.left <= r.left + 0.5 && q.top <= r.top + 0.5 && q.right >= r.right - 0.5 && q.bottom >= r.bottom - 0.5) || (r.left <= q.left + 0.5 && r.top <= q.top + 0.5 && r.right >= q.right - 0.5 && r.bottom >= q.bottom - 0.5);
          // Une zone distincte n'est jamais recouverte en son centre ; entre rangées collées, un chevauchement de bord (5, puis 10, puis 16 dp) est toléré
          // pour atteindre 48 dp. Une zone imbriquée (icône dans son cercle) fait partie du même bouton.
          bool free(Rect q0, double tol) => !taps.any((q) => q != r && !nested(q) && (q.overlaps(q0.deflate(tol)) || (tol > 5 && q0.contains(q.center))));
          final hs = needW > 0 ? [(needW / 2, needW / 2), (0.0, needW), (needW, 0.0), (needW / 2, 0.0), (0.0, needW / 2), (0.0, 0.0)] : [(0.0, 0.0)];
          final vs = needH > 0 ? [(needH / 2, needH / 2), (0.0, needH), (needH, 0.0), (needH / 2, 0.0), (0.0, needH / 2), (0.0, 0.0)] : [(0.0, 0.0)];
          for (final tol in const [5.0, 10.0, 16.0]) {
            var bestGain = 0.0;
            for (final hh in hs) {
              for (final vv in vs) {
                final q0 = Rect.fromLTRB(r.left - hh.$1, r.top - vv.$1, r.right + hh.$2, r.bottom + vv.$2);
                final gain = (hh.$1 + hh.$2) + (vv.$1 + vv.$2);
                if (gain > bestGain && free(q0, tol)) {
                  bestGain = gain;
                  e = q0;
                }
              }
            }
            if (e.width >= minTarget - 0.5 && e.height >= minTarget - 0.5) break;
          }
        }
      }
      // Le nœud TalkBack « bouton » couvre toute la zone de toucher (au moins 48 × 48 dp quand la place le permet) ; la zone dessinée reste au centre, intacte.
      final inner = e == r
          ? c.child
          : SizedBox(
              width: e.width,
              height: e.height,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned.fill(child: _ring(r, e, c.onTap!)),
                Positioned(left: r.left - e.left, top: r.top - e.top, width: r.width, height: r.height, child: c.child),
              ]),
            );
      out.add(GPos(
        x: e.left,
        y: e.top,
        gw: e.width,
        gh: e.height,
        tap: true,
        onTap: c.onTap,
        label: c.label,
        child: Semantics(container: true, button: true, enabled: true, label: label, onTap: c.onTap, child: ExcludeSemantics(child: inner)),
      ));
    }
    return out;
  }

  /// Anneau invisible autour de la zone dessinée : prolonge la zone de toucher sans toucher à l'apparence.
  static Widget _ring(Rect r, Rect e, VoidCallback onTap) {
    Widget strip(double l, double t, double w, double h) => w <= 0 || h <= 0 ? const SizedBox.shrink() : Positioned(left: l, top: t, width: w, height: h, child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: const SizedBox.expand()));
    final lw = r.left - e.left, rw = e.right - r.right, th = r.top - e.top, bh = e.bottom - r.bottom;
    return Stack(clipBehavior: Clip.none, children: [
      strip(0, 0, lw, e.height),
      strip(e.width - rw, 0, rw, e.height),
      strip(lw, 0, r.width, th),
      strip(lw, e.height - bh, r.width, bh),
    ]);
  }

  /// Rendu « cadre de maquette » (taille Figma exacte) : réservé aux rendus de référence et aux tests de coordonnées.
  static bool mockupFrame = false;

  /// Largeur maximale de la colonne des écrans de format mobile sur grand écran.
  static const maxColumn = 480.0;

  /// Hauteur de la fausse barre d'état iOS dessinée dans les maquettes (9:41, réseau, batterie).
  static const statusBand = 44.0;

  @override
  Widget build(BuildContext context) {
    var id = '';
    try {
      id = GoRouterState.of(context).uri.path;
    } catch (_) {}
    final off = id.startsWith('/s/') && kSansVerre.contains(id.substring(3));
    return _GlassPolicy(off: off, child: _buildScreen(context));
  }

  Widget _buildScreen(BuildContext context) {
    final canvas = SizedBox(
      width: w,
      height: h,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: bg, color: color),
          child: Stack(clipBehavior: Clip.hardEdge, children: children),
        ),
      ),
    );
    return Scaffold(
      backgroundColor: const Color(0xFFE9E6EE),
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(builder: (context, c) {
        // Téléphone : plein écran (largeur entière, hauteur entière), menus du bas fixes, contenu défilant jusqu'au bout.
        // Console web (toile de 1272 px) sur tablette ou téléphone : barre d'application, menu latéral en tiroir, contenu à une échelle lisible.
        if (!mockupFrame && w >= 1000 && c.maxWidth < 1000) return _web(context, c);
        // Borne ou tablette (toile de 700 à 999 px) plus large que l'écran : largeur adaptée, défilement vertical.
        if (!mockupFrame && w >= 700 && w < 1000 && c.maxWidth < w) {
          final s = c.maxWidth / w;
          return SingleChildScrollView(child: SizedBox(width: c.maxWidth, height: h * s, child: FittedBox(fit: BoxFit.fill, child: canvas)));
        }
        if (!mockupFrame && w < 700) {
          // Écran de format mobile sur tablette ou ordinateur : même composition plein écran que sur téléphone, mais dans une
          // colonne de 480 px au plus, centrée sur le fond de l'écran lui-même (ni cadre de téléphone, ni fausse barre d'état).
          final cw = math.min(c.maxWidth, maxColumn);
          final column = _phone(context, BoxConstraints.tightFor(width: cw, height: c.maxHeight));
          if (c.maxWidth <= cw + 0.5) return column;
          return DecoratedBox(
            decoration: BoxDecoration(gradient: bg, color: color ?? (bg == null ? const Color(0xFFFFFFFF) : null)),
            child: Center(child: SizedBox(width: cw, height: c.maxHeight, child: column)),
          );
        }
        if (h > 860 && w < 700) {
          // Maquette entière visible sans défilement tant qu'elle reste lisible :
          // ≥ 70 % de sa taille sur ordinateur, ≥ 85 % de la largeur disponible sur téléphone.
          final ws = math.min(1.0, c.maxWidth / w);
          final fit = math.min(c.maxWidth / w, c.maxHeight / h);
          if (h * ws > c.maxHeight + 1 && fit >= (c.maxWidth >= 600 ? 0.7 : 0.85 * ws)) {
            return Center(child: SizedBox(width: w * fit, height: h * fit, child: FittedBox(fit: BoxFit.fill, child: canvas)));
          }
          // Sinon : largeur adaptée, centrée si elle tient, défilement si l'écran est très long (jamais de contenu réduit ou inaccessible).
          final s = ws;
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: Center(child: SizedBox(width: w * s, height: h * s, child: FittedBox(fit: BoxFit.fill, child: canvas))),
            ),
          );
        }
        if (math.min(c.maxWidth / w, c.maxHeight / h) < 0.6) {
          // Maquette d'ordinateur sur petit écran : affichée en entier, agrandissable au pincement (jusqu'à 100 %) et déplaçable.
          return InteractiveViewer(
            maxScale: math.max(1.0, math.max(w / c.maxWidth, h / c.maxHeight)),
            child: Center(child: FittedBox(fit: BoxFit.contain, child: canvas)),
          );
        }
        return Center(child: FittedBox(fit: BoxFit.contain, child: canvas));
      }),
    );
  }

  /// Largeur du menu latéral des consoles web dans la maquette.
  static const webSidebar = 208.0;

  /// Console web sur écran étroit : le menu latéral devient un tiroir (entrées reconstruites depuis les zones cliquables de la
  /// maquette), la barre du haut devient une barre d'application, et le contenu garde une échelle lisible (au moins 60 %),
  /// avec défilement horizontal si nécessaire.
  Widget _web(BuildContext context, BoxConstraints c) {
    final side = <GPos>[];
    final main = <Widget>[];
    for (final ch in children) {
      if (ch is GPos) {
        final r = ch.rect;
        if (r.right <= webSidebar + 2 && r.bottom <= 58) continue; // logo et titre de la barre du haut
        // zones cliquables du menu : leur largeur déborde sur le contenu dans la maquette, on se fie à leur centre
        if (ch.tap && ch.onTap != null && r.center.dx < webSidebar && r.top >= 56) {
          side.add(ch);
          continue;
        }
        if (r.right <= webSidebar + 2 && r.top >= 56) continue;
      }
      main.add(ch);
    }
    final labels = [for (final ch in children) if (ch is GPos && ch.label != null && ch.rect.right <= webSidebar + 2 && ch.rect.top >= 56) ch];
    final entries = <({String label, VoidCallback onTap, double y})>[];
    for (final t in side) {
      final box = t.rect.inflate(4);
      final hit = labels.where((l) => box.contains(l.rect.center)).toList();
      if (hit.isEmpty) continue;
      if (entries.any((e) => e.label == hit.first.label)) continue;
      entries.add((label: hit.first.label!, onTap: t.onTap!, y: t.rect.top));
    }
    entries.sort((a, b) => a.y.compareTo(b.y));
    // Console dont la maquette ne rend pas ses entrées de menu cliquables : accès aux rubriques du rôle et à l'accueil.
    if (entries.isEmpty) {
      entries.add((label: 'Mes rubriques', onTap: () => gEspace(context), y: 0));
      entries.add((label: 'Accueil', onTap: () => gTab(context, '03'), y: 1));
    }
    final mainW = w - webSidebar;
    final s = math.max(c.maxWidth / mainW, 0.6);
    final canvasW = mainW * s;
    return Scaffold(
      backgroundColor: color ?? const Color(0xFFF7F6F4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Boutik-École', style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700, fontSize: 17, color: Color(0xFF18181B))),
        iconTheme: const IconThemeData(color: Color(0xFF111015)),
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: SafeArea(
          child: ListView(children: [
            for (final e in entries)
              ListTile(
                title: Text(e.label, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF18181B))),
                onTap: () {
                  Navigator.of(context).pop();
                  e.onTap();
                },
              ),
          ]),
        ),
      ),
      body: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: canvasW,
            height: h * s,
            child: FittedBox(
              fit: BoxFit.fill,
              child: SizedBox(
                width: mainW,
                height: h,
                child: ClipRect(
                  child: Stack(clipBehavior: Clip.hardEdge, children: [
                    Positioned(left: -webSidebar, top: 0, width: w, height: h, child: Stack(clipBehavior: Clip.none, children: main)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Plein écran sur téléphone. La maquette est mise à l'échelle de la largeur réelle de l'écran (référence Figma : `w`),
  /// sans cadre ni marges ; la fausse barre d'état et la fausse barre d'accueil iOS sont retirées (le téléphone a les siennes) ;
  /// le menu du bas et les barres d'actions pleine largeur restent fixes en bas, et le contenu reçoit en bas un espace de
  /// leur hauteur pour que la dernière section soit entièrement visible au-dessus.
  Widget _phone(BuildContext context, BoxConstraints c) {
    final pad = MediaQuery.paddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    var s = c.maxWidth / w;
    final rects = [for (final ch in children) ch is GPos ? ch.rect : null];
    final taps = [for (final ch in children) ch is GPos && ch.tap];

    final hidden = <int>{};
    for (var i = 0; i < children.length; i++) {
      final r = rects[i];
      if (r == null || taps[i]) continue;
      final status = r.bottom <= statusBand + 2 && r.height < 30 && r.width < 120;
      final homeBar = r.height <= 6 && r.width >= 100 && r.width <= 150 && (r.center.dx - w / 2).abs() < 12 && r.top >= h - 80;
      if (status || homeBar) hidden.add(i);
    }

    final band = <int>{};
    Rect? pill;
    var hasBar = false;
    for (var i = 0; i < children.length; i++) {
      final r = rects[i];
      if (r == null || taps[i] || r.top <= h * 0.6) continue;
      final nav = r.width >= 330 && r.width <= 360 && r.height >= 54 && r.height <= 74 && r.left >= 8 && r.left <= 36 && r.top > h * 0.8 && (r.height >= 58 || r.top > h * 0.85);
      final bar = r.left <= 1 && r.width >= w - 2 && r.bottom >= h - 2 && r.height >= 40 && r.height <= 160;
      if (!nav && !bar) continue;
      if (nav) pill ??= r;
      if (bar) hasBar = true;
      final zone = nav ? Rect.fromLTRB(r.left - 4, r.top - 24, r.right + 4, r.bottom + 8) : Rect.fromLTRB(-1, r.top - 2, w + 1, h + 1);
      for (var j = i; j < children.length; j++) {
        final q = rects[j];
        if (q != null && !hidden.contains(j) && zone.contains(q.center)) band.add(j);
      }
    }
    var bandTop = h, bandBottom = 0.0;
    for (final j in band) {
      bandTop = math.min(bandTop, rects[j]!.top);
      bandBottom = math.max(bandBottom, math.min(h, rects[j]!.bottom));
    }

    // Écran d'une page (hauteur de maquette ≤ 900) : il tient en entier dans la fenêtre, sans défilement. L'échelle est réduite au besoin
    // (barres du navigateur, petit téléphone) et la maquette reste centrée ; le contenu s'arrête au menu, qui reste fixe en bas.
    final single = h <= 900;
    final bandExtent = band.isEmpty ? 0.0 : (bandBottom - bandTop + 8);
    final contentTo = single && band.isNotEmpty ? bandTop : h;
    if (single) {
      final unit = (contentTo - statusBand) + bandExtent;
      final avail = c.maxHeight - pad.top - pad.bottom - keyboard;
      if (unit > 0 && avail > 0) s = math.min(s, avail / unit);
    }

    Widget layer(List<Widget> kids, double from, double to, {Clip clip = Clip.hardEdge}) => SizedBox(
          width: w * s,
          height: (to - from) * s,
          child: FittedBox(
            fit: BoxFit.fill,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: w,
              height: to - from,
              child: Stack(clipBehavior: clip, children: [
                Positioned(left: 0, top: -from, width: w, height: h, child: Stack(clipBehavior: Clip.none, children: kids)),
              ]),
            ),
          ),
        );

    // Menu du bas : cinq onglets reconstruits (Kéla, messages, accueil, réseau social, profil). La pastille sombre, cerclée
    // d'argent, suit l'onglet de l'écran affiché ; la loupe est devenue Kéla et le micro le réseau social.
    final swapped = <int>{};
    final extra = <Widget>[];
    if (pill != null) {
      const slotsX = [57.5, 124.0, 195.0, 266.0, 332.0];
      final bySlot = List.generate(5, (_) => <int>[]);
      for (final j in band) {
        final q = rects[j];
        if (q == null || q == pill || q.width > 70 || q.height > 70 || q.center.dy < pill.top - 4 || q.center.dy > pill.bottom + 4) continue;
        for (var k = 0; k < 5; k++) {
          if ((q.center.dx - slotsX[k]).abs() < 30) bySlot[k].add(j);
        }
      }
      if (bySlot.every((l) => l.isNotEmpty)) {
        for (final l in bySlot) {
          swapped.addAll(l);
        }
        var path = '';
        try {
          path = GoRouter.of(context).routeInformationProvider.value.uri.path;
        } catch (_) {}
        final id = path.startsWith('/s/') ? path.substring(3) : '';
        const kela = {'230', '231', 'A1', 'A2'};
        const reseau = {'244', '244b', '245', '246', '247', '248', '249', '250', '251', '252', '253', '254', '255'};
        final active = kela.contains(id) ? 0 : (id == '52' ? 1 : (id == '03' ? 2 : (reseau.contains(id) ? 3 : (id == '10' ? 4 : -1))));
        final cy = pill.center.dy;
        const targets = ['231', '52', '03', '244', '10'];
        Widget glyph(int k, Color c) => switch (k) {
              0 => Image.asset('assets/figma/img/2b51b5d6469cca917952ac344a2ddf9cc1440830.png', width: 30, height: 30, fit: BoxFit.contain),
              1 => Icon(Icons.chat_bubble_outline, size: 23, color: c),
              2 => Icon(Icons.home_rounded, size: 25, color: c),
              3 => Icon(Icons.groups_outlined, size: 25, color: c),
              _ => Icon(Icons.person_outline, size: 25, color: c),
            };
        for (var k = 0; k < 5; k++) {
          final on = k == active;
          extra.add(gP(
            slotsX[k] - 25,
            cy - 25,
            50,
            50,
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              alignment: Alignment.center,
              decoration: on
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(colors: [Color(0xF22A2D36), Color(0xF20E0F14)]),
                      border: Border.all(color: const Color(0xB3E3E6EE), width: 1.6),
                      boxShadow: const [BoxShadow(color: Color(0x33FFFFFF), blurRadius: 6, spreadRadius: -1), BoxShadow(color: Color(0x29122640), offset: Offset(0, 4), blurRadius: 10)],
                    )
                  : const BoxDecoration(shape: BoxShape.circle),
              child: glyph(k, on ? Colors.white : const Color(0xFF111015)),
            ),
            tap: () => gTab(context, targets[k]),
          ));
        }
      }
    }
    final content = [for (var i = 0; i < children.length; i++) if (!band.contains(i) && !hidden.contains(i)) children[i]];
    final fixed = [for (var i = 0; i < children.length; i++) if (band.contains(i) && !swapped.contains(i)) children[i], ...extra];
    final bandH = band.isEmpty ? 0.0 : (bandBottom - bandTop + 8) * s;
    // Barre d'actions pleine largeur (Continuer, Passer…) : les boutons reposent directement sur le fond de l'écran. Le contenu qui
    // défile derrière est masqué par le même fond, aligné sur le dégradé de l'écran entier (aucun aplat visible).
    Decoration? backing;
    double backingH = 0;
    // Aucun aplat derrière les boutons (Continuer, Passer…) : ils reposent directement sur le fond de la page.
    if (false && hasBar && band.isNotEmpty && !single) {
      backingH = (bandBottom - bandTop) * s + pad.bottom + 8;
      final g = bg;
      if (g != null && g.colors.length >= 2) {
        final viewH = c.maxHeight;
        final top = viewH - backingH;
        backing = BoxDecoration(gradient: LinearGradient(begin: Alignment(0, -2 * top / backingH - 1), end: Alignment(0, 2 * (viewH - top) / backingH - 1), colors: g.colors, stops: g.stops));
      } else {
        backing = BoxDecoration(color: color ?? const Color(0xFFFFFFFF));
      }
    }
    return DecoratedBox(
      decoration: BoxDecoration(gradient: bg, color: color ?? (bg == null ? const Color(0xFFFFFFFF) : null)),
      child: _PhoneBody(
        padding: EdgeInsets.only(top: pad.top, bottom: pad.bottom + bandH + keyboard),
        content: layer(content, statusBand, contentTo, clip: single ? Clip.none : Clip.hardEdge),
        fixed: band.isEmpty ? null : layer(fixed, bandTop, bandBottom),
        bottom: pad.bottom,
        backing: backing,
        backingHeight: backingH,
      ),
    );
  }
}

/// Corps d'un écran de téléphone : contenu défilant plein écran et menu du bas fixe. Un glissement vertical démarré sur le
/// menu fait défiler le contenu (le menu ne « mange » pas le geste), les appuis sur ses boutons restent des appuis.
class _PhoneBody extends StatefulWidget {
  const _PhoneBody({required this.padding, required this.content, required this.fixed, required this.bottom, this.backing, this.backingHeight = 0});
  final Decoration? backing;
  final double backingHeight;
  final EdgeInsets padding;
  final Widget content;
  final Widget? fixed;
  final double bottom;

  @override
  State<_PhoneBody> createState() => _PhoneBodyState();
}

class _PhoneBodyState extends State<_PhoneBody> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _drag(DragUpdateDetails d) {
    if (!_controller.hasClients) return;
    final p = _controller.position;
    _controller.jumpTo((p.pixels - d.delta.dy).clamp(p.minScrollExtent, p.maxScrollExtent));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(child: SingleChildScrollView(controller: _controller, padding: widget.padding, child: Align(alignment: Alignment.topCenter, child: widget.content))),
      if (widget.backing != null) Positioned(left: 0, right: 0, bottom: 0, height: widget.backingHeight, child: IgnorePointer(child: DecoratedBox(decoration: widget.backing!))),
      if (widget.fixed != null)
        Positioned(left: 0, right: 0, bottom: widget.bottom, child: Center(child: GestureDetector(onVerticalDragUpdate: _drag, child: widget.fixed))),
    ]);
  }
}

/// Positionne un élément (avec rotation, opacité, animation d'entrée, effet ambiant et retour tactile).
Widget gP(double x, double y, double w, double h, Widget child,
    {double rot = 0, double op = 1, VoidCallback? tap, String? fx, String sound = 'click', bool show = true}) {
  if (!show) return const Positioned(left: 0, top: 0, width: 0, height: 0, child: SizedBox.shrink());
  final kind = child is GToggle ? 'toggle' : child is GField ? 'field' : child is GCheck ? 'check' : child is GChoiceGroup ? 'chips' : null;
  if (child is GToggle && GScreen.a11y && child.padX == 0 && child.padY == 0 && (w < GScreen.minTarget || h < GScreen.minTarget)) {
    final px = math.max(0.0, (GScreen.minTarget - w) / 2), py = math.max(0.0, (GScreen.minTarget - h) / 2);
    return gP(x - px, y - py, w + 2 * px, h + 2 * py,
        GToggle(on: child.on, onColor: child.onColor, offColor: child.offColor, knob: child.knob, knobColor: child.knobColor, onChanged: child.onChanged, padX: px, padY: py),
        rot: rot, op: op, tap: tap, fx: fx, sound: sound);
  }
  if ((child is GHeart || child is GHeartLive) && GScreen.a11y && (w < GScreen.minTarget || h < GScreen.minTarget)) {
    final px = math.max(0.0, (GScreen.minTarget - w) / 2), py = math.max(0.0, (GScreen.minTarget - h) / 2);
    final pad = EdgeInsets.symmetric(horizontal: px, vertical: py);
    return gP(x - px, y - py, w + 2 * px, h + 2 * py, child is GHeart ? GHeart(pad: pad) : GHeartLive(title: (child as GHeartLive).title, pad: pad), rot: rot, op: op, tap: tap, fx: fx, sound: sound);
  }
  if (child is GCheck && GScreen.a11y && child.padX == 0 && child.padY == 0 && (w < GScreen.minTarget || h < GScreen.minTarget)) {
    final px = math.max(0.0, (GScreen.minTarget - w) / 2), py = math.max(0.0, (GScreen.minTarget - h) / 2);
    return gP(x - px, y - py, w + 2 * px, h + 2 * py,
        GCheck(on: child.on, onColor: child.onColor, offColor: child.offColor, radius: child.radius, border: child.border, padX: px, padY: py),
        rot: rot, op: op, tap: tap, fx: fx, sound: sound);
  }
  Widget c = SizedBox(width: w, height: h, child: child);
  if (fx != null && GAnim.enabled) c = GFx(kind: fx, seed: x * 7 + y, child: c);
  if (rot != 0) c = Transform.rotate(angle: rot, alignment: Alignment.topLeft, child: c);
  if (op < 1) c = Opacity(opacity: op, child: c);
  if (tap != null) c = GPress(onTap: tap, sound: sound, child: c);
  if (GAnim.enabled && w * h < 140000) c = GEnter(delay: Duration(milliseconds: (y * 0.5).clamp(0, 520).round()), child: c);
  return GPos(x: x, y: y, gw: w, gh: h, tap: tap != null, onTap: tap, label: child is GTextBox ? child.label : (child is GField && child.hint.isNotEmpty ? child.hint : null), kind: kind, child: c);
}

Widget gTap(double x, double y, double w, double h, VoidCallback tap) =>
    GPos(x: x, y: y, gw: w, gh: h, tap: true, onTap: tap, child: GPress(onTap: tap, sound: 'whoosh', flash: true, child: SizedBox(width: w, height: h)));

/// Élément positionné de la maquette qui connaît son rectangle (pour l'adaptation plein écran des téléphones).
class GPos extends Positioned {
  const GPos({super.key, required double x, required double y, required this.gw, required this.gh, this.tap = false, this.onTap, this.label, this.kind, required super.child})
      : super(left: x, top: y);
  final double gw, gh;
  final bool tap;

  /// Composant interactif sans zone tactile générique (interrupteur, champ, case, pastilles) : libellé TalkBack ajouté par l'écran.
  final String? kind;

  /// Action de la zone cliquable et libellé du texte, pour reconstruire les menus latéraux (consoles web).
  final VoidCallback? onTap;
  final String? label;
  Rect get rect => Rect.fromLTWH(left!, top!, gw, gh);
}

BorderRadius _br(List<double>? r) => r == null
    ? BorderRadius.zero
    : BorderRadius.only(
        topLeft: Radius.circular(r[0]),
        topRight: Radius.circular(r[1]),
        bottomRight: Radius.circular(r[2]),
        bottomLeft: Radius.circular(r[3]),
      );

/// Rectangle / ellipse / carte, avec dégradé, image, ombres, flous.
/// Un fond « verre » (flou d'arrière-plan) est conservé par défaut (menu du bas, boutons, cartes validés) ; il est retiré uniquement
/// sur les écrans de [kSansVerre], où le texte et les icônes reposent directement sur le fond de la page.
Widget gBox({
  Color? color,
  Gradient? gradient,
  List<double>? radii,
  Color? border,
  double bw = 1,
  List<BoxShadow>? shadows,
  bool oval = false,
  String? image,
  BoxFit fit = BoxFit.cover,
  double layerBlur = 0,
  double backBlur = 0,
}) {
  if (backBlur > 0 && image == null) {
    return _GGlassBox(make: () => _gBoxBuild(color: color, gradient: gradient, radii: radii, border: border, bw: bw, shadows: shadows, oval: oval, image: image, fit: fit, layerBlur: layerBlur, backBlur: backBlur));
  }
  return _gBoxBuild(color: color, gradient: gradient, radii: radii, border: border, bw: bw, shadows: shadows, oval: oval, image: image, fit: fit, layerBlur: layerBlur, backBlur: backBlur);
}

/// Écrans (maquette) sans fond verre : pages ouvertes depuis le profil étudiant et les espaces réseau, communauté, talents,
/// ateliers, alertes, départements, accueils et intégrations. Le menu du bas (pastille 330–360 × 54–74) garde toujours son verre.
const kSansVerre = <String>{
  '01', '02', '10', '13', '18b', '18c', '19', '72', '73', '74', '77', '100', '101', '103', '104', '105', '106', '107', '148-1', '148-2', '149', '150-1',
  '151', '152', '153', '155', '156', '157', '158', '159', '160', '161', '162', '163', '164', '165', '166', '167', '175', '176', '177', '178', '179',
  '203', '204', '205', '214', '215', '216', '217', '218', '219', '220', '221', '222', '223', '224', '225', '226', '227', '228', '229', '236', '240',
  '241', '242', '243', '244', '244b', '245', '246', '247', '248', '249', '250', '250b', '251', '252', '253', '253b', '254', '271', '272', '273', '274',
  '280', 'P1', 'P2', 'P3', 'P4', 'P5', 'V1', 'L1',
};

/// Politique « verre » de l'écran affiché, fournie par [GScreen].
class _GlassPolicy extends InheritedWidget {
  const _GlassPolicy({required this.off, required super.child});
  final bool off;
  @override
  bool updateShouldNotify(_GlassPolicy old) => off != old.off;
}

class _GGlassBox extends StatelessWidget {
  const _GGlassBox({required this.make});
  final Widget Function() make;
  @override
  Widget build(BuildContext context) {
    final off = context.dependOnInheritedWidgetOfExactType<_GlassPolicy>()?.off ?? false;
    if (!off) return make();
    return LayoutBuilder(builder: (context, c) {
      final menu = c.maxWidth >= 330 && c.maxWidth <= 360 && c.maxHeight >= 54 && c.maxHeight <= 74;
      return menu ? make() : const SizedBox.expand();
    });
  }
}

Widget _gBoxBuild({
  Color? color,
  Gradient? gradient,
  List<double>? radii,
  Color? border,
  double bw = 1,
  List<BoxShadow>? shadows,
  bool oval = false,
  String? image,
  BoxFit fit = BoxFit.cover,
  double layerBlur = 0,
  double backBlur = 0,
}) {
  if (image != null) image = _selfPhoto(image);
  if (image != null && gIsMockPhoto(image)) image = 'placeholder';
  final deco = BoxDecoration(
    color: color ?? (image == 'placeholder' ? const Color(0xFFEDE9F6) : null),
    gradient: gradient,
    shape: oval ? BoxShape.circle : BoxShape.rectangle,
    borderRadius: oval ? null : _br(radii),
    border: border == null ? null : Border.all(color: border, width: bw),
    boxShadow: shadows,
    image: image == null || image == 'placeholder' ? null : DecorationImage(image: image.startsWith('http') ? NetworkImage(image) as ImageProvider : AssetImage(image), fit: fit, filterQuality: FilterQuality.high, onError: (_, _) {}),
  );
  Widget w = DecoratedBox(decoration: deco, child: const SizedBox.expand());
  if (backBlur > 0) {
    w = Stack(fit: StackFit.expand, children: [
      ClipPath(
        clipper: _ShapeClipper(oval, radii),
        child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: backBlur / 2, sigmaY: backBlur / 2), child: const SizedBox.expand()),
      ),
      w,
    ]);
  }
  if (layerBlur > 0) w = ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: layerBlur / 2, sigmaY: layerBlur / 2), child: w);
  return w;
}

class _ShapeClipper extends CustomClipper<Path> {
  _ShapeClipper(this.oval, this.radii);
  final bool oval;
  final List<double>? radii;
  @override
  Path getClip(Size s) {
    final r = Offset.zero & s;
    return oval ? (Path()..addOval(r)) : (Path()..addRRect(_br(radii).toRRect(r)));
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}

/// Contraste (WCAG 2.2 AA, 4,5:1) des petits textes : même teinte que la maquette, un cran plus foncée quand la taille est petite
/// (gris secondaire 57545F -> 4A4854 ; rouge d'état E5484D -> B42318). Les grands textes et les couleurs de marque ne bougent pas.
Color _legible(Color c, double size) {
  if (size > 14) return c;
  if (c.toARGB32() == 0xFF57545F) return const Color(0xFF4A4854);
  if (c.toARGB32() == 0xFFE5484D) return const Color(0xFFB42318);
  return c;
}

TextStyle _ts(double size, Color color, int weight, bool inter, double? lh, double? ls, [TextDecoration? deco]) => TextStyle(
      inherit: false,
      textBaseline: TextBaseline.alphabetic,
      fontFamily: inter ? _inter : _jakarta,
      fontSize: size,
      fontWeight: FontWeight.values[((weight ~/ 100).clamp(1, 9)) - 1],
      color: _legible(color, size),
      height: lh == null ? null : lh / size,
      letterSpacing: ls,
      decoration: deco ?? TextDecoration.none,
      leadingDistribution: TextLeadingDistribution.even,
    );

/// Texte d'un seul style. [wrap] = boîte de largeur fixe (retour à la ligne) ; sinon une ligne.
Widget gText(String s, double size, Color color,
    {int weight = 400, bool inter = false, double? lh, double? ls, TextAlign align = TextAlign.left, bool wrap = false, TextDecoration? deco, int? maxLines}) {
  final t = Text(s,
      style: _ts(size, color, weight, inter, lh, ls, deco),
      textAlign: align,
      softWrap: wrap,
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.visible,
      textHeightBehavior: const TextHeightBehavior(leadingDistribution: TextLeadingDistribution.even));
  if (wrap) return GTextBox(label: s, child: t);
  return GTextBox(label: s, child: OverflowBox(alignment: Alignment.topLeft, minWidth: 0, maxWidth: double.infinity, child: t));
}

/// Texte de la maquette : garde son libellé pour reconstruire les menus latéraux des consoles web en tiroir.
class GTextBox extends IgnorePointer {
  const GTextBox({super.key, required this.label, required super.child});
  final String label;
}

/// Texte à plusieurs styles : chaque run = (texte, taille, poids, couleur).
Widget gRich(List<(String, double, int, Color)> runs,
    {bool inter = false, double? lh, double? ls, TextAlign align = TextAlign.left, bool wrap = false}) {
  final t = Text.rich(
    TextSpan(children: [for (final r in runs) TextSpan(text: r.$1, style: _ts(r.$2, r.$4, r.$3, inter, lh, ls))]),
    textAlign: align,
    softWrap: wrap,
    overflow: TextOverflow.visible,
    textHeightBehavior: const TextHeightBehavior(leadingDistribution: TextLeadingDistribution.even),
  );
  if (wrap) return IgnorePointer(child: t);
  return IgnorePointer(child: OverflowBox(alignment: Alignment.topLeft, minWidth: 0, maxWidth: double.infinity, child: t));
}

Widget gImg(String raw, {BoxFit fit = BoxFit.fill}) => _gImg(_selfPhoto(raw), fit);

Widget _gImg(String asset, BoxFit fit) => gIsMockPhoto(asset) ? const IgnorePointer(child: ColoredBox(color: Color(0xFFEDE9F6))) : IgnorePointer(
      child: asset.endsWith('.svg')
          ? SvgPicture.asset(asset, fit: fit)
          : (asset.startsWith('http')
              ? Image.network(asset, fit: fit, filterQuality: FilterQuality.high, gaplessPlayback: true, errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFEDE9F6)))
              : Image.asset(asset, fit: fit, filterQuality: FilterQuality.high, gaplessPlayback: true)),
    );

/// Cadre qui rogne son contenu (photos qui débordent). Les enfants sont en coordonnées locales.
Widget gClip(double x, double y, double w, double h, List<double>? radii, List<Widget> children) => Positioned(
      left: x,
      top: y,
      child: SizedBox(
        width: w,
        height: h,
        child: ClipRRect(borderRadius: _br(radii), child: Stack(clipBehavior: Clip.hardEdge, children: children)),
      ),
    );

// ---------------------------------------------------------------- couche dynamique

/// Message bref pour les actions simulées (démonstration).
void gToast(BuildContext context, String message) {
  final m = ScaffoldMessenger.maybeOf(context);
  GSound.play('success');
  final w = math.min(320.0, MediaQuery.sizeOf(context).width - 32);
  m?.hideCurrentSnackBar();
  m?.showSnackBar(SnackBar(
    content: Text(message, textAlign: TextAlign.center, style: const TextStyle(fontFamily: _jakarta, fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white)),
    duration: const Duration(milliseconds: 1800),
    behavior: SnackBarBehavior.floating,
    backgroundColor: const Color(0xFF111015),
    // Au-dessus de la barre d'actions du bas : le message ne doit jamais recouvrir (et bloquer) un bouton.
    margin: EdgeInsets.fromLTRB((MediaQuery.sizeOf(context).width - w) / 2, 0, (MediaQuery.sizeOf(context).width - w) / 2, 112),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    elevation: 6,
  ));
}

/// Fenêtre de dialogue contenue : largeur limitée, voile léger (jamais plein écran noir).
Future<T?> gDialog<T>({required BuildContext context, required WidgetBuilder builder}) => showDialog<T>(
      context: context,
      barrierColor: const Color(0x40111015),
      builder: (ctx) => Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 380), child: builder(ctx))),
    );

/// Fenêtre d'information (titre, message, un bouton) : pour les erreurs importantes qui ne doivent pas se réduire à une ligne de texte.
Future<void> gAlert(BuildContext context, String title, String message, {String button = 'Compris'}) {
  const st = TextStyle(inherit: false, fontFamily: 'PlusJakartaSans', fontSize: 14, height: 1.45, color: Color(0xFF4A4854), textBaseline: TextBaseline.alphabetic);
  return gDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(title, style: st.copyWith(fontSize: 17, fontWeight: FontWeight.w700, color: const Color(0xFF111015))),
      content: Text(message, style: st),
      actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(button, style: st.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF111015))))],
    ),
  );
}

/// Interrupteur animé (cliquable).
class GToggle extends StatefulWidget {
  const GToggle({super.key, required this.on, required this.onColor, required this.offColor, required this.knob, this.knobColor = Colors.white, this.onChanged, this.padX = 0, this.padY = 0});
  final bool on;
  /// Marge de toucher invisible autour de l'interrupteur (zone de 48 dp minimum) : l'interrupteur dessiné ne bouge pas.
  final double padX, padY;
  final Color onColor, offColor, knobColor;
  final double knob;
  final ValueChanged<bool>? onChanged;
  @override
  State<GToggle> createState() => _GToggleState();
}

class _GToggleState extends State<GToggle> {
  late bool on = widget.on;
  @override
  void didUpdateWidget(GToggle old) {
    super.didUpdateWidget(old);
    if (old.on != widget.on) on = widget.on;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final bh = c.maxHeight - 2 * widget.padY;
        final pad = (bh - widget.knob) / 2;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            GSound.play('pop');
            setState(() => on = !on);
            widget.onChanged?.call(on);
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: widget.padX, vertical: widget.padY),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(color: on ? widget.onColor : widget.offColor, borderRadius: BorderRadius.circular(bh / 2)),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 180),
                alignment: on ? Alignment.centerRight : Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.all(pad),
                  child: Container(width: widget.knob, height: widget.knob, decoration: BoxDecoration(color: widget.knobColor, shape: BoxShape.circle)),
                ),
              ),
            ),
          ),
        );
      });
}

/// Champ de saisie posé exactement sur le rectangle de la maquette.
class GField extends StatefulWidget {
  const GField({
    super.key,
    required this.hint,
    required this.size,
    required this.hintColor,
    this.initial = '',
    this.textColor = const Color(0xFF111015),
    this.weight = 400,
    this.padL = 16,
    this.inter = false,
    this.obscure = false,
    this.multiline = false,
    this.onChanged,
    this.onSubmitted,
    this.numeric = false,
    this.maxLength,
    this.padT = 0,
    this.dateMask = false,
    this.autoLocate = false,
  });
  final double padT;
  /// Date « JJ/MM/AAAA » : les barres « / » sont ajoutées automatiquement pendant la frappe.
  final bool dateMask;
  /// Ville détectée automatiquement (position du navigateur, avec autorisation) si le champ est vide ; reste modifiable.
  final bool autoLocate;
  final bool numeric;
  final int? maxLength;
  final ValueChanged<String>? onChanged, onSubmitted;
  final String hint, initial;
  final double size, padL;
  final Color hintColor, textColor;
  final int weight;
  final bool inter, obscure, multiline;
  @override
  State<GField> createState() => _GFieldState();
}

class _GFieldState extends State<GField> {
  late final TextEditingController c = TextEditingController(text: widget.initial);

  /// Champ de mot de passe : masqué par défaut, l'œil de la maquette (à droite) l'affiche ou le masque.
  late bool hide = widget.obscure;
  final FocusNode f = FocusNode();
  @override
  void initState() {
    super.initState();
    if (widget.autoLocate && Backend.ready && widget.initial.trim().isEmpty) {
      geo.detectCity().then((v) {
        if (!mounted || v == null || c.text.trim().isNotEmpty) return;
        c.text = v;
        widget.onChanged?.call(v);
      });
    }
  }

  @override
  void dispose() {
    c.dispose();
    f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = TextStyle(
      inherit: false,
      textBaseline: TextBaseline.alphabetic,
      fontFamily: widget.inter ? _inter : _jakarta,
      fontSize: widget.size,
      fontWeight: FontWeight.values[((widget.weight ~/ 100).clamp(1, 9)) - 1],
      color: widget.textColor,
    );
    final field = GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true, // le TextField porte déjà l'action et le libellé : pas de nœud tactile vide en plus
      onTap: f.requestFocus,
      child: Padding(
        padding: EdgeInsets.only(left: widget.padL, right: widget.obscure ? 56 : 14, top: widget.multiline ? widget.padT : 0),
        // Le champ occupe toute la hauteur du cadre (≥ 48 dp) : la zone tactile annoncée à TalkBack est celle du cadre entier.
        child: Align(
          alignment: Alignment.center,
          child: TextField(
            controller: c,
            focusNode: f,
            style: st,
            obscureText: hide,
            keyboardType: widget.numeric || widget.dateMask ? TextInputType.number : null,
            inputFormatters: [
              if (widget.dateMask) const _DateSlashFormatter(),
              if (widget.numeric) FilteringTextInputFormatter.digitsOnly,
              if (widget.maxLength != null) LengthLimitingTextInputFormatter(widget.maxLength),
            ],
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            expands: !widget.obscure,
            minLines: widget.obscure ? 1 : null,
            maxLines: widget.obscure ? 1 : null,
            textAlignVertical: widget.multiline ? TextAlignVertical.top : TextAlignVertical.center,
            cursorColor: const Color(0xFF6A4DFF),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              filled: false,
              hintText: widget.hint,
              hintStyle: st.copyWith(color: widget.hintColor),
              // Champ masqué : une seule ligne obligatoire ; le remplissage vertical donne une zone tactile de 48 dp.
              contentPadding: widget.obscure ? const EdgeInsets.symmetric(vertical: 16) : EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
    if (!widget.obscure) return field;
    return Stack(children: [
      Positioned.fill(child: field),
      Positioned(
        right: 0,
        top: 0,
        bottom: 0,
        width: 56,
        child: Semantics(
          button: true,
          label: hide ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => hide = !hide),
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(padding: const EdgeInsets.only(right: 14), child: hide ? const SizedBox(width: 26, height: 26) : CustomPaint(size: const Size(26, 26), painter: _EyeSlash())),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// Barre oblique sur l'œil de la maquette : le mot de passe est affiché.
class _EyeSlash extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF111015)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width * .18, size.height * .84), Offset(size.width * .82, size.height * .16), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Une pastille d'un groupe à choix unique.
class GChip {
  const GChip(this.x, this.y, this.w, this.h, this.label, this.size, this.weight);
  final double x, y, w, h, size;
  final String label;
  final int weight;
}

/// Groupe de pastilles / onglets : un seul choix actif à la fois.
class GChoiceGroup extends StatefulWidget {
  const GChoiceGroup({
    super.key,
    required this.chips,
    required this.selected,
    required this.selFill,
    required this.unselFill,
    required this.selText,
    required this.unselText,
    required this.radius,
    this.border,
    this.inter = false,
    this.onChanged,
  });
  final ValueChanged<int>? onChanged;
  final List<GChip> chips;
  final int selected;
  final Color selFill, unselFill, selText, unselText;
  final double radius;
  final Color? border;
  final bool inter;
  @override
  State<GChoiceGroup> createState() => _GChoiceGroupState();
}

class _GChoiceGroupState extends State<GChoiceGroup> {
  late int sel = widget.selected;

  List<Widget> _chips(double dy) => [
        for (var i = 0; i < widget.chips.length; i++)
          Positioned(
            left: widget.chips[i].x - _padX(widget.chips[i]),
            top: widget.chips[i].y - dy - _padY(widget.chips[i]),
            width: widget.chips[i].w + 2 * _padX(widget.chips[i]),
            height: widget.chips[i].h + 2 * _padY(widget.chips[i]),
            child: Semantics(
              button: true,
              selected: i == sel,
              label: widget.chips[i].label,
              excludeSemantics: true,
              onTap: () {
                GSound.play('tick');
                setState(() => sel = i);
                widget.onChanged?.call(i);
              },
              child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                GSound.play('tick');
                setState(() => sel = i);
                widget.onChanged?.call(i);
              },
              child: Padding(padding: EdgeInsets.symmetric(vertical: _padY(widget.chips[i]), horizontal: _padX(widget.chips[i])), child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == sel ? widget.selFill : widget.unselFill,
                  borderRadius: BorderRadius.circular(widget.radius),
                  border: widget.border == null || i == sel ? null : Border.all(color: widget.border!),
                ),
                child: OverflowBox(
                  maxWidth: double.infinity,
                  child: Text(widget.chips[i].label,
                      softWrap: false,
                      style: _ts(widget.chips[i].size, i == sel ? widget.selText : widget.unselText, widget.chips[i].weight, widget.inter, null, null)),
                ),
              )),
            )),
          ),
      ];

  /// Marge de toucher verticale invisible : la pastille reste dessinée à l'identique, sa zone de toucher fait au moins 48 dp de haut.
  double _padY(GChip c) => GScreen.a11y ? math.max(0.0, (GScreen.minTarget - c.h) / 2) : 0.0;

  /// Marge de toucher horizontale invisible pour les pastilles plus étroites que 48 dp.
  double _padX(GChip c) => GScreen.a11y ? math.max(0.0, (GScreen.minTarget - c.w) / 2) : 0.0;

  /// Les pastilles qui dépassent la largeur de l'écran défilent horizontalement (la dernière est atteignable).
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        if (widget.chips.isEmpty) return const SizedBox.shrink();
        final maxX = widget.chips.map((c) => c.x + c.w + _padX(c)).reduce(math.max);
        if (!box.hasBoundedWidth || maxX <= box.maxWidth + 0.5) return Stack(clipBehavior: Clip.none, children: _chips(0));
        final minY = widget.chips.map((c) => c.y - _padY(c)).reduce(math.min);
        final maxY = widget.chips.map((c) => c.y + c.h + _padY(c)).reduce(math.max);
        return Stack(children: [
          Positioned(
            left: 0,
            right: 0,
            top: minY,
            height: maxY - minY,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(width: maxX + 24, height: maxY - minY, child: Stack(clipBehavior: Clip.none, children: _chips(minY))),
            ),
          ),
        ]);
      });
}

/// Case à cocher.
class GCheck extends StatefulWidget {
  const GCheck({super.key, required this.on, required this.onColor, required this.offColor, required this.radius, this.border, this.padX = 0, this.padY = 0});
  final double padX, padY;
  final bool on;
  final Color onColor, offColor;
  final Color? border;
  final double radius;
  @override
  State<GCheck> createState() => _GCheckState();
}

class _GCheckState extends State<GCheck> {
  late bool on = widget.on;
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          GSound.play('pop');
          setState(() => on = !on);
        },
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.padX, vertical: widget.padY),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            decoration: BoxDecoration(
              color: on ? widget.onColor : widget.offColor,
              borderRadius: BorderRadius.circular(widget.radius),
              border: widget.border == null || on ? null : Border.all(color: widget.border!, width: 1.5),
            ),
            child: on ? Padding(padding: const EdgeInsets.all(1), child: FittedBox(child: SizedBox(width: 14.667, height: 11.958, child: gImg('assets/figma/v/w_check.svg')))) : null,
          ),
        ),
      );
}


/// Barre de chargement du démarrage : se remplit puis ouvre l'écran suivant (désactivée dans les tests).
class GSplashBar extends StatefulWidget {
  const GSplashBar({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<GSplashBar> createState() => _GSplashBarState();
}

class _GSplashBarState extends State<GSplashBar> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200));
  @override
  void initState() {
    super.initState();
    if (GAnim.enabled) {
      c.forward().whenComplete(() {
        if (mounted) widget.onDone();
      });
    }
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: c,
        builder: (_, _) => Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: Curves.easeInOut.transform(c.value),
            child: DecoratedBox(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)), child: const SizedBox.expand()),
          ),
        ),
      );
}


/// Saisie d'une date : n'accepte que des chiffres (8 au plus) et insère les barres « / » après le jour et le mois.
class _DateSlashFormatter extends TextInputFormatter {
  const _DateSlashFormatter();
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final d = newValue.text.replaceAll(RegExp(r'\D'), '');
    final t = d.length > 8 ? d.substring(0, 8) : d;
    final b = StringBuffer();
    for (var i = 0; i < t.length; i++) {
      if (i == 2 || i == 4) b.write('/');
      b.write(t[i]);
    }
    final out = b.toString();
    return TextEditingValue(text: out, selection: TextSelection.collapsed(offset: out.length));
  }
}
