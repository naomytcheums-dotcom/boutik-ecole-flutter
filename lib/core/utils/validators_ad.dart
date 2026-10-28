/// Règles de validation des formulaires de la section AD (vœux et duels).
abstract final class ValidatorsAD {
  static int? _amount(String? v) => int.tryParse((v ?? '').replaceAll(RegExp(r'[^0-9]'), ''));

  static String? wishTitle(String? v) {
    final t = v?.trim() ?? '';
    if (t.length < 3 || t.length > 80) return 'Indiquez le produit à fabriquer (3 à 80 caractères).';
    return null;
  }

  static String? description(String? v) {
    if ((v?.trim().length ?? 0) < 10) return 'Décrivez le produit : 10 caractères minimum.';
    return null;
  }

  static String? price(String? v) {
    final n = _amount(v);
    if (n == null || n < 1000) return 'Entrez un prix d’au moins 1 000 FCFA.';
    return null;
  }

  static String? threshold(String? v) {
    final n = int.tryParse((v ?? '').trim());
    if (n == null || n < 30) return 'Le seuil doit être d’au moins 30 précommandes.';
    return null;
  }

  static String? need(String? v) {
    final t = v?.trim() ?? '';
    if (t.length < 5) return 'Décrivez votre besoin (5 caractères minimum).';
    return null;
  }

  static String? prize(String? v) {
    final n = _amount(v);
    if (n == null || n < 5000) return 'Le prix du gagnant doit être d’au moins 5 000 FCFA.';
    return null;
  }
}
