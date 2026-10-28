/// Règles de validation des formulaires de la section E (livraison, réclamation).
abstract final class ValidatorsE {
  static String? recipient(String? v) {
    final t = v?.trim() ?? '';
    if (t.length < 2) return 'Le nom du destinataire est obligatoire.';
    return null;
  }

  static String? address(String? v) {
    final t = v?.trim() ?? '';
    if (t.length < 5) return 'Indiquez une adresse précise (5 caractères minimum).';
    return null;
  }

  static String? city(String? v) => (v == null || v.trim().isEmpty) ? 'Choisissez une ville et un quartier.' : null;

  /// Détails d'une réclamation : 20 à 1000 caractères.
  static String? claimDetails(String? v) {
    final t = v?.trim() ?? '';
    if (t.length < 20) return 'Décrivez le problème en 20 caractères minimum.';
    if (t.length > 1000) return 'Description trop longue : 1 000 caractères maximum.';
    return null;
  }
}
