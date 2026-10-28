import 'validators.dart';

/// Règles de validation des formulaires de la section D (renseignements, devis).
abstract final class ValidatorsD {
  /// Question au vendeur : 10 à 500 caractères.
  static String? question(String? v) {
    final t = v?.trim() ?? '';
    if (t.length < 10) return 'Écrivez votre question (10 caractères minimum).';
    if (t.length > 500) return 'Question trop longue : 500 caractères maximum.';
    return null;
  }

  /// Téléphone facultatif : vérifié seulement s'il est renseigné.
  static String? optionalPhone(String? v) => (v == null || v.trim().isEmpty) ? null : Validators.phoneCm(v);

  static String? quoteSubject(String? v) {
    final t = v?.trim() ?? '';
    if (t.length < 5) return 'Précisez l’objet de la demande (5 caractères minimum).';
    return null;
  }

  /// Description du besoin : 20 à 2000 caractères.
  static String? quoteNeed(String? v) {
    final t = v?.trim() ?? '';
    if (t.length < 20) return 'Décrivez votre besoin en 20 caractères minimum.';
    if (t.length > 2000) return 'Description trop longue : 2 000 caractères maximum.';
    return null;
  }
}
