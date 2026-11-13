import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../gen.dart' show gToast;
import '../i18n.dart' show Text;
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
});

final myCompaniesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final r = await marcheCall('my_company_memberships', const {});
  if (r.error != null) throw MarcheException(r.error);
  return [for (final x in (r.data as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
});

/// Droits d'un rôle : modifier la fiche, gérer l'équipe, payer le forfait.
bool roleCanManage(String role) => role == 'owner' || role == 'admin';
bool roleCanPay(String role) => role == 'owner' || role == 'admin' || role == 'finance';

/// Explication courte de ce que peut faire chaque rôle.
const companyRoleHelp = {
  'admin': 'Modifie la fiche, gère l’équipe, paie le forfait.',
  'finance': 'Consulte et paie le forfait.',
  'viewer': 'Consulte l’accueil, la fiche et l’équipe.',
};

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

  Future<void> _call(String fn, Map<String, dynamic> p, String ok) async {
    final r = await marcheCall(fn, {...p, if (_owner != null) 'p_owner': _owner});
    if (!mounted) return;
    gToast(context, r.error != null ? Backend.userMessage('${r.error}') : ok);
    ref.invalidate(companyMembersProvider);
    ref.invalidate(companyDashboardProvider);
  }

  Future<void> _invite() async {
    if (_email.text.trim().isEmpty) return gToast(context, 'Saisissez l’e-mail de la personne.');
    setState(() => _busy = true);
    await _call('company_invite', {'p_email': _email.text, 'p_role': _role}, 'Invitation envoyée.');
    if (mounted) {
      setState(() => _busy = false);
      _email.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(companyMembersProvider);
    final me = ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
    return MarchePage(
      title: 'Équipe de l’entreprise',
      child: mAsync<Map<String, dynamic>>(async, (d) {
        final myRole = '${d['my_role']}';
        final canManage = roleCanManage(myRole);
        final members = [for (final x in (d['members'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
        return ListView(padding: const EdgeInsets.only(bottom: 90), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text('Plusieurs personnes de l’entreprise partagent la même interface, avec des droits différents. Votre rôle : ${companyRoleLabels[myRole] ?? myRole}.', style: mst(13, c: kGrey).copyWith(height: 1.5)),
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
                if (canManage || '${m['user_id']}' == me)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(children: [
                      if (canManage) Expanded(child: MDropdown(label: 'Rôle', value: '${m['role']}', items: {for (final e in companyRoleLabels.entries) if (e.key != 'owner') e.key: e.value}, onChanged: (v) => _call('company_member_set_role', {'p_user': m['user_id'], 'p_role': v}, 'Rôle modifié.'))),
                      if (canManage) const SizedBox(width: 8),
                      TextButton(onPressed: () => _call('company_member_remove', {'p_user': m['user_id']}, '${m['user_id']}' == me ? 'Vous avez quitté l’équipe.' : 'Membre retiré.'), child: Text('${m['user_id']}' == me ? 'Quitter' : 'Retirer', style: mst(12.5, w: FontWeight.w700, c: kRed))),
                    ]),
                  ),
              ]),
            ),
          if (canManage) ...[
            mSectionTitle('Inviter un collègue'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'E-mail du compte', hintText: 'collegue@entreprise.cm', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)))),
                const SizedBox(height: 10),
                MDropdown(label: 'Rôle', value: _role, items: {for (final e in companyRoleLabels.entries) if (e.key != 'owner') e.key: e.value}, onChanged: (v) => setState(() => _role = v)),
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

/// « Mes entreprises » : invitations reçues et entreprises dont je suis membre.
class MyCompaniesScreen extends ConsumerWidget {
  const MyCompaniesScreen({super.key});

  Future<void> _respond(BuildContext context, WidgetRef ref, String owner, bool accept) async {
    final r = await marcheCall('company_member_respond', {'p_owner': owner, 'p_accept': accept});
    if (!context.mounted) return;
    gToast(context, r.error != null ? Backend.userMessage('${r.error}') : (accept ? 'Vous avez rejoint l’entreprise.' : 'Invitation déclinée.'));
    ref.invalidate(myCompaniesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MarchePage(
      title: 'Mes entreprises',
      child: mAsync<List<Map<String, dynamic>>>(
        ref.watch(myCompaniesProvider),
        (l) => l.isEmpty
            ? mNote('Vous n’êtes membre d’aucune entreprise.\nQuand un collègue vous invite avec votre e-mail, l’invitation apparaît ici.')
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
                      Text('Rôle : ${companyRoleLabels['${c['role']}'] ?? c['role']}', style: mst(12.5, c: kGrey)),
                      const SizedBox(height: 8),
                      if (c['status'] == 'invited')
                        Row(children: [
                          Expanded(child: mButton('Décliner', () => _respond(context, ref, '${c['owner_id']}', false), dark: false)),
                          const SizedBox(width: 10),
                          Expanded(child: mButton('Rejoindre', () => _respond(context, ref, '${c['owner_id']}', true))),
                        ])
                      else
                        mButton('Ouvrir l’espace entreprise', () => context.push('/entreprise/espace/${c['owner_id']}'), icon: Icons.business_center_outlined),
                    ]),
                  ),
              ]),
      ),
    );
  }
}

/// Espace partagé d'une entreprise dont on est membre : même accueil, avec les droits du rôle.
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
    Future.microtask(() => _ctx.set(null));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctx = ref.watch(companyContextProvider);
    if (ctx != widget.owner) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return const CompanyHomeScreen(shared: true);
  }
}
