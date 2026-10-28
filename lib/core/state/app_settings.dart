import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Préférences d'affichage : langue (écran 185), texte agrandi, contraste et animations (écrans 149, 186), mode léger (150, 184).
class AppSettings {
  const AppSettings({
    this.locale = const Locale('fr'),
    this.textScale = 1,
    this.boldText = false,
    this.highContrast = false,
    this.lightMode = false,
    this.offline = false,
    this.reduceMotion = false,
    this.screenReader = false,
  });

  final Locale locale;
  final double textScale;
  final bool boldText;
  final bool highContrast;
  final bool lightMode;
  final bool offline;
  final bool reduceMotion;

  /// Étiquettes vocales détaillées pour les lecteurs d'écran (149, 186).
  final bool screenReader;

  AppSettings copyWith({
    Locale? locale,
    double? textScale,
    bool? boldText,
    bool? highContrast,
    bool? lightMode,
    bool? offline,
    bool? reduceMotion,
    bool? screenReader,
  }) => AppSettings(
    locale: locale ?? this.locale,
    textScale: textScale ?? this.textScale,
    boldText: boldText ?? this.boldText,
    highContrast: highContrast ?? this.highContrast,
    lightMode: lightMode ?? this.lightMode,
    offline: offline ?? this.offline,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    screenReader: screenReader ?? this.screenReader,
  );
}

class AppSettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => const AppSettings();

  void setLocale(Locale l) => state = state.copyWith(locale: l);
  void setTextScale(double s) => state = state.copyWith(textScale: s.clamp(0.85, 1.6));
  void setBoldText(bool v) => state = state.copyWith(boldText: v);
  void setHighContrast(bool v) => state = state.copyWith(highContrast: v);
  void setLightMode(bool v) => state = state.copyWith(lightMode: v);
  void setOffline(bool v) => state = state.copyWith(offline: v);
  void setReduceMotion(bool v) => state = state.copyWith(reduceMotion: v);
  void setScreenReader(bool v) => state = state.copyWith(screenReader: v);
}

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(AppSettingsNotifier.new);
