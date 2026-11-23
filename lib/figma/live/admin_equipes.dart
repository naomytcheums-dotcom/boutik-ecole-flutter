import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gAlert, gConfirm, gToast;
import '../i18n.dart' show Text;
import '../nav.dart';
import 'access.dart' show roleKey;
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

/// Historique des attributions d'un seul compte (clé = identifiant du compte).
final adminTeamUserHistoryProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, user) async {
  ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  if (!Backend.ready) return const [];
  return _list(await _call('admin_team_history_list', {'p_user': user, 'p_limit': 60}));
}, retry: (_, _) => null);

/// Comptes Finance / Support dont les droits n'ont jamais été attribués explicitement (droits minimaux, à réviser par l'administrateur global).
final adminTeamsReviewProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  if (!Backend.ready) return const [];
  return _list(await _call('admin_team_accounts_review', const {}));
}, retry: (_, _) => null);

const _actionLabels = {
  'grant': 'Agent ajouté',
  'update': 'Permissions modifiées',
  'revoke': 'Agent retiré',
  'auto_enroll': 'Inscription automatique (sans permission)',
  'auto_revoke': 'Retrait automatique',
  'migration': 'Migration des comptes existants',
  'reduce': 'Droits hérités réduits au minimum',
  'keep_minimal': 'Droits minimaux confirmés',
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
    ref.invalidate(adminTeamUserHistoryProvider);
    ref.invalidate(adminTeamsReviewProvider);
  }

  /// L'administrateur confirme, avec un motif, que le compte doit garder les droits minimaux : il sort de la liste à réviser (événement historisé et audité côté serveur).
  Future<void> _keepMinimal(Map<String, dynamic> r) async {
    final note = await askText(
      context,
      title: 'Droits minimaux voulus pour ${r['name']} ?',
      body: 'Le compte garde le tableau de bord seulement, sans aucune opération sensible. Votre motif est inscrit dans l’historique du compte.',
      hint: 'Motif (5 caractères au moins)',
      ok: 'Confirmer',
      min: 5,
    );
    if (note == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await _call('admin_team_account_keep_minimal', {'p_user': r['user_id'], 'p_note': note.trim()});
      if (!mounted) return;
      gToast(context, 'Droits minimaux de ${r['name']} confirmés.');
      _refresh();
    } catch (e) {
      if (mounted) await gAlert(context, 'Confirmation impossible', _msg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Compte à réviser : l'administrateur choisit, en connaissance de cause, les permissions de l'équipe du rôle ; rien n'est coché d'office (les droits d'avant ne sont affichés que pour information).
  Future<void> _assignFromReview(List<Map<String, dynamic>> teams, Map<String, dynamic> r) async {
    final code = '${r['role']}';
    final team = teams.where((t) => t['code'] == code);
    if (team.isEmpty) return;
    final perms = await _pickPermissions(team.first, '${r['name']}', <String>{});
    if (perms == null || !mounted) return;
    setState(() => _team = code);
    await _save(team.first, '${r['user_id']}', '${r['name']}', perms, isNew: true);
  }

  Widget _reviewSection(List<Map<String, dynamic>> teams) {
    final review = ref.watch(adminTeamsReviewProvider);
    return review.when(
      loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Column(children: [
        tpNote(_msg(e), c: tpRed),
        TpButton('Réessayer', () => ref.invalidate(adminTeamsReviewProvider), dark: false),
      ]),
      data: (rows) {
        final todo = [for (final r in rows) if (r['needs_review'] == true) r];
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          tpSection('Comptes à réviser', hint: 'Comptes Finance ou Support sans permission attribuée par vos soins : droits minimaux (tableau de bord seulement) tant que vous ne leur en attribuez pas.'),
          if (todo.isEmpty)
            tpNote('Aucun compte à réviser : chaque compte Finance ou Support a reçu ses permissions de votre part ou la confirmation explicite de ses droits minimaux.')
          else
            for (final r in todo)
              TpCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('${r['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tpSt(14.5, w: FontWeight.w700))),
                    if (r['suspended'] == true) Text('Suspendu', style: tpSt(11.5, w: FontWeight.w700, c: tpRed)),
                  ]),
                  Text('${r['email'] ?? ''} · rôle ${r['role'] == 'finance' ? 'Finance' : 'Support'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tpSt(12, c: tpGrey)),
                  const SizedBox(height: 6),
                  Text('Droits minimaux : aucune opération sensible.', style: tpSt(12, c: tpGrey, h: 1.4)),
                  if (_list(r['previous']).isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('Droits hérités avant la réduction :', style: tpSt(11.5, w: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final p in _list(r['previous']).expand((x) => (x['permissions'] is List ? x['permissions'] as List : const [])).toSet())
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: const Color(0xFFF1F1F4), borderRadius: BorderRadius.circular(100)),
                          child: Text(kPermissionLabels['$p'] ?? '$p', style: tpSt(11.5, w: FontWeight.w600, c: tpGrey)),
                        ),
                    ]),
                  ],
                  const SizedBox(height: 10),
                  TpButton('Attribuer des permissions', (_busy || r['suspended'] == true) ? null : () => _assignFromReview(teams, r), compact: true),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: TpButton('Droits minimaux voulus', (_busy || r['suspended'] == true) ? null : () => _keepMinimal(r), dark: false, compact: true)),
                    const SizedBox(width: 10),
                    Expanded(child: TpButton('Historique', () => _history(account: r), dark: false, compact: true, icon: Icons.history_rounded)),
                  ]),
                ]),
              ),
          for (final r in rows)
            if (r['needs_review'] != true && r['minimal_confirmed'] == true)
              TpCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${r['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tpSt(14.5, w: FontWeight.w700)),
                  Text('${r['email'] ?? ''} · rôle ${r['role'] == 'finance' ? 'Finance' : 'Support'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tpSt(12, c: tpGrey)),
                  const SizedBox(height: 6),
                  Text('Droits minimaux confirmés par l’administrateur.', style: tpSt(12, c: tpGreen, w: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TpButton('Historique', () => _history(account: r), dark: false, compact: true, icon: Icons.history_rounded),
                ]),
              ),
        ]);
      },
    );
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

  Future<void> _history({Map<String, dynamic>? account}) async {
    ref.invalidate(adminTeamHistoryProvider);
    ref.invalidate(adminTeamUserHistoryProvider);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 420),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final h = account == null ? ref.watch(adminTeamHistoryProvider) : ref.watch(adminTeamUserHistoryProvider('${account['user_id']}'));
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.8),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 8), child: Text(account == null ? 'Historique des attributions' : 'Historique de ${account['name']}', style: tpSt(17, w: FontWeight.w700))),
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
                              if (m['permissions'] is List && (m['permissions'] as List).isEmpty) Text('Aucune permission : droits minimaux (tableau de bord seulement).', style: tpSt(12, c: tpGrey, h: 1.4)),
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
              _reviewSection(teams),
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

const _flagStatus = {'open': 'À examiner', 'escalated': 'Transmis', 'cleared': 'Hors de cause', 'suspended': 'Suspendus'};

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
      ref.invalidate(securityFlagsProvider('escalated'));
      ref.invalidate(securityFlagsProvider('suspended'));
      ref.invalidate(securityFlagsProvider('cleared'));
    } catch (e) {
      if (mounted) await gAlert(context, 'Action impossible', _msg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Décision de l'administrateur global : suspension réelle du compte (connexion bloquée) ou classement motivé.
  Future<void> _resolve(Map<String, dynamic> f, String decision) async {
    final suspend = decision == 'suspend';
    if (suspend && !await gConfirm(context, 'Suspendre ${f['name']} ?', 'Sa connexion est bloquée et ses sessions sont fermées. L’action est journalisée et l’auteur du signalement est prévenu.', yes: 'Suspendre')) return;
    if (!mounted) return;
    final note = await askText(
      context,
      title: suspend ? 'Motif de la suspension' : 'Classer le signalement',
      body: suspend ? 'Facultatif : inscrit dans la décision.' : 'Indiquez pourquoi ce compte n’est pas suspendu.',
      hint: suspend ? 'Motif' : 'Motif (5 caractères au moins)',
      ok: suspend ? 'Suspendre' : 'Classer',
      min: suspend ? 0 : 5,
    );
    if (note == null || !mounted) return;
    await _run(() => _call('security_flag_resolve', {'p_id': f['id'], 'p_decision': decision, if (note.trim().isNotEmpty) 'p_note': note.trim()}),
        suspend ? '${f['name']} est suspendu.' : 'Signalement classé.');
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
    final isAdmin = roleKey(ref.watch(authProvider.select((a) => a.current))) == 'admin';
    return TpPage(
      title: 'Comptes suspects',
      subtitle: 'Sécurité et modération',
      children: [
        tpNote(isAdmin
            ? 'Vous tranchez les comptes signalés : la suspension bloque réellement la connexion du compte ; le classement exige un motif. L’auteur du signalement est prévenu.'
            : 'Signalez un compte qui semble frauduleux ou abusif : l’administrateur global est prévenu et reste seul à suspendre un compte.'),
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
                          Text(_flagStatus['${f['status']}'] ?? '${f['status']}', style: tpSt(11.5, w: FontWeight.w700, c: (f['status'] == 'open' || f['status'] == 'suspended') ? tpRed : tpGreen)),
                        ]),
                        Text('${f['email'] ?? ''} · ${f['role']}${f['suspended'] == true ? ' · suspendu' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tpSt(12, c: tpGrey)),
                        const SizedBox(height: 8),
                        Text('${f['reason']}', style: tpSt(13, h: 1.45)),
                        const SizedBox(height: 6),
                        Text('Signalé par ${f['flagged_by'] ?? '—'} · ${tpDate(f['created_at'])}', style: tpSt(11.5, c: tpGrey)),
                        if ('${f['decision_note'] ?? ''}'.isNotEmpty) Text('Décision : ${f['decision_note']}', style: tpSt(11.5, c: tpGrey, h: 1.4)),
                        if (f['status'] == 'open' && !isAdmin) ...[
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(child: TpButton('Hors de cause', _busy ? null : () => _decide(f, 'clear'), dark: false, compact: true)),
                            const SizedBox(width: 10),
                            Expanded(child: TpButton('Transmettre', _busy ? null : () => _decide(f, 'escalate'), compact: true)),
                          ]),
                        ],
                        if (isAdmin && (f['status'] == 'open' || f['status'] == 'escalated')) ...[
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(child: TpButton('Classer', _busy ? null : () => _resolve(f, 'dismiss'), dark: false, compact: true)),
                            const SizedBox(width: 10),
                            Expanded(child: TpButton('Suspendre', (_busy || f['suspended'] == true) ? null : () => _resolve(f, 'suspend'), danger: true, compact: true)),
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
