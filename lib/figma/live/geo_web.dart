import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Adresse détectée à partir de la position réelle de l'appareil.
class GeoPlace {
  const GeoPlace({required this.lat, required this.lon, this.city = '', this.district = '', this.line = ''});
  final double lat, lon;
  final String city, district, line;
}

/// Résultat d'une détection : `status` vaut ok, denied (autorisation refusée), unavailable (position introuvable ou GPS coupé) ou unsupported.
typedef GeoResult = ({String status, GeoPlace? place});

Future<({double lat, double lon})?> _position(Completer<String> why) async {
  final pos = Completer<({double lat, double lon})?>();
  try {
    web.window.navigator.geolocation.getCurrentPosition(
      ((web.GeolocationPosition p) {
        if (!pos.isCompleted) pos.complete((lat: p.coords.latitude, lon: p.coords.longitude));
      }).toJS,
      ((web.GeolocationPositionError e) {
        if (!why.isCompleted) why.complete(e.code == 1 ? 'denied' : 'unavailable');
        if (!pos.isCompleted) pos.complete(null);
      }).toJS,
    );
  } catch (_) {
    if (!why.isCompleted) why.complete('unsupported');
    return null;
  }
  return pos.future.timeout(const Duration(seconds: 20), onTimeout: () {
    if (!why.isCompleted) why.complete('unavailable');
    return null;
  });
}

Future<Map?> _reverse(double lat, double lon, int zoom) async {
  try {
    final url = 'https://nominatim.openstreetmap.org/reverse?format=jsonv2&addressdetails=1&zoom=$zoom&accept-language=fr&lat=$lat&lon=$lon';
    final res = await web.window.fetch(url.toJS).toDart;
    final body = (await res.text().toDart).toDart;
    final a = (jsonDecode(body) as Map)['address'];
    return a is Map ? a : null;
  } catch (_) {
    return null;
  }
}

String _first(Map a, List<String> keys) {
  for (final k in keys) {
    final v = a[k];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  return '';
}

/// Position du navigateur (après autorisation de la personne) puis ville par géocodage inverse OpenStreetMap.
/// Renvoie null si l'autorisation est refusée, la position indisponible ou le service injoignable : la saisie manuelle prend alors le relais.
Future<String?> detectCity() async {
  final why = Completer<String>();
  final p = await _position(why);
  if (p == null) return null;
  final a = await _reverse(p.lat, p.lon, 10);
  if (a == null) return null;
  final v = _first(a, const ['city', 'town', 'village', 'municipality', 'county', 'state_district']);
  return v.isEmpty ? null : v;
}

/// Position réelle + ville, quartier, rue et coordonnées pour remplir une adresse de livraison sans saisie.
Future<GeoResult> detectPlace() async {
  final why = Completer<String>();
  final p = await _position(why);
  if (p == null) return (status: why.isCompleted ? await why.future : 'unavailable', place: null);
  final a = await _reverse(p.lat, p.lon, 18);
  if (a == null) return (status: 'ok', place: GeoPlace(lat: p.lat, lon: p.lon));
  final road = _first(a, const ['road', 'pedestrian', 'footway', 'path']);
  final house = _first(a, const ['house_number']);
  return (
    status: 'ok',
    place: GeoPlace(
      lat: p.lat,
      lon: p.lon,
      city: _first(a, const ['city', 'town', 'village', 'municipality', 'county', 'state_district']),
      district: _first(a, const ['suburb', 'neighbourhood', 'quarter', 'city_district', 'residential', 'hamlet']),
      line: [if (house.isNotEmpty) house, if (road.isNotEmpty) road].join(' '),
    ),
  );
}
