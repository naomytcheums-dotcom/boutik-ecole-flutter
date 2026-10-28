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

/// Ventilation d'un paiement : 70 % vendeur, 20 % institution, 10 % plateforme.
({int seller, int institution, int platform}) splitPayment(int amount) {
  final seller = (amount * 70) ~/ 100;
  final institution = (amount * 20) ~/ 100;
  return (
    seller: seller,
    institution: institution,
    platform: amount - seller - institution,
  );
}
