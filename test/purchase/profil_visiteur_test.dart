import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('« Se souvenir de moi »', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('case décochée : le drapeau « session seulement » est posé et l’e-mail n’est pas gardé', () async {
      await applyRememberChoice('a@b.cm', false);
      final p = await SharedPreferences.getInstance();
      expect(p.getBool('boutik_session_only'), isTrue);
      expect(p.getString('boutik_remember_email'), isNull);
    });

    test('case cochée : le drapeau est effacé et l’e-mail gardé', () async {
      SharedPreferences.setMockInitialValues({'boutik_session_only': true});
      await applyRememberChoice('a@b.cm', true);
      final p = await SharedPreferences.getInstance();
      expect(p.getBool('boutik_session_only'), isNull);
      expect(p.getString('boutik_remember_email'), 'a@b.cm');
    });

    test('déconnexion : e-mail et drapeau sont effacés', () async {
      await applyRememberChoice('a@b.cm', false);
      await saveRemembered(null);
      final p = await SharedPreferences.getInstance();
      expect(p.getBool('boutik_session_only'), isNull);
      expect(p.getString('boutik_remember_email'), isNull);
    });
  });

  group('messages serveur', () {
    test('les refus de publication d’un compte suspendu sont expliqués', () {
      for (final raw in ['Publication réservée aux étudiants et au département', 'Histoires réservées aux étudiants et au département']) {
        expect(Backend.userMessage(raw), 'Votre compte est suspendu : publication impossible. Contactez l’administration.');
      }
    });

    test('un message métier lisible reste inchangé', () {
      expect(Backend.userMessage('Stock insuffisant'), 'Stock insuffisant');
    });
  });
}
