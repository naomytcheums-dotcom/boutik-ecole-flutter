import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gAlert, gConfirm, gToast;
import '../i18n.dart' show Text;
import '../nav.dart';
import 'admin_centre.dart' show kPermissionLabels;
import 'auth.dart';
import 'backend.dart';
import 'talents.dart' show askText;
import 'tp_ui.dart';

/// Gestion des équipes et des permissions (écran 305, administrateur global) et comptes suspects de l'équipe Sécurité (écran 306).
/// Chaque attribution ou retrait passe par une fonction serveur réservée à l'administrateur, qui journalise (audit + historique) et prévient l'agent :
/// rien n'est annoncé comme enregistré sans confirmation du serveur.

List<Map<String, dynamic>> _list(Object? d) => [for (final x in (d is List ? d : const [])) if (x is Map) Map<String, dynamic>.from(x)];

Future<Object?> _call(String fn, Map<String, dynamic> params) async {
  final r = await Backend.rpc(fn, params);
  if (r.error != null) throw Exception(Backend.userMessage(r.error!));
  return r.data;
}

String _msg(Object e) => '$e'.replaceFirst('Exception: ', '');

/// Équipes avec leurs permissions (catalogue du serveur) : `[ {code, name, description, members, permissions:[{code,label,description,sensitive}], defaults:[…]} ]`.
final adminTeamsOverviewProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  if (!Backend.ready) return const [];
  return _list(await _call('admin_teams_overview', const {}));
}, retry: (_, _) => null);

final adminTeamMembersProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, team) async {
  ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  if (!Backend.ready) return const [];
  return _list(await _call('admin_team_members_list', {'p_team': team}));
}, retry: (_, _) => null);

final adminTeamHistoryProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  if (!Backend.ready) return const [];
  return _list(await _call('admin_team_history_list', const {'p_limit': 60}));
}, retry: (_, _) => null);

const _actionLabels = {
  'grant': 'Agent ajouté',
  'update': 'Permissions modifiées',
  'revoke': 'Agent retiré',
  'auto_enroll': 'Inscription automatique',
  'auto_revoke': 'Retrait automatique',
  'migration': 'Migration des comptes existants',
};

class AdminTeamsScreen extends ConsumerStatefulWidget {
  const AdminTeamsScreen({super.key});

  @override
  ConsumerState<AdminTeamsScreen> createState() => _AdminTeamsScreenState();
}

class _AdminTeamsScreenState extends ConsumerState<AdminTeamsScreen> {
  String _team = 'finance';
  bool _busy = false;

  void _refresh() {
    ref.invalidate(adminTeamsOverviewProvider);
    ref.invalidate(adminTeamMembersProvider(_team));
    ref.invalidate(adminTeamHistoryProvider);
  }

  Future<void> _save(Map<String, dynamic> team, String userId, String name, Set<String> perms, {required bool isNew}) async {
    setState(() => _busy = true);
    try {
      await _call('admin_team_member_set', {'p_user': userId, 'p_team': _team, 'p_permissions': perms.toList()..sort()});
      if (!mounted) return;
      gToast(context, isNew ? '$name rejoint l’équipe ${team['name']}.' : 'Permissions de $name mises à jour.');
      _refresh();
    } catch (e) {
      if (mounted) await gAlert(context, 'Permissions non modifiées', _msg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(Map<String, dynamic> team, Map<String, dynamic> m) async {
    final ok = await gConfirm(context, 'Retirer ${m['name']} ?', 'Il ou elle perd toutes les permissions de l’équipe ${team['name']}. L’action est journalisée et l’agent est prévenu.', yes: 'Retirer');
    if (!ok || !mounted) return;
    final note = await askText(context, title: 'Motif (facultatif)', body: 'Inscrit dans l’historique de l’équipe.', hint: 'Motif', ok: 'Retirer');
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await _call('admin_team_member_remove', {'p_user': m['user_id'], 'p_team': _team, if ((note ?? '').trim().isNotEmpty) 'p_note': note!.trim()});
      if (!mounted) return;
      gToast(context, '${m['name']} a quitté l’équipe.');
      _refresh();
    } catch (e) {
      if (mounted) await gAlert(context, 'Agent non retiré', _msg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Set<String>?> _pickPermissions(Map<String, dynamic> team, String name, Set<String> start) {
    final perms = _list(team['permissions']);
    final chosen = {...start};
    return showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 420),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.86),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                child: Text('Permissions de $name', style: tpSt(17, w: FontWeight.w700)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('Équipe ${team['name']} : cochez ce que cet agent peut faire. Les permissions sensibles engagent de l’argent ou la configuration.', style: tpSt(12, c: tpGrey, h: 1.45)),
              ),
              Flexible(
                child: ListView(shrinkWrap: true, padding: const EdgeInsets.symmetric(horizontal: 8), children: [
                  for (final p in perms)
                    CheckboxListTile(
                      value: chosen.contains(p['code']),
                      onChanged: (v) => set(() => v == true ? chosen.add('${p['code']}') : chosen.remove('${p['code']}')),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      title: Row(children: [
                        Flexible(child: Text('${p['label']}', style: tpSt(14, w: FontWeight.w600))),
                        if (p['sensitive'] == true) ...[
                          const SizedBox(width: 8),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFFDE6E7), borderRadius: BorderRadius.circular(100)), child: Text('Sensible', style: tpSt(10.5, w: FontWeight.w700, c: tpRed))),
                        ],
                      ]),
                      subtitle: Text('${p['description']}', style: tpSt(12, c: tpGrey, h: 1.4)),
                    ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(children: [
                  Expanded(child: TpButton('Annuler', () => Navigator.of(ctx).pop(), dark: false)),
                  const SizedBox(width: 12),
                  Expanded(child: TpButton('Enregistrer', chosen.isEmpty ? null : () => Navigator.of(ctx).pop(chosen))),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _add(Map<String, dynamic> team) async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 420),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) => const _CandidateSheet(),
    );
    if (picked == null || !mounted) return;
    final perms = await _pickPermissions(team, '${picked['name']}', {for (final p in (team['defaults'] is List ? team['defaults'] as List : const [])) '$p'});
    if (perms == null || !mounted) return;
    await _save(team, '${picked['id']}', '${picked['name']}', perms, isNew: true);
  }

  Future<void> _history() async {
    ref.invalidate(adminTeamHistoryProvider);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 420),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final h = ref.watch(adminTeamHistoryProvider);
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.8),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 8), child: Text('Historique des attributions', style: tpSt(17, w: FontWeight.w700))),
                Flexible(
                  child: h.when(
                    loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
                    error: (e, _) => Padding(padding: const EdgeInsets.all(20), child: Text(_msg(e), style: tpSt(13, c: tpRed))),
                    data: (rows) => rows.isEmpty
                        ? Padding(padding: const EdgeInsets.all(20), child: Text('Aucune attribution enregistrée.', style: tpSt(13, c: tpGrey)))
                        : ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
                            for (final r in rows)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('${_actionLabels[r['action']] ?? r['action']} · ${r['user']}', style: tpSt(13.5, w: FontWeight.w700)),
                                  Text('${tpDate(r['at'])} · équipe ${r['team']} · par ${r['actor'] ?? 'le système'}', style: tpSt(11.5, c: tpGrey)),
                                  if (r['after'] is List && (r['after'] as List).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text((r['after'] as List).map((p) => kPermissionLabels['$p'] ?? '$p').join(', '), style: tpSt(12, h: 1.4))),
                                  if ('${r['note'] ?? ''}'.isNotEmpty) Text('« ${r['note']} »', style: tpSt(12, c: tpGrey, h: 1.4)),
                                ]),
                              ),
                          ]),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(adminTeamsOverviewProvider);
    final members = ref.watch(adminTeamMembersProvider(_team));
    return TpPage(
      title: 'Équipes et permissions',
      subtitle: 'Administrateur global',
      actions: [TpRound(icon: Icons.history_rounded, label: 'Historique', onTap: _history)],
      children: [
        tpNote('Finance, Support, Sécurité et modération et Technique sont des équipes internes : les droits d’un agent viennent des permissions que vous lui attribuez. '
            'Vous gardez tous les droits. Chaque attribution et chaque retrait est journalisé.'),
        overview.when(
          loading: () => const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(children: [
              Text(_msg(e), textAlign: TextAlign.center, style: tpSt(13, c: tpRed, h: 1.5)),
              const SizedBox(height: 12),
              TpButton('Réessayer', () => ref.invalidate(adminTeamsOverviewProvider), dark: false),
            ]),
          ),
          data: (teams) {
            if (teams.isEmpty) {
              return TpEmpty(title: 'Aucune donnée', text: Backend.ready ? 'Aucune équipe n’a été trouvée.' : 'La gestion des équipes se fait connecté au serveur.', icon: Icons.groups_2_outlined);
            }
            final team = teams.firstWhere((t) => t['code'] == _team, orElse: () => teams.first);
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TpChoice('Équipe', {for (final t in teams) '${t['code']}': '${t['name']}'}, _team, (v) => setState(() => _team = v)),
              TpCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${team['name']}', style: tpSt(15, w: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('${team['description']}', style: tpSt(12.5, c: tpGrey, h: 1.45)),
                ]),
              ),
              tpSection('Agents de l’équipe', hint: 'Seuls les comptes de rôle Finance ou Support rejoignent une équipe (le rôle se règle dans « Comptes, rôles et permissions »).'),
              members.when(
                loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
                error: (e, _) => tpNote(_msg(e), c: tpRed),
                data: (rows) => rows.isEmpty
                    ? TpEmpty(title: 'Aucun agent', text: 'Personne n’a de permission dans cette équipe : ajoutez un agent.', action: 'Ajouter un agent', onAction: _busy ? null : () => _add(team), icon: Icons.person_add_alt_1_outlined)
                    : Column(children: [
                        for (final m in rows)
                          TpCard(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Expanded(child: Text('${m['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tpSt(14.5, w: FontWeight.w700))),
                                if (m['suspended'] == true) Text('Suspendu', style: tpSt(11.5, w: FontWeight.w700, c: tpRed)),
                              ]),
                              Text('${m['email'] ?? ''} · rôle ${m['role'] == 'finance' ? 'Finance' : 'Support'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tpSt(12, c: tpGrey)),
                              const SizedBox(height: 8),
                              Wrap(spacing: 6, runSpacing: 6, children: [
                                for (final p in (m['permissions'] is List ? m['permissions'] as List : const []))
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(color: const Color(0xFFEFEAFB), borderRadius: BorderRadius.circular(100)),
                                    child: Text(kPermissionLabels['$p'] ?? '$p', style: tpSt(11.5, w: FontWeight.w600, c: tpViolet)),
                                  ),
                              ]),
                              if ('${m['granted_by'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Attribué par ${m['granted_by']} · ${tpDate(m['updated_at'])}', style: tpSt(11.5, c: tpGrey))),
                              const SizedBox(height: 10),
                              Row(children: [
                                Expanded(
                                  child: TpButton('Modifier', _busy ? null : () async {
                                    final perms = await _pickPermissions(team, '${m['name']}', {for (final p in (m['permissions'] is List ? m['permissions'] as List : const [])) '$p'});
                                    if (perms != null && mounted) await _save(team, '${m['user_id']}', '${m['name']}', perms, isNew: false);
                                  }, dark: false, compact: true),
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: TpButton('Retirer', _busy ? null : () => _remove(team, m), danger: true, compact: true)),
                              ]),
                            ]),
                          ),
                        const SizedBox(height: 4),
                        TpButton('Ajouter un agent', _busy ? null : () => _add(team), icon: Icons.person_add_alt_1_outlined),
                      ]),
              ),
              const SizedBox(height: 18),
              TpButton('Comptes, rôles et permissions', () => gOpen(context, '128'), dark: false, icon: Icons.manage_accounts_outlined),
            ]);
          },
        ),
      ],
    );
  }
}

/// Recherche d'un agent à recruter (comptes de rôle finance ou support).
class _CandidateSheet extends StatefulWidget {
  const _CandidateSheet();

  @override
  State<_CandidateSheet> createState() => _CandidateSheetState();
}

class _CandidateSheetState extends State<_CandidateSheet> {
  final _q = TextEditingController();
  List<Map<String, dynamic>>? _rows;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = _list(await _call('admin_team_candidates', {'p_query': _q.text.trim()}));
      if (mounted) setState(() => _rows = r);
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 4), child: Text('Ajouter un agent', style: tpSt(17, w: FontWeight.w700))),
              Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text('Comptes de rôle Finance ou Support. Pour recruter une autre personne, changez d’abord son rôle.', style: tpSt(12, c: tpGrey, h: 1.45))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _q,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: 'Nom ou e-mail',
                    isDense: true,
                    suffixIcon: IconButton(onPressed: _search, icon: const Icon(Icons.search_rounded), tooltip: 'Rechercher'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: _loading
                    ? const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator()))
                    : _error != null
                        ? Padding(padding: const EdgeInsets.all(20), child: Text(_error!, style: tpSt(13, c: tpRed)))
                        : (_rows ?? const []).isEmpty
                            ? Padding(padding: const EdgeInsets.all(20), child: Text('Aucun compte Finance ou Support trouvé.', style: tpSt(13, c: tpGrey)))
                            : ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(8, 0, 8, 16), children: [
                                for (final c in _rows!)
                                  ListTile(
                                    minVerticalPadding: 10,
                                    enabled: c['suspended'] != true,
                                    title: Text('${c['name']}', style: tpSt(14, w: FontWeight.w600)),
                                    subtitle: Text('${c['email'] ?? ''} · ${c['role'] == 'finance' ? 'Finance' : 'Support'}${(c['teams'] is List && (c['teams'] as List).isNotEmpty) ? ' · équipes : ${(c['teams'] as List).join(', ')}' : ''}${c['suspended'] == true ? ' · suspendu' : ''}', style: tpSt(12, c: tpGrey)),
                                    onTap: c['suspended'] == true ? null : () => Navigator.of(context).pop(c),
                                  ),
                              ]),
              ),
            ]),
          ),
        ),
      );
}

// ------------------------------------------------------------------ comptes suspects (équipe Sécurité et modération)

final securityFlagsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, status) async {
  ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  if (!Backend.ready) return const [];
  return _list(await _call('security_flags_list', {'p_status': status}));
}, retry: (_, _) => null);

const _flagStatus = {'open': 'À examiner', 'escalated': 'Transmis', 'cleared': 'Hors de cause'};

class SecurityFlagsScreen extends ConsumerStatefulWidget {
  const SecurityFlagsScreen({super.key});

  @override
  ConsumerState<SecurityFlagsScreen> createState() => _SecurityFlagsScreenState();
}

class _SecurityFlagsScreenState extends ConsumerState<SecurityFlagsScreen> {
  String _status = 'open';
  bool _busy = false;

  Future<void> _run(Future<Object?> Function() job, String done) async {
    setState(() => _busy = true);
    try {
      await job();
      if (!mounted) return;
      gToast(context, done);
      ref.invalidate(securityFlagsProvider(_status));
      ref.invalidate(securityFlagsProvider('open'));
    } catch (e) {
      if (mounted) await gAlert(context, 'Action impossible', _msg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decide(Map<String, dynamic> f, String decision) async {
    final note = await askText(
      context,
      title: decision == 'clear' ? 'Mettre ${f['name']} hors de cause' : 'Transmettre à l’administrateur',
      body: decision == 'clear' ? 'Indiquez pourquoi ce compte n’est pas suspect.' : 'L’administrateur global décidera de la suspension. Ajoutez un élément utile (facultatif).',
      hint: decision == 'clear' ? 'Motif (5 caractères au moins)' : 'Précision',
      ok: 'Confirmer',
      min: decision == 'clear' ? 5 : 0,
    );
    if (note == null || !mounted) return;
    await _run(() => _call('security_flag_decide', {'p_id': f['id'], 'p_decision': decision, if (note.trim().isNotEmpty) 'p_note': note.trim()}),
        decision == 'clear' ? 'Compte mis hors de cause.' : 'Signalement transmis à l’administrateur.');
  }

  Future<void> _flag() async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 420),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) => const _AccountSearchSheet(),
    );
    if (picked == null || !mounted) return;
    final reason = await askText(context, title: 'Signaler ${picked['name']}', body: 'Décrivez ce qui rend ce compte suspect (fraude, abus…).', hint: 'Motif (5 à 500 caractères)', ok: 'Signaler', min: 5);
    if (reason == null || !mounted) return;
    await _run(() => _call('security_flag_account', {'p_user': picked['id'], 'p_reason': reason.trim()}), 'Compte signalé : les administrateurs sont prévenus.');
  }

  @override
  Widget build(BuildContext context) {
    final flags = ref.watch(securityFlagsProvider(_status));
    return TpPage(
      title: 'Comptes suspects',
      subtitle: 'Sécurité et modération',
      children: [
        tpNote('Signalez un compte qui semble frauduleux ou abusif : l’administrateur global est prévenu et reste seul à suspendre un compte.'),
        TpButton('Signaler un compte', _busy ? null : _flag, icon: Icons.flag_outlined),
        const SizedBox(height: 14),
        TpChoice('Afficher', _flagStatus, _status, (v) => setState(() => _status = v)),
        flags.when(
          loading: () => const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(children: [
              Text(_msg(e), textAlign: TextAlign.center, style: tpSt(13, c: tpRed, h: 1.5)),
              const SizedBox(height: 12),
              TpButton('Réessayer', () => ref.invalidate(securityFlagsProvider(_status)), dark: false),
            ]),
          ),
          data: (rows) => rows.isEmpty
              ? TpEmpty(title: 'Aucun signalement', text: Backend.ready ? 'Aucun compte dans cette catégorie.' : 'Les signalements s’affichent une fois connecté au serveur.', icon: Icons.verified_user_outlined)
              : Column(children: [
                  for (final f in rows)
                    TpCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text('${f['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tpSt(14.5, w: FontWeight.w700))),
                          Text(_flagStatus['${f['status']}'] ?? '${f['status']}', style: tpSt(11.5, w: FontWeight.w700, c: f['status'] == 'open' ? tpRed : tpGreen)),
                        ]),
                        Text('${f['email'] ?? ''} · ${f['role']}${f['suspended'] == true ? ' · suspendu' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tpSt(12, c: tpGrey)),
                        const SizedBox(height: 8),
                        Text('${f['reason']}', style: tpSt(13, h: 1.45)),
                        const SizedBox(height: 6),
                        Text('Signalé par ${f['flagged_by'] ?? '—'} · ${tpDate(f['created_at'])}', style: tpSt(11.5, c: tpGrey)),
                        if ('${f['decision_note'] ?? ''}'.isNotEmpty) Text('Décision : ${f['decision_note']}', style: tpSt(11.5, c: tpGrey, h: 1.4)),
                        if (f['status'] == 'open') ...[
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(child: TpButton('Hors de cause', _busy ? null : () => _decide(f, 'clear'), dark: false, compact: true)),
                            const SizedBox(width: 10),
                            Expanded(child: TpButton('Transmettre', _busy ? null : () => _decide(f, 'escalate'), compact: true)),
                          ]),
                        ],
                      ]),
                    ),
                ]),
        ),
      ],
    );
  }
}

class _AccountSearchSheet extends StatefulWidget {
  const _AccountSearchSheet();

  @override
  State<_AccountSearchSheet> createState() => _AccountSearchSheetState();
}

class _AccountSearchSheetState extends State<_AccountSearchSheet> {
  final _q = TextEditingController();
  List<Map<String, dynamic>>? _rows;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_q.text.trim().length < 3) {
      setState(() => _error = 'Saisissez au moins 3 caractères.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = _list(await _call('security_accounts_search', {'p_query': _q.text.trim()}));
      if (mounted) setState(() => _rows = r);
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 8), child: Text('Trouver le compte', style: tpSt(17, w: FontWeight.w700))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _q,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: 'Nom ou e-mail (3 caractères au moins)',
                    isDense: true,
                    suffixIcon: IconButton(onPressed: _search, icon: const Icon(Icons.search_rounded), tooltip: 'Rechercher'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: _loading
                    ? const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator()))
                    : _error != null
                        ? Padding(padding: const EdgeInsets.all(20), child: Text(_error!, style: tpSt(13, c: tpRed)))
                        : _rows == null
                            ? const SizedBox(height: 24)
                            : _rows!.isEmpty
                                ? Padding(padding: const EdgeInsets.all(20), child: Text('Aucun compte ne correspond (les comptes de l’équipe ne se signalent pas ici).', style: tpSt(13, c: tpGrey, h: 1.5)))
                                : ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(8, 0, 8, 16), children: [
                                    for (final c in _rows!)
                                      ListTile(
                                        minVerticalPadding: 10,
                                        enabled: c['open_flag'] != true,
                                        title: Text('${c['name']}', style: tpSt(14, w: FontWeight.w600)),
                                        subtitle: Text('${c['email'] ?? ''} · ${c['role']}${c['open_flag'] == true ? ' · déjà signalé' : ''}${c['suspended'] == true ? ' · suspendu' : ''}', style: tpSt(12, c: tpGrey)),
                                        onTap: c['open_flag'] == true ? null : () => Navigator.of(context).pop(c),
                                      ),
                                  ]),
              ),
            ]),
          ),
        ),
      );
}
