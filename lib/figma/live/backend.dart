import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth.dart';
import 'seller.dart' show Listing;
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

  static const _roles = ['client', 'student', 'company', 'other'];
  static const _staff = {'dept': 'Resp. département', 'direction': 'Direction', 'finance': 'Finance', 'support': 'Support', 'admin': 'Admin global'};

  /// Compte construit uniquement à partir de la ligne de profil du titulaire (aucune valeur empruntée à un autre compte).
  static Account _fromRow(Map<String, dynamic> r, String email) {
    final role = (r['role'] ?? 'client').toString();
    final idx = _roles.indexOf(role);
    return Account(
      name: (r['name'] ?? '').toString(),
      phone: (r['phone'] ?? '').toString(),
      email: (r['email'] ?? email).toString(),
      password: '',
      role: idx < 0 ? 3 : idx,
      staff: _staff[role] ?? '',
      verified: true,
      city: (r['city'] ?? '').toString(),
      institution: (r['institution'] ?? '').toString(),
      department: (r['department'] ?? '').toString(),
      birth: (r['birth'] ?? '').toString(),
      suspended: r['suspended'] == true,
      bio: (r['bio'] ?? '').toString(),
      skills: (r['skills'] ?? '').toString(),
      avatarUrl: (r['avatar_url'] ?? '').toString(),
      certification: (r['certification'] ?? 'none').toString(),
      serverId: (r['id'] ?? '').toString(),
    );
  }

  /// Connexion réelle : le profil est chargé exclusivement avec l'identifiant de la session ouverte.
  static Future<({Account? account, String? error})> login(String email, String password) async {
    final c = _c;
    if (c == null) return (account: null, error: 'Connexion au serveur impossible.');
    try {
      final r = await c.auth.signInWithPassword(email: email, password: password);
      final user = r.user;
      if (user == null) return (account: null, error: 'Identifiant ou mot de passe incorrect.');
      var row = await c.from('profiles').select().eq('id', user.id).maybeSingle();
      if (row == null) {
        // Profil absent (inscription interrompue) : on l'initialise vierge, pour CET utilisateur uniquement.
        final meta = user.userMetadata ?? const {};
        final name = (meta['name'] ?? '').toString().trim();
        await _insertProfile(c, user.id, name.isEmpty ? email.split('@').first : name, (meta['phone'] ?? '').toString(), email, 'client');
        row = await c.from('profiles').select().eq('id', user.id).maybeSingle();
      }
      if (row == null) {
        await c.auth.signOut();
        return (account: null, error: 'Profil introuvable. Contactez le support.');
      }
      final a = _fromRow(row, email);
      if (a.suspended) {
        await c.auth.signOut();
        return (account: null, error: 'Compte suspendu. Contactez l’administration.');
      }
      return (account: a, error: null);
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('not confirmed')) return (account: null, error: 'Confirmez d’abord votre adresse e-mail (lien reçu par e-mail).');
      if (m.contains('banned')) return (account: null, error: 'Ce compte est désactivé.');
      return (account: null, error: 'Identifiant ou mot de passe incorrect.');
    } catch (_) {
      return (account: null, error: 'Connexion au serveur impossible. Réessayez.');
    }
  }

  static Future<void> _insertProfile(SupabaseClient c, String id, String name, String phone, String email, String role) async {
    final base = {
      'id': id,
      'name': name,
      'email': email.isEmpty ? null : email,
      'role': role,
    };
    try {
      await c.from('profiles').insert({...base, 'phone': phone.isEmpty ? null : phone});
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        // numéro déjà rattaché à un autre compte : on ne touche pas à ce compte, le profil est créé sans numéro
        await c.from('profiles').insert(base);
      } else {
        rethrow;
      }
    }
  }

  /// Inscription réelle. exists : adresse déjà utilisée · needsConfirm : confirmation d'e-mail requise · error : échec technique.
  static Future<({bool exists, bool needsConfirm, String? error})> register(Account a, String password) async {
    final c = _c;
    if (c == null) return (exists: false, needsConfirm: false, error: 'Connexion au serveur impossible.');
    try {
      final r = await c.auth.signUp(email: loginOf(a), password: password, data: {'name': a.name, 'phone': a.phone});
      final user = r.user;
      if (user == null) return (exists: false, needsConfirm: false, error: 'Inscription impossible. Réessayez.');
      if (user.identities != null && user.identities!.isEmpty) return (exists: true, needsConfirm: false, error: null);
      if (r.session == null) return (exists: false, needsConfirm: true, error: null);
      await _insertProfile(c, user.id, a.name, a.phone, a.email, _roles[a.role.clamp(0, 3)]);
      return (exists: false, needsConfirm: false, error: null);
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('already') || e.code == 'user_already_exists') return (exists: true, needsConfirm: false, error: null);
      return (exists: false, needsConfirm: false, error: e.message);
    } catch (_) {
      return (exists: false, needsConfirm: false, error: 'Connexion au serveur impossible. Réessayez.');
    }
  }

  /// Enregistre les champs que le titulaire a le droit de modifier (jamais le rôle, jamais la certification).
  static Future<bool> saveProfile(Account a) async {
    final c = _c;
    final uid = c?.auth.currentUser?.id;
    if (c == null || uid == null) return false;
    try {
      await c.from('profiles').update({
        'name': a.name,
        'city': a.city,
        'institution': a.institution,
        'department': a.department,
        'bio': a.bio,
        'skills': a.skills,
      }).eq('id', uid);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Favoris de l'utilisateur connecté : titres des annonces (la politique RLS ne renvoie que ses propres lignes).
  static Future<List<String>> loadFavorites() async {
    final c = _c;
    final uid = c?.auth.currentUser?.id;
    if (c == null || uid == null) return const [];
    try {
      final rows = await c.from('favorites').select('listing_id, listings(title)').eq('user_id', uid);
      return [
        for (final r in rows)
          if (((r['listings'] as Map?)?['title'] ?? '').toString().isNotEmpty) (r['listings'] as Map)['title'].toString(),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Ajoute ou retire un favori ; retourne false si l'écriture a échoué.
  static Future<bool> setFavorite(String title, bool on) async {
    final c = _c;
    final uid = c?.auth.currentUser?.id;
    if (c == null || uid == null) return false;
    try {
      final l = await c.from('listings').select('id').eq('title', title).isFilter('seller_id', null).maybeSingle();
      if (l == null) return false;
      if (on) {
        await c.from('favorites').upsert({'user_id': uid, 'listing_id': l['id']});
      } else {
        await c.from('favorites').delete().eq('user_id', uid).eq('listing_id', l['id']);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------- annonces et stock (RLS : chaque vendeur ne voit que les siennes)

  static String _msg(Object e) {
    final m = e is PostgrestException ? e.message : e.toString();
    if (m.contains('listings_titre_unique') || m.contains('duplicate key')) return 'Une annonce porte déjà ce titre.';
    if (m.contains('listings_price_min')) return 'Le prix doit être d’au moins 500 FCFA.';
    if (m.contains('listings_title_len')) return 'Le titre doit comporter de 3 à 80 caractères.';
    if (m.contains('listings_stock_check')) return 'Le stock doit être compris entre 0 et 100 000.';
    if (m.contains('row-level security')) return 'Votre compte n’est pas autorisé à publier des annonces (rôle étudiant-vendeur requis).';
    return m;
  }

  static Future<List<Listing>> myListings() async {
    final c = _c;
    final uid = c?.auth.currentUser?.id;
    if (c == null || uid == null) return const [];
    try {
      final rows = await c.from('listings').select().eq('seller_id', uid).neq('status', 'removed').order('created_at', ascending: false);
      return [for (final r in rows) Listing.fromRow(r)];
    } catch (_) {
      return const [];
    }
  }

  static Future<List<Listing>> publicListings() async {
    final c = _c;
    if (c == null) return const [];
    try {
      final rows = await c.from('listings').select().eq('status', 'approved').not('seller_id', 'is', null).order('created_at', ascending: false).limit(200);
      return [for (final r in rows) Listing.fromRow(r)];
    } catch (_) {
      return const [];
    }
  }

  static Future<({Listing? listing, String? error})> createListing(Listing l, {required bool submit}) async {
    final c = _c;
    final uid = c?.auth.currentUser?.id;
    if (c == null || uid == null) return (listing: null, error: 'Connexion requise pour enregistrer une annonce.');
    try {
      final dept = (await restore())?.department ?? '';
      final row = await c.from('listings').insert({
        'seller_id': uid,
        'title': l.title.trim(),
        'department': dept.isNotEmpty ? dept : 'IUT de Douala',
        'category': l.category,
        'price': l.price,
        'stock': l.stock,
        'description': l.description.trim().isEmpty ? null : l.description.trim(),
        'status': submit ? 'pending' : 'draft',
      }).select().single();
      return (listing: Listing.fromRow(row), error: null);
    } catch (e) {
      return (listing: null, error: _msg(e));
    }
  }

  static Future<String?> updateListingStock(String id, int stock) async {
    final c = _c;
    if (c == null) return 'Connexion requise.';
    try {
      final r = await c.from('listings').update({'stock': stock}).eq('id', id).select('id');
      return r.isEmpty ? 'Annonce introuvable ou non autorisée.' : null;
    } catch (e) {
      return _msg(e);
    }
  }

  static Future<String?> setListingStatus(String id, String status) async {
    final c = _c;
    if (c == null) return 'Connexion requise.';
    try {
      final r = await c.from('listings').update({'status': status}).eq('id', id).select('id');
      return r.isEmpty ? 'Annonce introuvable ou non autorisée.' : null;
    } catch (e) {
      return _msg(e);
    }
  }

  /// File de validation (département / administrateur : la RLS ne renvoie rien aux autres rôles).
  static Future<List<Map<String, dynamic>>> reviewQueue() async {
    final c = _c;
    if (c == null || c.auth.currentUser == null) return const [];
    try {
      final rows = await c.from('listings').select('id,title,category,price,seller_id,status,review_note,created_at,updated_at').not('seller_id', 'is', null).inFilter('status', ['pending', 'approved', 'rejected']).order('updated_at', ascending: false).limit(200);
      return [for (final r in rows) Map<String, dynamic>.from(r)];
    } catch (_) {
      return const [];
    }
  }

  static Future<String?> decideListing(String id, bool approve, String note) async {
    final c = _c;
    if (c == null) return 'Connexion requise.';
    try {
      final r = await c.from('listings').update({'status': approve ? 'approved' : 'rejected', 'review_note': note.isEmpty ? null : note}).eq('id', id).select('id');
      return r.isEmpty ? 'Décision non autorisée pour votre rôle.' : null;
    } catch (e) {
      return _msg(e);
    }
  }

  /// Annule une commande impayée : le stock réservé est restitué par le serveur.
  static Future<String?> cancelOrder(String number) async {
    final c = _c;
    if (c == null) return 'Connexion requise.';
    try {
      await c.rpc('cancel_order', params: {'p_number': number});
      return null;
    } catch (e) {
      return _msg(e);
    }
  }

  /// Dépose une demande de certification (état « en attente ») ; la décision appartient au département.
  static Future<String?> requestCertification() async {
    final c = _c;
    if (c == null) return 'Connexion au serveur impossible.';
    try {
      await c.rpc('request_certification');
      return null;
    } on PostgrestException catch (e) {
      return e.message;
    } catch (_) {
      return 'Connexion au serveur impossible.';
    }
  }

  /// Adresse de la session ouverte (le client Supabase conserve la session dans le navigateur).
  static String? get sessionEmail => _c?.auth.currentUser?.email;

  /// Recharge le profil du titulaire de la session ouverte, rien d'autre.
  static Future<Account?> restore() async {
    final c = _c;
    final u = c?.auth.currentUser;
    if (c == null || u == null) return null;
    try {
      final row = await c.from('profiles').select().eq('id', u.id).maybeSingle();
      if (row == null) return null;
      final a = _fromRow(row, u.email ?? '');
      return a.suspended ? null : a;
    } catch (_) {
      return null;
    }
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
