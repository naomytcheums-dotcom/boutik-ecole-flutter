import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart';
import 'audit.dart';
import 'backend.dart';
import 'profile_data.dart' show saveAcademic;
import 'lots.dart' show formDialog;
import 'drafts.dart';
import 'native_push_stub.dart'
    if (dart.library.io) 'native_push.dart'
    as native_push;
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
    this.matricule = '',
    this.institutionId = '',
    this.departmentId = '',
    this.studyLevel = '',
  });
  final String name,
      phone,
      email,
      password,
      city,
      institution,
      department,
      birth;

  /// Description, compétences (séparées par des virgules), photo, état de certification (none · pending · review · approved · rejected · revoked) et identifiant Supabase.
  final String bio, skills, avatarUrl, certification, serverId;

  /// Matricule saisi par la personne (jamais généré), références du référentiel et niveau d'études.
  final String matricule, institutionId, departmentId, studyLevel;

  /// Le badge bleu n'existe que pour une certification réellement approuvée côté serveur.
  bool get certified => certification == 'approved';
  final int role; // 0 client · 1 étudiant vendeur · 2 entreprise · 3 autre
  final bool verified, suspended;
  final String
  staff; // rôle interne (Resp. département, Finance, Admin global…)

  String get roleLabel => staff.isNotEmpty
      ? staff
      : const ['Client', 'Étudiant-vendeur', 'Entreprise', 'Autre rôle'][role
            .clamp(0, 3)];

  String get firstName => name.split(' ').first;
  String get lastName =>
      name.split(' ').length > 1 ? name.split(' ').skip(1).join(' ') : '';

  Account copyWith({
    String? name,
    String? password,
    int? role,
    bool? verified,
    String? city,
    String? institution,
    String? department,
    String? birth,
    bool? suspended,
    String? staff,
    String? bio,
    String? skills,
    String? avatarUrl,
    String? serverId,
    String? matricule,
    String? institutionId,
    String? departmentId,
    String? studyLevel,
  }) => Account(
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
    matricule: matricule ?? this.matricule,
    institutionId: institutionId ?? this.institutionId,
    departmentId: departmentId ?? this.departmentId,
    studyLevel: studyLevel ?? this.studyLevel,
  );
}

const demoAccount = Account(
  name: 'Mariam Essono',
  phone: '690112233',
  email: 'mariam@iut-douala.cm',
  password: 'Boutik2026',
  bio: 'Étudiante en informatique, je crée des applications web et mobiles pour des clients locaux.',
  skills: 'Python, React, Mobile',
  certification: 'approved',
);
const demoCode = '482917';

/// Comptes internes de démonstration (écran 128).
const seedAccounts = <Account>[
  demoAccount,
  Account(
    name: 'Dr Mbarga',
    phone: '677000001',
    email: 'mbarga@iut-douala.cm',
    password: 'Boutik2026',
    role: 3,
    staff: 'Resp. département',
  ),
  Account(
    name: 'Orange Cameroun',
    phone: '677000002',
    email: 'contact@orange.cm',
    password: 'Boutik2026',
    role: 2,
    institution: '—',
  ),
  Account(
    name: 'Support 01',
    phone: '677000003',
    email: 'support@boutik-ecole.cm',
    password: 'Boutik2026',
    role: 3,
    staff: 'Support',
    institution: 'Plateforme',
  ),
  Account(
    name: 'Carine Mbarga',
    phone: '677000004',
    email: 'carine@iut-douala.cm',
    password: 'Boutik2026',
    suspended: true,
  ),
  Account(
    name: 'Direction IUT',
    phone: '677000005',
    email: 'direction@iut-douala.cm',
    password: 'Boutik2026',
    role: 3,
    staff: 'Direction',
  ),
  Account(
    name: 'Finance IUT',
    phone: '677000006',
    email: 'finance@iut-douala.cm',
    password: 'Boutik2026',
    role: 3,
    staff: 'Finance',
    institution: 'IUT de Douala',
  ),
  Account(
    name: 'Super admin',
    phone: '677000007',
    email: 'admin@boutik-ecole.cm',
    password: 'Boutik2026',
    role: 3,
    staff: 'Admin global',
    institution: 'Plateforme',
  ),
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
  AuthState copy({
    List<Account>? accounts,
    Account? current,
    Account? pending,
    bool clearCurrent = false,
    bool clearPending = false,
  }) => AuthState(
    accounts: accounts ?? this.accounts,
    current: clearCurrent ? null : (current ?? this.current),
    pending: clearPending ? null : (pending ?? this.pending),
  );
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    final a = ref.read(initialAccountProvider);
    gSelfAvatarUrl = a?.avatarUrl ?? '';
    return AuthState(current: a);
  }

  void login(Account a) {
    gSelfAvatarUrl = a.avatarUrl;
    state = state.copy(current: a);
    unawaited(native_push.syncNativePushForCurrentUser());
  }

  void logout() {
    saveRemembered(null);
    Drafts.clearAll(); // brouillons de cet appareil : jamais visibles par l'utilisateur suivant
    Backend.signOut();
    gSelfAvatarUrl = '';
    state = state.copy(clearCurrent: true);
    appReset?.call(); // aucun état du compte précédent ne survit (formulaires, annonces, panier, commandes…)
  }

  void register(Account a) =>
      state = state.copy(accounts: [...state.accounts, a], pending: a);

  void update(Account a) {
    if (state.current?.email == a.email) gSelfAvatarUrl = a.avatarUrl;
    state = state.copy(
      accounts: [for (final x in state.accounts) x.email == a.email ? a : x],
      current: state.current?.email == a.email ? a : state.current,
      pending: state.pending?.email == a.email ? a : state.pending,
    );
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

/// Compte affiché sur le profil : connecté, sinon en cours d'inscription. Le compte de démonstration ne sert que hors connexion au serveur (tests, aperçu).
const _blankAccount = Account(
  name: '',
  phone: '',
  email: '',
  password: '',
  verified: false,
  institution: '',
  department: '',
  city: '',
);
final profileAccountProvider = Provider<Account>((ref) {
  final s = ref.watch(authProvider);
  return s.current ??
      s.pending ??
      (Backend.ready ? _blankAccount : demoAccount);
});

/// Valeurs saisies dans les formulaires (clé → texte) et messages d'erreur (clé → message).
class FormValues extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => {...Drafts.values};
  void put(String k, String v) => state = {...state, k: v};
  String get(String k) => state[k] ?? '';
  void clear(Iterable<String> keys) => state = {
    for (final e in state.entries)
      if (!keys.contains(e.key)) e.key: e.value,
  };
}

final formProvider = NotifierProvider<FormValues, Map<String, String>>(
  FormValues.new,
);

class FormErrors extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => const {};
  void setAll(Map<String, String> m) => state = m;
  void clear() => state = const {};
}

final errorsProvider = NotifierProvider<FormErrors, Map<String, String>>(
  FormErrors.new,
);

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
    // Un étudiant arrive directement sur son profil ; les autres comptes sur l'accueil.
    final a = ref.read(authProvider).current;
    gOpen(context, a != null && a.role == 1 && a.staff.isEmpty ? '10' : '03');
  }
}

/// Action réservée aux comptes. L'utilisateur explore librement : on ne lui demande de se connecter qu'au moment où l'action l'exige,
/// avec la possibilité de renoncer. Retourne true si un compte est connecté (ou si l'application est hors connexion serveur).
Future<bool> requireLogin(
  BuildContext context,
  WidgetRef ref,
  String pour,
) async {
  if (!Backend.ready || ref.read(authProvider).current != null) return true;
  const st = TextStyle(
    inherit: false,
    fontFamily: 'PlusJakartaSans',
    fontSize: 14,
    height: 1.45,
    color: Color(0xFF4A4854),
    textBaseline: TextBaseline.alphabetic,
  );
  final choix = await gDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(
        'Un compte est nécessaire',
        style: st.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF111015),
        ),
      ),
      content: Text(
        'Pour $pour, connectez-vous ou créez un compte gratuit.\n\nVous pouvez continuer à explorer sans compte.',
        style: st,
      ),
      actionsOverflowAlignment: OverflowBarAlignment.end,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop('later'),
          child: Text('Plus tard', style: st),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop('signup'),
          child: Text(
            'Créer un compte',
            style: st.copyWith(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF111015),
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop('login'),
          child: Text(
            'Se connecter',
            style: st.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF5A3FE0),
            ),
          ),
        ),
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

String? validName(String v) => v.trim().length < 3
    ? 'Entrez votre nom complet (3 caractères minimum).'
    : null;

String normPhone(String v) {
  var d = v.replaceAll(RegExp(r'[^0-9+]'), '');
  if (d.startsWith('+237')) d = d.substring(4);
  if (d.startsWith('237') && d.length == 12) d = d.substring(3);
  return d;
}

String? validPhone(String v) => RegExp(r'^6\d{8}$').hasMatch(normPhone(v))
    ? null
    : 'Numéro invalide : 9 chiffres commençant par 6.';

String? validEmail(String v) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(v.trim())
    ? null
    : 'Adresse e-mail invalide.';

String? validPassword(String v) {
  if (v.length < 8) return '8 caractères minimum.';
  if (!RegExp('[A-Z]').hasMatch(v)) return 'Ajoutez une lettre majuscule.';
  if (!RegExp('[0-9]').hasMatch(v)) return 'Ajoutez un chiffre.';
  return null;
}

// ------------------------------------------------------------------ actions

void _errors(WidgetRef ref, Map<String, String?> m) =>
    ref.read(errorsProvider.notifier).setAll({
      for (final e in m.entries)
        if (e.value != null) e.key: e.value!,
    });

/// Case « Se souvenir de moi » : garde le compte connecté entre deux visites.
class RememberV extends Notifier<bool> {
  @override
  bool build() => true; // active par défaut : on reste connecté d'une visite à l'autre
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
      // Session ouverte par un lien de réinitialisation : conservée (sans connecter le compte) jusqu'au nouveau mot de passe (écran 16).
      if (Backend.recovery.value) return null;
      // La session reste ouverte tant que la personne ne se déconnecte pas elle-même (plus de déconnexion à chaque rechargement).
      if (e == null || e.toLowerCase() != live.toLowerCase()) await saveRemembered(live);
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
  x,
  y,
  150,
  18,
  Consumer(
    builder: (context, ref, _) {
      final on = ref.watch(rememberProvider);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => ref.read(rememberProvider.notifier).set(!on),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: on ? const Color(0xFF111015) : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
                border: on
                    ? null
                    : Border.all(color: const Color(0xFF57545F), width: 1.4),
              ),
              child: on
                  ? OverflowBox(
                      maxWidth: 16,
                      maxHeight: 16,
                      child: Center(
                        child: SizedBox(
                          width: 14.667,
                          height: 11.958,
                          child: gImg('assets/figma/v/w_check.svg'),
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'Se souvenir de moi',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  inherit: false,
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF111015),
                  textBaseline: TextBaseline.alphabetic,
                ),
              ),
            ),
          ],
        ),
      );
    },
  ),
);

void submitLogin(WidgetRef ref, BuildContext context) {
  final f = ref.read(formProvider);
  final id = (f['li_id'] ?? '').trim();
  final pw = f['li_pw'] ?? '';
  final isMail = id.contains('@');
  final errs = <String, String?>{
    'li_id': id.isEmpty
        ? 'Saisissez votre téléphone ou votre e-mail.'
        : (isMail ? validEmail(id) : validPhone(id)),
    'li_pw': pw.isEmpty ? 'Saisissez votre mot de passe.' : null,
  };
  if (errs.values.any((e) => e != null)) return _errors(ref, errs);
  if (Backend.ready) {
    _serverLogin(ref, context, id, pw, isMail);
    return;
  }
  final accounts = ref.read(authProvider).accounts;
  final hit = accounts
      .where(
        (a) =>
            (isMail
                ? a.email.toLowerCase() == id.toLowerCase()
                : a.phone == normPhone(id)) &&
            a.password == pw,
      )
      .toList();
  if (hit.isEmpty) {
    _errors(ref, {'li_pw': 'Identifiant ou mot de passe incorrect.'});
    ref
        .read(auditProvider.notifier)
        .log(
          'Visiteur',
          'Échec de connexion',
          id,
          'Connexions',
          level: 'Sensible',
        );
    return;
  }
  if (hit.first.suspended) {
    _errors(ref, {'li_pw': 'Compte suspendu. Contactez l’administration.'});
    ref
        .read(auditProvider.notifier)
        .log(
          hit.first.name,
          'Connexion refusée (compte suspendu)',
          id,
          'Connexions',
          level: 'Sensible',
        );
    return;
  }
  ref.read(errorsProvider.notifier).clear();
  ref.read(authProvider.notifier).login(hit.first);
  saveRemembered(ref.read(rememberProvider) ? hit.first.email : null);
  ref
      .read(auditProvider.notifier)
      .log(hit.first.name, 'Connexion réussie', 'Application', 'Connexions');
  gToast(context, 'Bienvenue, ${hit.first.firstName} !');
  _afterLogin(ref, context);
}

Future<void> _serverLogin(
  WidgetRef ref,
  BuildContext context,
  String id,
  String pw,
  bool isMail,
) async {
  // Téléphone : identifiant dérivé du numéro (comptes créés avec le seul téléphone) ; e-mail : adresse saisie.
  final r = await Backend.login(
    isMail ? id : '${normPhone(id)}@phone.boutik-ecole.cm',
    pw,
    phone: isMail ? null : normPhone(id),
  );
  final a = r.account;
  if (a == null) {
    _errors(ref, {
      'li_pw': r.error ?? 'Identifiant ou mot de passe incorrect.',
    });
    ref
        .read(auditProvider.notifier)
        .log(
          'Visiteur',
          'Échec de connexion',
          id,
          'Connexions',
          level: 'Sensible',
        );
    return;
  }
  ref.read(errorsProvider.notifier).clear();
  ref.read(authProvider.notifier).login(a);
  saveRemembered(ref.read(rememberProvider) ? a.email : null);
  ref
      .read(auditProvider.notifier)
      .log(a.name, 'Connexion réussie', 'Application', 'Connexions');
  if (!context.mounted) return;
  gToast(
    context,
    a.name.isEmpty ? 'Bienvenue !' : 'Bienvenue, ${a.firstName} !',
  );
  _afterLogin(ref, context);
}

Future<void> _serverSignup(
  WidgetRef ref,
  BuildContext context,
  Account created,
) async {
  final r = await Backend.register(created, created.password);
  if (!context.mounted) return;
  if (r.exists) {
    await gAlert(
      context,
      'Compte déjà existant',
      'Un compte existe déjà avec l’adresse ${created.email}.\n\nConnectez-vous, ou utilisez « Mot de passe oublié » si vous ne vous en souvenez plus.',
      button: 'Compris',
    );
    return;
  }
  if (r.error != null) {
    await gAlert(context, 'Inscription impossible', r.error!);
    return;
  }
  ref.read(errorsProvider.notifier).clear();
  ref
      .read(auditProvider.notifier)
      .log(created.name, 'Compte créé', created.email, 'Comptes');
  if (r.needsConfirm) {
    await gAlert(
      context,
      'Vérifiez votre boîte e-mail',
      'Un lien de confirmation a été envoyé à ${created.email}. Cliquez dessus, puis connectez-vous.',
      button: 'Aller à la connexion',
    );
    if (context.mounted) gOpen(context, '11');
    return;
  }
  final a =
      await Backend.restore() ??
      created.copyWith(serverId: Backend.currentUserId ?? '');
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
    'su_pw2':
        (f['su_pw'] ?? '') == (f['su_pw2'] ?? '') &&
            (f['su_pw2'] ?? '').isNotEmpty
        ? null
        : 'Les mots de passe ne correspondent pas.',
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
    // aucune valeur imposée : établissement, département et ville sont choisis par la personne
    institution: '',
    department: '',
    city: '',
  );
  if (Backend.ready) {
    _serverSignup(ref, context, created);
    return;
  }
  final accounts = ref.read(authProvider).accounts;
  if (accounts.any(
    (a) => a.email.toLowerCase() == created.email.toLowerCase(),
  )) {
    gAlert(
      context,
      'Compte déjà existant',
      'Un compte existe déjà avec l’adresse ${created.email}.\n\nConnectez-vous, ou utilisez « Mot de passe oublié ».',
    );
    return;
  }
  ref.read(errorsProvider.notifier).clear();
  ref.read(authProvider.notifier).register(created);
  ref.read(formProvider.notifier).put('otp', '');
  ref
      .read(auditProvider.notifier)
      .log(
        f['su_name']!.trim(),
        'Compte créé',
        f['su_email']!.trim(),
        'Comptes',
      );
  gToast(context, 'Code envoyé par SMS (démonstration : $demoCode)');
  gOpen(context, '14');
}

/// Écran 14 « Renvoyer le code ». Avec le serveur, la vérification du compte se fait par un lien e-mail (Supabase Auth) :
/// on renvoie ce lien, et rien n'est annoncé comme envoyé sans réponse du serveur.
Future<void> resendSignupCode(WidgetRef ref, BuildContext context) async {
  if (!Backend.ready) {
    gToast(context, 'Nouveau code envoyé (démonstration : $demoCode)');
    return;
  }
  final email =
      (ref.read(authProvider).pending?.email ?? Backend.sessionEmail ?? '')
          .trim();
  if (email.isEmpty || !email.contains('@')) {
    await gAlert(
      context,
      'Confirmation par e-mail',
      'La vérification du compte se fait par le lien envoyé à votre adresse e-mail lors de l’inscription. Inscrivez-vous, puis ouvrez ce lien.',
    );
    return;
  }
  final err = await Backend.resendSignupConfirmation(email);
  if (!context.mounted) return;
  if (err != null) {
    await gAlert(context, 'Envoi impossible', err);
    return;
  }
  gToast(context, 'Lien de confirmation renvoyé à $email');
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
    _errors(ref, {
      if (first.isEmpty) 'pf_first': 'Prénom obligatoire.',
      if (last.isEmpty) 'pf_last': 'Nom obligatoire.',
    });
    return;
  }
  ref.read(errorsProvider.notifier).clear();
  if (a != null) {
    final instId = (f['pf_inst_id'] ?? '').isNotEmpty
        ? f['pf_inst_id']!
        : a.institutionId;
    final deptId = (f['pf_dept_id'] ?? '').isNotEmpty
        ? f['pf_dept_id']!
        : a.departmentId;
    final birth = (f['pf_birth'] ?? a.birth).trim();
    if (birth.isNotEmpty && parseBirth(birth) == null) {
      _errors(ref, {
        'pf_birth':
            'Date invalide : écrivez JJ/MM/AAAA, par exemple 07/03/2002.',
      });
      return;
    }
    final maj = a.copyWith(
      name: '$first $last',
      city: (f['pf_city'] ?? a.city).trim(),
      institution: (f['pf_inst_name'] ?? a.institution).trim(),
      institutionId: instId,
      department: (f['pf_dept_name'] ?? a.department).trim(),
      departmentId: deptId,
      birth: birth,
    );
    if (Backend.ready) {
      await Backend.createProfile(
        maj,
      ); // idempotent : crée le profil si le choix du rôle a été sauté
      if (!await Backend.saveProfile(maj)) {
        if (context.mounted)
          await gAlert(
            context,
            'Profil non enregistré',
            'Vos informations n’ont pas pu être enregistrées. Réessayez.',
          );
        return;
      }
      // établissement et département viennent du référentiel ; le matricule et le niveau déjà saisis sont conservés
      if (instId.isNotEmpty || deptId.isNotEmpty) {
        final err = await saveAcademic(
          ref,
          institutionId: instId,
          departmentId: deptId,
          matricule: a.matricule,
          level: a.studyLevel,
        );
        if (err != null) {
          if (context.mounted)
            await gAlert(context, 'Établissement non enregistré', err);
          return;
        }
      }
    }
    ref.read(authProvider.notifier).update(maj);
  }
  if (!context.mounted) return;
  gToast(context, 'Profil enregistré');
  gOpen(context, '18c');
}

/// Canal choisi sur l'écran 15 : « email », « sms » ou « whatsapp » (par défaut l'e-mail).
String forgotChannel(Map<String, String> f) => const {'email', 'sms', 'whatsapp'}.contains(f['fg_channel']) ? f['fg_channel']! : 'email';

/// Canaux réellement disponibles côté serveur (secrets Twilio présents) ; hors connexion (démonstration) : e-mail et SMS simulés.
final recoveryChannelsProvider = FutureProvider<Map<String, bool>>((ref) async {
  if (!Backend.ready) return {'email': true, 'sms': true, 'whatsapp': false};
  return Backend.recoveryChannels();
});

/// Choix du canal : le champ de saisie est vidé (e-mail et téléphone ne se mélangent pas).
void pickForgotChannel(WidgetRef ref, String channel) {
  final n = ref.read(formProvider.notifier);
  n.put('fg_channel', channel);
  n.clear(const ['fg_id']);
  ref.read(errorsProvider.notifier).clear();
}

/// Déplace vers le bas des éléments positionnés d'un écran généré (ex. : champ « code » inséré sur l'écran 16).
List<Widget> gShift(double dy, List<Widget> ws) => [
  for (final w in ws)
    if (w is GPos)
      GPos(x: w.left!, y: w.top! + dy, gw: w.gw, gh: w.gh, tap: w.tap, onTap: w.onTap, label: w.label, kind: w.kind, child: w.child)
    else
      w,
];

void submitForgot(WidgetRef ref, BuildContext context) {
  final f = ref.read(formProvider);
  final id = (f['fg_id'] ?? '').trim();
  final channel = forgotChannel(f);
  final byMail = channel == 'email';
  final err = id.isEmpty
      ? (byMail ? 'Saisissez l’adresse e-mail de votre compte.' : 'Saisissez le numéro de téléphone de votre compte.')
      : (byMail ? validEmail(id) : validPhone(id));
  if (err != null) return _errors(ref, {'fg_id': err});
  if (Backend.ready) {
    _serverForgot(ref, context, id, channel);
    return;
  }
  final exists = ref
      .read(authProvider)
      .accounts
      .any(
        (a) => byMail
            ? a.email.toLowerCase() == id.toLowerCase()
            : a.phone == normPhone(id),
      );
  ref.read(errorsProvider.notifier).clear();
  ref.read(formProvider.notifier).put('fg_target', id);
  ref.read(formProvider.notifier).put('fg_mode', '');
  gToast(
    context,
    exists
        ? 'Code de réinitialisation envoyé (démonstration : $demoCode)'
        : 'Si un compte existe, un code a été envoyé.',
  );
  gOpen(context, '16');
}

/// Avec le serveur : e-mail = lien Supabase Auth ; SMS / WhatsApp = code à usage unique (Edge Function « auth-recovery »).
/// Rien n'est annoncé comme envoyé sans réponse du serveur ; la réponse est identique que le compte existe ou non.
Future<void> _serverForgot(
  WidgetRef ref,
  BuildContext context,
  String id,
  String channel,
) async {
  ref.read(errorsProvider.notifier).clear();
  final form = ref.read(formProvider.notifier);
  if (channel != 'email') {
    final phone = normPhone(id);
    final err = await Backend.requestRecoveryCode(channel, phone);
    if (!context.mounted) return;
    if (err != null) {
      await gAlert(context, 'Envoi impossible', err);
      return;
    }
    form.put('fg_target', phone);
    form.put('fg_mode', 'code');
    form.clear(const ['rs_code', 'rs_pw', 'rs_pw2']);
    await gAlert(
      context,
      channel == 'sms' ? 'Vérifiez vos SMS' : 'Vérifiez WhatsApp',
      'Si un compte existe pour le numéro +237 $phone, un code à 6 chiffres vient d’être envoyé. Il est valable 10 minutes.\n\nSaisissez-le à l’écran suivant, avec votre nouveau mot de passe.',
      button: 'Saisir le code',
    );
    if (context.mounted) gOpen(context, '16');
    return;
  }
  form.put('fg_mode', '');
  final err = await Backend.resetPassword(id);
  if (!context.mounted) return;
  if (err != null) {
    await gAlert(context, 'Envoi impossible', err);
    return;
  }
  await gAlert(
    context,
    'Vérifiez votre boîte e-mail',
    'Si un compte existe pour $id, un lien de réinitialisation vient d’être envoyé (pensez aux courriers indésirables).\n\nOuvrez-le dans ce navigateur : vous pourrez alors choisir un nouveau mot de passe.',
    button: 'Retour à la connexion',
  );
  if (context.mounted) gOpen(context, '11');
}

void submitReset(WidgetRef ref, BuildContext context) {
  final f = ref.read(formProvider);
  final codeMode = Backend.ready && f['fg_mode'] == 'code' && !Backend.recovery.value;
  final errs = <String, String?>{
    if (codeMode)
      'rs_code': RegExp(r'^\d{6}$').hasMatch((f['rs_code'] ?? '').trim())
          ? null
          : 'Saisissez le code à 6 chiffres reçu.',
    'rs_pw': validPassword(f['rs_pw'] ?? ''),
    'rs_pw2':
        (f['rs_pw'] ?? '') == (f['rs_pw2'] ?? '') &&
            (f['rs_pw2'] ?? '').isNotEmpty
        ? null
        : 'Les mots de passe ne correspondent pas.',
  };
  if (errs.values.any((e) => e != null)) return _errors(ref, errs);
  if (codeMode) {
    _serverResetByCode(ref, context, f['fg_target'] ?? '', (f['rs_code'] ?? '').trim(), f['rs_pw']!);
    return;
  }
  if (Backend.ready) {
    _serverReset(ref, context, f['rs_pw']!);
    return;
  }
  final id = f['fg_target'] ?? '';
  final accounts = ref.read(authProvider).accounts;
  for (final a in accounts) {
    if (id.contains('@')
        ? a.email.toLowerCase() == id.toLowerCase()
        : a.phone == normPhone(id)) {
      ref.read(authProvider.notifier).update(a.copyWith(password: f['rs_pw']!));
    }
  }
  ref.read(errorsProvider.notifier).clear();
  gToast(context, 'Mot de passe modifié. Connectez-vous.');
  gOpen(context, '11');
}

/// Réinitialisation par code (SMS / WhatsApp) : le mot de passe n'est annoncé comme modifié qu'après confirmation du serveur.
Future<void> _serverResetByCode(
  WidgetRef ref,
  BuildContext context,
  String phone,
  String code,
  String password,
) async {
  final err = await Backend.confirmRecoveryCode(phone, code, password);
  if (!context.mounted) return;
  if (err != null) {
    _errors(ref, {'rs_code': err});
    return;
  }
  ref.read(errorsProvider.notifier).clear();
  ref.read(formProvider.notifier).clear(const ['rs_pw', 'rs_pw2', 'rs_code', 'fg_mode']);
  gToast(context, 'Mot de passe modifié. Connectez-vous avec le nouveau mot de passe.');
  gOpen(context, '11');
}

/// Avec le serveur : le mot de passe n'est annoncé comme modifié qu'après confirmation de Supabase Auth.
Future<void> _serverReset(
  WidgetRef ref,
  BuildContext context,
  String password,
) async {
  final err = await Backend.updatePassword(password);
  if (!context.mounted) return;
  if (err != null) {
    await gAlert(context, 'Mot de passe non modifié', err);
    if (context.mounted && !Backend.recovery.value) gOpen(context, '15');
    return;
  }
  ref.read(errorsProvider.notifier).clear();
  ref.read(formProvider.notifier).clear(const ['rs_pw', 'rs_pw2']);
  gToast(
    context,
    'Mot de passe modifié. Connectez-vous avec le nouveau mot de passe.',
  );
  gOpen(context, '11');
}

/// Message d'erreur rouge sous un champ.
DateTime _lastErrorPopup = DateTime.fromMillisecondsSinceEpoch(0);

/// Erreur d'un champ : affichée dans une fenêtre (pop-up) lisible par tous, jamais en petits caractères rouges sous le champ.
/// Une seule fenêtre à la fois, même si plusieurs champs sont en erreur ; le message reste disponible pour les lecteurs d'écran.
Widget errorText(String key, double x, double y) => gP(
  x,
  y,
  320,
  1,
  Consumer(
    builder: (context, ref, _) {
      ref.listen(errorsProvider, (prev, next) {
        final e = next[key];
        if (e == null || e.isEmpty || !context.mounted) return;
        final now = DateTime.now();
        if (now.difference(_lastErrorPopup).inMilliseconds < 500) return;
        _lastErrorPopup = now;
        gAlert(context, 'À corriger', e);
      });
      return const SizedBox.shrink();
    },
  ),
);

// ------------------------------------------------------------------ profil (identité réelle)

/// Vrai tant qu'aucun serveur n'est joint (tests, aperçu) : seuls ces modes affichent le contenu d'exemple de la maquette.
bool get demoContent => !Backend.ready;

/// Texte de maquette d'un écran : la valeur d'exemple n'est affichée qu'hors connexion au serveur ; connecté, [blank] (« — » ou vide).
String gm(String demo, [String blank = '—']) => Backend.ready ? blank : demo;

/// Nom du titulaire à la place du nom de maquette (« Mariam Essono », « Mariam E. », « Bonjour Mariam »…) ; vide tant qu'il n'est pas renseigné.
String gSelf(WidgetRef ref, String demo) {
  if (!Backend.ready) return demo;
  final n = ref.watch(profileAccountProvider).name.trim();
  if (n.isEmpty) return '';
  final p = n.split(RegExp(r'\s+'));
  if (demo.startsWith('Bonjour')) return 'Bonjour ${p.first}';
  if (demo == 'Mariam') return p.first;
  if (demo.endsWith('.pdf')) return '';
  if (demo == 'Mariam E.') return p.length > 1 ? '${p.first} ${p.last[0]}.' : p.first;
  if (demo == 'M. Essono') return p.length > 1 ? 'M. ${p.last}' : n;
  return n;
}

/// Numéro enregistré, masqué (« +237 6•• •• •• 42 ») ; message neutre s'il n'y en a pas.
String maskedPhone(String raw) {
  final d = normPhone(raw);
  if (d.length < 9) return 'Aucun numéro enregistré';
  return '+237 ${d[0]}•• •• •• ${d.substring(d.length - 2)}';
}

/// Appareil courant (le seul que l'application connaît avec certitude).
String currentDeviceLabel() {
  if (kIsWeb) return 'Navigateur web • Cet appareil';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'Android • Cet appareil',
    TargetPlatform.iOS => 'iPhone • Cet appareil',
    _ => 'Cet appareil',
  };
}

/// Centre de sécurité : envoie le lien de changement de mot de passe à l'adresse e-mail du compte.
Future<void> sendPasswordResetLink(WidgetRef ref, BuildContext context) async {
  final email = ref.read(profileAccountProvider).email.trim();
  if (email.isEmpty) {
    await gAlert(context, 'Mot de passe', 'Aucune adresse e-mail n’est enregistrée sur ce compte.');
    return;
  }
  final err = await Backend.resetPassword(email);
  if (!context.mounted) return;
  if (err != null) {
    await gAlert(context, 'Envoi impossible', err);
    return;
  }
  gToast(context, 'Lien envoyé à $email');
}


/// Établissement du titulaire à la place de « IUT de Douala » (vide s'il n'en a pas choisi).
String gSelfInst(WidgetRef ref, String demo) => Backend.ready ? ref.watch(profileAccountProvider).institution.trim() : demo;

TextStyle _pt(double size, Color c, FontWeight w) => TextStyle(
  inherit: false,
  fontFamily: 'PlusJakartaSans',
  fontSize: size,
  fontWeight: w,
  color: c,
  textBaseline: TextBaseline.alphabetic,
);

String _initials(String name) {
  final p = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .toList();
  if (p.isEmpty) return '?';
  return (p.first[0] + (p.length > 1 ? p.last[0] : '')).toUpperCase();
}

/// Photo du titulaire, sinon avatar neutre avec ses initiales (jamais la photo d'un autre compte).
Widget profileAvatar(double x, double y, double size) => gP(
  x,
  y,
  size,
  size,
  Consumer(
    builder: (context, ref, _) {
      final a = ref.watch(profileAccountProvider);
      Widget initials() => Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFEDE9F6),
        ),
        alignment: Alignment.center,
        child: Text(
          _initials(a.name),
          style: _pt(size * .34, const Color(0xFF4A4854), FontWeight.w600),
        ),
      );
      if (demoContent && a.email == demoAccount.email)
        return ClipOval(
          child: Image.asset(
            'assets/figma/img/d902a4aabb7fd7d1d301a3bebd0f8ff54ecefb47.png',
            fit: BoxFit.cover,
            width: size,
            height: size,
          ),
        );
      if (a.avatarUrl.isEmpty) return initials();
      return ClipOval(
        child: Image.network(
          a.avatarUrl,
          fit: BoxFit.cover,
          width: size,
          height: size,
          errorBuilder: (_, __, ___) => initials(),
        ),
      );
    },
  ),
);

/// Nom centré, suivi du badge bleu uniquement si la certification a été approuvée côté serveur.
Widget profileNameBadge(double y) => gP(
  0,
  y,
  390,
  29,
  Consumer(
    builder: (context, ref, _) {
      final a = ref.watch(profileAccountProvider);
      final empty = a.name.trim().isEmpty;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                empty ? 'Nom à compléter' : a.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _pt(
                  23,
                  empty ? const Color(0xFF57545F) : const Color(0xFF111015),
                  FontWeight.w500,
                ),
              ),
            ),
            if (a.certified) ...[
              const SizedBox(width: 8),
              Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: Color(0xFF2F7DF6),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: SizedBox(
                  width: 13,
                  height: 10.6,
                  child: gImg('assets/figma/v/w_check.svg'),
                ),
              ),
            ],
          ],
        ),
      );
    },
  ),
);

/// Ligne sous le profil : compétences, sinon état de certification (avec la possibilité d'en faire la demande).
Widget profileSkillsOrCert(double y) => gP(
  0,
  y,
  390,
  15,
  Consumer(
    builder: (context, ref, _) {
      final a = ref.watch(profileAccountProvider);
      final skills = a.skills
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .map((e) => '#$e')
          .join('   ');
      if (skills.isNotEmpty)
        return Center(
          child: Text(
            skills,
            style: _pt(12, const Color(0xFF57545F), FontWeight.w400),
          ),
        );
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
        child: Center(
          child: Text(
            label,
            style: _pt(
              12,
              canAsk ? const Color(0xFF5A3FE0) : const Color(0xFF57545F),
              canAsk ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      );
    },
  ),
);

/// Publication réservée aux comptes certifiés (annonces, publications). Retourne vrai si la personne peut publier ;
/// sinon explique pourquoi et propose la certification. Ne bloque jamais la consultation (visiteurs). Hors serveur : toujours vrai.
Future<bool> requireCertified(BuildContext context, WidgetRef ref, String action) async {
  if (!Backend.ready) return true;
  if (!await requireLogin(context, ref, action) || !context.mounted) return false;
  final a = ref.read(authProvider).current;
  if (a == null) return false;
  const staff = {'Resp. département', 'Direction', 'Finance', 'Support', 'Admin global'};
  if (a.certified || staff.contains(a.staff)) return true;
  final state = switch (a.certification) {
    'pending' => 'Votre demande de certification est en attente d’examen.',
    'review' => 'Votre demande de certification est en cours d’examen.',
    'rejected' => 'Votre dernière demande a été refusée : complétez votre dossier et refaites une demande.',
    'revoked' => 'Le badge de certification de votre compte a été retiré.',
    _ => 'Votre compte n’est pas encore certifié.',
  };
  final ask = a.certification == 'none' || a.certification == 'rejected';
  final go = await gDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text('Publication réservée aux comptes certifiés', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF111015))),
      content: Text('Pour $action, votre compte doit être certifié. $state\n\nVous pouvez continuer à parcourir, rechercher et acheter normalement.', style: const TextStyle(fontSize: 14, height: 1.45, color: Color(0xFF4A4854))),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Plus tard', style: TextStyle(color: Color(0xFF57545F)))),
        if (ask) TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Demander la certification', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF111015)))),
      ],
    ),
  );
  if (go == true && context.mounted) await requestCertificationFlow(ref, context);
  return false;
}

Future<void> requestCertificationFlow(
  WidgetRef ref,
  BuildContext context,
) async {
  if (!Backend.ready)
    return gAlert(
      context,
      'Certification',
      'La demande de certification nécessite la connexion au serveur.',
    );
  // Visiteur : on propose la connexion au lieu d'envoyer une demande que le serveur refuserait (D-024).
  if (!await requireLogin(context, ref, 'demander la certification')) return;
  if (!context.mounted) return;
  final v = await formDialog(
    context,
    'Demande de certification',
    [('Pourquoi demandez-vous la certification ? (20 caractères minimum)', ''), ('Liens utiles (portfolio, LinkedIn…) — facultatif', '')],
    submit: 'Envoyer la demande',
    intro: 'Le département examine votre dossier. Les justificatifs (carte d’étudiant, certificat de scolarité, diplôme…) se déposent dans votre dossier de profil.',
  );
  if (v == null || !context.mounted) return;
  final err = await Backend.requestCertification(motive: v[0], links: v[1]);
  if (!context.mounted) return;
  if (err != null) {
    await gAlert(context, 'Demande impossible', err);
    // justificatif manquant : on ouvre directement le dossier pour en déposer un
    if (context.mounted && err.toLowerCase().contains('justificatif')) gOpen(context, '154');
    return;
  }
  final fresh = await Backend.restore();
  if (fresh != null) ref.read(authProvider.notifier).login(fresh);
  if (context.mounted) {
    await gAlert(
      context,
      'Demande envoyée',
      'Votre demande de certification est en attente. Le badge bleu n’apparaîtra qu’après examen et approbation par l’IUT.',
    );
  }
}

Widget profileBio(double y) => gP(
  28.5,
  y,
  333,
  34,
  Consumer(
    builder: (context, ref, _) {
      final a = ref.watch(profileAccountProvider);
      final empty = a.bio.trim().isEmpty;
      return gText(
        empty ? 'Aucune description pour le moment.' : a.bio.trim(),
        11.5,
        empty ? const Color(0xFF57545F) : const Color(0xFF6F6D77),
        lh: 17,
        align: TextAlign.center,
        wrap: true,
      );
    },
  ),
);

Widget profileStat(double x, String label, int Function(WidgetRef ref) count) =>
    gP(
      x,
      519,
      104,
      14,
      Consumer(
        builder: (context, ref, _) => Center(
          child: Text(
            '${count(ref)} $label',
            style: _pt(11.5, const Color(0xFF111015), FontWeight.w500),
          ),
        ),
      ),
    );

/// Département · établissement du titulaire (rien si non renseignés).
Widget profileSubline(double y) => gP(
  0,
  y,
  390,
  14,
  Consumer(
    builder: (context, ref, _) {
      final a = ref.watch(profileAccountProvider);
      final t = [
        a.department,
        a.institution,
      ].where((e) => e.trim().isNotEmpty && e != '—').join(' · ');
      return Center(
        child: Text(
          t,
          style: _pt(11.5, const Color(0xFF57545F), FontWeight.w400),
        ),
      );
    },
  ),
);

Widget profilePassport(double x, double y) => gP(
  x,
  y,
  270,
  15,
  Consumer(
    builder: (context, ref, _) {
      final a = ref.watch(profileAccountProvider);
      return gText(
        a.certified
            ? 'Talent Passport · Certifié'
            : 'Talent Passport · Non certifié',
        12,
        const Color(0xFF111015),
        weight: 600,
      );
    },
  ),
);

/// « Modifier mon profil » : description, compétences et ville du titulaire. Enregistré sur le serveur ; jamais le rôle ni la certification.
Future<void> editProfileDialog(BuildContext context, WidgetRef ref) async {
  if (!await requireLogin(context, ref, 'modifier votre profil')) return;
  final a = ref.read(authProvider).current;
  if (a == null || !context.mounted) return;
  final bio = TextEditingController(text: a.bio);
  final skills = TextEditingController(text: a.skills);
  final city = TextEditingController(text: a.city);
  const st = TextStyle(
    inherit: false,
    fontFamily: 'PlusJakartaSans',
    fontSize: 13.5,
    color: Color(0xFF111015),
    textBaseline: TextBaseline.alphabetic,
  );
  InputDecoration deco(String h) => InputDecoration(
    hintText: h,
    hintStyle: st.copyWith(color: const Color(0xFF57545F)),
    isDense: true,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
  );
  final saved = await gDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(
        'Modifier mon profil',
        style: st.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Description',
                style: st.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: bio,
                style: st,
                maxLines: 4,
                maxLength: 300,
                decoration: deco('Présentez-vous en quelques lignes'),
              ),
              const SizedBox(height: 8),
              Text(
                'Compétences (séparées par des virgules)',
                style: st.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: skills,
                style: st,
                decoration: deco('Python, React, Design'),
              ),
              const SizedBox(height: 14),
              Text('Ville', style: st.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: city,
                style: st,
                decoration: deco('Douala'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('Annuler', style: st),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(
            'Enregistrer',
            style: st.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF5A3FE0),
            ),
          ),
        ),
      ],
    ),
  );
  if (saved != true) return;
  final updated = a.copyWith(
    bio: bio.text.trim(),
    skills: skills.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join(', '),
    city: city.text.trim().isEmpty ? a.city : city.text.trim(),
  );
  if (Backend.ready && !await Backend.saveProfile(updated)) {
    if (context.mounted)
      await gAlert(
        context,
        'Profil non enregistré',
        'Vos modifications n’ont pas pu être enregistrées. Réessayez.',
      );
    return;
  }
  ref.read(authProvider.notifier).update(updated);
  if (context.mounted) gToast(context, 'Profil enregistré');
}

/// « Se déconnecter de tous les appareils » :
/// retire les appareils enregistrés, puis révoque les sessions serveur.
Future<void> logoutEverywhere(WidgetRef ref, BuildContext context) async {
  // Nettoyage des appareils avant la révocation de la session.
  // La déconnexion reste prioritaire si le nettoyage échoue.
  await Backend.rpc('unregister_all_devices', {});

  await Backend.signOutAll();
  ref.read(authProvider.notifier).logout();
}

/// Date de naissance saisie « JJ/MM/AAAA » (espaces tolérés) ou « AAAA-MM-JJ » : renvoie la date, ou null si elle est invalide ou irréaliste.
DateTime? parseBirth(String v) {
  final t = v.replaceAll(' ', '');
  final m =
      RegExp(r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})$').firstMatch(t) ??
      RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(t);
  if (m == null) return null;
  final iso = t.contains(RegExp(r'^\d{4}-'));
  final y = int.parse(iso ? m.group(1)! : m.group(3)!),
      mo = int.parse(m.group(2)!),
      d = int.parse(iso ? m.group(3)! : m.group(1)!);
  final dt = DateTime(y, mo, d);
  if (dt.year != y || dt.month != mo || dt.day != d) return null;
  final now = DateTime.now();
  if (dt.isAfter(now) || y < 1920) return null;
  return dt;
}


/// Force du mot de passe et liste des règles de l'écran 16 : calculées sur la saisie réelle (rien de figé).
class ResetStrength extends ConsumerWidget {
  const ResetStrength({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pw = ref.watch(formProvider.select((m) => m['rs_pw'] ?? ''));
    final rules = [
      pw.length >= 8,
      RegExp('[A-Z]').hasMatch(pw),
      RegExp('[0-9]').hasMatch(pw),
      RegExp('[^A-Za-z0-9]').hasMatch(pw),
    ];
    const labels = ['8 caractères minimum', 'Une lettre majuscule', 'Un chiffre', 'Un caractère spécial (! @ # …)'];
    final n = rules.where((e) => e).length;
    const green = Color(0xFF1F9D6B);
    final level = pw.isEmpty ? '' : (n <= 1 ? 'Faible' : (n == 2 ? 'Moyen' : (n == 3 ? 'Bon' : 'Fort')));
    final levelColor = n <= 1 ? const Color(0xFFC0261B) : (n == 2 ? const Color(0xFFB36B00) : const Color(0xFF0F7A52));
    return Stack(children: [
      for (var i = 0; i < 4; i++)
        gP(24.0 + 87 * i, 4, 80, 6, gBox(color: i < n ? green : const Color(0xFFE4E8EE), radii: const [3, 3, 3, 3])),
      gP(24, 22, 200, 16, gText('Force du mot de passe', 12.5, const Color(0xFF57545F))),
      gP(266, 22, 100, 16, gText(level, 12.5, levelColor, weight: 700, align: TextAlign.right)),
      for (var i = 0; i < 4; i++) ...[
        gP(24, 62.0 + 30 * i, 20, 20, gBox(color: rules[i] ? green : Colors.white, border: rules[i] ? null : const Color(0xFFDAD5E4), bw: 1.5, oval: true)),
        gP(27, 66.0 + 30 * i, 14, 11.5, gImg('assets/figma/v/d9758b2cc9e4ca.svg'), show: rules[i]),
        gP(56, 63.5 + 30 * i, 280, 17, gText(labels[i], 13.5, rules[i] ? const Color(0xFF111015) : const Color(0xFF57545F), weight: 500)),
      ],
    ]);
  }
}
