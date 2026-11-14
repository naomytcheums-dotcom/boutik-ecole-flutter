import 'dart:async';
import 'dart:io';

const _probeHost = String.fromEnvironment('BE_HOST', defaultValue: 'zxqcnmgwhtbxkdpjqtlr.supabase.co');
const _probeEvery = Duration(seconds: 8);
const _probeTimeout = Duration(seconds: 3);

bool _online = true;
int _failures = 0;

/// Hors navigateur (mobile, bureau) : dernier état mesuré par la sonde DNS ; « en ligne » tant qu'aucune mesure n'a échoué.
bool browserOnline() => _online;

Future<bool> _reachable() async {
  try {
    final r = await InternetAddress.lookup(_probeHost).timeout(_probeTimeout);
    return r.isNotEmpty && r.first.rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
}

/// Sonde périodique du réseau : deux échecs consécutifs sont nécessaires pour annoncer la coupure.
/// Renvoie la fonction qui arrête la sonde. Aucune sonde pendant les tests Flutter.
void Function() listenConnectivity(void Function(bool online) onChange) {
  if (Platform.environment.containsKey('FLUTTER_TEST')) return () {};
  var stopped = false;
  var probing = false;
  Future<void> probe() async {
    if (stopped || probing) return;
    probing = true;
    final ok = await _reachable();
    probing = false;
    if (stopped) return;
    _failures = ok ? 0 : _failures + 1;
    final next = ok || _failures < 2;
    if (next != _online) {
      _online = next;
      onChange(next);
    }
  }

  final timer = Timer.periodic(_probeEvery, (_) => probe());
  probe();
  return () {
    stopped = true;
    timer.cancel();
  };
}
