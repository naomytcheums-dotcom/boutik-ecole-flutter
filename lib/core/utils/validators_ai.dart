import 'validators.dart';

/// Règles de validation de la section AI (Kéla et WhatsApp).
abstract final class AiValidators {
  /// Numéro WhatsApp : le numéro masqué déjà enregistré est accepté tel quel, sinon numéro camerounais valide.
  static String? whatsappNumber(String? v, {required String saved}) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Entrez votre numéro WhatsApp.';
    if (t == saved) return null;
    return Validators.phoneCm(t);
  }

  /// Message saisi dans le compositeur : non vide, 1 000 caractères au plus.
  static String? chatMessage(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Écrivez un message.';
    if (t.length > 1000) return 'Message trop long : 1 000 caractères maximum.';
    return null;
  }
}
