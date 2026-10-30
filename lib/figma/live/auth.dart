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
  });
  final String name, phone, email, password, city, institution, department, birth;
  final int role; // 0 client · 1 étudiant vendeur · 2 entreprise · 3 autre
  final bool verified, suspended;
  final String staff; // rôle interne (Resp. département, Finance, Admin global…)

  String get roleLabel => staff.isNotEmpty ? staff : const ['Client', 'Étudiant-vendeur', 'Entreprise', 'Autre rôle'][role.clamp(0, 3)];

  String get firstName => name.split(' ').first;
  String get lastName => name.split(' ').length > 1 ? name.split(' ').skip(1).join(' ') : '';

  Account copyWith({String? name, String? password, int? role, bool? verified, String? city, String? institution, String? department, String? birth, bool? suspended, String? staff}) => Account(
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
      );
}

const demoAccount = Account(name: 'Mariam Essono', phone: '690112233', email: 'mariam@iut-douala.cm', password: 'Boutik2026');
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

/// Compte affiché sur le profil : connecté, sinon en cours d'inscription, sinon la démo.
final profileAccountProvider = Provider<Account>((ref) {
  final s = ref.watch(authProvider);
  return s.current ?? s.pending ?? demoAccount;
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

final termsProvider = NotifierProvider<Flag, bool>(Flag.new);

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
  Backend.signIn(hit.first, pw);
  ref.read(auditProvider.notifier).log(hit.first.name, 'Connexion réussie', 'Application', 'Connexions');
  gToast(context, 'Bienvenue, ${hit.first.firstName} !');
  gOpen(context, '03');
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
  final accounts = ref.read(authProvider).accounts;
  if (accounts.any((a) => a.email.toLowerCase() == (f['su_email'] ?? '').trim().toLowerCase())) {
    return _errors(ref, {'su_email': 'Un compte existe déjà avec cette adresse.'});
  }
  ref.read(errorsProvider.notifier).clear();
  final created = Account(
    name: f['su_name']!.trim(),
    phone: normPhone(f['su_phone']!),
    email: f['su_email']!.trim(),
    password: f['su_pw']!,
    verified: false,
  );
  ref.read(authProvider.notifier).register(created);
  Backend.signUp(created, created.password).then((hasSession) {
    if (hasSession == false && context.mounted) gToast(context, 'Un e-mail de confirmation vous a été envoyé : cliquez sur le lien, puis connectez-vous.');
  });
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

void submitRole(WidgetRef ref, BuildContext context) {
  final a = ref.read(authProvider).current;
  if (a != null) ref.read(authProvider.notifier).update(a.copyWith(role: ref.read(signupRoleProvider)));
  gOpen(context, '18b');
}

void submitProfile(WidgetRef ref, BuildContext context) {
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
    ref.read(authProvider.notifier).update(a.copyWith(
          name: '$first $last',
          city: (f['pf_city'] ?? a.city).trim(),
          institution: (f['pf_inst'] ?? a.institution).trim(),
          department: (f['pf_dept'] ?? a.department).trim(),
          birth: f['pf_birth'] ?? a.birth,
        ));
  }
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
