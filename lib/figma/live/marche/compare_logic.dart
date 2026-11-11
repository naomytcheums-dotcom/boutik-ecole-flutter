/// Calculs de la comparaison de deux offres : lecture des caractéristiques saisies par les vendeurs (texte libre), compatibilité avec les critères
/// de l'acheteur et meilleure valeur par ligne. Fonctions pures, sans écran, pour être testées.

/// Critères de l'acheteur ; un critère vide n'entre pas dans le calcul.
class CompareCriteria {
  const CompareCriteria({this.budget, this.minCapacity, this.material = '', this.color = '', this.minWarrantyMonths, this.maxDeliveryDays, this.city = ''});
  final int? budget;
  final double? minCapacity;
  final String material, color, city;
  final int? minWarrantyMonths, maxDeliveryDays;

  CompareCriteria copy({Object? budget = _k, Object? minCapacity = _k, String? material, String? color, Object? minWarrantyMonths = _k, Object? maxDeliveryDays = _k, String? city}) => CompareCriteria(
        budget: identical(budget, _k) ? this.budget : budget as int?,
        minCapacity: identical(minCapacity, _k) ? this.minCapacity : minCapacity as double?,
        material: material ?? this.material,
        color: color ?? this.color,
        minWarrantyMonths: identical(minWarrantyMonths, _k) ? this.minWarrantyMonths : minWarrantyMonths as int?,
        maxDeliveryDays: identical(maxDeliveryDays, _k) ? this.maxDeliveryDays : maxDeliveryDays as int?,
        city: city ?? this.city,
      );

  /// Nombre de critères renseignés (la ville de livraison n'en est pas un : elle sert au prix livré).
  int get count => [budget, minCapacity, material.trim().isEmpty ? null : material, color.trim().isEmpty ? null : color, minWarrantyMonths, maxDeliveryDays].where((e) => e != null).length;
}

const _k = Object();

/// Ce que l'on sait d'une offre pour la comparer ; une valeur inconnue reste nulle (jamais devinée).
class OfferFacts {
  const OfferFacts({required this.title, required this.price, this.deliveryFee, this.capacity, this.material = '', this.colors = '', this.warrantyMonths, this.deliveryDays, this.rating, this.stock = 0});
  final String title, material, colors;
  final int price, stock;

  /// Frais de livraison vers la ville de l'acheteur ; nul si la ville n'est pas desservie par ce vendeur.
  final int? deliveryFee;
  final double? capacity, rating;
  final int? warrantyMonths, deliveryDays;

  /// Prix total livré : prix + frais de livraison (nul si la livraison n'est pas proposée vers la ville).
  int? get totalDelivered => deliveryFee == null ? null : price + deliveryFee!;
}

String _fold(String s) {
  const from = 'àâäáãéèêëíîïìóôöòõúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  var out = s.toLowerCase();
  for (var i = 0; i < from.length; i++) {
    out = out.replaceAll(from[i], to[i]);
  }
  return out;
}

/// Premier nombre d'un texte (« 20 L » → 20, « 1,5 kg » → 1.5) ; nul s'il n'y en a pas.
double? firstNumber(String s) {
  final m = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(s);
  return m == null ? null : double.tryParse(m.group(1)!.replaceAll(',', '.'));
}

/// Garantie en mois : « 6 mois » → 6, « 1 an » → 12, « 2 ans » → 24.
int? warrantyMonths(String s) {
  final n = firstNumber(s);
  if (n == null) return null;
  final t = _fold(s);
  if (RegExp(r'\bans?\b').hasMatch(t)) return (n * 12).round();
  return n.round();
}

/// Délai de livraison en jours (borne haute d'une plage : « 2-5 jours » → 5, « 1 semaine » → 7).
int? deliveryDays(String s) {
  final nums = RegExp(r'\d+').allMatches(s).map((m) => int.parse(m.group(0)!)).toList();
  if (nums.isEmpty) return null;
  final top = nums.reduce((a, b) => a > b ? a : b);
  return _fold(s).contains('semaine') ? top * 7 : top;
}

/// Valeur brute d'une caractéristique saisie par le vendeur, telle qu'il l'a écrite ; nulle si elle n'existe pas.
String? specText(Map<String, dynamic> specs, List<String> keys) {
  for (final e in specs.entries) {
    final k = _fold('${e.key}');
    if (keys.any(k.contains)) return '${e.value}';
  }
  return null;
}

/// Lit les caractéristiques saisies par le vendeur (clés libres : « Matériau », « Capacité », « Garantie », « Couleurs », « Livraison »).
OfferFacts factsFrom({required String title, required int price, required Map<String, dynamic> specs, int? deliveryFee, double? rating, int stock = 0}) {
  String? pick(List<String> keys) {
    for (final e in specs.entries) {
      final k = _fold('${e.key}');
      if (keys.any(k.contains)) return '${e.value}';
    }
    return null;
  }

  final cap = pick(['capac']);
  final war = pick(['garant']);
  final liv = pick(['livr', 'delai']);
  return OfferFacts(
    title: title,
    price: price,
    deliveryFee: deliveryFee,
    capacity: cap == null ? null : firstNumber(cap),
    material: pick(['mat']) ?? '',
    colors: pick(['coul']) ?? '',
    warrantyMonths: war == null ? null : warrantyMonths(war),
    deliveryDays: liv == null ? null : deliveryDays(liv),
    rating: rating,
    stock: stock,
  );
}

double _ratioAtLeast(double have, double want) => want <= 0 ? 1 : (have >= want ? 1 : (have / want).clamp(0, 1).toDouble());
double _ratioAtMost(double have, double want) => have <= 0 ? 1 : (have <= want ? 1 : (want / have).clamp(0, 1).toDouble());

/// Compatibilité de l'offre avec les critères, de 0 à 100 ; nulle si aucun critère n'est renseigné.
/// Chaque critère renseigné pèse autant que les autres ; une information absente chez le vendeur vaut 0 pour ce critère.
int? compatibility(OfferFacts f, CompareCriteria c) {
  final scores = <double>[];
  if (c.budget != null) {
    final total = (f.totalDelivered ?? f.price).toDouble();
    scores.add(total <= c.budget! ? 1 : (1 - (total - c.budget!) / c.budget!).clamp(0, 1).toDouble());
  }
  if (c.minCapacity != null) scores.add(f.capacity == null ? 0 : _ratioAtLeast(f.capacity!, c.minCapacity!));
  if (c.material.trim().isNotEmpty) scores.add(f.material.isEmpty ? 0 : (_fold(f.material).contains(_fold(c.material.trim())) ? 1 : 0));
  if (c.color.trim().isNotEmpty) scores.add(f.colors.isEmpty ? 0 : (_fold(f.colors).contains(_fold(c.color.trim())) ? 1 : 0));
  if (c.minWarrantyMonths != null) scores.add(f.warrantyMonths == null ? 0 : _ratioAtLeast(f.warrantyMonths!.toDouble(), c.minWarrantyMonths!.toDouble()));
  if (c.maxDeliveryDays != null) scores.add(f.deliveryDays == null ? 0 : _ratioAtMost(f.deliveryDays!.toDouble(), c.maxDeliveryDays!.toDouble()));
  if (scores.isEmpty) return null;
  return (scores.reduce((a, b) => a + b) / scores.length * 100).round();
}

/// Indice (0 ou 1) de l'offre qui gagne une ligne ; nul si égalité ou si l'une des deux valeurs manque. [lowerIsBetter] : prix, délai…
int? bestOf(num? a, num? b, {bool lowerIsBetter = false}) {
  if (a == null || b == null || a == b) return null;
  final firstWins = lowerIsBetter ? a < b : a > b;
  return firstWins ? 0 : 1;
}
