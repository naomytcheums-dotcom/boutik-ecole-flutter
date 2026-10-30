import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart';
import 'audit.dart';
import 'backend.dart';
import '../nav.dart';

/// Comptes, connexion, inscription, vérification et profil (écrans 10 à 18c).
class Account {
  const Account({
    required this.name,
    required this.phone,
    required this.email,
    required this.password,
    this.role = 1,
    this.verified = true,
    this.city = 'Douala',
    this.institution = 'IUT de Douala',
    this.department = 'Génie informatique',
    this.birth = '',
    this.suspended = false,
    this.staff = '',
    this.bio = '',
    this.skills = '',
    this.avatarUrl = '',
    this.certification = 'none',
    this.serverId = '',
  });
  final String name, phone, email, password, city, institution, department, birth;
  /// Description, compétences (séparées par des virgules), photo, état de certification (none · pending · review · approved · rejected · revoked) et identifiant Supabase.
  final String bio, skills, avatarUrl, certification, serverId;
  /// Le badge bleu n'existe que pour une certification réellement approuvée côté serveur.
  bool get certified => certification == 'approved';
  final int role; // 0 client · 1 étudiant vendeur · 2 entreprise · 3 autre
  final bool verified, suspended;
  final String staff; // rôle interne (Resp. département, Finance, Admin global…)

  String get roleLabel => staff.isNotEmpty ? staff : const ['Client', 'Étudiant-vendeur', 'Entreprise', 'Autre rôle'][role.clamp(0, 3)];

  String get firstName => name.split(' ').first;
  String get lastName => name.split(' ').length > 1 ? name.split(' ').skip(1).join(' ') : '';

  Account copyWith({String? name, String? password, int? role, bool? verified, String? city, String? institution, String? department, String? birth, bool? suspended, String? staff, String? bio, String? skills, String? avatarUrl, String? serverId}) => Account(
        name: name ?? this.name,
        phone: phone,
        email: email,
        password: password ?? this.password,
        role: role ?? this.role,
        verified: verified ?? this.verified,
        city: city ?? this.city,
        institution: institution ?? this.institution,
        department: department ?? this.department,
        birth: birth ?? this.birth,
        suspended: suspended ?? this.suspended,
        staff: staff ?? this.staff,
        bio: bio ?? this.bio,
        skills: skills ?? this.skills,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        certification: certification,
        serverId: serverId ?? this.serverId,
      );
}

const demoAccount = Account(name: 'Mariam Essono', phone: '690112233', email: 'mariam@iut-douala.cm', password: 'Boutik2026', bio: 'Étudiante en informatique, je crée des applications web et mobiles pour des clients locaux.', skills: 'Python, React, Mobile', certification: 'approved');
const demoCode = '482917';

/// Comptes internes de démonstration (écran 128).
const seedAccounts = <Account>[
  demoAccount,
  Account(name: 'Dr Mbarga', phone: '677000001', email: 'mbarga@iut-douala.cm', password: 'Boutik2026', role: 3, staff: 'Resp. département'),
  Account(name: 'Orange Cameroun', phone: '677000002', email: 'contact@orange.cm', password: 'Boutik2026', role: 2, institution: '—'),
  Account(name: 'Support 01', phone: '677000003', email: 'support@boutik-ecole.cm', password: 'Boutik2026', role: 3, staff: 'Support', institution: 'Plateforme'),
  Account(name: 'Carine Mbarga', phone: '677000004', email: 'carine@iut-douala.cm', password: 'Boutik2026', suspended: true),
  Account(name: 'Direction IUT', phone: '677000005', email: 'direction@iut-douala.cm', password: 'Boutik2026', role: 3, staff: 'Direction'),
  Account(name: 'Finance IUT', phone: '677000006', email: 'finance@iut-douala.cm', password: 'Boutik2026', role: 3, staff: 'Finance', institution: 'IUT de Douala'),
  Account(name: 'Super admin', phone: '677000007', email: 'admin@boutik-ecole.cm', password: 'Boutik2026', role: 3, staff: 'Admin global', institution: 'Plateforme'),
];

/// Compte connecté au démarrage (la démonstration commence avec l'étudiante) ; remplaçable dans les tests.
final initialAccountProvider = Provider<Account?>((_) => null);

/// Réinitialise tout l'état de l'application (branché par main.dart) : appelé à la déconnexion.
void Function()? appReset;

/// Session perdue sans déconnexion demandée : l'état est remis à zéro puis l'écran 150-2 « Session expirée » s'affiche.
void Function()? appSessionExpired;

class AuthState {
  const AuthState({this.accounts = seedAccounts, this.current, this.pending});
  final List<Account> accounts;
  final Account? current, pending;
  AuthState copy({List<Account>? accounts, Account? current, Account? pending, bool clearCurrent = false, bool clearPending = false}) => AuthState(
        accounts: accounts ?? this.accounts,
        current: clearCurrent ? null : (current ?? this.current),
        pending: clearPending ? null : (pending ?? this.pending),
      );
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => AuthState(current: ref.read(initialAccountProvider));

  void login(Account a) => state = state.copy(current: a);
  void logout() {
    saveRemembered(null);
    Backend.signOut();
    state = state.copy(clearCurrent: true);
    appReset?.call(); // aucun état du compte précédent ne survit (formulaires, annonces, panier, commandes…)
  }
  void register(Account a) => state = state.copy(accounts: [...state.accounts, a], pending: a);

  void update(Account a) {
    state = state.copy(
      accounts: [for (final x in state.accounts) x.email == a.email ? a : x],
      current: state.current?.email == a.email ? a : state.current,
      pending: state.pending?.email == a.email ? a : state.pending,
    );
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

/// Compte affiché sur le profil : connecté, sinon en cours d'inscription. Le compte de démonstration ne sert que hors connexion au serveur (tests, aperçu).
const _blankAccount = Account(name: '', phone: '', email: '', password: '', verified: false, institution: '', department: '', city: '');
final profileAccountProvider = Provider<Account>((ref) {
  final s = ref.watch(authProvider);
  return s.current ?? s.pending ?? (Backend.ready ? _blankAccount : demoAccount);
});

/// Valeurs saisies dans les formulaires (clé → texte) et messages d'erreur (clé → message).
class FormValues extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => const {};
  void put(String k, String v) => state = {...state, k: v};
  String get(String k) => state[k] ?? '';
  void clear(Iterable<String> keys) => state = {for (final e in state.entries) if (!keys.contains(e.key)) e.key: e.value};
}

final formProvider = NotifierProvider<FormValues, Map<String, String>>(FormValues.new);

class FormErrors extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => const {};
  void setAll(Map<String, String> m) => state = m;
  void clear() => state = const {};
}

final errorsProvider = NotifierProvider<FormErrors, Map<String, String>>(FormErrors.new);

class Flag extends Notifier<bool> {
  @override
  bool build() => true;
  void set(bool v) => state = v;
  void toggle() => state = !state;
}

/// Interrupteur éteint au départ : le consentement aux conditions doit être donné explicitement.
class FlagOff extends Flag {
  @override
  bool build() => false;
}

final termsProvider = NotifierProvider<FlagOff, bool>(FlagOff.new);

/// Vrai quand l'écran de connexion a été ouvert depuis une action réservée : après connexion on revient où l'on était.
final returnAfterAuthProvider = NotifierProvider<FlagOff, bool>(FlagOff.new);

void _afterLogin(WidgetRef ref, BuildContext context) {
  if (ref.read(returnAfterAuthProvider)) {
    ref.read(returnAfterAuthProvider.notifier).set(false);
    gBack(context);
  } else {
    gOpen(context, '03');
  }
}

/// Action réservée aux comptes. L'utilisateur explore librement : on ne lui demande de se connecter qu'au moment où l'action l'exige,
/// avec la possibilité de renoncer. Retourne true si un compte est connecté (ou si l'application est hors connexion serveur).
Future<bool> requireLogin(BuildContext context, WidgetRef ref, String pour) async {
  if (!Backend.ready || ref.read(authProvider).current != null) return true;
  const st = TextStyle(inherit: false, fontFamily: 'PlusJakartaSans', fontSize: 14, height: 1.45, color: Color(0xFF4A4854), textBaseline: TextBaseline.alphabetic);
  final choix = await gDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text('Un compte est nécessaire', style: st.copyWith(fontSize: 17, fontWeight: FontWeight.w700, color: const Color(0xFF111015))),
      content: Text('Pour $pour, connectez-vous ou créez un compte gratuit.\n\nVous pouvez continuer à explorer sans compte.', style: st),
      actionsOverflowAlignment: OverflowBarAlignment.end,
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop('later'), child: Text('Plus tard', style: st)),
        TextButton(onPressed: () => Navigator.of(ctx).pop('signup'), child: Text('Créer un compte', style: st.copyWith(fontWeight: FontWeight.w600, color: const Color(0xFF111015)))),
        TextButton(onPressed: () => Navigator.of(ctx).pop('login'), child: Text('Se connecter', style: st.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF5A3FE0)))),
      ],
    ),
  );
  if (choix == 'login' || choix == 'signup') {
    ref.read(returnAfterAuthProvider.notifier).set(true);
    if (context.mounted) gOpen(context, choix == 'login' ? '11' : '12');
  }
  return false;
}

class IntState extends Notifier<int> {
  @override
  int build() => 1;
  void set(int v) => state = v;
}

final signupRoleProvider = NotifierProvider<IntState, int>(IntState.new);
final loginModeProvider = NotifierProvider<IntState, int>(IntState.new);

// ------------------------------------------------------------------ validations

String? validName(String v) => v.trim().length < 3 ? 'Entrez votre nom complet (3 caractères minimum).' : null;

String normPhone(String v) {
  var d = v.replaceAll(RegExp(r'[^0-9+]'), '');
  if (d.startsWith('+237')) d = d.substring(4);
  if (d.startsWith('237') && d.length == 12) d = d.substring(3);
  return d;
}

String? validPhone(String v) => RegExp(r'^6\d{8}$').hasMatch(normPhone(v)) ? null : 'Numéro invalide : 9 chiffres commençant par 6.';

String? validEmail(String v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(v.trim()) ? null : 'Adresse e-mail invalide.';

String? validPassword(String v) {
  if (v.length < 8) return '8 caractères minimum.';
  if (!RegExp('[A-Z]').hasMatch(v)) return 'Ajoutez une lettre majuscule.';
  if (!RegExp('[0-9]').hasMatch(v)) return 'Ajoutez un chiffre.';
  return null;
}

// ------------------------------------------------------------------ actions

void _errors(WidgetRef ref, Map<String, String?> m) => ref.read(errorsProvider.notifier).setAll({for (final e in m.entries) if (e.value != null) e.key: e.value!});

/// Case « Se souvenir de moi » : garde le compte connecté entre deux visites.
class RememberV extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool v) => state = v;
}

final rememberProvider = NotifierProvider<RememberV, bool>(RememberV.new);
const _rememberKey = 'boutik_remember_email';

Future<void> saveRemembered(String? email) async {
  try {
    final p = await SharedPreferences.getInstance();
    if (email == null) {
      await p.remove(_rememberKey);
    } else {
      await p.setString(_rememberKey, email);
    }
  } catch (_) {}
}

Future<Account?> loadRemembered() async {
  try {
    final p = await SharedPreferences.getInstance();
    final e = p.getString(_rememberKey);
    if (Backend.ready) {
      // Avec le serveur : on ne reprend que la session réelle du titulaire qui a coché « Se souvenir de moi », sinon on la ferme.
      final live = Backend.sessionEmail;
      if (live == null) return null;
      if (e == null || e.toLowerCase() != live.toLowerCase()) {
        await Backend.signOut();
        return null;
      }
      return await Backend.restore();
    }
    if (e == null) return null;
    for (final a in seedAccounts) {
      if (a.email == e && !a.suspended) return a;
    }
  } catch (_) {}
  return null;
}

Widget rememberBox(double x, double y) => gP(
      x, y, 150, 18,
      Consumer(builder: (context, ref, _) {
        final on = ref.watch(rememberProvider);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => ref.read(rememberProvider.notifier).set(!on),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 16,
              height: 16,
              decoration: BoxDecoration(color: on ? const Color(0xFF111015) : Colors.transparent, borderRadius: BorderRadius.circular(5), border: on ? null : Border.all(color: const Color(0xFF66636E), width: 1.4)),
              child: on ? OverflowBox(maxWidth: 16, maxHeight: 16, child: Center(child: SizedBox(width: 14.667, height: 11.958, child: gImg('assets/figma/v/w_check.svg')))) : null,
            ),
            const SizedBox(width: 8),
            const Text('Se souvenir de moi', style: TextStyle(inherit: false, fontFamily: 'PlusJakartaSans', fontSize: 11.5, fontWeight: FontWeight.w500, color: Color(0xFF111015), textBaseline: TextBaseline.alphabetic)),
          ]),
        );
      }),
    );

void submitLogin(WidgetRef ref, BuildContext context) {
  final f = ref.read(formProvider);
  final id = (f['li_id'] ?? '').trim();
  final pw = f['li_pw'] ?? '';
  final isMail = id.contains('@');
  final errs = <String, String?>{
    'li_id': id.isEmpty ? 'Saisissez votre téléphone ou votre e-mail.' : (isMail ? validEmail(id) : validPhone(id)),
    'li_pw': pw.isEmpty ? 'Saisissez votre mot de passe.' : null,
  };
  if (errs.values.any((e) => e != null)) return _errors(ref, errs);
  if (Backend.ready) {
    _serverLogin(ref, context, id, pw, isMail);
    return;
  }
  final accounts = ref.read(authProvider).accounts;
  final hit = accounts.where((a) => (isMail ? a.email.toLowerCase() == id.toLowerCase() : a.phone == normPhone(id)) && a.password == pw).toList();
  if (hit.isEmpty) {
    _errors(ref, {'li_pw': 'Identifiant ou mot de passe incorrect.'});
    ref.read(auditProvider.notifier).log('Visiteur', 'Échec de connexion', id, 'Connexions', level: 'Sensible');
    return;
  }
  if (hit.first.suspended) {
    _errors(ref, {'li_pw': 'Compte suspendu. Contactez l’administration.'});
    ref.read(auditProvider.notifier).log(hit.first.name, 'Connexion refusée (compte suspendu)', id, 'Connexions', level: 'Sensible');
    return;
  }
  ref.read(errorsProvider.notifier).clear();
  ref.read(authProvider.notifier).login(hit.first);
  saveRemembered(ref.read(rememberProvider) ? hit.first.email : null);
  ref.read(auditProvider.notifier).log(hit.first.name, 'Connexion réussie', 'Application', 'Connexions');
  gToast(context, 'Bienvenue, ${hit.first.firstName} !');
  _afterLogin(ref, context);
}

Future<void> _serverLogin(WidgetRef ref, BuildContext context, String id, String pw, bool isMail) async {
  if (!isMail) return _errors(ref, {'li_id': 'Connectez-vous avec votre adresse e-mail.'});
  final r = await Backend.login(id, pw);
  final a = r.account;
  if (a == null) {
    _errors(ref, {'li_pw': r.error ?? 'Identifiant ou mot de passe incorrect.'});
    ref.read(auditProvider.notifier).log('Visiteur', 'Échec de connexion', id, 'Connexions', level: 'Sensible');
    return;
  }
  ref.read(errorsProvider.notifier).clear();
  ref.read(authProvider.notifier).login(a);
  saveRemembered(ref.read(rememberProvider) ? a.email : null);
  ref.read(auditProvider.notifier).log(a.name, 'Connexion réussie', 'Application', 'Connexions');
  if (!context.mounted) return;
  gToast(context, a.name.isEmpty ? 'Bienvenue !' : 'Bienvenue, ${a.firstName} !');
  _afterLogin(ref, context);
}

Future<void> _serverSignup(WidgetRef ref, BuildContext context, Account created) async {
  final r = await Backend.register(created, created.password);
  if (!context.mounted) return;
  if (r.exists) {
    await gAlert(context, 'Compte déjà existant', 'Un compte existe déjà avec l’adresse ${created.email}.\n\nConnectez-vous, ou utilisez « Mot de passe oublié » si vous ne vous en souvenez plus.', button: 'Compris');
    return;
  }
  if (r.error != null) {
    await gAlert(context, 'Inscription impossible', r.error!);
    return;
  }
  ref.read(errorsProvider.notifier).clear();
  ref.read(auditProvider.notifier).log(created.name, 'Compte créé', created.email, 'Comptes');
  if (r.needsConfirm) {
    await gAlert(context, 'Vérifiez votre boîte e-mail', 'Un lien de confirmation a été envoyé à ${created.email}. Cliquez dessus, puis connectez-vous.', button: 'Aller à la connexion');
    if (context.mounted) gOpen(context, '11');
    return;
  }
  final a = await Backend.restore() ?? created.copyWith(serverId: Backend.currentUserId ?? '');
  ref.read(authProvider.notifier).login(a);
  if (context.mounted) gOpen(context, '13');
}

void submitSignup(WidgetRef ref, BuildContext context) {
  final f = ref.read(formProvider);
  final errs = <String, String?>{
    'su_name': validName(f['su_name'] ?? ''),
    'su_phone': validPhone(f['su_phone'] ?? ''),
    'su_email': validEmail(f['su_email'] ?? ''),
    'su_pw': validPassword(f['su_pw'] ?? ''),
    'su_pw2': (f['su_pw'] ?? '') == (f['su_pw2'] ?? '') && (f['su_pw2'] ?? '').isNotEmpty ? null : 'Les mots de passe ne correspondent pas.',
  };
  if (errs.values.any((e) => e != null)) return _errors(ref, errs);
  if (!ref.read(termsProvider)) {
    gToast(context, 'Acceptez les conditions d’utilisation pour continuer.');
    return;
  }
  final created = Account(
    name: f['su_name']!.trim(),
    phone: normPhone(f['su_phone']!),
    email: f['su_email']!.trim(),
    password: f['su_pw']!,
    verified: false,
  );
  if (Backend.ready) {
    _serverSignup(ref, context, created);
    return;
  }
  final accounts = ref.read(authProvider).accounts;
  if (accounts.any((a) => a.email.toLowerCase() == created.email.toLowerCase())) {
    gAlert(context, 'Compte déjà existant', 'Un compte existe déjà avec l’adresse ${created.email}.\n\nConnectez-vous, ou utilisez « Mot de passe oublié ».');
    return;
  }
  ref.read(errorsProvider.notifier).clear();
  ref.read(authProvider.notifier).register(created);
  ref.read(formProvider.notifier).put('otp', '');
  ref.read(auditProvider.notifier).log(f['su_name']!.trim(), 'Compte créé', f['su_email']!.trim(), 'Comptes');
  gToast(context, 'Code envoyé par SMS (démonstration : $demoCode)');
  gOpen(context, '14');
}

void submitOtp(WidgetRef ref, BuildContext context) {
  final code = ref.read(formProvider)['otp'] ?? '';
  if (code.length < 6) {
    gToast(context, 'Entrez les 6 chiffres du code.');
    return;
  }
  if (code != demoCode) {
    gToast(context, 'Code incorrect. Réessayez.');
    return;
  }
  final p = ref.read(authProvider).pending;
  if (p != null) {
    final v = p.copyWith(verified: true);
    ref.read(authProvider.notifier).update(v);
    ref.read(authProvider.notifier).login(v);
  }
  gToast(context, 'Compte vérifié ✓');
  gOpen(context, '13');
}

/// Choix du rôle : c'est à cet instant que le profil serveur est créé, avec ce rôle. Ensuite seul l'administrateur peut le modifier.
Future<void> submitRole(WidgetRef ref, BuildContext context) async {
  final a = ref.read(authProvider).current;
  if (a != null) {
    final choisi = a.copyWith(role: ref.read(signupRoleProvider));
    if (Backend.ready) {
      final err = await Backend.createProfile(choisi);
      if (err != null) {
        if (context.mounted) await gAlert(context, 'Profil non créé', err);
        return;
      }
    }
    ref.read(authProvider.notifier).update(choisi);
  }
  if (context.mounted) gOpen(context, '18b');
}

Future<void> submitProfile(WidgetRef ref, BuildContext context) async {
  final f = ref.read(formProvider);
  final a = ref.read(authProvider).current;
  final first = (f['pf_first'] ?? a?.firstName ?? '').trim();
  final last = (f['pf_last'] ?? a?.lastName ?? '').trim();
  if (first.isEmpty || last.isEmpty) {
    _errors(ref, {if (first.isEmpty) 'pf_first': 'Prénom obligatoire.', if (last.isEmpty) 'pf_last': 'Nom obligatoire.'});
    return;
  }
  ref.read(errorsProvider.notifier).clear();
  if (a != null) {
    final maj = a.copyWith(
      name: '$first $last',
      city: (f['pf_city'] ?? a.city).trim(),
      institution: (f['pf_inst'] ?? a.institution).trim(),
      department: (f['pf_dept'] ?? a.department).trim(),
      birth: f['pf_birth'] ?? a.birth,
    );
    if (Backend.ready) {
      await Backend.createProfile(maj); // idempotent : crée le profil si le choix du rôle a été sauté
      if (!await Backend.saveProfile(maj)) {
        if (context.mounted) await gAlert(context, 'Profil non enregistré', 'Vos informations n’ont pas pu être enregistrées. Réessayez.');
        return;
      }
    }
    ref.read(authProvider.notifier).update(maj);
  }
  if (!context.mounted) return;
  gToast(context, 'Profil enregistré');
  gOpen(context, '18c');
}

void submitForgot(WidgetRef ref, BuildContext context) {
  final id = (ref.read(formProvider)['fg_id'] ?? '').trim();
  final err = id.isEmpty ? 'Saisissez votre téléphone ou votre e-mail.' : (id.contains('@') ? validEmail(id) : validPhone(id));
  if (err != null) return _errors(ref, {'fg_id': err});
  final exists = ref.read(authProvider).accounts.any((a) => id.contains('@') ? a.email.toLowerCase() == id.toLowerCase() : a.phone == normPhone(id));
  ref.read(errorsProvider.notifier).clear();
  ref.read(formProvider.notifier).put('fg_target', id);
  gToast(context, exists ? 'Code de réinitialisation envoyé (démonstration : $demoCode)' : 'Si un compte existe, un code a été envoyé.');
  gOpen(context, '16');
}

void submitReset(WidgetRef ref, BuildContext context) {
  final f = ref.read(formProvider);
  final errs = <String, String?>{
    'rs_pw': validPassword(f['rs_pw'] ?? ''),
    'rs_pw2': (f['rs_pw'] ?? '') == (f['rs_pw2'] ?? '') && (f['rs_pw2'] ?? '').isNotEmpty ? null : 'Les mots de passe ne correspondent pas.',
  };
  if (errs.values.any((e) => e != null)) return _errors(ref, errs);
  final id = f['fg_target'] ?? '';
  final accounts = ref.read(authProvider).accounts;
  for (final a in accounts) {
    if (id.contains('@') ? a.email.toLowerCase() == id.toLowerCase() : a.phone == normPhone(id)) {
      ref.read(authProvider.notifier).update(a.copyWith(password: f['rs_pw']!));
    }
  }
  ref.read(errorsProvider.notifier).clear();
  gToast(context, 'Mot de passe modifié. Connectez-vous.');
  gOpen(context, '11');
}

/// Message d'erreur rouge sous un champ.
Widget errorText(String key, double x, double y) => gP(
      x, y, 320, 13,
      Consumer(builder: (context, ref, _) => gText(ref.watch(errorsProvider)[key] ?? '', 10.5, const Color(0xFFD92D20), weight: 500)),
    );

// ------------------------------------------------------------------ profil (identité réelle)

/// Vrai tant qu'aucun serveur n'est joint (tests, aperçu) : seuls ces modes affichent le contenu d'exemple de la maquette.
bool get demoContent => !Backend.ready;

TextStyle _pt(double size, Color c, FontWeight w) => TextStyle(inherit: false, fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c, textBaseline: TextBaseline.alphabetic);

String _initials(String name) {
  final p = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (p.isEmpty) return '?';
  return (p.first[0] + (p.length > 1 ? p.last[0] : '')).toUpperCase();
}

/// Photo du titulaire, sinon avatar neutre avec ses initiales (jamais la photo d'un autre compte).
Widget profileAvatar(double x, double y, double size) => gP(
      x, y, size, size,
      Consumer(builder: (context, ref, _) {
        final a = ref.watch(profileAccountProvider);
        Widget initials() => Container(
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFEDE9F6)),
              alignment: Alignment.center,
              child: Text(_initials(a.name), style: _pt(size * .34, const Color(0xFF4A4854), FontWeight.w600)),
            );
        if (demoContent && a.email == demoAccount.email) return ClipOval(child: Image.asset('assets/figma/img/d902a4aabb7fd7d1d301a3bebd0f8ff54ecefb47.png', fit: BoxFit.cover, width: size, height: size));
        if (a.avatarUrl.isEmpty) return initials();
        return ClipOval(child: Image.network(a.avatarUrl, fit: BoxFit.cover, width: size, height: size, errorBuilder: (_, __, ___) => initials()));
      }),
    );

/// Nom centré, suivi du badge bleu uniquement si la certification a été approuvée côté serveur.
Widget profileNameBadge(double y) => gP(
      0, y, 390, 29,
      Consumer(builder: (context, ref, _) {
        final a = ref.watch(profileAccountProvider);
        final empty = a.name.trim().isEmpty;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Flexible(
              child: Text(empty ? 'Nom à compléter' : a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _pt(23, empty ? const Color(0xFF9A98A3) : const Color(0xFF111015), FontWeight.w500)),
            ),
            if (a.certified) ...[
              const SizedBox(width: 8),
              Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(color: Color(0xFF2F7DF6), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: SizedBox(width: 13, height: 10.6, child: gImg('assets/figma/v/w_check.svg')),
              ),
            ],
          ]),
        );
      }),
    );

/// Ligne sous le profil : compétences, sinon état de certification (avec la possibilité d'en faire la demande).
Widget profileSkillsOrCert(double y) => gP(
      0, y, 390, 15,
      Consumer(builder: (context, ref, _) {
        final a = ref.watch(profileAccountProvider);
        final skills = a.skills.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).map((e) => '#$e').join('   ');
        if (skills.isNotEmpty) return Center(child: Text(skills, style: _pt(12, const Color(0xFF66636E), FontWeight.w400)));
        const labels = {
          'pending': 'Certification en attente',
          'review': 'Certification en cours d’examen',
          'rejected': 'Certification refusée · refaire une demande',
          'revoked': 'Certification révoquée',
          'none': 'Demander la certification',
        };
        final label = labels[a.certification];
        if (label == null) return const SizedBox.shrink();
        final canAsk = a.certification == 'none' || a.certification == 'rejected';
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: canAsk ? () => requestCertificationFlow(ref, context) : null,
          child: Center(child: Text(label, style: _pt(12, canAsk ? const Color(0xFF5A3FE0) : const Color(0xFF66636E), canAsk ? FontWeight.w600 : FontWeight.w500))),
        );
      }),
    );

Future<void> requestCertificationFlow(WidgetRef ref, BuildContext context) async {
  if (!Backend.ready) return gAlert(context, 'Certification', 'La demande de certification nécessite la connexion au serveur.');
  final err = await Backend.requestCertification();
  if (!context.mounted) return;
  if (err != null) return gAlert(context, 'Demande impossible', err);
  final fresh = await Backend.restore();
  if (fresh != null) ref.read(authProvider.notifier).login(fresh);
  if (context.mounted) {
    await gAlert(context, 'Demande envoyée', 'Votre demande de certification est en attente. Le badge bleu n’apparaîtra qu’après examen et approbation par l’IUT.');
  }
}

Widget profileBio(double y) => gP(
      28.5, y, 333, 34,
      Consumer(builder: (context, ref, _) {
        final a = ref.watch(profileAccountProvider);
        final empty = a.bio.trim().isEmpty;
        return gText(empty ? 'Aucune description pour le moment.' : a.bio.trim(), 11.5, empty ? const Color(0xFF9A98A3) : const Color(0xFF6F6D77), lh: 17, align: TextAlign.center, wrap: true);
      }),
    );

Widget profileStat(double x, String label, int Function(WidgetRef ref) count) => gP(
      x, 519, 104, 14,
      Consumer(builder: (context, ref, _) => Center(child: Text('${count(ref)} $label', style: _pt(11.5, const Color(0xFF111015), FontWeight.w500)))),
    );

/// Département · établissement du titulaire (rien si non renseignés).
Widget profileSubline(double y) => gP(
      0, y, 390, 14,
      Consumer(builder: (context, ref, _) {
        final a = ref.watch(profileAccountProvider);
        final t = [a.department, a.institution].where((e) => e.trim().isNotEmpty && e != '—').join(' · ');
        return Center(child: Text(t, style: _pt(11.5, const Color(0xFF66636E), FontWeight.w400)));
      }),
    );

Widget profilePassport(double x, double y) => gP(
      x, y, 270, 15,
      Consumer(builder: (context, ref, _) {
        final a = ref.watch(profileAccountProvider);
        return gText(a.certified ? 'Talent Passport · Certifié' : 'Talent Passport · Non certifié', 12, const Color(0xFF111015), weight: 600);
      }),
    );


/// « Modifier mon profil » : description, compétences et ville du titulaire. Enregistré sur le serveur ; jamais le rôle ni la certification.
Future<void> editProfileDialog(BuildContext context, WidgetRef ref) async {
  if (!await requireLogin(context, ref, 'modifier votre profil')) return;
  final a = ref.read(authProvider).current;
  if (a == null || !context.mounted) return;
  final bio = TextEditingController(text: a.bio);
  final skills = TextEditingController(text: a.skills);
  final city = TextEditingController(text: a.city);
  const st = TextStyle(inherit: false, fontFamily: 'PlusJakartaSans', fontSize: 13.5, color: Color(0xFF111015), textBaseline: TextBaseline.alphabetic);
  InputDecoration deco(String h) => InputDecoration(hintText: h, hintStyle: st.copyWith(color: const Color(0xFF9A98A3)), isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)));
  final saved = await gDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text('Modifier mon profil', style: st.copyWith(fontSize: 17, fontWeight: FontWeight.w700)),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 340,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Description', style: st.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(controller: bio, style: st, maxLines: 4, maxLength: 300, decoration: deco('Présentez-vous en quelques lignes')),
            const SizedBox(height: 8),
            Text('Compétences (séparées par des virgules)', style: st.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(controller: skills, style: st, decoration: deco('Python, React, Design')),
            const SizedBox(height: 14),
            Text('Ville', style: st.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(controller: city, style: st, decoration: deco('Douala')),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Annuler', style: st)),
        TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('Enregistrer', style: st.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF5A3FE0)))),
      ],
    ),
  );
  if (saved != true) return;
  final updated = a.copyWith(bio: bio.text.trim(), skills: skills.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).join(', '), city: city.text.trim().isEmpty ? a.city : city.text.trim());
  if (Backend.ready && !await Backend.saveProfile(updated)) {
    if (context.mounted) await gAlert(context, 'Profil non enregistré', 'Vos modifications n’ont pas pu être enregistrées. Réessayez.');
    return;
  }
  ref.read(authProvider.notifier).update(updated);
  if (context.mounted) gToast(context, 'Profil enregistré');
}


/// « Se déconnecter de tous les appareils » : sessions révoquées côté serveur, puis retour à l'accueil.
Future<void> logoutEverywhere(WidgetRef ref, BuildContext context) async {
  await Backend.signOutAll();
  ref.read(authProvider.notifier).logout();
}
