import 'dart:io';

/// Application mobile : Wi-Fi ou données mobiles d'après les interfaces réseau actives (wlan / en0 = Wi-Fi ; rmnet / ccmni / pdp_ip = mobile).
Future<bool> isCellularNetwork() async {
  try {
    final list = await NetworkInterface.list(includeLoopback: false);
    var wifi = false, mobile = false;
    for (final i in list) {
      if (i.addresses.isEmpty) continue;
      final n = i.name.toLowerCase();
      if (n.startsWith('wlan') || n == 'en0' || n.startsWith('eth')) wifi = true;
      if (n.startsWith('rmnet') || n.startsWith('ccmni') || n.startsWith('pdp_ip') || n.startsWith('v4-rmnet')) mobile = true;
    }
    return mobile && !wifi;
  } catch (_) {
    return false;
  }
}
