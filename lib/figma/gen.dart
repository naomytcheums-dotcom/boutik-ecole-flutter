import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'gsound.dart';

export 'gsound.dart';

/// Primitives utilisées par le code généré depuis Figma (tool/figma_export/convert.py).
/// Ne pas éditer à la main les fichiers lib/figma/g/*.dart : ils sont régénérés.
const _jakarta = 'PlusJakartaSans';
const _inter = 'Inter';

class GScreen extends StatelessWidget {
  const GScreen({super.key, required this.w, required this.h, required this.children, this.radius = 0, this.bg, this.color});
  final double w, h, radius;
  final Gradient? bg;
  final Color? color;
  final List<Widget> children;

  /// Rendu « cadre de maquette » (taille Figma exacte) : réservé aux rendus de référence et aux tests de coordonnées.
  static bool mockupFrame = false;

  /// Largeur maximale de la colonne des écrans de format mobile sur grand écran.
  static const maxColumn = 480.0;

  /// Hauteur de la fausse barre d'état iOS dessinée dans les maquettes (9:41, réseau, batterie).
  static const statusBand = 44.0;

  @override
  Widget build(BuildContext context) {
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

  /// Plein écran sur téléphone. La maquette est mise à l'échelle de la largeur réelle de l'écran (référence Figma : `w`),
  /// sans cadre ni marges ; la fausse barre d'état et la fausse barre d'accueil iOS sont retirées (le téléphone a les siennes) ;
  /// le menu du bas et les barres d'actions pleine largeur restent fixes en bas, et le contenu reçoit en bas un espace de
  /// leur hauteur pour que la dernière section soit entièrement visible au-dessus.
  Widget _phone(BuildContext context, BoxConstraints c) {
    final pad = MediaQuery.paddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final s = c.maxWidth / w;
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
    for (var i = 0; i < children.length; i++) {
      final r = rects[i];
      if (r == null || taps[i] || r.top <= h * 0.6) continue;
      final nav = r.width >= 330 && r.width <= 360 && r.height >= 54 && r.height <= 74 && r.left >= 8 && r.left <= 36;
      final bar = r.left <= 1 && r.width >= w - 2 && r.bottom >= h - 2 && r.height >= 40 && r.height <= 160;
      if (!nav && !bar) continue;
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

    Widget layer(List<Widget> kids, double from, double to) => SizedBox(
          width: w * s,
          height: (to - from) * s,
          child: FittedBox(
            fit: BoxFit.fill,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: w,
              height: to - from,
              child: Stack(clipBehavior: Clip.hardEdge, children: [
                Positioned(left: 0, top: -from, width: w, height: h, child: Stack(clipBehavior: Clip.none, children: kids)),
              ]),
            ),
          ),
        );

    final content = [for (var i = 0; i < children.length; i++) if (!band.contains(i) && !hidden.contains(i)) children[i]];
    final fixed = [for (var i = 0; i < children.length; i++) if (band.contains(i)) children[i]];
    final bandH = band.isEmpty ? 0.0 : (bandBottom - bandTop + 8) * s;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: bg, color: color ?? (bg == null ? const Color(0xFFFFFFFF) : null)),
      child: Stack(children: [
        Positioned.fill(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(top: pad.top, bottom: pad.bottom + bandH + keyboard),
            child: layer(content, statusBand, h),
          ),
        ),
        if (band.isNotEmpty) Positioned(left: 0, right: 0, bottom: pad.bottom, child: layer(fixed, bandTop, bandBottom)),
      ]),
    );
  }
}

/// Positionne un élément (avec rotation, opacité, animation d'entrée, effet ambiant et retour tactile).
Widget gP(double x, double y, double w, double h, Widget child,
    {double rot = 0, double op = 1, VoidCallback? tap, String? fx, String sound = 'click', bool show = true}) {
  if (!show) return const Positioned(left: 0, top: 0, width: 0, height: 0, child: SizedBox.shrink());
  Widget c = SizedBox(width: w, height: h, child: child);
  if (fx != null && GAnim.enabled) c = GFx(kind: fx, seed: x * 7 + y, child: c);
  if (rot != 0) c = Transform.rotate(angle: rot, alignment: Alignment.topLeft, child: c);
  if (op < 1) c = Opacity(opacity: op, child: c);
  if (tap != null) c = GPress(onTap: tap, sound: sound, child: c);
  if (GAnim.enabled && w * h < 140000) c = GEnter(delay: Duration(milliseconds: (y * 0.5).clamp(0, 520).round()), child: c);
  return GPos(x: x, y: y, gw: w, gh: h, tap: tap != null, child: c);
}

Widget gTap(double x, double y, double w, double h, VoidCallback tap) =>
    GPos(x: x, y: y, gw: w, gh: h, tap: true, child: GPress(onTap: tap, sound: 'whoosh', flash: true, child: SizedBox(width: w, height: h)));

/// Élément positionné de la maquette qui connaît son rectangle (pour l'adaptation plein écran des téléphones).
class GPos extends Positioned {
  const GPos({super.key, required double x, required double y, required this.gw, required this.gh, this.tap = false, required super.child})
      : super(left: x, top: y);
  final double gw, gh;
  final bool tap;
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

TextStyle _ts(double size, Color color, int weight, bool inter, double? lh, double? ls, [TextDecoration? deco]) => TextStyle(
      inherit: false,
      textBaseline: TextBaseline.alphabetic,
      fontFamily: inter ? _inter : _jakarta,
      fontSize: size,
      fontWeight: FontWeight.values[((weight ~/ 100).clamp(1, 9)) - 1],
      color: color,
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
  if (wrap) return IgnorePointer(child: t);
  return IgnorePointer(child: OverflowBox(alignment: Alignment.topLeft, minWidth: 0, maxWidth: double.infinity, child: t));
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

Widget gImg(String asset, {BoxFit fit = BoxFit.fill}) => IgnorePointer(
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
  const GToggle({super.key, required this.on, required this.onColor, required this.offColor, required this.knob, this.knobColor = Colors.white, this.onChanged});
  final bool on;
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
        final pad = (c.maxHeight - widget.knob) / 2;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            GSound.play('pop');
            setState(() => on = !on);
            widget.onChanged?.call(on);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(color: on ? widget.onColor : widget.offColor, borderRadius: BorderRadius.circular(c.maxHeight / 2)),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 180),
              alignment: on ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.all(pad),
                child: Container(width: widget.knob, height: widget.knob, decoration: BoxDecoration(color: widget.knobColor, shape: BoxShape.circle)),
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
  });
  final double padT;
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
  final FocusNode f = FocusNode();
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: f.requestFocus,
      child: Padding(
        padding: EdgeInsets.only(left: widget.padL, right: 14, top: widget.multiline ? widget.padT : 0),
        child: Align(
          alignment: widget.multiline ? Alignment.topLeft : Alignment.centerLeft,
          child: TextField(
            controller: c,
            focusNode: f,
            style: st,
            obscureText: widget.obscure,
            keyboardType: widget.numeric ? TextInputType.number : null,
            inputFormatters: [
              if (widget.numeric) FilteringTextInputFormatter.digitsOnly,
              if (widget.maxLength != null) LengthLimitingTextInputFormatter(widget.maxLength),
            ],
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            minLines: widget.multiline ? 2 : 1,
            maxLines: widget.multiline ? 6 : 1,
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
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }
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
  @override
  Widget build(BuildContext context) => Stack(clipBehavior: Clip.none, children: [
        for (var i = 0; i < widget.chips.length; i++)
          Positioned(
            left: widget.chips[i].x,
            top: widget.chips[i].y,
            width: widget.chips[i].w,
            height: widget.chips[i].h,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                GSound.play('tick');
                setState(() => sel = i);
                widget.onChanged?.call(i);
              },
              child: AnimatedContainer(
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
              ),
            ),
          ),
      ]);
}

/// Case à cocher.
class GCheck extends StatefulWidget {
  const GCheck({super.key, required this.on, required this.onColor, required this.offColor, required this.radius, this.border});
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: on ? widget.onColor : widget.offColor,
            borderRadius: BorderRadius.circular(widget.radius),
            border: widget.border == null || on ? null : Border.all(color: widget.border!, width: 1.5),
          ),
          child: on ? Padding(padding: const EdgeInsets.all(1), child: FittedBox(child: SizedBox(width: 14.667, height: 11.958, child: gImg('assets/figma/v/w_check.svg')))) : null,
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
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));
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
