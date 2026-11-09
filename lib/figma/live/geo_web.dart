import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Position du navigateur (après autorisation de la personne) puis ville par géocodage inverse OpenStreetMap.
/// Renvoie null si l'autorisation est refusée, la position indisponible ou le service injoignable : la saisie manuelle prend alors le relais.
Future<String?> detectCity() async {
  final pos = Completer<({double lat, double lon})?>();
  try {
    web.window.navigator.geolocation.getCurrentPosition(
      ((web.GeolocationPosition p) {
        if (!pos.isCompleted) pos.complete((lat: p.coords.latitude, lon: p.coords.longitude));
      }).toJS,
      ((web.GeolocationPositionError e) {
        if (!pos.isCompleted) pos.complete(null);
      }).toJS,
    );
  } catch (_) {
    return null;
  }
  final p = await pos.future.timeout(const Duration(seconds: 20), onTimeout: () => null);
  if (p == null) return null;
  try {
    final url = 'https://nominatim.openstreetmap.org/reverse?format=jsonv2&zoom=10&accept-language=fr&lat=${p.lat}&lon=${p.lon}';
    final res = await web.window.fetch(url.toJS).toDart;
    final body = (await res.text().toDart).toDart;
    final a = (jsonDecode(body) as Map)['address'];
    if (a is! Map) return null;
    for (final k in const ['city', 'town', 'village', 'municipality', 'county', 'state_district']) {
      final v = a[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
  } catch (_) {}
  return null;
}
