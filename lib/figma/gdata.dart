import 'dart:async';

import 'package:flutter/widgets.dart';

import 'gdata_native.dart' if (dart.library.js_interop) 'gdata_web.dart';

/// Économie de données : les quatre réglages de l'écran « Économie de données » agissent réellement.
///  · Mode économie (ON/OFF, mémorisé sur l'appareil) : vidéos jamais lancées toutes seules ; images en basse qualité (480 px au plus) sur réseau mobile,
///    en haute qualité sur Wi-Fi. Désactivé, tout redevient normal.
///  · Téléchargement des vidéos : « Wi-Fi uniquement » le refuse sur données mobiles (message « Connectez-vous en Wi-Fi pour télécharger »), « Wi-Fi + mobile » l'autorise.
///  · Synchronisation en arrière-plan : « Wi-Fi uniquement » (suspendue sur données mobiles) ou « Jamais » (aucune actualisation automatique) ;
///    la connexion est revérifiée avant chaque synchronisation.
class GData {
  static bool saver = true, lowImages = true, wifiVideo = true, wifiSync = true, syncNever = false;
  static bool cellular = false;
  static Timer? _poll;

  /// Réseau mobile détecté (rafraîchi toutes les 20 s).
  static void watchNetwork() {
    _poll ??= Timer.periodic(const Duration(seconds: 20), (_) async => cellular = await isCellularNetwork());
    isCellularNetwork().then((v) => cellular = v);
  }

  static bool get reduceImages => saver && lowImages && cellular;
  static bool get blockVideo => saver || (wifiVideo && cellular);

  /// Téléchargement de vidéo refusé : « Wi-Fi uniquement » choisi et appareil sur données mobiles.
  static bool get blockDownload => wifiVideo && cellular;
  static bool get blockSync => syncNever || (wifiSync && cellular);

  /// Revérifie le réseau maintenant (avant un téléchargement ou une synchronisation).
  static Future<void> refreshNetwork() async {
    cellular = await isCellularNetwork();
  }

  /// Synchronisation autorisée ? Revérifie la connexion à chaque appel : « Jamais » refuse toujours, « Wi-Fi uniquement » refuse sur données mobiles.
  static Future<bool> syncAllowed() async {
    if (syncNever) return false;
    await refreshNetwork();
    return !blockSync;
  }

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
