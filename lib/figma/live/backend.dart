import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth.dart';
import '../../data/demo/section_a_demo.dart' show CartLine;

/// Connexion à la base Supabase (projet « boutik-ecole »).
/// La clé « publishable » est publique par conception : la sécurité repose sur les règles RLS de la base.
/// Sans connexion (tests, hors ligne) toutes les méthodes sont sans effet et l'application reste fonctionnelle.
class Backend {
  static const url = 'https://zxqcnmgwhtbxkdpjqtlr.supabase.co';
  static const key = 'sb_publishable_yYEzuivRZlBnVOkuMCiSow_syCjss01';
  static bool ready = false;

  static Future<void> init() async {
    try {
      await Supabase.initialize(url: url, publishableKey: key);
      ready = true;
    } catch (_) {
      ready = false;
    }
  }

  static SupabaseClient? get _c => ready ? Supabase.instance.client : null;

  /// Identifiant de connexion côté serveur : l'e-mail, ou un e-mail dérivé du téléphone.
  static String loginOf(Account a) => a.email.isNotEmpty ? a.email : '${a.phone}@phone.boutik-ecole.cm';

  static Future<void> signIn(Account a, String password) async {
    final c = _c;
    if (c == null) return;
    try {
      final r = await c.auth.signInWithPassword(email: loginOf(a), password: password);
      await _ensureProfile(a, r.user?.id);
    } on AuthException {
      // Compte local pas encore créé côté serveur : on l'inscrit puis on le connecte.
      await signUp(a, password);
    } catch (_) {}
  }

  /// Retourne true si une session est ouverte, false si une confirmation d'e-mail est requise, null si le serveur est indisponible.
  static Future<bool?> signUp(Account a, String password) async {
    final c = _c;
    if (c == null) return null;
    try {
      final r = await c.auth.signUp(email: loginOf(a), password: password);
      final id = r.user?.id;
      if (id == null || r.session == null) return r.user == null ? null : false;
      await c.from('profiles').upsert({
        'id': id,
        'name': a.name,
        'phone': a.phone,
        'email': a.email.isEmpty ? null : a.email,
        'role': const ['client', 'student', 'company', 'other'][a.role.clamp(0, 3)],
        'city': a.city,
        'institution': a.institution,
        'department': a.department,
      });
      return true;
    } catch (_) {
      return null;
    }
  }

  /// Crée le profil au premier passage connecté (cas de la confirmation d'e-mail, où l'inscription n'ouvre pas de session).
  static Future<void> _ensureProfile(Account a, String? id) async {
    final c = _c;
    if (c == null || id == null) return;
    try {
      await c.from('profiles').upsert({
        'id': id,
        'name': a.name,
        'phone': a.phone,
        'email': a.email.isEmpty ? null : a.email,
        'role': const ['client', 'student', 'company', 'other'][a.role.clamp(0, 3)],
        'city': a.city,
        'institution': a.institution,
        'department': a.department,
      }, ignoreDuplicates: true);
    } catch (_) {}
  }

  static Future<void> signOut() async {
    try {
      await _c?.auth.signOut();
    } catch (_) {}
  }

  /// Création de commande côté serveur : le serveur recalcule les prix, le client n'envoie que des titres et des quantités.
  /// Retourne {number, subtotal, fee} ou {error: message}.
  static Future<Map<String, dynamic>> createOrder(List<CartLine> lines, bool home, String method) async {
    final c = _c;
    if (c == null || c.auth.currentUser == null) return {'error': 'Connexion requise pour passer commande.'};
    try {
      final r = await c.rpc('create_order', params: {
        'p_items': [for (final l in lines) {'title': l.title, 'qty': l.qty}],
        'p_home': home,
        'p_method': method,
      });
      return Map<String, dynamic>.from(r as Map);
    } on PostgrestException catch (e) {
      return {'error': e.message};
    } catch (_) {
      return {'error': 'Connexion impossible au serveur.'};
    }
  }

  static Future<void> audit(String actor, String action, String target, String category, String level) async {
    final c = _c;
    if (c == null || c.auth.currentUser == null) return;
    try {
      // L'acteur est déterminé par le serveur (jamais fourni par le client).
      await c.rpc('log_audit', params: {'p_action': action, 'p_target': target, 'p_category': category, 'p_level': level});
    } catch (_) {}
  }
}
