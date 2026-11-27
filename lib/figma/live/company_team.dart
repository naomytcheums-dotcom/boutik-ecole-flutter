import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../gen.dart' show gToast;
import '../i18n.dart' show Text;
import 'access.dart' show LoginGuard, roleKey, roleNames;
import 'auth.dart';
import 'backend.dart';
import 'company_home.dart';
import 'company_screens.dart';
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';

/// Équipe de l'entreprise : plusieurs comptes, même interface, niveaux de droits (migration 20261114002900).

final companyMembersProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final ctx = ref.watch(companyContextProvider);
  final r = await marcheCall('company_members_list', {if (ctx != null) 'p_owner': ctx});
  if (r.error != null) throw MarcheException(r.error);
  return Map<String, dynamic>.from(r.data as Map);
}, retry: (_, _) => null);

final myCompaniesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final r = await marcheCall('my_company_memberships', const {});
  if (r.error != null) throw MarcheException(r.error);
  return [for (final x in (r.data as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
}, retry: (_, _) => null);

/// Droits d'un rôle : modifier la fiche, gérer l'équipe, payer le forfait.
bool roleCanManage(String role) => role == 'owner' || role == 'admin';
bool roleCanPay(String role) => role == 'owner' || role == 'admin' || role == 'finance';

/// Changement de rôle d'un membre : le propriétaire gère tout le monde ; un administrateur ne touche ni aux autres administrateurs ni à lui-même.
bool canChangeMemberRole(String myRole, String memberRole, {required bool isMe}) => !isMe && (myRole == 'owner' || (myRole == 'admin' && memberRole != 'admin'));

/// Retrait d'un membre : chacun peut quitter l'équipe ; le propriétaire retire tout le monde, un administrateur seulement les non-administrateurs.
bool canRemoveMember(String myRole, String memberRole, {required bool isMe}) => isMe || myRole == 'owner' || (myRole == 'admin' && memberRole != 'admin');

/// Rôles attribuables : seul le propriétaire nomme un administrateur.
Map<String, String> assignableCompanyRoles(String myRole) => {for (final e in companyRoleLabels.entries) if (e.key != 'owner' && (e.key != 'admin' || myRole == 'owner')) e.key: e.value};

/// Garde des routes de l'espace Organisation : comptes Organisation (ex-Entreprise, rôle « autre » fusionné) et administrateur, ou membre actif d'une organisation
/// (espace partagé). Un autre compte, un Client sans organisation par exemple, voit « Réservé aux organisations » avec le chemin
/// pour rejoindre une équipe. Visiteur : « Connexion requise ». Hors connexion au serveur (aperçu, tests), l'écran reste ouvert.
/// [owner] : organisation visée (route d'espace partagé) ; [useContext] : l'organisation consultée est celle du contexte courant.
class CompanyGuard extends ConsumerWidget {
  const CompanyGuard({super.key, required this.child, this.owner, this.useContext = false});
  final Widget child;
  final String? owner;
  final bool useContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) => LoginGuard(child: _build(context, ref));

  Widget _build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(authProvider.select((a) => a.current));
    if (!Backend.ready || account == null || const {'company', 'admin'}.contains(roleKey(account))) return child;
    final target = owner ?? (useContext ? ref.watch(companyContextProvider) : null);
    if (target == null) return const _CompanyReserved();
    final memberships = ref.watch(myCompaniesProvider);
    return memberships.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const _CompanyReserved(),
      data: (l) => l.any((c) => '${c['owner_id']}' == target && c['status'] == 'active') ? child : const _CompanyReserved(),
    );
  }
}

class _CompanyReserved extends StatelessWidget {
  const _CompanyReserved();

  @override
  Widget build(BuildContext context) => MarchePage(
        title: 'Espace organisation',
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.business_center_outlined, size: 46, color: kViolet),
              const SizedBox(height: 14),
              Text('Réservé aux organisations', style: mst(20, w: FontWeight.w800), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Cet espace est réservé aux comptes Organisation et aux personnes invitées dans leur équipe. Si un collègue vous a invité, l’invitation vous attend dans « Mes organisations ».', style: mst(13.5, c: kGrey).copyWith(height: 1.5), textAlign: TextAlign.center),
              const SizedBox(height: 22),
              mButton('Mes organisations', () => context.push('/mes-entreprises'), icon: Icons.groups_2_outlined),
              const SizedBox(height: 10),
              mButton('Retour à l’accueil', () => context.go('/s/03'), dark: false),
            ]),
          ),
        ),
      );
}

/// Explication courte de ce que peut faire chaque rôle.
const companyRoleHelp = {
  'admin': 'Modifie la fiche, gère l’équipe, paie le forfait.',
  'finance': 'Consulte et paie le forfait.',
  'viewer': 'Consulte l’accueil, la fiche et l’équipe.',
};

/// Droit d'inviter des collègues (« gestion_equipe » ou forfait d'entreprise payant) ; en cas d'erreur on ouvre le formulaire, le serveur reste juge.
final _teamAccessProvider = FutureProvider.autoDispose.family<bool, String?>((ref, owner) async {
  final r = await marcheCall('company_team_access', {if (owner != null) 'p_owner': owner});
  return r.error != null ? true : r.data != false;
});

class CompanyMembersScreen extends ConsumerStatefulWidget {
  const CompanyMembersScreen({super.key});

  @override
  ConsumerState<CompanyMembersScreen> createState() => _MembersState();
}

class _MembersState extends ConsumerState<CompanyMembersScreen> {
  final _email = TextEditingController();
  String _role = 'viewer';
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  String? get _owner => ref.read(companyContextProvider);

  Future<bool> _call(String fn, Map<String, dynamic> p, String ok) async {
    final r = await marcheCall(fn, {...p, if (_owner != null) 'p_owner': _owner});
    if (!mounted) return false;
    gToast(context, r.error != null ? Backend.userMessage('${r.error}') : ok);
    ref.invalidate(companyMembersProvider);
    ref.invalidate(companyDashboardProvider);
    return r.error == null;
  }

  Future<void> _leave(String me) async {
    final ok = await _call('company_member_remove', {'p_user': me}, 'Vous avez quitté l’équipe.');
    if (!ok || !mounted) return;
    ref.invalidate(myCompaniesProvider);
    context.go('/mes-entreprises');
  }

  Future<void> _invite() async {
    final email = _email.text.trim();
    if (email.isEmpty) return gToast(context, 'Saisissez l’e-mail de la personne.');
    setState(() => _busy = true);
    final ok = await _call('company_invite', {'p_email': email, 'p_role': _role}, 'Si un compte existe avec cet e-mail, la personne reçoit l’invitation.');
    if (mounted) {
      setState(() => _busy = false);
      if (ok) _email.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(companyMembersProvider);
    final me = ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
    return MarchePage(
      title: 'Équipe de l’organisation',
      child: mAsync<Map<String, dynamic>>(async, (d) {
        final myRole = '${d['my_role']}';
        final canManage = roleCanManage(myRole);
        final teamOpen = ref.watch(_teamAccessProvider(ref.watch(companyContextProvider))).maybeWhen(data: (v) => v, orElse: () => true);
        final members = [for (final x in (d['members'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
        return ListView(padding: const EdgeInsets.only(bottom: 90), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text('Plusieurs personnes de l’organisation partagent la même interface, avec des droits différents. Votre rôle : ${companyRoleLabels[myRole] ?? myRole}.', style: mst(13, c: kGrey).copyWith(height: 1.5)),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: kLine)),
            child: Row(children: [const Icon(Icons.workspace_premium_outlined, color: kViolet), const SizedBox(width: 10), Expanded(child: Text('${(d['owner'] as Map)['name']}', style: mst(14, w: FontWeight.w800))), Text('Propriétaire', style: mst(12, w: FontWeight.w700, c: kViolet))]),
          ),
          for (final m in members)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: kLine)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('${m['name']}', style: mst(14, w: FontWeight.w800))),
                  Text(m['status'] == 'invited' ? 'Invitation envoyée' : (companyRoleLabels['${m['role']}'] ?? '${m['role']}'), style: mst(12, w: FontWeight.w700, c: m['status'] == 'invited' ? const Color(0xFFB45309) : kViolet)),
                ]),
                if ('${m['email'] ?? ''}'.isNotEmpty) Text('${m['email']}', style: mst(12, c: kGrey)),
                if (m['status'] == 'active' && '${m['account_role'] ?? ''}'.isNotEmpty)
                  Text('Compte : ${roleNames['${m['account_role']}'] ?? m['account_role']} · ${m['certified'] == true ? 'profil certifié' : 'profil non certifié'}', style: mst(11.5, c: kGrey)),
                if (canChangeMemberRole(myRole, '${m['role']}', isMe: '${m['user_id']}' == me) || canRemoveMember(myRole, '${m['role']}', isMe: '${m['user_id']}' == me))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(children: [
                      if (canChangeMemberRole(myRole, '${m['role']}', isMe: '${m['user_id']}' == me)) Expanded(child: MDropdown(label: 'Rôle', value: '${m['role']}', items: assignableCompanyRoles(myRole), onChanged: (v) => _call('company_member_set_role', {'p_user': m['user_id'], 'p_role': v}, 'Rôle modifié.'))),
                      if (canChangeMemberRole(myRole, '${m['role']}', isMe: '${m['user_id']}' == me)) const SizedBox(width: 8),
                      TextButton(
                        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                        onPressed: () => '${m['user_id']}' == me ? _leave(me) : _call('company_member_remove', {'p_user': m['user_id']}, m['status'] == 'invited' ? 'Invitation annulée.' : 'Membre retiré.'),
                        child: Text('${m['user_id']}' == me ? 'Quitter' : (m['status'] == 'invited' ? 'Annuler l’invitation' : 'Retirer'), style: mst(12.5, w: FontWeight.w700, c: kRed)),
                      ),
                    ]),
                  ),
              ]),
            ),
          if (canManage && !teamOpen)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: kLine)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [const Icon(Icons.lock_outline, size: 18, color: kGrey), const SizedBox(width: 8), Expanded(child: Text('Inviter des collègues : réservé à l’offre Organisation', style: mst(14, w: FontWeight.w800)))]),
                const SizedBox(height: 6),
                Text('L’invitation de nouveaux membres demande l’abonnement Organisation ou un forfait d’organisation payant. Les membres déjà dans l’équipe gardent leur accès.', style: mst(12.5, c: kGrey).copyWith(height: 1.4)),
                const SizedBox(height: 10),
                mButton('Voir les forfaits d’organisation', () => showCompanyPlans(context, ref), icon: Icons.workspace_premium_outlined),
                const SizedBox(height: 8),
                mButton('Voir les offres premium', () => context.push('/offres'), dark: false),
              ]),
            ),
          if (canManage && teamOpen) ...[
            mSectionTitle('Inviter un collègue'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'E-mail du compte', hintText: 'collegue@organisation.cm', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)))),
                const SizedBox(height: 10),
                MDropdown(label: 'Rôle', value: assignableCompanyRoles(myRole).containsKey(_role) ? _role : 'viewer', items: assignableCompanyRoles(myRole), onChanged: (v) => setState(() => _role = v)),
                Padding(padding: const EdgeInsets.only(top: 6), child: Text(companyRoleHelp[_role] ?? '', style: mst(12, c: kGrey))),
                const SizedBox(height: 4),
                Text('La personne doit déjà avoir un compte Boutik-École. Elle reçoit une notification et accepte l’invitation.', style: mst(12, c: kGrey)),
                const SizedBox(height: 10),
                mButton('Envoyer l’invitation', _invite, busy: _busy, icon: Icons.person_add_alt),
              ]),
            ),
          ],
        ]);
      }),
    );
  }
}

/// Organisations de la personne (la sienne et celles où elle est membre ou invitée) avec droits et pastilles d'activité calculés par le serveur (migration 20261128063000).
/// Fonction indisponible : repli sur la liste des appartenances, sans pastilles.
final myOrganizationsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final r = await marcheCall('my_organizations', const {});
  if (r.error != null) {
    // repli : la liste des appartenances (sans pastilles) ; si elle échoue aussi, l'erreur d'origine est dite
    try {
      return await ref.watch(myCompaniesProvider.future);
    } catch (_) {
      throw MarcheException(r.error);
    }
  }
  return [for (final x in (r.data as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
}, retry: (_, _) => null);

/// « Mes organisations » : sélecteur d'organisation active. Chaque organisation affiche mon rôle, ses pastilles d'activité (propositions à examiner, rappels échus,
/// demandes de contact sans réponse : absentes si mon rôle n'y donne pas accès) et des raccourcis qui ouvrent l'écran DANS cette organisation.
class MyCompaniesScreen extends ConsumerWidget {
  const MyCompaniesScreen({super.key});

  Future<void> _respond(BuildContext context, WidgetRef ref, String owner, bool accept) async {
    final r = await marcheCall('company_member_respond', {'p_owner': owner, 'p_accept': accept});
    if (!context.mounted) return;
    gToast(context, r.error != null ? Backend.userMessage('${r.error}') : (accept ? 'Vous avez rejoint l’organisation.' : 'Invitation déclinée.'));
    ref.invalidate(myCompaniesProvider);
    ref.invalidate(myOrganizationsProvider);
  }

  /// Ouvre [path] avec l'organisation [owner] comme organisation active ; le contexte est rendu au retour (null = ma propre organisation).
  Future<void> _openIn(BuildContext context, WidgetRef ref, Map<String, dynamic> c, String path) async {
    final ctx = ref.read(companyContextProvider.notifier);
    final own = c['is_own'] == true;
    final owner = '${c['owner_id']}';
    ctx.set(own ? null : owner);
    await context.push(path);
    if (own) {
      ctx.set(null);
    } else {
      ctx.clearIf(owner);
    }
  }

  Widget _badges(Map<String, dynamic> c) {
    final items = <String>[
      if (mInt(c['pending_proposals']) > 0) '${mInt(c['pending_proposals'])} proposition(s) à examiner',
      if (mInt(c['due_reminders']) > 0) '${mInt(c['due_reminders'])} rappel(s) échu(s)',
      if (mInt(c['pending_contacts']) > 0) '${mInt(c['pending_contacts'])} demande(s) sans réponse',
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(bottom: 6), child: Wrap(spacing: 6, runSpacing: 4, children: [for (final s in items) Chip(label: Text(s, style: mst(11.5, w: FontWeight.w700, c: kViolet)), visualDensity: VisualDensity.compact)]));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MarchePage(
      title: 'Mes organisations',
      child: mAsync<List<Map<String, dynamic>>>(
        ref.watch(myOrganizationsProvider),
        (l) => l.isEmpty
            ? mNote('Vous n’êtes membre d’aucune organisation.\nQuand un collègue vous invite avec votre e-mail, l’invitation apparaît ici.')
            : ListView(padding: const EdgeInsets.only(bottom: 90), children: [
                for (final c in l)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: kLine)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text('${c['company_name']}', style: mst(15, w: FontWeight.w800))),
                        if (c['verified'] == true) const Icon(Icons.verified, color: kGreen, size: 18),
                      ]),
                      Text(c['is_own'] == true ? 'Votre organisation' : 'Rôle : ${companyRoleLabels['${c['role']}'] ?? c['role']}', style: mst(12.5, c: kGrey)),
                      if (c['status'] == 'active' && c['verified'] != true) Text('En attente de vérification : certaines fonctions (vivier, contacts) ne sont pas encore ouvertes.', style: mst(12, c: kGrey)),
                      const SizedBox(height: 8),
                      if (c['status'] == 'invited')
                        Row(children: [
                          Expanded(child: mButton('Décliner', () => _respond(context, ref, '${c['owner_id']}', false), dark: false)),
                          const SizedBox(width: 10),
                          Expanded(child: mButton('Rejoindre', () => _respond(context, ref, '${c['owner_id']}', true))),
                        ])
                      else ...[
                        _badges(c),
                        if (c['is_own'] != true) mButton('Ouvrir l’espace de l’organisation', () => context.push('/entreprise/espace/${c['owner_id']}'), icon: Icons.business_center_outlined),
                        Wrap(spacing: 4, children: [
                          TextButton(onPressed: () => _openIn(context, ref, c, '/entreprise/suivi-missions'), child: const Text('Missions')),
                          if (c['can_pool_read'] == true) TextButton(onPressed: () => _openIn(context, ref, c, '/entreprise/vivier'), child: const Text('Vivier')),
                          if (c['can_pool_read'] == true) TextButton(onPressed: () => _openIn(context, ref, c, '/entreprise/contacts'), child: const Text('Demandes aux talents')),
                        ]),
                      ],
                    ]),
                  ),
              ]),
      ),
    );
  }
}
/// Espace partagé d'une organisation dont on est membre : même accueil, avec les droits du rôle.
class CompanySpaceScreen extends ConsumerStatefulWidget {
  const CompanySpaceScreen({super.key, required this.owner});
  final String owner;

  @override
  ConsumerState<CompanySpaceScreen> createState() => _SpaceState();
}

class _SpaceState extends ConsumerState<CompanySpaceScreen> {
  late final CompanyContext _ctx;

  @override
  void initState() {
    super.initState();
    _ctx = ref.read(companyContextProvider.notifier);
    Future.microtask(() => _ctx.set(widget.owner));
  }

  @override
  void dispose() {
    // l'espace partagé se referme : on revient à sa propre entreprise (après l'image en cours)
    Future.microtask(() => _ctx.clearIf(widget.owner));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctx = ref.watch(companyContextProvider);
    if (ctx != widget.owner) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return const CompanyHomeScreen(shared: true);
  }
}
