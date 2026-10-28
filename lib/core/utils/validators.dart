/// Règles de validation des formulaires (messages de l'écran 275).
abstract final class Validators {
  static String? title(String? v) {
    final t = v?.trim() ?? '';
    if (t.length < 3 || t.length > 80) return 'Le titre est obligatoire (3 à 80 caractères).';
    return null;
  }

  static String? priceFcfa(String? v) {
    final digits = (v ?? '').replaceAll(RegExp(r'[\s\u00A0]'), '');
    final n = int.tryParse(digits);
    if (n == null || n <= 500) return 'Entrez un montant entier supérieur à 500 FCFA.';
    return null;
  }

  static const maxImageBytes = 5 * 1024 * 1024;
  static const imageExtensions = ['jpg', 'jpeg', 'png', 'webp'];

  static String? image(String name, int bytes) {
    final ext = name.split('.').last.toLowerCase();
    if (!imageExtensions.contains(ext) || bytes > maxImageBytes) {
      return 'Fichier trop lourd : 5 Mo maximum (JPG, PNG, WebP).';
    }
    return null;
  }

  static String? required(String? v, String label) => (v == null || v.trim().isEmpty) ? '$label est obligatoire.' : null;

  static String? email(String? v) {
    final t = v?.trim() ?? '';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) return 'Adresse e-mail invalide.';
    return null;
  }

  /// Numéro camerounais : 9 chiffres commençant par 6 (indicatif +237 facultatif).
  static String? phoneCm(String? v) {
    final d = (v ?? '').replaceAll(RegExp(r'[\s\u00A0.-]'), '').replaceFirst(RegExp(r'^(\+?237)'), '');
    if (!RegExp(r'^6\d{8}$').hasMatch(d)) return 'Numéro invalide : 9 chiffres commençant par 6.';
    return null;
  }

  /// Critères de mot de passe (écran 16) : 8 caractères, une majuscule, un chiffre, un caractère spécial.
  static ({bool length, bool upper, bool digit, bool special}) passwordCriteria(String v) => (
    length: v.length >= 8,
    upper: v.contains(RegExp(r'[A-Z]')),
    digit: v.contains(RegExp(r'\d')),
    special: v.contains(RegExp(r'[^A-Za-z0-9]')),
  );

  /// 0 à 4 critères respectés.
  static int passwordScore(String v) {
    final c = passwordCriteria(v);
    return [c.length, c.upper, c.digit, c.special].where((b) => b).length;
  }

  static String? password(String? v) =>
      (v == null || v.length < 8) ? 'Le mot de passe doit contenir au moins 8 caractères.' : null;

  static String? phoneOrEmail(String? v) => (email(v) == null || phoneCm(v) == null) ? null : 'Entrez un numéro ou un e-mail valide.';
}
