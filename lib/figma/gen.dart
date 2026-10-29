import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
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
      body: LayoutBuilder(builder: (context, c) {
        if (h > 1000 && w < 700) {
          // Écran long : on adapte la largeur et on fait défiler.
          final s = math.min(1.0, c.maxWidth / w);
          return SingleChildScrollView(
            child: Center(child: SizedBox(width: w * s, height: h * s, child: FittedBox(fit: BoxFit.fill, child: canvas))),
          );
        }
        return Center(child: FittedBox(fit: BoxFit.contain, child: canvas));
      }),
    );
  }
}

/// Positionne un élément (avec rotation, opacité, animation d'entrée, effet ambiant et retour tactile).
Widget gP(double x, double y, double w, double h, Widget child,
    {double rot = 0, double op = 1, VoidCallback? tap, String? fx, String sound = 'click'}) {
  Widget c = SizedBox(width: w, height: h, child: child);
  if (fx != null && GAnim.enabled) c = GFx(kind: fx, seed: x * 7 + y, child: c);
  if (rot != 0) c = Transform.rotate(angle: rot, alignment: Alignment.topLeft, child: c);
  if (op < 1) c = Opacity(opacity: op, child: c);
  if (tap != null) c = GPress(onTap: tap, sound: sound, child: c);
  if (GAnim.enabled && w * h < 140000) c = GEnter(delay: Duration(milliseconds: (y * 0.5).clamp(0, 520).round()), child: c);
  return Positioned(left: x, top: y, child: c);
}

Widget gTap(double x, double y, double w, double h, VoidCallback tap) =>
    Positioned(left: x, top: y, child: GPress(onTap: tap, sound: 'whoosh', flash: true, child: SizedBox(width: w, height: h)));

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
    color: color,
    gradient: gradient,
    shape: oval ? BoxShape.circle : BoxShape.rectangle,
    borderRadius: oval ? null : _br(radii),
    border: border == null ? null : Border.all(color: border, width: bw),
    boxShadow: shadows,
    image: image == null ? null : DecorationImage(image: AssetImage(image), fit: fit, filterQuality: FilterQuality.high),
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
    {int weight = 400, bool inter = false, double? lh, double? ls, TextAlign align = TextAlign.left, bool wrap = false, TextDecoration? deco}) {
  final t = Text(s,
      style: _ts(size, color, weight, inter, lh, ls, deco),
      textAlign: align,
      softWrap: wrap,
      overflow: TextOverflow.visible,
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

Widget gImg(String asset, {BoxFit fit = BoxFit.fill}) => asset.endsWith('.svg')
    ? SvgPicture.asset(asset, fit: fit)
    : Image.asset(asset, fit: fit, filterQuality: FilterQuality.high, gaplessPlayback: true);

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
  m?.hideCurrentSnackBar();
  m?.showSnackBar(SnackBar(
    content: Text(message, style: const TextStyle(fontFamily: _jakarta, fontSize: 13, color: Colors.white)),
    duration: const Duration(milliseconds: 1600),
    behavior: SnackBarBehavior.floating,
    backgroundColor: const Color(0xFF111015),
    margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
  ));
}

/// Interrupteur animé (cliquable).
class GToggle extends StatefulWidget {
  const GToggle({super.key, required this.on, required this.onColor, required this.offColor, required this.knob, this.knobColor = Colors.white});
  final bool on;
  final Color onColor, offColor, knobColor;
  final double knob;
  @override
  State<GToggle> createState() => _GToggleState();
}

class _GToggleState extends State<GToggle> {
  late bool on = widget.on;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final pad = (c.maxHeight - widget.knob) / 2;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            GSound.play('pop');
            setState(() => on = !on);
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
  });
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
        padding: EdgeInsets.only(left: widget.padL, right: 14),
        child: Align(
          alignment: widget.multiline ? Alignment.topLeft : Alignment.centerLeft,
          child: TextField(
            controller: c,
            focusNode: f,
            style: st,
            obscureText: widget.obscure,
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
  });
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
          child: on ? const FittedBox(child: Icon(Icons.check_rounded, color: Colors.white, size: 40)) : null,
        ),
      );
}
