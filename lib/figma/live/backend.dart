import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth.dart';
import 'store.dart';

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
      await c.auth.signInWithPassword(email: loginOf(a), password: password);
    } on AuthException {
      // Compte local pas encore créé côté serveur : on l'inscrit puis on le connecte.
      await signUp(a, password);
    } catch (_) {}
  }

  static Future<void> signUp(Account a, String password) async {
    final c = _c;
    if (c == null) return;
    try {
      final r = await c.auth.signUp(email: loginOf(a), password: password);
      final id = r.user?.id;
      if (id == null) return;
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
    } catch (_) {}
  }

  static Future<void> signOut() async {
    try {
      await _c?.auth.signOut();
    } catch (_) {}
  }

  static Future<void> saveOrder(Order o) async {
    final c = _c;
    final uid = c?.auth.currentUser?.id;
    if (c == null || uid == null) return;
    try {
      final row = await c
          .from('orders')
          .insert({'number': o.id, 'buyer_id': uid, 'subtotal': o.subtotal, 'fee': o.fee, 'method': o.method, 'reference': o.reference, 'status': o.status, 'paid': o.paid})
          .select('id')
          .single();
      await c.from('order_lines').insert([
        for (final l in o.lines) {'order_id': row['id'], 'title': l.title, 'unit_price': l.price, 'qty': l.qty},
      ]);
    } catch (_) {}
  }

  static Future<void> audit(String actor, String action, String target, String category, String level) async {
    final c = _c;
    if (c == null || c.auth.currentUser == null) return;
    try {
      await c.from('audit_log').insert({'actor': actor, 'action': action, 'target': target, 'category': category, 'level': level});
    } catch (_) {}
  }
}
