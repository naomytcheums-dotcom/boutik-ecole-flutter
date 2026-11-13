import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../gen.dart' show gToast;
import '../i18n.dart' show Text;
import 'auth.dart';
import 'backend.dart';
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';

/// Comptes de test de l'administrateur : un compte par profil, marqués « test » (migration 20261114002300), créés et ouverts uniquement par
/// l'administrateur (fonction « admin-test-accounts »). Aucun mot de passe n'est connu : l'ouverture se fait par lien à usage unique et est journalisée.

const testRoleLabels = {
  'visitor': 'Visiteur',
  'client': 'Client',
  'student': 'Étudiant-vendeur',
  'company': 'Entreprise',
  'other': 'Autre rôle',
  'dept': 'Responsable de département',
  'direction': 'Direction',
  'finance': 'Finance',
  'support': 'Support',
  'admin': 'Administrateur',
};

final testAccountsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final r = await marcheCall('test_accounts_list', const {});
  if (r.error != null) throw MarcheException(r.error);
  return [for (final x in (r.data as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
});

/// Vrai quand le compte connecté est un compte de test (pour afficher le bandeau « Revenir à mon compte »).
final isTestAccountProvider = FutureProvider.autoDispose<bool>((ref) async {
  final uid = ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  if (!Backend.ready || uid.isEmpty) return false;
  try {
    final row = await Supabase.instance.client.from('profiles').select('is_test').eq('id', uid).maybeSingle();
    return row?['is_test'] == true;
  } catch (_) {
    return false;
  }
});

/// Session de l'administrateur, gardée en mémoire seulement (jamais écrite sur l'appareil) pour pouvoir y revenir.
String? _adminRefreshToken;

String testAccountLabel(Map<String, dynamic> a) => testRoleLabels['${a['role']}'] ?? '${a['role']}';

Future<({Map<String, dynamic>? data, String? error})> _fn(Map<String, dynamic> body) async {
  try {
    final r = await Supabase.instance.client.functions.invoke('admin-test-accounts', body: body);
    final d = r.data;
    if (d is Map) return (data: Map<String, dynamic>.from(d), error: null);
    return (data: null, error: 'Réponse inattendue du serveur');
  } on FunctionException catch (e) {
    final d = e.details;
    return (data: null, error: d is Map && d['message'] != null ? '${d['message']}' : 'Action refusée (${e.status})');
  } catch (e) {
    return (data: null, error: 'Le service ne répond pas pour le moment. Réessayez dans un instant.');
  }
}

/// Mot de passe choisi par l'administrateur (10 caractères au moins, une lettre et un chiffre) ; jamais affiché ni enregistré par l'application.
bool validTestPassword(String p) => p.length >= 10 && p.length <= 72 && RegExp(r'[A-Za-z]').hasMatch(p) && RegExp(r'[0-9]').hasMatch(p);

Future<String?> _askPassword(BuildContext context, String title) async {
  final ctl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: ctl, obscureText: true, autofocus: true, decoration: const InputDecoration(labelText: 'Mot de passe des comptes de test')),
        const SizedBox(height: 8),
        Text('10 caractères au moins, avec une lettre et un chiffre. Vous le saisissez vous-même : il n’est affiché nulle part.', style: mst(12, c: kGrey)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Annuler')), TextButton(onPressed: () => Navigator.pop(c, true), child: Text('Valider'))],
    ),
  );
  final v = ctl.text;
  ctl.dispose();
  if (ok != true || !context.mounted) return null;
  if (!validTestPassword(v)) {
    gToast(context, 'Mot de passe trop faible : 10 caractères au moins, avec une lettre et un chiffre.');
    return null;
  }
  return v;
}

Future<void> setTestPassword(BuildContext context, WidgetRef ref) async {
  final pw = await _askPassword(context, 'Changer le mot de passe des comptes de test');
  if (pw == null || !context.mounted) return;
  final r = await _fn({'action': 'password', 'password': pw});
  if (!context.mounted) return;
  gToast(context, r.error ?? '${r.data?['changed'] ?? 0} compte(s) de test mis à jour.');
}

Future<void> ensureTestAccounts(BuildContext context, WidgetRef ref) async {
  final pw = await _askPassword(context, 'Créer les comptes de test');
  if (pw == null || !context.mounted) return;
  final r = await _fn({'action': 'ensure', 'password': pw});
  if (!context.mounted) return;
  if (r.error != null) return gToast(context, r.error!);
  final created = (r.data?['created'] as List? ?? const []).length;
  final failed = (r.data?['failed'] as List? ?? const []);
  gToast(context, failed.isNotEmpty ? '$created créé(s), ${failed.length} en échec : ${failed.first['message']}' : (created == 0 ? 'Tous les comptes de test existent déjà.' : '$created compte(s) de test créé(s).'));
  ref.invalidate(testAccountsProvider);
}

Future<void> openTestAccount(BuildContext context, WidgetRef ref, Map<String, dynamic> acct) async {
  final yes = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('Ouvrir « ${testAccountLabel(acct)} » ?'),
      content: Text('Vous quittez votre compte administrateur pour ce compte de test. Un bandeau « Revenir à mon compte » reste affiché en haut.'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Annuler')), TextButton(onPressed: () => Navigator.pop(c, true), child: Text('Ouvrir'))],
    ),
  );
  if (yes != true || !context.mounted) return;
  final client = Supabase.instance.client;
  final mine = client.auth.currentSession?.refreshToken;
  final r = await _fn({'action': 'login', 'target_id': acct['id']});
  if (!context.mounted) return;
  if (r.error != null || r.data?['token_hash'] == null) return gToast(context, r.error ?? 'Ouverture impossible.');
  try {
    await client.auth.verifyOTP(tokenHash: '${r.data!['token_hash']}', type: OtpType.magiclink);
  } catch (_) {
    if (context.mounted) gToast(context, 'Le lien de connexion a expiré. Réessayez.');
    return;
  }
  _adminRefreshToken = mine ?? _adminRefreshToken;
  final fresh = await Backend.restore();
  if (fresh != null) ref.read(authProvider.notifier).login(fresh);
  ref.invalidate(isTestAccountProvider);
  if (context.mounted) gToast(context, 'Vous êtes connecté en tant que « ${testAccountLabel(acct)} ».');
}

/// Revient au compte administrateur (session gardée en mémoire) ; à défaut, ferme la session de test et demande de se reconnecter.
Future<void> backToAdmin(BuildContext context, WidgetRef ref) async {
  final client = Supabase.instance.client;
  final token = _adminRefreshToken;
  _adminRefreshToken = null;
  try {
    if (token != null) {
      await client.auth.setSession(token);
      final fresh = await Backend.restore();
      if (fresh != null) {
        ref.read(authProvider.notifier).login(fresh);
        ref.invalidate(isTestAccountProvider);
        if (context.mounted) gToast(context, 'Vous êtes revenu à votre compte administrateur.');
        return;
      }
    }
  } catch (_) {}
  await client.auth.signOut();
  ref.read(authProvider.notifier).logout();
  ref.invalidate(isTestAccountProvider);
  if (context.mounted) gToast(context, 'Session de test fermée. Reconnectez-vous avec votre compte administrateur.');
}

/// Bandeau affiché au-dessus de toute l'application tant qu'on est connecté sur un compte de test.
class TestAccountBanner extends ConsumerWidget {
  const TestAccountBanner({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTest = ref.watch(isTestAccountProvider).asData?.value ?? false;
    final name = ref.watch(authProvider.select((a) => a.current?.name ?? ''));
    if (!isTest) return child;
    return Stack(children: [
      child,
      Positioned(
        left: 0,
        right: 0,
        top: 0,
        child: Material(
          color: const Color(0xFFB45309),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 30,
              child: Row(children: [
                const SizedBox(width: 12),
                Expanded(child: Text('Compte de test : $name', maxLines: 1, overflow: TextOverflow.ellipsis, style: mst(11.5, w: FontWeight.w700, c: Colors.white))),
                TextButton(onPressed: () => backToAdmin(context, ref), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: const Size(0, 30)), child: Text('Revenir à mon compte', style: mst(11.5, w: FontWeight.w800, c: Colors.white))),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }
}

class TestAccountsScreen extends ConsumerWidget {
  const TestAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MarchePage(
      title: 'Comptes de test',
      child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text('Un compte par profil, reconnus comme comptes de test par le système. Ouvrez-en un pour parcourir l’application comme ce profil, puis touchez « Revenir à mon compte ».', style: mst(13, c: kGrey).copyWith(height: 1.5)),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), child: mButton('Créer les comptes de test manquants', () => ensureTestAccounts(context, ref), icon: Icons.add)),
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: mButton('Changer le mot de passe des comptes de test', () => setTestPassword(context, ref), dark: false, icon: Icons.lock_reset)),
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: Text('Chaque compte se connecte aussi normalement : page de connexion, e-mail ci-dessous et le mot de passe que vous avez choisi.', style: mst(12, c: kGrey).copyWith(height: 1.4))),
        mAsync<List<Map<String, dynamic>>>(
          ref.watch(testAccountsProvider),
          (l) => l.isEmpty
              ? mNote('Aucun compte de test pour le moment.\nTouchez « Créer les comptes de test manquants ».')
              : Column(children: [
                  for (final a in l)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: kLine)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(testAccountLabel(a), style: mst(15, w: FontWeight.w800)),
                        SelectableText('${a['email']}', style: mst(12.5, w: FontWeight.w600, c: kInk)),
                        Text(a['last_login'] == null ? 'Jamais ouvert' : 'Dernière ouverture : ${'${a['last_login']}'.substring(0, 10)}', style: mst(12, c: kGrey)),
                        const SizedBox(height: 10),
                        mButton('Ouvrir en tant que ce profil', () => openTestAccount(context, ref, a), icon: Icons.login),
                      ]),
                    ),
                ]),
        ),
      ]),
    );
  }
}
