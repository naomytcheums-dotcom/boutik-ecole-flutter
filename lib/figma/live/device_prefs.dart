import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Réglages de l'appareil (écrans 184 Économie de données, 186 Accessibilité) : enregistrés sur l'appareil, pas sur le compte.
/// Les valeurs par défaut sont celles de la maquette ; chaque interrupteur est mémorisé dès qu'on le change.
class DevicePrefs extends Notifier<Map<String, bool>> {
  DevicePrefs(this.defaults);
  final Map<String, bool> defaults;

  @override
  Map<String, bool> build() {
    Future.microtask(_load);
    return Map.of(defaults);
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!ref.mounted) return;
      state = {for (final k in defaults.keys) k: p.getBool('dev_$k') ?? defaults[k]!};
    } catch (_) {}
  }

  Future<void> set(String key, bool on) async {
    state = {...state, key: on};
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('dev_$key', on);
    } catch (_) {}
  }
}

const dataPrefsDefaults = {'data_saver': true, 'low_images': true, 'wifi_video': true, 'wifi_sync': false};
const accessPrefsDefaults = {'large_text': true, 'contrast': true, 'reduce_motion': false, 'screen_reader': false};
final dataPrefsProvider = NotifierProvider<DevicePrefs, Map<String, bool>>(() => DevicePrefs(dataPrefsDefaults));
final accessPrefsProvider = NotifierProvider<DevicePrefs, Map<String, bool>>(() => DevicePrefs(accessPrefsDefaults));

const accessPrefs149Defaults = {'a149_large_text': false, 'a149_contrast': true, 'a149_reduce_motion': false, 'a149_screen_reader': false};
final accessPrefs149Provider = NotifierProvider<DevicePrefs, Map<String, bool>>(() => DevicePrefs(accessPrefs149Defaults));
