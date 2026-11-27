import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../gen.dart' show gToast;
import 'lots.dart' show formDialog;
import 'org_contacts.dart' show TalentContactCard;
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';
import 'top100_data.dart';
import 'top100_widgets.dart';

/// Espace étudiant du TOP 100 : tableau de bord du score, explication des points, positions, visibilité, rattachement, activités et contestations.
/// Chaque écriture passe par une fonction serveur ; rien n'est confirmé tant que le serveur n'a pas répondu avec succès.

class MyTalentScreen extends ConsumerWidget {
  const MyTalentScreen({super.key});

  static const _links = <(IconData, String, String, String)>[
    (Icons.fact_check_outlined, 'Comment mon score est calculé', 'Points par règle, historique, activités sans point ou non comptées.', '/top100/mon-score/points'),
    (Icons.rule_folder_outlined, 'Cohérence de mon score', 'Écarts entre mon profil, mes preuves et mes points.', '/top100/mon-score/coherence'),
    (Icons.leaderboard_outlined, 'Mes positions', 'Mes rangs dans les classements publiés.', '/top100/mon-score/positions'),
    (Icons.visibility_outlined, 'Ma visibilité', 'Choisir si j’apparais et ce que je partage.', '/top100/mon-score/visibilite'),
    (Icons.school_outlined, 'Mon rattachement', 'Mon établissement et ma filière vérifiés.', '/top100/mon-score/rattachement'),
    (Icons.flag_outlined, 'Mes activités et contestations', 'Contester une activité ou un score.', '/top100/mon-score/activites'),
    (Icons.mail_outline, 'Demandes de contact reçues', 'Les entreprises qui m’ont écrit.', '/top100/mon-score/contacts'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) => MarchePage(
        title: 'Mon score de talent',
        child: top100Async(ref.watch(myTalentDashboardProvider), () => ref.invalidate(myTalentDashboardProvider), (d) {
          final act = tMap(d['activities']);
          final aff = d['affiliation'] == null ? null : tMap(d['affiliation']);
          return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
            top100Card([
              Text('Mon score', style: mst(13, c: kGrey)),
              Text('${tNum(d['total'])} pts', style: mst(30, w: FontWeight.w800)),
              const SizedBox(height: 6),
              top100Line('Points de ${top100PeriodLabel(d['period'])}', tNum(d['month_points'])),
              top100Line('Points du mois précédent', tNum(d['previous_month_points'])),
              top100Line('Progression', tNum(d['progression'])),
              top100Line('Activités comptées', tNum(act['confirmed'])),
              top100Line('Activités annulées', tNum(act['cancelled'])),
              top100Line('Activités non comptées', tNum(act['not_counted'])),
              top100Line('Règles de score actives', tNum(d['rules_active'])),
            ]),
            if (mInt(d['rules_active']) == 0) mNote('Aucune règle de score n’est encore active : aucun point n’est attribué pour le moment.'),
            top100Card([
              Text('Mon rattachement', style: mst(15, w: FontWeight.w800)),
              if (aff == null) Text('Aucun rattachement : demandez-le pour pouvoir figurer dans les classements.', style: mst(12.5, c: kGrey)) else ...[
                top100Line('Établissement', tStr(aff['institution'])),
                top100Line('Filière', tStr(aff['program'])),
                top100Line('Promotion', tStr(aff['promotion'])),
                top100Line('État', aff['status'] == 'verified' ? 'Vérifié' : 'En attente de validation'),
              ],
            ]),
            _normalization(tMap(d['normalization'])),
            top100Card([
              Text('Mon rang', style: mst(15, w: FontWeight.w800)),
              Text(tStr(d['rank_note']).isEmpty ? (d['rank'] == null ? top100NothingPublished : 'Rang ${tNum(d['rank'])}') : tStr(d['rank_note']), style: mst(12.5, c: kGrey)),
            ]),
            for (final l in _links)
              top100Card(onTap: () => GoRouter.of(context).push(l.$4), [
                Row(children: [
                  Icon(l.$1, color: kViolet),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l.$2, style: mst(14.5, w: FontWeight.w800)), Text(l.$3, style: mst(12.5, c: kGrey))])),
                  const Icon(Icons.chevron_right, color: kGrey),
                ]),
              ]),
          ]);
        }),
      );

  Widget _normalization(Map<String, dynamic> n) {
    if (n.isEmpty) return const SizedBox.shrink();
    if (n['affiliated'] != true) {
      return top100Card([Text('Comparaison', style: mst(15, w: FontWeight.w800)), Text('Sans rattachement vérifié, votre position relative n’est pas calculée.', style: mst(12.5, c: kGrey))]);
    }
    Widget scope(String label, Object? s) {
      final m = tMap(s);
      final c = m['percentile_total'];
      return top100Line(label, c == null ? 'cohorte insuffisante (${tNum(m['cohort_size'])} étudiants, minimum ${tNum(n['min_cohort'])})' : 'centile ${tNum(c)} sur ${tNum(m['cohort_size'])} étudiants');
    }

    return top100Card([
      Text('Ma position relative (étudiants vérifiés)', style: mst(15, w: FontWeight.w800)),
      scope('Ma filière', n['program']),
      scope('Mon établissement', n['institution']),
      scope('National', n['national']),
    ]);
  }
}

// ------------------------------------------------------------------ explication

const _causeLabels = {'rule_inactive': 'Règle non active', 'cap_or_quality': 'Plafond atteint ou qualité non mesurée'};
const _statusLabels = {'confirmed': 'Comptée', 'cancelled': 'Annulée', 'neutralized': 'Neutralisée'};

class MyTalentExplainScreen extends ConsumerWidget {
  const MyTalentExplainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MarchePage(
        title: 'Comment mon score est calculé',
        child: top100Async(ref.watch(myTalentExplainProvider), () => ref.invalidate(myTalentExplainProvider), (d) {
          final byRule = tList(d['by_rule']);
          final entries = tList(d['entries']);
          final without = tList(d['without_points']);
          final notCounted = tList(d['not_counted']);
          return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
            top100Card([
              Text('${tNum(d['total'])} pts', style: mst(26, w: FontWeight.w800)),
              top100Line('Points de ${top100PeriodLabel(d['period'])}', tNum(d['month_points'])),
              top100Line('Points du mois précédent', tNum(d['previous_month_points'])),
            ]),
            mSectionTitle('Points par règle'),
            if (byRule.isEmpty) mNote('Aucune règle n’est définie pour le moment.'),
            for (final r in byRule)
              top100Card([
                Text(tStr(r['label']), style: mst(14.5, w: FontWeight.w800)),
                top100Line('État de la règle', r['active'] == true ? 'Active' : 'Non active (0 point)'),
                top100Line('Points par activité', tNum(r['points_per_activity'])),
                top100Line('Activités', tNum(r['activities'])),
                top100Line('Points obtenus', tNum(r['points'])),
              ]),
            mSectionTitle('Historique des points'),
            if (entries.isEmpty) mNote('Aucun point attribué pour le moment.'),
            for (final e in entries)
              top100Card([
                Row(children: [
                  Expanded(child: Text(tStr(e['label']), style: mst(14, w: FontWeight.w700))),
                  Text('${e['kind'] == 'reversal' ? '' : '+'}${tNum(e['points'])} pts', style: mst(14, w: FontWeight.w800, c: e['kind'] == 'reversal' ? kRed : kGreen)),
                ]),
                Text('${top100DateText(e['at'])}${e['kind'] == 'reversal' ? ' · retrait' : ''} · solde ${tNum(e['balance_after'])}', style: mst(12, c: kGrey)),
                if (tStr(e['reason']).isNotEmpty) Text(tStr(e['reason']), style: mst(12, c: kGrey)),
              ]),
            mSectionTitle('Activités sans point'),
            if (without.isEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('Aucune activité tracée sans point.', style: mst(12.5, c: kGrey))),
            for (final w in without) top100Line('${top100DateText(w['at'])} · ${tStr(w['label'])}', _causeLabels[tStr(w['cause'])] ?? tStr(w['cause'])),
            mSectionTitle('Activités non comptées'),
            if (notCounted.isEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('Aucune activité annulée ou neutralisée.', style: mst(12.5, c: kGrey))),
            for (final n in notCounted)
              top100Card([
                Text('${tStr(n['label'])} · ${_statusLabels[tStr(n['status'])] ?? tStr(n['status'])}', style: mst(14, w: FontWeight.w700)),
                Text(top100DateText(n['at']), style: mst(12, c: kGrey)),
                if (tStr(n['reason']).isNotEmpty) Text(tStr(n['reason']), style: mst(12, c: kGrey)),
              ]),
          ]);
        }),
      );
}

// ------------------------------------------------------------------ positions

class MyRankingPositionsScreen extends ConsumerWidget {
  const MyRankingPositionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MarchePage(
        title: 'Mes positions',
        child: top100Async(ref.watch(myRankingPositionsProvider), () => ref.invalidate(myRankingPositionsProvider), (d) {
          final pos = tList(d['positions']);
          return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
            Text(d['public'] == true ? 'Votre profil est visible dans les classements publics.' : 'Votre profil n’est pas visible publiquement : vous seul voyez ces rangs. Vous pouvez changer cela dans « Ma visibilité ».', style: mst(12.5, c: kGrey)),
            const SizedBox(height: 8),
            if (d['published'] != true) mNote(tStr(d['note']).isEmpty ? top100NothingPublished : tStr(d['note'])),
            if (d['published'] == true) ...[
              Text('Classement de ${top100PeriodLabel(d['period'])}', style: mst(12.5, w: FontWeight.w700, c: kGrey)),
              if (pos.isEmpty) mNote('Vous ne figurez dans aucun classement publié ce mois-ci.'),
              for (final p in pos)
                top100Card([
                  Row(children: [Expanded(child: Text(_scope(p), style: mst(14.5, w: FontWeight.w800))), ?top100Delta(p)]),
                  top100Line('Rang', '${tNum(p['rank'])} sur ${tNum(p['cohort_size'])}'),
                  top100Line('Score', tNum(p['score'])),
                  top100Line('Points du mois', tNum(p['month_points'])),
                ]),
            ],
          ]);
        }),
      );

  String _scope(Map<String, dynamic> p) {
    final s = const {'national': 'National', 'program': 'Ma filière', 'institution': 'Mon établissement', 'department': 'Mon département', 'domain': 'Mon domaine'}[tStr(p['scope'])] ?? tStr(p['scope']);
    return s;
  }
}

// ------------------------------------------------------------------ visibilité

const _sectionLabels = {
  'rank': 'Mon rang',
  'score': 'Mon score',
  'evolution': 'Mon évolution mensuelle',
  'skills': 'Mes compétences',
  'badges': 'Mes badges',
  'projects': 'Mes projets',
  'passport': 'Mon passeport talent',
};

class MyTop100VisibilityScreen extends ConsumerWidget {
  const MyTop100VisibilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MarchePage(
        title: 'Ma visibilité',
        child: top100Async(ref.watch(myTop100VisibilityProvider), () => ref.invalidate(myTop100VisibilityProvider), (d) => _VisibilityForm(key: ValueKey('${d['public_ranking']}${d['shared_sections']}'), initial: d)),
      );
}

class _VisibilityForm extends ConsumerStatefulWidget {
  const _VisibilityForm({super.key, required this.initial});
  final Map<String, dynamic> initial;
  @override
  ConsumerState<_VisibilityForm> createState() => _VisibilityFormState();
}

class _VisibilityFormState extends ConsumerState<_VisibilityForm> {
  late bool publicRanking = widget.initial['public_ranking'] == true;
  late bool fullName = widget.initial['show_full_name'] == true;
  late bool photo = widget.initial['show_photo'] == true;
  late bool availability = widget.initial['availability_public'] == true;
  late final Set<String> sections = {for (final s in (widget.initial['shared_sections'] as List? ?? const [])) '$s'};
  bool busy = false;

  List<String> get _allowed {
    final a = [for (final s in (widget.initial['allowed_sections'] as List? ?? const [])) '$s'];
    return a.isEmpty ? _sectionLabels.keys.toList() : a;
  }

  Future<void> _save() async {
    if (busy) return;
    setState(() => busy = true);
    final r = await top100Write('my_top100_visibility_set', {
      'p_public_ranking': publicRanking,
      'p_full_name': fullName,
      'p_photo': photo,
      'p_sections': [for (final s in _allowed) if (sections.contains(s)) s],
      'p_availability': availability,
    });
    if (!mounted) return;
    setState(() => busy = false);
    if (r.error != null) {
      gToast(context, 'Non enregistré : ${r.error}');
      return;
    }
    gToast(context, publicRanking ? 'Enregistré : votre profil peut apparaître dans les classements publics.' : 'Enregistré : votre profil n’apparaît plus dans les classements publics.');
    ref.invalidate(myTop100VisibilityProvider);
  }

  Widget _switch(String label, bool v, ValueChanged<bool> on, {String? sub}) => MergeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: busy ? null : () => on(!v),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(label, style: mst(14, w: FontWeight.w700)),
                if (sub != null) Text(sub, style: mst(12, c: kGrey)),
              ])),
              Switch(value: v, onChanged: busy ? null : on),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
        Text('Par défaut, vous n’apparaissez nulle part. Vous décidez de ce que les visiteurs et les entreprises voient. Retirer votre visibilité vous fait disparaître immédiatement des pages publiques.', style: mst(13, c: kGrey).copyWith(height: 1.5)),
        const SizedBox(height: 10),
        top100Card([
          _switch('Apparaître dans les classements publics', publicRanking, (v) => setState(() => publicRanking = v)),
          _switch('Afficher mon nom complet', fullName, (v) => setState(() => fullName = v), sub: 'Sinon : prénom et initiale du nom.'),
          _switch('Afficher ma photo', photo, (v) => setState(() => photo = v)),
          _switch('Rendre ma disponibilité publique', availability, (v) => setState(() => availability = v), sub: 'Stage, mission, emploi…'),
        ]),
        top100Card([
          Text('Rubriques partagées', style: mst(15, w: FontWeight.w800)),
          for (final s in _allowed) _switch(_sectionLabels[s] ?? s, sections.contains(s), (v) => setState(() => v ? sections.add(s) : sections.remove(s))),
        ]),
        mButton('Enregistrer', busy ? null : _save, busy: busy),
      ]);
}

// ------------------------------------------------------------------ rattachement

class MyAffiliationScreen extends ConsumerStatefulWidget {
  const MyAffiliationScreen({super.key});
  @override
  ConsumerState<MyAffiliationScreen> createState() => _MyAffiliationScreenState();
}

class _MyAffiliationScreenState extends ConsumerState<MyAffiliationScreen> {
  String institution = '', program = '';
  final promotion = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    promotion.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    final promo = promotion.text.trim();
    if (program.isEmpty) return gToast(context, 'Choisissez un établissement puis une filière.');
    if (promo.length < 2 || promo.length > 20) return gToast(context, 'Écrivez votre promotion (2 à 20 caractères), par exemple 2026.');
    setState(() => busy = true);
    final r = await top100Write('student_affiliation_request', {'p_program': program, 'p_promotion': promo});
    if (!mounted) return;
    setState(() => busy = false);
    if (r.error != null) return gToast(context, r.error!);
    gToast(context, 'Demande envoyée : elle sera examinée par votre établissement.');
    promotion.clear();
    ref.invalidate(myAffiliationProvider);
  }

  static const _actions = {'requested': 'Demande envoyée', 'verified': 'Rattachement vérifié', 'rejected': 'Demande refusée', 'ended': 'Rattachement terminé'};

  @override
  Widget build(BuildContext context) {
    final inst = ref.watch(top100InstitutionsProvider).asData?.value ?? const <Top100Option>[];
    final progs = institution.isEmpty ? const <Top100Option>[] : (ref.watch(top100ProgramsProvider(institution)).asData?.value ?? const <Top100Option>[]);
    return MarchePage(
      title: 'Mon rattachement',
      child: top100Async(ref.watch(myAffiliationProvider), () => ref.invalidate(myAffiliationProvider), (d) {
        final cur = d['current'] == null ? null : tMap(d['current']);
        final history = tList(d['history']);
        final pending = cur != null && cur['status'] == 'pending';
        return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
          if (cur == null) mNote('Vous n’avez aucun rattachement. Demandez-le : seuls les étudiants au rattachement vérifié peuvent figurer dans les classements.'),
          if (cur != null)
            top100Card([
              Text(cur['status'] == 'verified' ? 'Rattachement vérifié' : 'Demande en attente de validation', style: mst(15, w: FontWeight.w800, c: cur['status'] == 'verified' ? kGreen : kInk)),
              top100Line('Établissement', tStr(cur['institution'])),
              top100Line('Filière', tStr(cur['program'])),
              top100Line('Promotion', tStr(cur['promotion'])),
              if (tStr(cur['decision_note']).isNotEmpty) top100Line('Note de l’établissement', tStr(cur['decision_note'])),
            ]),
          if (!pending) ...[
            mSectionTitle(cur == null ? 'Demander mon rattachement' : 'Demander un changement'),
            if (inst.isEmpty) mNote('Aucun établissement n’est encore référencé : la demande sera possible dès que l’administration en aura ajouté.') else ...[
              MDropdown(label: 'Établissement', value: institution, items: {'': 'Choisir un établissement', for (final o in inst) o.id: o.name}, onChanged: (v) => setState(() {
                    institution = v;
                    program = '';
                  })),
              const SizedBox(height: 8),
              if (institution.isNotEmpty && progs.isEmpty) Text('Aucune filière n’est encore référencée pour cet établissement.', style: mst(12.5, c: kGrey)),
              if (progs.isNotEmpty) MDropdown(label: 'Filière', value: program, items: {'': 'Choisir une filière', for (final o in progs) o.id: o.name}, onChanged: (v) => setState(() => program = v)),
              const SizedBox(height: 8),
              TextField(controller: promotion, style: mst(14, w: FontWeight.w600), decoration: const InputDecoration(labelText: 'Promotion (ex. 2026)', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 10),
              mButton('Envoyer la demande', busy ? null : _request, busy: busy),
            ],
          ],
          if (history.isNotEmpty) ...[
            mSectionTitle('Historique'),
            for (final h in history) top100Line('${top100DateText(h['at'])} · ${_actions[tStr(h['action'])] ?? tStr(h['action'])}', tStr(h['note'])),
          ],
        ]);
      }),
    );
  }
}

// ------------------------------------------------------------------ activités, contestations, contacts

const _eventFilters = {'': 'Toutes', 'confirmed': 'Comptées', 'neutralized': 'Neutralisées', 'cancelled': 'Annulées'};
const _disputeLabels = {'open': 'En cours d’examen', 'accepted': 'Acceptée', 'rejected': 'Rejetée'};

class MyTalentEventsScreen extends ConsumerStatefulWidget {
  const MyTalentEventsScreen({super.key});
  @override
  ConsumerState<MyTalentEventsScreen> createState() => _MyTalentEventsScreenState();
}

class _MyTalentEventsScreenState extends ConsumerState<MyTalentEventsScreen> {
  String status = '';
  bool busy = false;

  Future<void> _dispute(Map<String, dynamic> e) async {
    if (busy) return;
    final v = await formDialog(context, 'Contester cette activité', [('Votre message (10 caractères minimum)', '')], submit: 'Envoyer la contestation', intro: '${tStr(e['label'])} · ${top100DateText(e['at'])}. Un modérateur l’examinera et vous répondra.');
    if (v == null || !mounted) return;
    if (v[0].length < 10) return gToast(context, 'Expliquez votre contestation en 10 caractères au moins.');
    setState(() => busy = true);
    final r = await top100Write('talent_score_dispute_open', {'p_event': e['id'], 'p_message': v[0]});
    if (!mounted) return;
    setState(() => busy = false);
    if (r.error != null) return gToast(context, r.error!);
    gToast(context, 'Contestation envoyée.');
    ref.invalidate(myTalentEventsProvider(status));
    ref.invalidate(myTalentDisputesProvider);
  }

  @override
  Widget build(BuildContext context) => MarchePage(
        title: 'Mes activités',
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
          Wrap(spacing: 8, children: [for (final f in _eventFilters.entries) MChip(f.value, selected: status == f.key, onTap: () => setState(() => status = f.key))]),
          const SizedBox(height: 8),
          top100Async(ref.watch(myTalentEventsProvider(status)), () => ref.invalidate(myTalentEventsProvider(status)), (events) {
            if (events.isEmpty) return mNote('Aucune activité pour ce filtre.');
            return Column(children: [
              for (final e in events)
                top100Card([
                  Row(children: [
                    Expanded(child: Text(tStr(e['label']), style: mst(14, w: FontWeight.w800))),
                    top100Pill(_statusLabels[tStr(e['status'])] ?? tStr(e['status']), bg: e['status'] == 'confirmed' ? const Color(0xFFE3F5EC) : const Color(0xFFFDE8E8), fg: e['status'] == 'confirmed' ? kGreen : kRed),
                  ]),
                  Text('${top100DateText(e['at'])} · ${tNum(e['points'])} pts', style: mst(12, c: kGrey)),
                  if (tStr(e['reason']).isNotEmpty) Text(tStr(e['reason']), style: mst(12, c: kGrey)),
                  const SizedBox(height: 6),
                  if (e['open_dispute'] == true) top100Pill('Contestation en cours') else mButton('Contester', busy ? null : () => _dispute(e), dark: false),
                ]),
            ]);
          }),
          mSectionTitle('Mes contestations'),
          top100Async(ref.watch(myTalentDisputesProvider), () => ref.invalidate(myTalentDisputesProvider), (ds) {
            if (ds.isEmpty) return Text('Vous n’avez fait aucune contestation.', style: mst(12.5, c: kGrey));
            return Column(children: [
              for (final x in ds)
                top100Card([
                  Text('${tStr(x['label'])} · ${_disputeLabels[tStr(x['status'])] ?? tStr(x['status'])}', style: mst(14, w: FontWeight.w800)),
                  Text(tStr(x['message']), style: mst(12.5, c: kGrey)),
                  if (tStr(x['resolution']).isNotEmpty) Text('Réponse : ${x['resolution']}', style: mst(12.5, w: FontWeight.w600)),
                ]),
            ]);
          }),
        ]),
      );
}

class MyTalentContactsScreen extends ConsumerWidget {
  const MyTalentContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MarchePage(
        title: 'Demandes de contact',
        child: top100Async(ref.watch(myTalentContactsProvider), () => ref.invalidate(myTalentContactsProvider), (l) {
          if (l.isEmpty) return mNote('Aucune entreprise ne vous a contacté pour le moment.');
          return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
            for (final c in l) TalentContactCard(request: c, onChanged: () => ref.invalidate(myTalentContactsProvider)),
          ]);
        }),
      );
}
