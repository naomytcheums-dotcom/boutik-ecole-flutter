/// Validateurs des formulaires de la section J (entreprises et B2B).
abstract final class ValidatorsJ {
  /// Intitulé d'un besoin ou objet d'une demande : 3 à 80 caractères.
  static String? heading(String? v, String what) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return '$what est obligatoire.';
    if (t.length < 3 || t.length > 80) return '$what doit compter de 3 à 80 caractères.';
    return null;
  }

  /// Description d'au moins 20 caractères.
  static String? description(String? v) =>
      (v?.trim().length ?? 0) < 20 ? 'Décrivez le besoin en au moins 20 caractères.' : null;

  /// Quantité entière strictement positive (« 5 » ou « 5 unités »).
  static String? quantity(String? v) {
    final n = int.tryParse(RegExp(r'\d+').firstMatch(v ?? '')?.group(0) ?? '');
    return (n == null || n < 1) ? 'Indiquez une quantité supérieure à 0.' : null;
  }

  /// Montant en FCFA d'au moins 5 000 (espaces et « FCFA » acceptés).
  static String? budget(String? v) {
    final digits = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    final n = int.tryParse(digits);
    return (n == null || n < 5000) ? 'Indiquez un budget d’au moins 5 000 FCFA.' : null;
  }

  /// Date obligatoire.
  static String? date(String? v) => (v?.trim().isEmpty ?? true) ? 'Choisissez une date.' : null;
}
