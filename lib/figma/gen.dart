import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
    return ColoredBox(
      color: const Color(0xFFE9E6EE),
      child: LayoutBuilder(builder: (context, c) {
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

/// Positionne un élément (avec rotation et opacité éventuelles) et le rend cliquable.
Widget gP(double x, double y, double w, double h, Widget child, {double rot = 0, double op = 1, VoidCallback? tap}) {
  Widget c = SizedBox(width: w, height: h, child: child);
  if (rot != 0) c = Transform.rotate(angle: rot, alignment: Alignment.topLeft, child: c);
  if (op < 1) c = Opacity(opacity: op, child: c);
  if (tap != null) c = GestureDetector(behavior: HitTestBehavior.opaque, onTap: tap, child: c);
  return Positioned(left: x, top: y, child: c);
}

Widget gTap(double x, double y, double w, double h, VoidCallback tap) => gP(x, y, w, h, const SizedBox.expand(), tap: tap);

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
  if (wrap) return t;
  return OverflowBox(alignment: Alignment.topLeft, minWidth: 0, maxWidth: double.infinity, child: t);
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
  if (wrap) return t;
  return OverflowBox(alignment: Alignment.topLeft, minWidth: 0, maxWidth: double.infinity, child: t);
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
