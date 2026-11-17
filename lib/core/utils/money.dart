/// Espace insécable : un montant ne doit jamais être coupé en fin de ligne.
const nbsp = '\u00A0';

/// Formate un montant en FCFA : `330000` → `330 000 FCFA`.
String fcfa(num amount, {bool withUnit = true}) {
  final negative = amount < 0;
  final digits = amount.abs().round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(nbsp);
    buf.write(digits[i]);
  }
  final value = '${negative ? '-' : ''}$buf';
  return withUnit ? '$value${nbsp}FCFA' : value;
}

/// Montant FCFA selon la langue : français `25 000 FCFA`, anglais `25,000 FCFA` (écran 185).
String fcfaLocalized(num amount, String languageCode) {
  if (languageCode != 'en') return fcfa(amount);
  return '${fcfa(amount, withUnit: false).replaceAll(nbsp, ',')}${nbsp}FCFA';
}

/// Règle de répartition d'un paiement (vendeur / fonds d'innovation / plateforme), en pourcentages.
/// La règle EN BASE (money_split_rules) fait foi : cette classe ne fait que la porter, aucune valeur n'est supposée.
class SplitRule {
  const SplitRule(this.beneficiary, this.institution, this.platform);
  final int beneficiary, institution, platform;

  /// Règle de la maquette hors connexion (`!Backend.ready`) : jamais utilisée avec le serveur.
  static const demo = SplitRule(70, 20, 10);

  /// Depuis `money_split_get()['current']` ; null si les pourcentages manquent ou sont incohérents.
  static SplitRule? fromServer(Object? current) {
    if (current is! Map) return null;
    final b = (current['beneficiary_pct'] as num?)?.toInt(), i = (current['institution_pct'] as num?)?.toInt(), p = (current['platform_pct'] as num?)?.toInt();
    if (b == null || i == null || p == null || b < 0 || i < 0 || p < 0 || b + i + p != 100) return null;
    return SplitRule(b, i, p);
  }

  String get label => '$beneficiary / $institution / $platform';
}

/// Ventilation d'un montant selon [rule] ; le reliquat d'arrondi revient à la plateforme (comme `money_split_amounts` côté serveur).
({int seller, int institution, int platform}) splitPayment(int amount, SplitRule rule) {
  final seller = (amount * rule.beneficiary) ~/ 100;
  final institution = (amount * rule.institution) ~/ 100;
  return (seller: seller, institution: institution, platform: amount - seller - institution);
}
