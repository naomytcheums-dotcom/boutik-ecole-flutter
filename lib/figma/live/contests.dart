import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart';
import 'auth.dart';
import 'backend.dart';
import 'hackathons.dart';
import 'talents.dart' show askText;

/// Concours réels (migration 20261101000200) : liste, équipes, dépôt, jury, classement, publication et modération.
/// Toute écriture passe par une fonction serveur ; aucun succès n'est annoncé sans sa réponse.

const _mois = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

String _jour(DateTime d) => '${d.day} ${_mois[d.month - 1]}';

/// Fiche concours (format de l'écran) à partir d'une ligne serveur ; [teams] = équipes déjà inscrites.
Hackathon contestFromRow(Map<String, dynamic> r, int teams) {
  final s = DateTime.tryParse('${r['starts_on'] ?? ''}');
  final e = DateTime.tryParse('${r['ends_on'] ?? ''}');
  final close = DateTime.tryParse('${r['reg_close_at'] ?? ''}')?.toLocal();
  final dates = s == null ? (close == null ? '' : 'Inscriptions jusqu’au ${_jour(close)}') : (e == null || e == s ? _jour(s) : '${s.day}–${_jour(e)}');
  final st = '${r['status'] ?? ''}';
  final open = st == 'published' && (close == null || close.isAfter(DateTime.now()));
  return Hackathon(
    '${r['id']}',
    '${r['title'] ?? ''}',
    dates,
    '${r['city'] ?? 'En ligne'}',
    (r['prize'] as num?)?.toInt() ?? 0,
    (r['places'] as num?)?.toInt() ?? 0,
    switch (st) { 'judging' => 'Jury', 'results' => 'Résultats', 'cancelled' => 'Annulé', _ => open ? 'Ouvert' : 'Clos' },
    free: true,
    hours: s != null && e != null ? (e.difference(s).inDays + 1) * 24 : 48,
    desc: '${r['description'] ?? ''}',
    taken: teams,
    serverStatus: st,
  );
}

/// Concours visibles sur le serveur (publiés, en jury, résultats ; tous pour le département) ; null avant la première lecture.
class ServerContests extends Notifier<List<Hackathon>?> {
  @override
  List<Hackathon>? build() {
    if (!Backend.ready) return null;
    Future.microtask(refresh);
    return null;
  }

  Future<void> refresh() async {
    final c = await Backend.rows('contests', 'id,title,description,city,reg_close_at,submit_close_at,starts_on,ends_on,prize,places,status', order: 'reg_close_at', ascending: true, limit: 100);
    if (c.error != null || !ref.mounted) return;
    final t = await Backend.rows('contest_teams', 'contest_id', limit: 1000);
    final counts = <String, int>{};
    for (final x in t.rows) {
      counts.update('${x['contest_id']}', (v) => v + 1, ifAbsent: () => 1);
    }
    if (ref.mounted) state = [for (final r in c.rows) if (r['status'] != 'cancelled') contestFromRow(r, counts['${r['id']}'] ?? 0)];
  }
}

final serverContestsProvider = NotifierProvider<ServerContests, List<Hackathon>?>(ServerContests.new);

/// Mes équipes : concours → (équipe, capitaine ?). Lues sur le serveur (RLS : mes adhésions).
class MyContestTeams extends Notifier<Map<String, ({String teamId, String name, bool captain})>> {
  @override
  Map<String, ({String teamId, String name, bool captain})> build() {
    if (!Backend.ready) return const {};
    final uid = ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
    if (uid.isNotEmpty) Future.microtask(refresh);
    return const {};
  }

  Future<void> refresh() async {
    final r = await Backend.rows('contest_members', 'status,team_id,contest_teams(contest_id,name,captain_id)', limit: 200);
    if (r.error != null || !ref.mounted) return;
    final me = ref.read(profileAccountProvider).serverId;
    state = {
      for (final m in r.rows)
        if (m['status'] != 'invited' && m['contest_teams'] is Map)
          '${(m['contest_teams'] as Map)['contest_id']}': (
            teamId: '${m['team_id']}',
            name: '${(m['contest_teams'] as Map)['name']}',
            captain: '${(m['contest_teams'] as Map)['captain_id']}' == me,
          ),
    };
  }
}

final myContestTeamsProvider = NotifierProvider<MyContestTeams, Map<String, ({String teamId, String name, bool captain})>>(MyContestTeams.new);

/// Classement réel du concours affiché (vide tant que les résultats ne sont pas publiés, sauf jury et département).
class ServerRanking extends Notifier<List<Ranked>> {
  @override
  List<Ranked> build() {
    if (!Backend.ready) return const [];
    final id = ref.watch(currentEventProvider).id;
    if (id.isNotEmpty) Future.microtask(() => refresh(id));
    return const [];
  }

  Future<void> refresh(String contest) async {
    final r = await Backend.rpc('contest_ranking', {'p_contest': contest});
    if (r.error != null || !ref.mounted || r.data is! List) return;
    state = [
      for (final x in r.data as List)
        Ranked('${(x as Map)['team_name']}', '${x['project']}', (((x['total'] as num?) ?? 0) * 100 / 40).round()),
    ];
  }
}

final serverRankingProvider = NotifierProvider<ServerRanking, List<Ranked>>(ServerRanking.new);

Future<String?> _call(BuildContext context, String fn, Map<String, dynamic> params, String failTitle) async {
  final r = await Backend.rpc(fn, params);
  if (r.error != null && context.mounted) await gAlert(context, failTitle, r.error!);
  return r.error;
}

/// 162 : inscription réelle (le serveur vérifie règlement, places, échéance et rôle étudiant).
Future<bool> registerContestTeam(BuildContext context, WidgetRef ref, Hackathon ev, String name, String theme) async {
  if (!await requireLogin(context, ref, 'inscrire votre équipe') || !context.mounted) return false;
  final err = await _call(context, 'register_contest_team', {'p_contest': ev.id, 'p_name': name, 'p_theme': theme, 'p_solo': false, 'p_rules': true}, 'Inscription refusée');
  if (err != null) return false;
  await ref.read(myContestTeamsProvider.notifier).refresh();
  await ref.read(serverContestsProvider.notifier).refresh();
  if (context.mounted) gToast(context, 'Inscription enregistrée : ${ev.title}');
  return true;
}

/// 163, 164 : invitation d'un coéquipier par son adresse e-mail (capitaine).
Future<void> inviteContestMate(BuildContext context, WidgetRef ref) async {
  final team = ref.read(myContestTeamsProvider)[ref.read(currentEventProvider).id];
  if (team == null || !team.captain) return gAlert(context, 'Invitation', 'Seul le capitaine d’une équipe inscrite à ce concours peut inviter.');
  final mail = await askText(context, title: 'Inviter un coéquipier', body: 'Adresse e-mail de son compte étudiant (5 membres au plus).', hint: 'prenom.nom@…', ok: 'Inviter', min: 5);
  if (mail == null || !context.mounted) return;
  if (await _call(context, 'invite_contest_member', {'p_team': team.teamId, 'p_email': mail}, 'Invitation refusée') == null && context.mounted) {
    gToast(context, 'Invitation envoyée : elle doit être acceptée par l’étudiant.');
  }
}

/// 165 : dépôt réel par le capitaine, après certification d'originalité.
Future<void> submitContestProject(BuildContext context, WidgetRef ref, String title, String link, String desc) async {
  final ev = ref.read(currentEventProvider);
  final team = ref.read(myContestTeamsProvider)[ev.id];
  if (team == null) return gAlert(context, 'Dépôt', 'Votre équipe n’est pas inscrite à ce concours.');
  if (!team.captain) return gAlert(context, 'Dépôt', 'Seul le capitaine de l’équipe dépose le projet.');
  final ok = await gDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Dépôt définitif'),
      content: const Text('Je certifie que le projet est original. Après envoi, le dépôt ne peut plus être modifié.'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Je certifie et j’envoie'))],
    ),
  );
  if (ok != true || !context.mounted) return;
  final err = await _call(context, 'submit_contest_project',
      {'p_team': team.teamId, 'p_title': title, 'p_description': desc, 'p_demo': link, 'p_video': null, 'p_deck': null, 'p_original': true, 'p_final': true}, 'Dépôt refusé');
  if (err == null && context.mounted) gToast(context, 'Projet déposé : il sera transmis au jury après la clôture.');
}

/// 167 : le juré choisit un projet du concours affiché, puis la note (4 critères sur 10) est enregistrée par le serveur.
Future<bool> scoreContestProject(BuildContext context, WidgetRef ref, List<int> scores) async {
  final ev = ref.read(currentEventProvider);
  final r = await Backend.rows('contest_submissions', 'id,title,team_id,contest_teams(contest_id,name)', limit: 200);
  if (!context.mounted) return false;
  if (r.error != null) {
    await gAlert(context, 'Lecture impossible', r.error!);
    return false;
  }
  final mine = [for (final s in r.rows) if (s['contest_teams'] is Map && '${(s['contest_teams'] as Map)['contest_id']}' == ev.id) s];
  if (mine.isEmpty) {
    await gAlert(context, 'Aucun projet à noter', 'Vous n’êtes pas juré de ce concours, ou aucun projet n’a encore été soumis.');
    return false;
  }
  final pick = await gDialog<Map<String, dynamic>>(
    context: context,
    builder: (c) => SimpleDialog(title: const Text('Projet à noter'), children: [
      for (final s in mine) SimpleDialogOption(onPressed: () => Navigator.pop(c, s), child: Text('${s['title']} · ${(s['contest_teams'] as Map)['name']}')),
    ]),
  );
  if (pick == null || !context.mounted) return false;
  final err = await _call(context, 'score_contest_submission', {
    'p_submission': pick['id'], 'p_innovation': scores[0], 'p_feasibility': scores[1], 'p_impact': scores[2], 'p_pitch': scores[3], 'p_comment': null,
  }, 'Note refusée');
  if (err != null) return false;
  if (context.mounted) gToast(context, 'Note enregistrée : ${scores.fold(0, (a, b) => a + b)} / 40 pour « ${pick['title']} »');
  return true;
}

/// 168 : publication réelle par le département (les champs manquants à l'écran sont demandés ici).
Future<void> publishContestDialog(BuildContext context, WidgetRef ref) async {
  if (!Backend.ready) return gAlert(context, 'Hors connexion', 'La publication d’un concours nécessite la connexion au serveur.');
  final ctl = {for (final k in ['titre', 'description', 'lieu', 'inscriptions', 'depots', 'places', 'dotation']) k: TextEditingController()};
  ctl['lieu']!.text = 'Douala';
  ctl['places']!.text = '50';
  ctl['dotation']!.text = '0';
  final go = await gDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Publier un concours'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: ctl['titre'], decoration: const InputDecoration(labelText: 'Titre')),
          TextField(controller: ctl['description'], maxLines: 3, decoration: const InputDecoration(labelText: 'Thématique, critères, conditions (30 caractères min.)')),
          TextField(controller: ctl['lieu'], decoration: const InputDecoration(labelText: 'Lieu ou « En ligne »')),
          TextField(controller: ctl['inscriptions'], decoration: const InputDecoration(labelText: 'Clôture des inscriptions (AAAA-MM-JJ)')),
          TextField(controller: ctl['depots'], decoration: const InputDecoration(labelText: 'Clôture des dépôts (AAAA-MM-JJ)')),
          TextField(controller: ctl['places'], keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Places (équipes)')),
          TextField(controller: ctl['dotation'], keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Dotation en FCFA (versée par l’organisateur)')),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Publier'))],
    ),
  );
  if (go != true || !context.mounted) return;
  final reg = DateTime.tryParse(ctl['inscriptions']!.text.trim());
  final dep = DateTime.tryParse(ctl['depots']!.text.trim());
  if (reg == null || dep == null) return gAlert(context, 'Dates invalides', 'Saisissez les dates au format AAAA-MM-JJ.');
  final err = await _call(context, 'save_contest', {
    'p_id': null, 'p_title': ctl['titre']!.text.trim(), 'p_description': ctl['description']!.text.trim(), 'p_theme': '', 'p_rules': '',
    'p_city': ctl['lieu']!.text.trim(), 'p_reg_close': DateTime(reg.year, reg.month, reg.day, 23, 59).toUtc().toIso8601String(),
    'p_submit_close': DateTime(dep.year, dep.month, dep.day, 23, 59).toUtc().toIso8601String(), 'p_starts': null, 'p_ends': null,
    'p_prize': int.tryParse(ctl['dotation']!.text.replaceAll(RegExp(r'\D'), '')) ?? 0, 'p_places': int.tryParse(ctl['places']!.text.trim()) ?? 0, 'p_publish': true,
  }, 'Publication refusée');
  if (err != null || !context.mounted) return;
  await ref.read(serverContestsProvider.notifier).refresh();
  if (context.mounted) gToast(context, 'Concours publié');
}

/// 169 : modération du concours affiché (jury, résultats, jurés, équipes écartées) par le département.
Future<void> moderateContestDialog(BuildContext context, WidgetRef ref) async {
  if (!Backend.ready) return gAlert(context, 'Hors connexion', 'La modération nécessite la connexion au serveur.');
  final ev = ref.read(currentEventProvider);
  if (ev.id.isEmpty) return gAlert(context, 'Modération', 'Aucun concours sélectionné.');
  final action = await gDialog<String>(
    context: context,
    builder: (c) => SimpleDialog(title: Text('Modérer : ${ev.title}'), children: [
      SimpleDialogOption(onPressed: () => Navigator.pop(c, 'juror'), child: const Text('Désigner un juré (e-mail)')),
      SimpleDialogOption(onPressed: () => Navigator.pop(c, 'judging'), child: const Text('Ouvrir la délibération du jury')),
      SimpleDialogOption(onPressed: () => Navigator.pop(c, 'results'), child: const Text('Publier les résultats')),
      SimpleDialogOption(onPressed: () => Navigator.pop(c, 'hide'), child: const Text('Écarter une équipe (motif obligatoire)')),
      SimpleDialogOption(onPressed: () => Navigator.pop(c, 'cancelled'), child: const Text('Annuler le concours')),
    ]),
  );
  if (action == null || !context.mounted) return;
  String? err;
  if (action == 'juror') {
    final mail = await askText(context, title: 'Désigner un juré', body: 'Adresse e-mail du compte du juré.', hint: 'prenom.nom@…', ok: 'Désigner', min: 5);
    if (mail == null || !context.mounted) return;
    err = await _call(context, 'assign_contest_juror', {'p_contest': ev.id, 'p_email': mail, 'p_add': true}, 'Désignation refusée');
  } else if (action == 'hide') {
    final t = await Backend.rows('contest_teams', 'id,name,contest_id', eq: {'contest_id': ev.id}, limit: 200);
    if (!context.mounted) return;
    final pick = await gDialog<Map<String, dynamic>>(
      context: context,
      builder: (c) => SimpleDialog(title: const Text('Équipe à écarter'), children: [for (final x in t.rows) SimpleDialogOption(onPressed: () => Navigator.pop(c, x), child: Text('${x['name']}'))]),
    );
    if (pick == null || !context.mounted) return;
    final why = await askText(context, title: 'Motif', body: 'Le capitaine est notifié du motif.', hint: 'Non-respect du règlement…', ok: 'Écarter', min: 5);
    if (why == null || !context.mounted) return;
    err = await _call(context, 'moderate_contest_team', {'p_team': pick['id'], 'p_hidden': true, 'p_reason': why}, 'Modération refusée');
  } else {
    err = await _call(context, 'set_contest_status', {'p_contest': ev.id, 'p_status': action}, 'Changement refusé');
  }
  if (err != null || !context.mounted) return;
  await ref.read(serverContestsProvider.notifier).refresh();
  if (context.mounted) gToast(context, 'Modification enregistrée');
}
