import 'package:boutik_ecole/figma/live/talent_passport.dart';
import 'package:boutik_ecole/figma/live/vendeur_public.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('S2-66 : les codes de certificat à 16 et 24 caractères sont acceptés, pas les autres', () {
    expect(normalizeCertificateCode('be-cert-0123456789abcdef'), 'BE-CERT-0123456789ABCDEF');
    expect(normalizeCertificateCode(' BE-CERT-0A1B2C3D '), 'BE-CERT-0A1B2C3D');
    expect(normalizeCertificateCode('BE-CERT-0123456789ABCDE'), isNull);
    expect(normalizeCertificateCode('BE-CERT-0123456789ABCDEF0'), isNull);
    expect(normalizeCertificateCode('BE-CERT-ZZZZZZZZ'), isNull);
    expect(normalizeCertificateCode(''), isNull);
  });

  test('S2-66 : le code est retrouvé en entier dans le contenu d\'un QR', () {
    expect(certificateCodeInText('https://boutik-ecole.vercel.app/?code=BE-CERT-0123456789ABCDEF&x=1'), 'BE-CERT-0123456789ABCDEF');
    expect(certificateCodeInText('code BE-CERT-0A1B2C3D.'), 'BE-CERT-0A1B2C3D');
    expect(certificateCodeInText('BE-CERT-0123456789ABCDEF0'), isNull);
    expect(certificateCodeInText('rien ici'), isNull);
  });

  test('S2-32 : libellés du Talent Passport', () {
    expect(passportSkillLevel('expert'), 'Expert');
    expect(passportLevelFraction('avance'), .75);
    expect(passportLevelFraction('inconnu'), .25);
    expect(passportYears(0), 'moins d’un an');
    expect(passportYears(2.5), '2,5 ans');
    expect(passportYears(1), '1 an');
    expect(passportBadgeLabel('missions', 3), '3 missions menées à terme');
    expect(passportBadgeLabel('missions', 1), '1 mission menée à terme');
    expect(passportBadgeLabel('helper', 1, level: 'silver'), 'Aidant Argent');
    expect(passportBadgeLabel('inconnu', 1), '');
  });
}
