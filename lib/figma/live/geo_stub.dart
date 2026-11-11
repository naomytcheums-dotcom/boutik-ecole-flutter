/// Adresse détectée à partir de la position réelle de l'appareil.
class GeoPlace {
  const GeoPlace({required this.lat, required this.lon, this.city = '', this.district = '', this.line = ''});
  final double lat, lon;
  final String city, district, line;
}

typedef GeoResult = ({String status, GeoPlace? place});

/// Hors navigateur (tests, mobile sans module de localisation) : aucune position disponible ; la saisie manuelle reste possible.
Future<String?> detectCity() async => null;

Future<GeoResult> detectPlace() async => (status: 'unsupported', place: null);
