import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Préférences d'affichage : langue (écran 185), texte agrandi (écran 186), mode léger (182).
class AppSettings {
  const AppSettings({
    this.locale = const Locale('fr'),
    this.textScale = 1,
    this.boldText = false,
    this.highContrast = false,
    this.lightMode = false,
    this.offline = false,
  });

  final Locale locale;
  final double textScale;
  final bool boldText;
  final bool highContrast;
  final bool lightMode;
  final bool offline;

  AppSettings copyWith({
    Locale? locale,
    double? textScale,
    bool? boldText,
    bool? highContrast,
    bool? lightMode,
    bool? offline,
  }) => AppSettings(
    locale: locale ?? this.locale,
    textScale: textScale ?? this.textScale,
    boldText: boldText ?? this.boldText,
    highContrast: highContrast ?? this.highContrast,
    lightMode: lightMode ?? this.lightMode,
    offline: offline ?? this.offline,
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
}

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(AppSettingsNotifier.new);
