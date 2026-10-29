import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Petits blocs « fidèles Figma » : tout est positionné aux coordonnées exactes de la maquette
/// (x, y, largeur, hauteur en pixels logiques). Les écrans générés dans lib/figma/ n'utilisent que ça.
const _jakarta = 'PlusJakartaSans';
const _inter = 'Inter';

Color hex(int rgb, [double a = 1]) => Color(0xFF000000 | rgb).withValues(alpha: a);

class FxScreen extends StatelessWidget {
  const FxScreen({super.key, required this.w, required this.h, required this.children, this.radius = 46, this.bg});
  final double w, h;
  final double radius;
  final Gradient? bg;
  final List<Widget> children;

  static const gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)],
  );

  @override
  Widget build(BuildContext context) {
    // L'écran garde exactement ses proportions et se met à l'échelle pour tenir dans la fenêtre.
    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: w,
          height: h,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: bg ?? gradient),
              child: Stack(clipBehavior: Clip.hardEdge, children: children),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rectangle (carte, bouton, pastille, trait…).
Widget fxBox(
  double x,
  double y,
  double w,
  double h, {
  Color? color,
  double radius = 0,
  Color? border,
  double borderW = 1,
  List<BoxShadow>? shadow,
  Gradient? gradient,
  bool oval = false,
  VoidCallback? onTap,
}) {
  Widget b = DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      gradient: gradient,
      shape: oval ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: oval ? null : BorderRadius.circular(radius),
      border: border == null ? null : Border.all(color: border, width: borderW),
      boxShadow: shadow,
    ),
    child: const SizedBox.expand(),
  );
  if (onTap != null) b = GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: b);
  return Positioned(left: x, top: y, width: w, height: h, child: b);
}

BoxShadow fxShadow(double dx, double dy, double blur, Color c, [double spread = 0]) =>
    BoxShadow(offset: Offset(dx, dy), blurRadius: blur, spreadRadius: spread, color: c);

/// Texte positionné à (x, y) = coin haut-gauche de la boîte de texte Figma.
Widget fxText(
  String s,
  double x,
  double y,
  double size,
  Color color, {
  int weight = 400,
  double? w,
  double? lh,
  TextAlign align = TextAlign.left,
  bool inter = false,
  double? letterSpacing,
  TextDecoration? decoration,
  int? maxLines,
}) {
  final style = TextStyle(
    fontFamily: inter ? _inter : _jakarta,
    fontSize: size,
    fontWeight: FontWeight.values[(weight ~/ 100) - 1],
    color: color,
    height: lh == null ? null : lh / size,
    letterSpacing: letterSpacing,
    decoration: decoration,
  );
  final t = Text(s, style: style, textAlign: align, maxLines: maxLines, softWrap: w != null, overflow: TextOverflow.visible);
  return Positioned(left: x, top: y, width: w, child: w == null ? FittedBox(fit: BoxFit.none, alignment: Alignment.topLeft, child: t) : t);
}

/// Image raster ou SVG exportée de Figma (assets/figma/…).
Widget fxImg(String asset, double x, double y, double w, double h, {BoxFit fit = BoxFit.fill, VoidCallback? onTap}) {
  final Widget img = asset.endsWith('.svg')
      ? SvgPicture.asset(asset, width: w, height: h, fit: fit)
      : Image.asset(asset, width: w, height: h, fit: fit, filterQuality: FilterQuality.high);
  return Positioned(
    left: x,
    top: y,
    width: w,
    height: h,
    child: onTap == null ? img : GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: img),
  );
}

/// Zone cliquable invisible (liens du prototype).
Widget fxTap(double x, double y, double w, double h, VoidCallback onTap) => Positioned(
      left: x,
      top: y,
      width: w,
      height: h,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: const SizedBox.expand()),
    );

/// Image qui déborde de sa boîte (halo : inset négatif).
Widget fxImgBleed(String asset, double x, double y, double w, double h, double bleedPct) {
  final dx = w * bleedPct, dy = h * bleedPct;
  return fxImg(asset, x - dx, y - dy, w + 2 * dx, h + 2 * dy);
}
