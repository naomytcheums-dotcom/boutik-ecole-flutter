/// Validateurs des formulaires de la section H (talents et parcours).
abstract final class ValidatorsH {
  /// Intitulé obligatoire de 3 à 80 caractères.
  static String? heading(String? v, String what) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return '$what est obligatoire.';
    if (t.length < 3 || t.length > 80) return '$what doit compter de 3 à 80 caractères.';
    return null;
  }

  /// Description d'au moins 20 caractères.
  static String? description(String? v) =>
      (v?.trim().length ?? 0) < 20 ? 'Décrivez en au moins 20 caractères (contexte, rôle, résultats).' : null;
}
