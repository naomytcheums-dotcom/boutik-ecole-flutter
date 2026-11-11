import 'dart:async';

import 'package:flutter/widgets.dart';

import 'gdata_native.dart' if (dart.library.js_interop) 'gdata_web.dart';

/// Économie de données : les quatre réglages de l'écran « Économie de données » agissent réellement.
///  · Mode économie : images réduites et vidéos jamais lancées toutes seules, quel que soit le réseau.
///  · Images basse qualité sur réseau mobile : images réduites quand l'appareil est sur données mobiles.
///  · Vidéos en Wi-Fi uniquement : aucune vidéo ne se charge ni ne démarre seule sur données mobiles (un appui la lance).
///  · Synchronisation en arrière-plan en Wi-Fi uniquement : les actualisations automatiques sont suspendues sur données mobiles.
class GData {
  static bool saver = true, lowImages = true, wifiVideo = true, wifiSync = false;
  static bool cellular = false;
  static Timer? _poll;

  /// Réseau mobile détecté (rafraîchi toutes les 20 s).
  static void watchNetwork() {
    _poll ??= Timer.periodic(const Duration(seconds: 20), (_) async => cellular = await isCellularNetwork());
    isCellularNetwork().then((v) => cellular = v);
  }

  static bool get reduceImages => saver || (lowImages && cellular);
  static bool get blockVideo => saver || (wifiVideo && cellular);
  static bool get blockSync => wifiSync && cellular;

  /// Largeur maximale de décodage des images quand elles sont réduites.
  static int? get imageWidth => reduceImages ? 480 : null;
}

/// `Image.network` qui réduit la taille de décodage des images quand l'économie de données le demande.
Image gNetImage(
  String src, {
  Key? key,
  double scale = 1.0,
  ImageFrameBuilder? frameBuilder,
  ImageLoadingBuilder? loadingBuilder,
  ImageErrorWidgetBuilder? errorBuilder,
  String? semanticLabel,
  bool excludeFromSemantics = false,
  double? width,
  double? height,
  Color? color,
  Animation<double>? opacity,
  BlendMode? colorBlendMode,
  BoxFit? fit,
  AlignmentGeometry alignment = Alignment.center,
  ImageRepeat repeat = ImageRepeat.noRepeat,
  Rect? centerSlice,
  bool matchTextDirection = false,
  bool gaplessPlayback = false,
  bool isAntiAlias = false,
  Map<String, String>? headers,
  int? cacheWidth,
  int? cacheHeight,
  FilterQuality filterQuality = FilterQuality.medium,
}) =>
    Image.network(
      src,
      key: key,
      scale: scale,
      frameBuilder: frameBuilder,
      loadingBuilder: loadingBuilder,
      errorBuilder: errorBuilder,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      width: width,
      height: height,
      color: color,
      opacity: opacity,
      colorBlendMode: colorBlendMode,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
      centerSlice: centerSlice,
      matchTextDirection: matchTextDirection,
      gaplessPlayback: gaplessPlayback,
      isAntiAlias: isAntiAlias,
      headers: headers,
      cacheWidth: cacheWidth ?? (cacheHeight == null ? GData.imageWidth : null),
      cacheHeight: cacheHeight,
      filterQuality: filterQuality,
    );
