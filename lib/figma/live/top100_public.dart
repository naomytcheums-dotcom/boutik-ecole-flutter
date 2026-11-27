import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../gen.dart' show gToast;
import 'auth.dart';
import 'lots.dart' show formDialog;
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';
import 'social_posts.dart' show socialAvatar;
import 'top100_data.dart';
import 'top100_widgets.dart';

/// Pages publiques du TOP 100 national des talents : lisibles sans compte. Seules les actions (contacter, suivre son score) invitent à se connecter.

const _hubTiles = <(IconData, String, String, String)>[
  (Icons.emoji_events_outlined, 'TOP 100 National', 'Les meilleurs talents du mois, tous établissements.', '/top100/national'),
  (Icons.school_outlined, 'TOP 100 par établissement', 'Le classement des étudiants d’un établissement.', '/top100/etablissement'),
  (Icons.menu_book_outlined, 'TOP 100 par filière', 'Le classement des étudiants d’une filière.', '/top100/filiere'),
  (Icons.apartment_outlined, 'Les établissements les plus performants du Cameroun', 'Comparaison par étudiant vérifié, jamais par effectif seul.', '/top100/etablissements'),
  (Icons.trending_up, 'Talents en progression', 'Ceux qui ont gagné le plus de places ce mois-ci.', '/top100/progression'),
  (Icons.fiber_new_outlined, 'Nouveaux talents du mois', 'Entrés pour la première fois au classement.', '/top100/nouveaux'),
  (Icons.visibility_outlined, 'Les plus consultés par les entreprises', 'Chiffres agrégés, sans jamais nommer les entreprises.', '/top100/plus-consultes'),
  (Icons.history, 'Historique des classements mensuels', 'Chaque publication mensuelle et son empreinte.', '/top100/historique'),
  (Icons.rule, 'Règles du score, en toute transparence', 'Les activités qui rapportent des points.', '/top100/regles'),
  (Icons.calculate_outlined, 'Comment est calculé le classement', 'Formule, seuils, critères et raisons d’exclusion, sans nommer personne.', '/top100/calcul'),
  (Icons.verified_outlined, 'Vérifier une publication', 'Contrôler l’intégrité d’un classement publié.', '/top100/verification'),
];

class Top100HubScreen extends ConsumerWidget {
  const Top100HubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MarchePage(
        title: 'TOP 100 national des talents',
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
          Text('Chaque mois, l’administration publie le classement des étudiants selon leurs activités réellement réalisées sur la plateforme. Un étudiant n’y apparaît que s’il l’a accepté.', style: mst(13.5, c: kGrey).copyWith(height: 1.5)),
          const SizedBox(height: 12),
          for (final t in _hubTiles)
            top100Card(onTap: () => GoRouter.of(context).push(t.$4), [
              Row(children: [
                Icon(t.$1, color: kViolet),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.$2, style: mst(14.5, w: FontWeight.w800)),
                  Text(t.$3, style: mst(12.5, c: kGrey)),
                ])),
                const Icon(Icons.chevron_right, color: kGrey),
              ]),
            ]),
          top100Card(onTap: () async {
            if (await requireLogin(context, ref, 'suivre votre score de talent') && context.mounted) GoRouter.of(context).push('/top100/mon-score');
          }, [
            Row(children: [
              const Icon(Icons.person_outline, color: kViolet),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Mon score de talent', style: mst(14.5, w: FontWeight.w800)),
                Text('Étudiants : mes points, mes rangs et ma visibilité.', style: mst(12.5, c: kGrey)),
              ])),
              const Icon(Icons.chevron_right, color: kGrey),
            ]),
          ]),
        ]),
      );
}

/// Classement d'étudiants : national, par établissement, par filière, en progression ou nouveaux.
class Top100ListScreen extends ConsumerStatefulWidget {
  const Top100ListScreen({super.key, required this.kind, this.initialPeriod = ''});
  final String kind;
  final String initialPeriod;

  @override
  ConsumerState<Top100ListScreen> createState() => _Top100ListScreenState();
}

class _Top100ListScreenState extends ConsumerState<Top100ListScreen> {
  late Top100Query q = Top100Query(widget.kind, period: widget.initialPeriod);

  static const _titles = {
    'national': 'TOP 100 National',
    'institution': 'TOP 100 par établissement',
    'program': 'TOP 100 par filière',
    'rising': 'Talents en progression',
    'new': 'Nouveaux talents du mois',
  };

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final bar = Top100FilterBar(
      query: q,
      onChanged: (n) => setState(() => q = n),
      department: kind == 'national' || kind == 'institution',
      domain: kind != 'program',
      level: kind == 'national' || kind == 'institution' || kind == 'program',
    );
    Widget body;
    if (q.needsSelection) {
      body = mNote(kind == 'institution' ? 'Choisissez un établissement pour voir le classement de ses étudiants.' : 'Choisissez un établissement puis une filière pour voir son classement.');
    } else {
      body = top100Async(ref.watch(top100ListProvider(q)), () => ref.invalidate(top100ListProvider(q)), (d) => Column(children: top100ListBody(d)));
    }
    return MarchePage(title: _titles[kind] ?? 'TOP 100', child: ListView(padding: const EdgeInsets.only(bottom: 100), children: [bar, body]));
  }
}

// ------------------------------------------------------------------ établissements

class Top100InstitutionsScreen extends ConsumerStatefulWidget {
  const Top100InstitutionsScreen({super.key});
  @override
  ConsumerState<Top100InstitutionsScreen> createState() => _Top100InstitutionsScreenState();
}

class _Top100InstitutionsScreenState extends ConsumerState<Top100InstitutionsScreen> {
  String period = '';
  String? open;

  @override
  Widget build(BuildContext context) {
    final periods = ref.watch(top100PeriodsProvider).asData?.value ?? const <String>[];
    return MarchePage(
      title: 'Établissements les plus performants',
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
        Text('Les établissements les plus performants du Cameroun', style: mst(16, w: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Indicateurs normalisés par étudiant vérifié : un grand effectif n’est jamais avantagé.', style: mst(12.5, c: kGrey)),
        const SizedBox(height: 10),
        if (periods.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: MDropdown(label: 'Mois et année', value: period, items: {'': 'Dernier mois publié', for (final p in periods) p: top100PeriodLabel(p)}, onChanged: (v) => setState(() => period = v))),
        top100Async(ref.watch(top100InstitutionsRankingProvider(period)), () => ref.invalidate(top100InstitutionsRankingProvider(period)), (d) {
          if (d['published'] != true) return mNote(tStr(d['note']).isEmpty ? top100NothingPublished : tStr(d['note']));
          final items = tList(d['items']);
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Classement de ${top100PeriodLabel(d['period'])}', style: mst(12.5, w: FontWeight.w700, c: kGrey)),
            if (tStr(d['method']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4, bottom: 8), child: Text(tStr(d['method']), style: mst(12, c: kGrey))),
            if (items.isEmpty) mNote('Aucun établissement n’atteint encore l’effectif minimal de comparaison.'),
            for (final it in items) _institutionCard(it),
          ]);
        }),
      ]),
    );
  }

  Widget _institutionCard(Map<String, dynamic> it) {
    final id = tStr(it['institution_id']);
    final per = tMap(it['per_student']);
    final programs = tList(it['programs']);
    final delta = top100Delta(it);
    final isOpen = open == id;
    return top100Card(onTap: () => setState(() => open = isOpen ? null : id), [
      Row(children: [
        SizedBox(width: 38, child: Text('#${tNum(it['rank'])}', style: mst(17, w: FontWeight.w800, c: kViolet))),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tStr(it['name']), style: mst(15, w: FontWeight.w800)),
          if (tStr(it['city']).isNotEmpty) Text(tStr(it['city']), style: mst(12.5, c: kGrey)),
        ])),
        ?delta,
      ]),
      const SizedBox(height: 6),
      top100Line('Points moyens par étudiant vérifié', tNum(it['avg_score'])),
      top100Line('Étudiants vérifiés', tNum(it['verified_students'])),
      top100Line('Étudiants actifs', '${tNum(it['active_students'])} (${tNum(it['active_rate'])} %)'),
      top100Line('Talents classés', tNum(it['ranked_talents'])),
      top100Line('Projets', tNum(it['projects'])),
      top100Line('Badges et certifications', tNum(it['badges'])),
      top100Line('Participations aux challenges', tNum(it['challenges'])),
      top100Line('Missions et collaborations', tNum(it['missions'])),
      if (per.isNotEmpty) top100Line('Par étudiant vérifié', 'projets ${tNum(per['projects'])} · badges ${tNum(per['badges'])} · challenges ${tNum(per['challenges'])} · missions ${tNum(per['missions'])}'),
      if (it['delta_avg_score'] != null) top100Line('Progression des points moyens', tNum(it['delta_avg_score'])),
      if (programs.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text('Répartition par filière', style: mst(13, w: FontWeight.w800)),
        for (final p in programs) top100Line(tStr(p['name']), '${tNum(p['verified_students'])} étudiants · moy. ${tNum(p['avg_score'])}'),
        if (mInt(it['other_programs_students']) > 0) top100Line('Autres filières (effectif trop petit)', '${mInt(it['other_programs_students'])} étudiants'),
      ],
      const SizedBox(height: 6),
      Text(isOpen ? 'Masquer la progression mensuelle' : 'Voir la progression mensuelle', style: mst(12.5, w: FontWeight.w700, c: kViolet)),
      if (isOpen) _InstitutionHistory(id),
    ]);
  }
}

class _InstitutionHistory extends ConsumerWidget {
  const _InstitutionHistory(this.id);
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => top100Async(ref.watch(top100InstitutionHistoryProvider(id)), () => ref.invalidate(top100InstitutionHistoryProvider(id)), (h) {
        if (h.isEmpty) return Padding(padding: const EdgeInsets.only(top: 8), child: Text('Aucune publication mensuelle pour cet établissement.', style: mst(12.5, c: kGrey)));
        return Column(children: [
          for (final x in h) top100Line(top100PeriodLabel(x['period']), 'rang ${tNum(x['rank'])} · moy. ${tNum(x['avg_score'])} · actifs ${tNum(x['active_rate'])} %'),
        ]);
      });
}

// ------------------------------------------------------------------ plus consultés, historique

class Top100MostViewedScreen extends ConsumerStatefulWidget {
  const Top100MostViewedScreen({super.key});
  @override
  ConsumerState<Top100MostViewedScreen> createState() => _Top100MostViewedScreenState();
}

class _Top100MostViewedScreenState extends ConsumerState<Top100MostViewedScreen> {
  String period = '';

  @override
  Widget build(BuildContext context) {
    final periods = ref.watch(top100PeriodsProvider).asData?.value ?? const <String>[];
    return MarchePage(
      title: 'Les plus consultés par les entreprises',
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
        Text('Chiffres agrégés : une vue compte une fois par entreprise, talent et jour. Les entreprises ne sont jamais nommées.', style: mst(12.5, c: kGrey)),
        const SizedBox(height: 10),
        if (periods.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: MDropdown(label: 'Mois et année', value: period, items: {'': 'Mois en cours', for (final p in periods) p: top100PeriodLabel(p)}, onChanged: (v) => setState(() => period = v))),
        top100Async(ref.watch(top100MostViewedProvider(period)), () => ref.invalidate(top100MostViewedProvider(period)), (d) {
          final items = tList(d['items']);
          if (items.isEmpty) return mNote('Aucun talent n’a encore été consulté par des entreprises vérifiées sur cette période.');
          return Column(children: [
            for (final it in items)
              top100Card(onTap: () => GoRouter.of(context).push('/top100/talent/${it['user_id']}'), [
                Row(children: [
                  socialAvatar(tStr(it['photo']), tStr(it['name']), 44),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tStr(it['name']), style: mst(15, w: FontWeight.w800)),
                    Text([tStr(it['institution']), tStr(it['program'])].where((s) => s.isNotEmpty).join(' · '), style: mst(12.5, c: kGrey)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${tNum(it['companies'])} entreprise${mInt(it['companies']) > 1 ? 's' : ''}', style: mst(13, w: FontWeight.w800)),
                    Text('${tNum(it['views'])} vue${mInt(it['views']) > 1 ? 's' : ''}', style: mst(12, c: kGrey)),
                  ]),
                ]),
              ]),
          ]);
        }),
      ]),
    );
  }
}

class Top100HistoryScreen extends ConsumerWidget {
  const Top100HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MarchePage(
        title: 'Historique des classements',
        child: top100Async(ref.watch(top100HistoryProvider), () => ref.invalidate(top100HistoryProvider), (h) {
          if (h.isEmpty) return mNote(top100NothingPublished);
          return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
            for (final x in h)
              top100Card([
                Text(top100PeriodLabel(x['period']), style: mst(16, w: FontWeight.w800)),
                top100Line('État', x['status'] == 'archived' ? 'Archivé' : 'Publié'),
                if (x['published_at'] != null) top100Line('Publié le', top100DateText(x['published_at'])),
                top100Line('Talents classés', tNum(x['entries_count'])),
                top100Line('Corrections auditées', tNum(x['corrections'])),
                if (tStr(x['content_hash']).isNotEmpty) top100Line('Empreinte', tStr(x['content_hash']).substring(0, tStr(x['content_hash']).length < 16 ? tStr(x['content_hash']).length : 16)),
                for (final t in tList(x['top'])) Padding(padding: const EdgeInsets.only(top: 6), child: Top100Row(t)),
                Wrap(spacing: 8, children: [
                  TextButton(onPressed: () => GoRouter.of(context).push('/top100/national?periode=${x['period']}'), child: const Text('Voir le classement')),
                  TextButton(onPressed: () => GoRouter.of(context).push('/top100/verification?periode=${x['period']}'), child: const Text('Vérifier l’empreinte')),
                ]),
              ]),
          ]);
        }),
      );
}

// ------------------------------------------------------------------ règles et vérification

class Top100RulesScreen extends ConsumerWidget {
  const Top100RulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MarchePage(
        title: 'Règles du score',
        child: top100Async(ref.watch(top100RulesProvider), () => ref.invalidate(top100RulesProvider), (rules) => ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
              Text('Les points viennent d’activités réellement réalisées et vérifiées. Les simples vues et les « j’aime » ne rapportent aucun point. Les règles sont fixées par l’administration et versionnées.', style: mst(13, c: kGrey).copyWith(height: 1.5)),
              const SizedBox(height: 10),
              if (rules.isEmpty) mNote('Aucune règle de score n’est active pour le moment : aucun point n’est attribué.'),
              for (final r in rules)
                top100Card([
                  Text(tStr(r['label']), style: mst(15, w: FontWeight.w800)),
                  if (tStr(r['description']).isNotEmpty) Text(tStr(r['description']), style: mst(12.5, c: kGrey)),
                  const SizedBox(height: 6),
                  top100Line('Points par activité', tNum(r['points'])),
                  top100Line('Plafond par jour', r['cap_per_day'] == null ? 'Aucun' : tNum(r['cap_per_day'])),
                  top100Line('Plafond par mois', r['cap_per_period'] == null ? 'Aucun' : tNum(r['cap_per_period'])),
                  top100Line('Part de la qualité', tNum(r['quality_weight'])),
                  top100Line('Version de la règle', tNum(r['version'])),
                ]),
            ])),
      );
}

class Top100VerifyScreen extends ConsumerStatefulWidget {
  const Top100VerifyScreen({super.key, this.initialPeriod = ''});
  final String initialPeriod;
  @override
  ConsumerState<Top100VerifyScreen> createState() => _Top100VerifyScreenState();
}

class _Top100VerifyScreenState extends ConsumerState<Top100VerifyScreen> {
  late final c = TextEditingController(text: widget.initialPeriod);
  bool busy = false;
  String? error;
  Map<String, dynamic>? result;

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final p = c.text.trim();
    if (!RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(p)) {
      setState(() {
        error = 'Écrivez le mois au format AAAA-MM, par exemple 2026-10.';
        result = null;
      });
      return;
    }
    setState(() {
      busy = true;
      error = null;
      result = null;
    });
    try {
      final d = await top100Map('ranking_verify_hash', {'p_period': p});
      if (mounted) setState(() => result = d);
    } on Top100Exception catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = result;
    return MarchePage(
      title: 'Vérifier une publication',
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
        Text('Chaque classement publié est figé et porte une empreinte (SHA-256). Cette vérification recalcule les empreintes à partir du contenu et les compare à celles enregistrées à la publication.', style: mst(13, c: kGrey).copyWith(height: 1.5)),
        const SizedBox(height: 12),
        TextField(controller: c, keyboardType: TextInputType.datetime, style: mst(14, w: FontWeight.w600), decoration: const InputDecoration(labelText: 'Mois (AAAA-MM)', border: OutlineInputBorder(), isDense: true), onSubmitted: (_) => _verify()),
        const SizedBox(height: 10),
        mButton('Vérifier', busy ? null : _verify, busy: busy),
        const SizedBox(height: 14),
        if (error != null) mNote(error!),
        if (r != null && r['found'] != true) mNote('Aucune publication n’existe pour ce mois.'),
        if (r != null && r['found'] == true)
          top100Card([
            Text(top100PeriodLabel(r['period']), style: mst(16, w: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(r['intact'] == true ? 'Empreintes concordantes : le contenu publié n’a pas été modifié.' : 'Attention : les empreintes recalculées ne correspondent pas à celles enregistrées.', style: mst(14, w: FontWeight.w800, c: r['intact'] == true ? kGreen : kRed)),
            top100Line('État', r['status'] == 'archived' ? 'Archivé' : 'Publié'),
            top100Line('Corrections auditées', tNum(r['corrections'])),
            const SizedBox(height: 4),
            SelectableText(tStr(r['content_hash']), style: mst(11.5, c: kGrey)),
          ]),
      ]),
    );
  }
}

// ------------------------------------------------------------------ page publique d'un talent

String _levelLabel(String l) => const {'debutant': 'Débutant', 'intermediaire': 'Intermédiaire', 'avance': 'Avancé', 'expert': 'Expert'}[l] ?? l;
String _scopeLabel(String s) => const {'national': 'National', 'program': 'Filière', 'institution': 'Établissement', 'department': 'Département', 'domain': 'Domaine'}[s] ?? s;

class TalentPublicProfileScreen extends ConsumerStatefulWidget {
  const TalentPublicProfileScreen({super.key, required this.userId});
  final String userId;
  @override
  ConsumerState<TalentPublicProfileScreen> createState() => _TalentPublicProfileScreenState();
}

class _TalentPublicProfileScreenState extends ConsumerState<TalentPublicProfileScreen> {
  bool recorded = false;
  bool busy = false;

  /// Vue enregistrée seulement pour une personne connectée que le serveur autorise à contacter (entreprise vérifiée ou membre) ; le serveur décide et dédoublonne.
  void _maybeRecordView(Map<String, dynamic> d) {
    if (recorded || d['found'] != true || d['contact'] != 'allowed' || ref.read(authProvider).current == null) return;
    recorded = true;
    unawaited(marcheCall('talent_profile_view_record', {'p_user': widget.userId}));
  }

  Future<void> _contact(Map<String, dynamic> d) async {
    if (busy) return;
    final v = await formDialog(context, 'Contacter ${tStr(d['name'])}', [('Message (facultatif, 500 caractères au plus)', '')], submit: 'Envoyer la demande', intro: 'Votre demande est enregistrée dans votre vivier et le talent est notifié. Aucune décision automatique n’est prise.');
    if (v == null || !mounted) return;
    setState(() => busy = true);
    final r = await top100Write('discovery_contact_request', {'p_student': widget.userId, 'p_kind': 'contact', 'p_message': v[0]});
    if (!mounted) return;
    setState(() => busy = false);
    gToast(context, r.error ?? 'Demande envoyée.');
  }

  Future<void> _login() async {
    if (await requireLogin(context, ref, 'contacter ce talent') && mounted) ref.invalidate(talentProfileProvider(widget.userId));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(talentProfileProvider(widget.userId), (_, n) {
      final d = n.asData?.value;
      if (d != null) _maybeRecordView(d);
    });
    return MarchePage(
      title: 'Talent',
      child: top100Async(ref.watch(talentProfileProvider(widget.userId)), () => ref.invalidate(talentProfileProvider(widget.userId)), (d) {
        if (d['found'] != true) return mNote('Ce profil n’est pas public ou n’existe pas.');
        return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: _sections(d));
      }),
    );
  }

  List<Widget> _sections(Map<String, dynamic> d) {
    final name = tStr(d['name']);
    final ranking = d['ranking'] == null ? null : tList(d['ranking']);
    final evolution = d['evolution'] == null ? null : tList(d['evolution']);
    final skills = d['skills'] == null ? null : tList(d['skills']);
    final badges = d['badges'] == null ? null : tList(d['badges']);
    final projects = d['projects'] == null ? null : tList(d['projects']);
    final passport = d['passport'] == null ? null : tMap(d['passport']);
    final availability = d['availability'] == null ? null : tMap(d['availability']);
    final contact = tStr(d['contact']);
    final score = d['score'];
    return [
      top100Card([
        Row(children: [
          socialAvatar(tStr(d['photo']), name, 64),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: mst(18, w: FontWeight.w800)),
            Text([tStr(d['institution']), tStr(d['program'])].where((s) => s.isNotEmpty).join(' · '), style: mst(13, c: kGrey)),
            if (tStr(d['promotion']).isNotEmpty) Text('Promotion ${d['promotion']}', style: mst(12.5, c: kGrey)),
            if (d['affiliation_verified'] == true) Padding(padding: const EdgeInsets.only(top: 4), child: top100Pill('Établissement et filière vérifiés', bg: const Color(0xFFE3F5EC), fg: kGreen)),
          ])),
        ]),
        if (score != null) ...[const SizedBox(height: 8), top100Line('Score de talent', '${tNum(score)} pts')],
      ]),
      if (contact == 'login_required') mButton('Se connecter pour contacter', _login, icon: Icons.login),
      if (contact == 'allowed') mButton('Contacter', busy ? null : () => _contact(d), busy: busy, icon: Icons.mail_outline),
      if (contact == 'not_allowed') mNote('Le contact est réservé aux entreprises vérifiées.'),
      if (contact == 'self') mNote('Ceci est votre page publique. Vous choisissez ce qui s’y affiche dans « Ma visibilité ».'),
      if (ranking != null && ranking.isNotEmpty)
        top100Card([
          Text('Rangs', style: mst(15, w: FontWeight.w800)),
          for (final r in ranking) top100Line('${_scopeLabel(tStr(r['scope']))}${tStr(r['scope_label']).isNotEmpty ? ' · ${r['scope_label']}' : ''}', 'rang ${tNum(r['rank'])} sur ${tNum(r['cohort_size'])}'),
          if (ranking.isNotEmpty) Text('Classement de ${top100PeriodLabel(ranking.first['period'])}', style: mst(11.5, c: kGrey)),
        ]),
      if (evolution != null && evolution.isNotEmpty)
        top100Card([
          Text('Évolution mensuelle', style: mst(15, w: FontWeight.w800)),
          for (final e in evolution) top100Line(top100PeriodLabel(e['period']), 'rang ${tNum(e['rank'])}${e['delta_rank'] is num && (e['delta_rank'] as num) != 0 ? ' (${(e['delta_rank'] as num) > 0 ? '▲' : '▼'} ${(e['delta_rank'] as num).abs().toInt()})' : ''} · +${tNum(e['month_points'])} pts'),
        ]),
      if (skills != null)
        top100Card([
          Text('Compétences', style: mst(15, w: FontWeight.w800)),
          if (skills.isEmpty) Text('Aucune compétence démontrée pour le moment.', style: mst(12.5, c: kGrey)),
          for (final s in skills)
            top100Line('${tStr(s['skill'])}${tStr(s['domain']).isNotEmpty ? ' (${s['domain']})' : ''}', [
              if (tStr(s['level']).isNotEmpty) _levelLabel(tStr(s['level'])),
              if (s['has_proof'] == true) s['proof_verified'] == true ? 'preuve vérifiée' : 'preuve déposée',
            ].join(' · ')),
        ]),
      if (projects != null)
        top100Card([
          Text('Projets', style: mst(15, w: FontWeight.w800)),
          if (projects.isEmpty) Text('Aucun projet approuvé pour le moment.', style: mst(12.5, c: kGrey)),
          for (final p in projects) Padding(padding: const EdgeInsets.only(top: 6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tStr(p['title']), style: mst(13.5, w: FontWeight.w700)),
            if (tStr(p['summary']).isNotEmpty) Text(tStr(p['summary']), style: mst(12.5, c: kGrey)),
          ])),
        ]),
      if (badges != null)
        top100Card([
          Text('Badges', style: mst(15, w: FontWeight.w800)),
          if (badges.isEmpty) Text('Aucun badge pour le moment.', style: mst(12.5, c: kGrey)),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final b in badges) top100Pill('${b['code']}${mInt(b['count']) > 1 ? ' ×${mInt(b['count'])}' : ''}', bg: const Color(0xFFFFF3D6), fg: const Color(0xFF8A5A00))]),
        ]),
      if (passport != null)
        top100Card([
          Text('Passeport talent', style: mst(15, w: FontWeight.w800)),
          if (tStr(passport['headline']).isNotEmpty) Text(tStr(passport['headline']), style: mst(13.5, w: FontWeight.w700)),
          if (tStr(passport['summary']).isNotEmpty) Text(tStr(passport['summary']), style: mst(12.5, c: kGrey)),
          for (final c in tList(passport['certificates'])) top100Line('Certificat : ${tStr(c['title'])}', top100DateText(c['issued_at'])),
          for (final m in tList(passport['missions'])) top100Line('Mission : ${tStr(m['title'])}', top100DateText(m['ended_on'])),
        ]),
      if (availability != null)
        top100Card([
          Text('Disponibilité', style: mst(15, w: FontWeight.w800)),
          if (availability['kinds'] is List && (availability['kinds'] as List).isNotEmpty) Text((availability['kinds'] as List).map(_availabilityLabel).join(', '), style: mst(13)),
          if (availability['available_from'] != null) top100Line('À partir du', top100DateText(availability['available_from'])),
        ]),
      Padding(padding: const EdgeInsets.only(top: 4), child: Text('Seules les rubriques que le talent a choisi de partager sont affichées.', style: mst(11.5, c: kGrey))),
    ];
  }
}

String _availabilityLabel(Object? k) => const {'internship': 'Stage', 'vacation': 'Vacation', 'mission': 'Mission', 'job': 'Emploi', 'volunteer': 'Bénévolat'}['$k'] ?? '$k';

