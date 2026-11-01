import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth.dart';
import 'seller.dart' show Listing;
import '../../data/demo/section_a_demo.dart' show CartLine;

/// Connexion à la base Supabase (projet « boutik-ecole »).
/// La clé « publishable » est publique par conception : la sécurité repose sur les règles RLS de la base.
/// Sans connexion (tests, hors ligne) toutes les méthodes sont sans effet et l'application reste fonctionnelle.
class Backend {
  /// Production par défaut ; un environnement de test isolé se choisit au build :
  /// `flutter build web --dart-define=BE_URL=http://127.0.0.1:54321 --dart-define=BE_KEY=<clé publishable locale>`.
  static const url = String.fromEnvironment('BE_URL', defaultValue: 'https://zxqcnmgwhtbxkdpjqtlr.supabase.co');
  static const key = String.fromEnvironment('BE_KEY', defaultValue: 'sb_publishable_yYEzuivRZlBnVOkuMCiSow_syCjss01');
  static bool ready = false;

  /// Vrai entre l'ouverture du lien de réinitialisation reçu par e-mail (événement passwordRecovery) et le changement
  /// effectif du mot de passe : l'écran 16 n'enregistre un nouveau mot de passe que dans cet état.
  static final recovery = ValueNotifier<bool>(false);

  static Future<void> init() async {
    try {
      await Supabase.initialize(url: url, publishableKey: key);
      ready = true;
      // gotrue rejoue les événements passés : le passwordRecovery émis pendant l'initialisation est bien reçu ici.
      Supabase.instance.client.auth.onAuthStateChange.listen((s) {
        if (s.event == AuthChangeEvent.passwordRecovery) recovery.value = true;
      });
      await Future<void>.delayed(Duration.zero);
    } catch (_) {
      ready = false;
    }
  }

  /// Envoie le lien de réinitialisation (flux PKCE : le lien doit être ouvert dans ce même navigateur).
  /// Supabase répond de la même façon que le compte existe ou non : aucune information sur l'existence d'un compte ne fuit.
  static Future<String?> resetPassword(String email) async {
    final c = _c;
    if (c == null) return 'Connexion au serveur impossible.';
    try {
      await c.auth.resetPasswordForEmail(email, redirectTo: kIsWeb ? '${Uri.base.origin}/' : null);
      return null;
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (e.statusCode == '429' || m.contains('rate limit') || m.contains('security purposes')) {
        return 'Trop de demandes rapprochées : réessayez dans quelques minutes.';
      }
      return 'Envoi impossible : ${e.message}';
    } catch (_) {
      return 'Connexion au serveur impossible. Réessayez.';
    }
  }

  /// Renvoie l'e-mail de confirmation d'inscription (Supabase Auth). Retourne null si le serveur a accepté l'envoi.
  static Future<String?> resendSignupConfirmation(String email) async {
    final c = _c;
    if (c == null) return 'Connexion au serveur impossible.';
    try {
      await c.auth.resend(type: OtpType.signup, email: email);
      return null;
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (e.statusCode == '429' || m.contains('rate limit') || m.contains('security purposes')) {
        return 'Trop de demandes rapprochées : réessayez dans quelques minutes.';
      }
      return 'Envoi impossible : ${e.message}';
    } catch (_) {
      return 'Connexion au serveur impossible. Réessayez.';
    }
  }

  /// Enregistre le nouveau mot de passe pendant une récupération, puis ferme la session de récupération :
  /// l'utilisateur se reconnecte avec le nouveau mot de passe. Retourne null si le serveur a confirmé.
  static Future<String?> updatePassword(String password) async {
    if (!recovery.value) return 'Ouvrez d’abord, dans ce navigateur, le lien de réinitialisation reçu par e-mail.';
    final c = _c;
    if (c == null) return 'Connexion au serveur impossible.';
    if (c.auth.currentUser == null) {
      return 'Ouvrez d’abord, dans ce navigateur, le lien de réinitialisation reçu par e-mail.';
    }
    try {
      await c.auth.updateUser(UserAttributes(password: password));
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (e.code == 'same_password' || m.contains('different from the old')) return 'Choisissez un mot de passe différent de l’ancien.';
      if (e.code == 'weak_password' || m.contains('weak')) return 'Mot de passe trop faible : choisissez-en un plus long et plus varié.';
      if (m.contains('session') || m.contains('jwt')) return 'Le lien de réinitialisation a expiré : demandez-en un nouveau.';
      return 'Mot de passe non modifié : ${e.message}';
    } catch (_) {
      return 'Connexion au serveur impossible. Réessayez.';
    }
    recovery.value = false;
    await signOut();
    return null;
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
        signingOut = true;
        await c.auth.signOut();
        return (account: null, error: 'Profil introuvable. Contactez le support.');
      }
      final a = _fromRow(row, email);
      if (a.suspended) {
        signingOut = true;
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
      // le profil est créé plus tard, au choix du rôle (écran 13) : le rôle est ainsi fixé à la création
      return (exists: false, needsConfirm: false, error: null);
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('already') || e.code == 'user_already_exists') return (exists: true, needsConfirm: false, error: null);
      return (exists: false, needsConfirm: false, error: e.message);
    } catch (_) {
      return (exists: false, needsConfirm: false, error: 'Connexion au serveur impossible. Réessayez.');
    }
  }

  /// Crée le profil du compte connecté avec le rôle choisi (une seule fois : s'il existe déjà, rien n'est modifié).
  static Future<String?> createProfile(Account a) async {
    final c = _c;
    final uid = c?.auth.currentUser?.id;
    if (c == null || uid == null) return 'Connexion requise.';
    try {
      final exist = await c.from('profiles').select('id').eq('id', uid).maybeSingle();
      if (exist != null) return null;
      await _insertProfile(c, uid, a.name.isEmpty ? (a.email.split('@').first) : a.name, a.phone, a.email, _roles[a.role.clamp(0, 3)]);
      return null;
    } catch (e) {
      return _msg(e);
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
    final code = e is PostgrestException ? e.code : null;
    if (code == 'PGRST202' || code == 'PGRST205' || m.contains('Could not find the function') || m.contains('Could not find the table')) {
      return 'Cette fonction n’est pas encore activée sur le serveur (migration 20261031a à appliquer par l’administrateur de la base).';
    }
    if (m.contains('listings_titre_unique') || m.contains('duplicate key')) return 'Une annonce porte déjà ce titre. Choisissez un titre plus précis (marque, couleur, taille…).';
    if (m.contains('listings_price_min')) return 'Le prix doit être d’au moins 500 FCFA.';
    if (m.contains('listings_title_len')) return 'Le titre doit comporter de 3 à 80 caractères.';
    if (m.contains('listings_stock_check')) return 'Le stock doit être compris entre 0 et 100 000.';
    if (m.contains('row-level security')) return 'Votre compte n’est pas autorisé à publier des annonces (rôle étudiant-vendeur requis).';
    return m;
  }

  /// Annonces du vendeur connecté ; avec [platform] (département, administrateur), aussi les produits de la plateforme.
  static Future<List<Listing>> myListings({bool platform = false}) async {
    final c = _c;
    final uid = c?.auth.currentUser?.id;
    if (c == null || uid == null) return const [];
    try {
      final base = c.from('listings').select();
      final rows = await (platform ? base.or('seller_id.eq.$uid,seller_id.is.null') : base.eq('seller_id', uid)).neq('status', 'removed').order('created_at', ascending: false);
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

  /// Produits de la plateforme (annonces sans vendeur) publiés : prix, stock et description font foi côté serveur.
  static Future<List<Listing>?> platformListings() async {
    final c = _c;
    if (c == null) return null;
    try {
      final rows = await c.from('listings').select().eq('status', 'approved').isFilter('seller_id', null).order('title');
      return [for (final r in rows) Listing.fromRow(r)];
    } catch (_) {
      return null;
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

  static Future<String?> updateListing(String id, Map<String, dynamic> fields) async {
    final c = _c;
    if (c == null) return 'Connexion requise.';
    try {
      final r = await c.from('listings').update(fields).eq('id', id).select('id');
      return r.isEmpty ? 'Annonce introuvable ou non autorisée.' : null;
    } catch (e) {
      return _msg(e);
    }
  }

  /// URL publique d'une photo d'annonce (le stockage `listing-images` est en lecture publique, écriture réservée au propriétaire).
  static String listingImageUrl(String path) {
    try {
      return _c?.storage.from('listing-images').getPublicUrl(path) ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<({String? error, List<String> images})> addListingImage(String listingId, List<String> current, Uint8List bytes, String name, String mime) async {
    final c = _c;
    final uid = c?.auth.currentUser?.id;
    if (c == null || uid == null) return (error: 'Connexion requise.', images: current);
    if (current.length >= 8) return (error: '8 photos maximum.', images: current);
    final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = '$uid/$listingId/${DateTime.now().microsecondsSinceEpoch}-$safe';
    try {
      await c.storage.from('listing-images').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime));
    } catch (e) {
      final m = e.toString();
      if (m.contains('mime') || m.contains('415')) return (error: 'Format accepté : JPEG, PNG ou WebP.', images: current);
      if (m.contains('413') || m.contains('too large')) return (error: 'Photo trop lourde (5 Mo maximum).', images: current);
      return (error: 'Envoi de la photo impossible.', images: current);
    }
    final next = [...current, path];
    final err = await updateListing(listingId, {'images': next});
    if (err != null) {
      try {
        await c.storage.from('listing-images').remove([path]);
      } catch (_) {}
      return (error: err, images: current);
    }
    return (error: null, images: next);
  }

  static Future<({String? error, List<String> images})> removeListingImage(String listingId, List<String> current, String path) async {
    final c = _c;
    if (c == null) return (error: 'Connexion requise.', images: current);
    final next = [for (final p in current) if (p != path) p];
    final err = await updateListing(listingId, {'images': next});
    if (err != null) return (error: err, images: current);
    try {
      await c.storage.from('listing-images').remove([path]);
    } catch (_) {}
    return (error: null, images: next);
  }

  // ---------------------------------------------------------------- commandes reçues par le vendeur

  static Future<List<Map<String, dynamic>>> sellerOrders() async {
    final c = _c;
    if (c == null || c.auth.currentUser == null) return const [];
    try {
      final rows = await c.rpc('seller_orders') as List;
      return [for (final r in rows) Map<String, dynamic>.from(r as Map)];
    } catch (_) {
      return const [];
    }
  }

  static Future<String?> requestQuote(String service, String brief, int? budget, String deadline) =>
      _call('request_quote', {'p_service': service, 'p_brief': brief, 'p_budget': budget, 'p_deadline': deadline});

  static Future<String?> answerQuote(String id, int amount, int days, String message) =>
      _call('answer_quote', {'p_id': id, 'p_amount': amount, 'p_delay_days': days, 'p_message': message});

  static Future<String?> decideQuote(String id, bool accept) => _call('decide_quote', {'p_id': id, 'p_accept': accept});

  static Future<String?> cancelQuote(String id) => _call('cancel_quote', {'p_id': id});

  /// Demandes de devis de la personne connectée (envoyées ou reçues).
  static Future<List<Map<String, dynamic>>> myQuotes() async {
    final c = _c;
    if (c == null || c.auth.currentUser == null) return const [];
    try {
      final r = await c.from('quote_requests').select('id,requester_id,provider_id,brief,budget,deadline,status,quote_amount,quote_delay_days,quote_message,created_at,listings(title)').order('created_at', ascending: false);
      return [for (final x in r) Map<String, dynamic>.from(x as Map)];
    } catch (_) {
      return const [];
    }
  }

  /// Enregistre une action de l'utilisateur sur le serveur (inscription, candidature, vote, alerte, suivi, demande…).
  static Future<String?> engage(String kind, String ref, Map<String, dynamic> data) =>
      _call('engage', {'p_kind': kind, 'p_ref': ref, 'p_data': data});

  static Future<String?> cancelEngagement(String kind, String ref) => _call('cancel_engagement', {'p_kind': kind, 'p_ref': ref});

  /// Engagements de la personne connectée (isolés par le serveur), éventuellement filtrés par type ; les plus récents d'abord.
  static Future<List<Map<String, dynamic>>> myEngagements({String? kind}) async {
    final c = _c;
    if (c == null || c.auth.currentUser == null) return const [];
    try {
      var q = c.from('engagements').select('kind,ref,data,status,created_at,updated_at');
      if (kind != null) q = q.eq('kind', kind);
      final r = await q.order('updated_at', ascending: false);
      return [for (final x in r) Map<String, dynamic>.from(x as Map)];
    } catch (_) {
      return const [];
    }
  }

  /// Engagement précis (inscription, candidature…) de la personne connectée, ou null.
  static Future<Map<String, dynamic>?> myEngagement(String kind, String ref) async {
    final c = _c;
    if (c == null || c.auth.currentUser == null) return null;
    try {
      final r = await c.from('engagements').select('kind,ref,data,status,created_at,updated_at').eq('kind', kind).eq('ref', ref).maybeSingle();
      return r == null ? null : Map<String, dynamic>.from(r);
    } catch (_) {
      return null;
    }
  }

  /// Commandes de la personne connectée, avec leurs articles (isolées par le serveur).
  static Future<List<Map<String, dynamic>>> myOrders() async {
    final c = _c;
    if (c == null || c.auth.currentUser == null) return const [];
    try {
      final rows = await c.from('orders').select('number,subtotal,fee,method,reference,status,paid,cancelled,cancelled_at,created_at,order_lines(title,qty,unit_price,fulfillment)').order('created_at', ascending: false);
      return [for (final r in rows) Map<String, dynamic>.from(r as Map)];
    } catch (_) {
      return const [];
    }
  }

  /// Fait avancer la préparation d'une commande (1 acceptée · 2 en préparation · 3 prête · 4 livrée) ; l'acheteur est notifié par le serveur.
  static Future<String?> setSellerOrderStatus(String orderNumber, int status) async {
    final c = _c;
    if (c == null) return 'Connexion requise.';
    try {
      await c.rpc('set_seller_order_status', params: {'p_order': orderNumber, 'p_status': status});
      return null;
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

  // ---------------------------------------------------------------- notifications et messagerie (RLS : chacun ne lit que les siennes)

  static Future<List<Map<String, dynamic>>> notifications() async {
    final c = _c;
    if (c == null || c.auth.currentUser == null) return const [];
    try {
      final rows = await c.from('notifications').select().order('created_at', ascending: false).limit(100);
      return [for (final r in rows) Map<String, dynamic>.from(r)];
    } catch (_) {
      return const [];
    }
  }

  static Future<void> markNotificationsRead() async {
    try {
      await _c?.rpc('mark_notifications_read');
    } catch (_) {}
  }

  static Future<({int notifications, int messages})> unreadCounts() async {
    final c = _c;
    if (c == null || c.auth.currentUser == null) return (notifications: 0, messages: 0);
    try {
      final r = await c.rpc('unread_counts') as Map;
      return (notifications: (r['notifications'] as num?)?.toInt() ?? 0, messages: (r['messages'] as num?)?.toInt() ?? 0);
    } catch (_) {
      return (notifications: 0, messages: 0);
    }
  }

  // ---------------------------------------------------------------- conversations (RLS : seuls les participants lisent et écrivent)

  static String? get currentUserId => _c?.auth.currentUser?.id;

  static Future<List<Map<String, dynamic>>> conversations() async {
    final c = _c;
    if (c == null || c.auth.currentUser == null) return const [];
    try {
      final rows = await c.rpc('my_conversations') as List;
      return [for (final r in rows) Map<String, dynamic>.from(r as Map)];
    } catch (_) {
      return const [];
    }
  }

  static Future<List<Map<String, dynamic>>> messages(String conversationId) async {
    final c = _c;
    if (c == null || c.auth.currentUser == null || conversationId.isEmpty) return const [];
    try {
      final rows = await c.from('messages').select('id,sender_id,body,created_at,kind,attachment_path,attachment_name,attachment_size').eq('conversation_id', conversationId).order('id').limit(500);
      return [for (final r in rows) Map<String, dynamic>.from(r)];
    } catch (_) {
      return const [];
    }
  }

  static Future<String?> sendMessage(String conversationId, String body) async {
    final c = _c;
    final uid = c?.auth.currentUser?.id;
    if (c == null || uid == null) return 'Connexion requise.';
    try {
      await c.from('messages').insert({'conversation_id': conversationId, 'sender_id': uid, 'body': body});
      return null;
    } catch (e) {
      return _msg(e);
    }
  }

  /// Envoie une pièce jointe (photo, fichier, vocal) : dépôt dans le stockage privé de la conversation, puis message.
  static Future<String?> sendAttachment(String conversationId, String kind, Uint8List bytes, String name, String mime, String label) async {
    final c = _c;
    final uid = c?.auth.currentUser?.id;
    if (c == null || uid == null) return 'Connexion requise.';
    final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = '$conversationId/${DateTime.now().microsecondsSinceEpoch}-$safe';
    try {
      await c.storage.from('chat-files').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime));
    } catch (e) {
      final m = e.toString();
      if (m.contains('mime') || m.contains('415')) return 'Ce type de fichier n’est pas accepté.';
      if (m.contains('413') || m.contains('too large')) return 'Fichier trop volumineux (10 Mo maximum).';
      return 'Envoi du fichier impossible.';
    }
    try {
      await c.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': uid,
        'body': label,
        'kind': kind,
        'attachment_path': path,
        'attachment_name': name,
        'attachment_size': bytes.length,
      });
      return null;
    } catch (e) {
      try {
        await c.storage.from('chat-files').remove([path]);
      } catch (_) {}
      return _msg(e);
    }
  }

  /// Lien temporaire (1 h) vers une pièce jointe : n'est délivré qu'aux participants de la conversation.
  static Future<String?> chatFileUrl(String path) async {
    try {
      return await _c?.storage.from('chat-files').createSignedUrl(path, 3600);
    } catch (_) {
      return null;
    }
  }

  /// Conversation liée à une commande (acheteur → vendeur, ou vendeur → acheteur).
  static Future<({String? id, String? error})> startOrderConversation(String orderNumber, String body) async {
    final c = _c;
    if (c == null || c.auth.currentUser == null) return (id: null, error: 'Connexion requise.');
    try {
      final id = await c.rpc('start_order_conversation', params: {'p_order': orderNumber, 'p_body': body});
      return (id: id.toString(), error: null);
    } catch (e) {
      return (id: null, error: _msg(e));
    }
  }

  static Future<void> markConversationRead(String conversationId) async {
    try {
      await _c?.rpc('mark_conversation_read', params: {'cid': conversationId});
    } catch (_) {}
  }

  static Future<({String? id, String? error})> startConversation(String listingId, String body) async {
    final c = _c;
    if (c == null || c.auth.currentUser == null) return (id: null, error: 'Connexion requise.');
    try {
      final id = await c.rpc('start_conversation', params: {'p_listing': listingId, 'p_body': body});
      return (id: id.toString(), error: null);
    } catch (e) {
      return (id: null, error: _msg(e));
    }
  }

  static Future<({String listingId, bool hasSeller})?> listingContact(String title) async {
    final c = _c;
    if (c == null || title.isEmpty) return null;
    try {
      final rows = await c.rpc('listing_contact', params: {'p_title': title}) as List;
      if (rows.isEmpty) return null;
      final r = rows.first as Map;
      return (listingId: r['listing_id'].toString(), hasSeller: r['has_seller'] == true);
    } catch (_) {
      return null;
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

  /// Annulation avec motif (écran 47) ; tant que la migration 20261031a n'est pas appliquée, l'annulation simple est utilisée.
  static Future<String?> cancelOrderWithReason(String number, String reason) async {
    final c = _c;
    if (c == null) return 'Connexion requise.';
    try {
      await c.rpc('cancel_order_with_reason', params: {'p_number': number, 'p_reason': reason});
      return null;
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST202') return cancelOrder(number);
      return _msg(e);
    } catch (e) {
      return _msg(e);
    }
  }

  /// Avis vérifié : seul l'acheteur d'une commande payée, une fois l'article prêt, un avis par article.
  static Future<String?> submitReview(String order, String title, int rating, String comment) => _call(
      'submit_review', {'p_order': order, 'p_title': title, 'p_rating': rating, 'p_comment': comment});

  static Future<String?> submitClaim(String order, String reason, String details) =>
      _call('submit_claim', {'p_order': order, 'p_reason': reason, 'p_details': details});

  static Future<String?> reportListing(String title, String reason, String details) =>
      _call('report_listing', {'p_title': title, 'p_reason': reason, 'p_details': details});

  static Future<String?> answerClaim(String claimId, String message) => _call('answer_claim', {'p_claim': claimId, 'p_message': message});

  static Future<String?> _call(String fn, Map<String, dynamic> params) async {
    final c = _c;
    if (c == null) return 'Connexion requise.';
    try {
      await c.rpc(fn, params: params);
      return null;
    } catch (e) {
      return _msg(e);
    }
  }

  /// Fonction serveur qui renvoie une valeur (identifiant, code, objet) : (data, error) ; error null si succès.
  /// [timeout] : délai au-delà duquel l'appel est considéré comme échoué ([timeoutMessage] est alors renvoyé comme erreur).
  /// L'état réel côté serveur reste inconnu : le message doit le dire, jamais annoncer un succès.
  static Future<({Object? data, String? error})> rpc(String fn, Map<String, dynamic> params, {Duration? timeout, String? timeoutMessage}) async {
    final c = _c;
    if (c == null) return (data: null, error: 'Connexion requise.');
    try {
      final Future<dynamic> f = c.rpc(fn, params: params);
      return (data: (timeout == null ? await f : await f.timeout(timeout)) as Object?, error: null);
    } on TimeoutException {
      return (data: null, error: timeoutMessage ?? 'Le serveur n’a pas répondu à temps. Réessayez.');
    } catch (e) {
      return (data: null, error: _msg(e));
    }
  }

  /// Lecture d'une table protégée par RLS (le serveur ne renvoie que ce que le compte peut voir).
  static Future<({List<Map<String, dynamic>> rows, String? error})> rows(String table, String select,
      {Map<String, Object> eq = const {}, String? order, bool ascending = false, int limit = 50}) async {
    final c = _c;
    if (c == null) return (rows: const <Map<String, dynamic>>[], error: 'Connexion requise.');
    try {
      dynamic q = c.from(table).select(select);
      for (final e in eq.entries) {
        q = q.eq(e.key, e.value);
      }
      if (order != null) q = q.order(order, ascending: ascending);
      final r = await q.limit(limit);
      return (rows: [for (final x in r as List) Map<String, dynamic>.from(x as Map)], error: null);
    } catch (e) {
      return (rows: const <Map<String, dynamic>>[], error: _msg(e));
    }
  }

  /// Dépôt dans le compartiment privé « project-files » (chemin dans le dossier de la personne connectée).
  static Future<({String? path, String? error})> uploadProjectFile(String scope, String name, Uint8List bytes, String mime) async {
    final c = _c;
    final uid = c?.auth.currentUser?.id;
    if (c == null || uid == null) return (path: null, error: 'Connexion requise.');
    final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    final path = '$uid/$scope/${DateTime.now().microsecondsSinceEpoch}-$safe';
    try {
      await c.storage.from('project-files').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime));
      return (path: path, error: null);
    } on StorageException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('mime') || m.contains('type')) return (path: null, error: 'Type de fichier refusé (JPG, PNG, WebP, PDF, MP4, ZIP).');
      if (m.contains('size') || m.contains('large')) return (path: null, error: 'Fichier trop lourd (50 Mo au maximum).');
      if (m.contains('bucket')) return (path: null, error: 'Le stockage des fichiers n’est pas encore activé (migration 20261031b).');
      return (path: null, error: e.message);
    } catch (e) {
      return (path: null, error: _msg(e));
    }
  }

  /// Lien temporaire (1 h) vers un fichier du compartiment privé, si le compte y a droit.
  static Future<String?> projectFileUrl(String path) async {
    try {
      return await _c?.storage.from('project-files').createSignedUrl(path, 3600);
    } catch (_) {
      return null;
    }
  }

  /// Double authentification (TOTP) : facteurs du compte connecté.
  static Future<List<Factor>> totpFactors() async {
    final c = _c;
    if (c == null || c.auth.currentUser == null) return const [];
    try {
      return (await c.auth.mfa.listFactors()).totp;
    } catch (_) {
      return const [];
    }
  }

  static Future<({AuthMFAEnrollResponse? enrolled, String? error})> enrollTotp() async {
    final c = _c;
    if (c == null || c.auth.currentUser == null) return (enrolled: null, error: 'Connexion requise.');
    try {
      // un facteur jamais vérifié (activation abandonnée) est retiré avant d'en créer un nouveau
      for (final f in (await c.auth.mfa.listFactors()).all) {
        if (f.status == FactorStatus.unverified) await c.auth.mfa.unenroll(f.id);
      }
      return (enrolled: await c.auth.mfa.enroll(factorType: FactorType.totp, issuer: 'Boutik-École', friendlyName: 'Application ${DateTime.now().millisecondsSinceEpoch}'), error: null);
    } on AuthException catch (e) {
      return (enrolled: null, error: e.message.toLowerCase().contains('disabled') ? 'La double authentification n’est pas activée sur le serveur.' : e.message);
    }
  }

  static Future<String?> verifyTotp(String factorId, String code) async {
    final c = _c;
    if (c == null) return 'Connexion requise.';
    try {
      await c.auth.mfa.challengeAndVerify(factorId: factorId, code: code);
      return null;
    } on AuthException catch (e) {
      return e.message.toLowerCase().contains('invalid') ? 'Code incorrect ou expiré.' : e.message;
    }
  }

  /// Réclamations visibles par la personne connectée (les siennes, ou celles qui concernent ses ventes).
  static Future<List<Map<String, dynamic>>> claims() async {
    final c = _c;
    if (c == null) return const [];
    try {
      final r = await c.from('claims').select('id,order_id,reason,details,status,answer,created_at,claimant_id').order('created_at', ascending: false);
      return [for (final x in r) Map<String, dynamic>.from(x as Map)];
    } catch (_) {
      return const [];
    }
  }

  /// Notes de toutes les annonces : titre -> (moyenne, nombre d'avis). Les avis sont publics.
  static Future<Map<String, ({double average, int total})>> allRatings() async {
    final c = _c;
    if (c == null) return const {};
    try {
      final r = await c.from('reviews').select('rating,listings(title)');
      final sum = <String, int>{}, n = <String, int>{};
      for (final x in r) {
        final t = (x['listings'] as Map?)?['title'] as String?;
        if (t == null) continue;
        sum[t] = (sum[t] ?? 0) + (x['rating'] as int);
        n[t] = (n[t] ?? 0) + 1;
      }
      return {for (final t in n.keys) t: (average: (sum[t]! / n[t]!), total: n[t]!)};
    } catch (_) {
      return const {};
    }
  }

  /// Note moyenne publique d'une annonce.
  static Future<({double average, int total})?> listingRating(String title) async {
    final c = _c;
    if (c == null) return null;
    try {
      final r = await c.rpc('listing_rating', params: {'p_title': title}) as List;
      if (r.isEmpty || r.first['total'] == 0) return null;
      return (average: (r.first['average'] as num).toDouble(), total: r.first['total'] as int);
    } catch (_) {
      return null;
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

  /// Vrai pendant une déconnexion demandée par l'utilisateur (sinon, une perte de session est une expiration : écran 150-2).
  static bool signingOut = false;

  /// Administration (écran 128) : comptes lisibles par l'administrateur (RLS), les plus récents d'abord.
  static Future<List<Account>?> adminAccounts() async {
    final c = _c;
    if (c == null || c.auth.currentUser == null) return null;
    try {
      final rows = await c.from('profiles').select().order('created_at', ascending: false).limit(500);
      return [for (final r in rows) _fromRow(r, (r['email'] ?? '').toString())];
    } catch (_) {
      return null;
    }
  }

  /// Signalements d'annonces visibles par la modération (RLS : support, département, administration), les plus récents d'abord.
  static Future<List<Map<String, dynamic>>?> moderationReports() async {
    final c = _c;
    if (c == null || c.auth.currentUser == null) return null;
    try {
      final rows = await c.from('listing_reports').select('id,listing_id,reason,details,status,created_at,listings(title)').order('created_at', ascending: false).limit(200);
      return [for (final r in rows) Map<String, dynamic>.from(r)];
    } catch (_) {
      return null;
    }
  }

  /// Statut d'un signalement (open, reviewing, closed), appliqué par le serveur. Retourne null si le serveur a confirmé.
  static Future<String?> setReportStatus(String reportId, String status) async {
    final c = _c;
    if (c == null || c.auth.currentUser == null) return 'Connexion requise.';
    try {
      await c.rpc('set_report_status', params: {'p_report': reportId, 'p_status': status});
      return null;
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST202' || e.code == '42883') return 'Fonction serveur non encore installée (migration 20261101000000 à appliquer).';
      return e.message;
    } catch (_) {
      return 'Connexion au serveur impossible. Réessayez.';
    }
  }

  /// Rôle et suspension d'un compte, appliqués par le serveur (admin_set_account). Retourne null si le serveur a confirmé.
  static Future<String?> adminSetAccount(String userId, String role, bool suspended) async {
    final c = _c;
    if (c == null || c.auth.currentUser == null) return 'Connexion requise.';
    if (userId.isEmpty) return 'Compte sans identifiant serveur.';
    try {
      await c.rpc('admin_set_account', params: {'p_user': userId, 'p_role': role, 'p_suspended': suspended});
      return null;
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST202' || e.code == '42883') return 'Fonction serveur non encore installée (migration 20261101000000 à appliquer).';
      return e.message;
    } catch (_) {
      return 'Connexion au serveur impossible. Réessayez.';
    }
  }

  /// Ferme les sessions de ce compte sur TOUS les appareils.
  static Future<void> signOutAll() async {
    signingOut = true;
    try {
      await _c?.auth.signOut(scope: SignOutScope.global);
    } catch (_) {}
  }

  static Future<void> signOut() async {
    signingOut = true;
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
