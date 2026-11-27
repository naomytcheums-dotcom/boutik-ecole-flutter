import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../gen.dart' show gToast;
import '../i18n.dart' show Text;
import 'auth.dart';
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';
import 'top100_data.dart';
import 'top100_widgets.dart';

/// H13 · classement : page publique « Comment est calculé le classement » (ranking_explain), cohérence du score de l'étudiant (my_talent_consistency, lecture seule)
/// et pointage aux événements (code émis par l'organisateur, saisi par l'étudiant inscrit ; event_attendance_*). Tout vient du serveur : serveur muet = erreur lisible,
/// jamais un classement, un score, une présence ni un zéro inventés.

final rankingExplainProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, period) => top100Map('ranking_explain', {if (period.isNotEmpty) 'p_period': period}),
  retry: (_, _) => null,
);

final myTalentConsistencyProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) => top100Map('my_talent_consistency'), retry: (_, _) => null);

final myEventAttendanceProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  return top100List('my_event_attendance');
}, retry: (_, _) => null);

String _when(Object? iso) {
  final d = DateTime.tryParse('$iso')?.toLocal();
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} à ${two(d.hour)} h ${two(d.minute)}';
}

// ------------------------------------------------------------------ Comment est calculé le classement

const _formulaLabels = {
  'points': 'Points attribués',
  'caps': 'Plafonds',
  'score': 'Score',
  'ranking': 'Classement',
  'normalization': 'Comparaison par groupe',
  'institutions': 'Établissements',
  'not_counted': 'Ce qui ne rapporte rien',
  'freeze': 'Publication figée',
};

class RankingExplainScreen extends ConsumerWidget {
  const RankingExplainScreen({super.key, this.period = ''});
  final String period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prov = rankingExplainProvider(period);
    return MarchePage(
      title: 'Comment est calculé le classement',
      child: top100Async(ref.watch(prov), () => ref.invalidate(prov), (d) {
        final published = d['published'] == true;
        final rules = tList(d['rules']);
        final settings = d['settings'] == null ? null : tMap(d['settings']);
        final formula = tMap(d['formula']);
        final exclusions = tList(d['exclusions']);
        return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
          top100Card([
            Text(published ? 'Classement de ${top100PeriodLabel(d['period'])}' : 'Aucun classement publié', style: mst(16, w: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              published
                  ? 'Les règles ci-dessous sont celles figées au moment de la publication : elles ne changent plus.'
                  : tStr(d['note']).isEmpty
                      ? top100NothingPublished
                      : tStr(d['note']),
              style: mst(12.5, c: kGrey).copyWith(height: 1.5),
            ),
            if (published && d['published_at'] != null) top100Line('Publié le', top100DateText(d['published_at'])),
            if (published) top100Line('Étudiants classés dans cette portée', tNum(d['entries_in_scope'])),
          ]),
          mSectionTitle('Règles du score'),
          if (rules.isEmpty) mNote('Aucune règle de score n’est en vigueur pour cette période : aucun point n’est attribué.'),
          for (final r in rules)
            top100Card([
              Text(tStr(r['label']), style: mst(14.5, w: FontWeight.w800)),
              if (tStr(r['description']).isNotEmpty) Text(tStr(r['description']), style: mst(12.5, c: kGrey)),
              const SizedBox(height: 4),
              top100Line('Points par activité', tNum(r['points'])),
              top100Line('Plafond par jour', r['cap_per_day'] == null ? 'Aucun' : tNum(r['cap_per_day'])),
              top100Line('Plafond par mois', r['cap_per_period'] == null ? 'Aucun' : tNum(r['cap_per_period'])),
              top100Line('Part de la qualité', tNum(r['quality_weight'])),
            ]),
          mSectionTitle('Seuils et réglages'),
          if (settings == null) mNote('Les seuils de publication ne sont pas encore décidés par l’administration : aucun classement ne peut être publié.')
          else
            top100Card([
              top100Line('Score minimal', tNum(settings['min_score'])),
              top100Line('Activités confirmées minimales', settings['min_activities'] == null ? 'Aucune exigence' : tNum(settings['min_activities'])),
              top100Line('Nombre d’entrées par classement', tNum(settings['entries_limit'])),
              top100Line('Taille minimale d’un groupe', tNum(settings['min_cohort'])),
            ]),
          mSectionTitle('Formule de calcul'),
          top100Card([
            for (final k in _formulaLabels.keys)
              if (tStr(formula[k]).isNotEmpty)
                Padding(padding: const EdgeInsets.only(bottom: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_formulaLabels[k]!, style: mst(13, w: FontWeight.w800)),
                  Text(tStr(formula[k]), style: mst(12.5, c: kGrey).copyWith(height: 1.45)),
                ])),
          ]),
          mSectionTitle('Qui peut être classé'),
          top100Card([for (final x in (d['eligibility'] as List? ?? const [])) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text('• ${tStr(x)}', style: mst(12.5, c: kGrey).copyWith(height: 1.4)))]),
          mSectionTitle('Pourquoi un étudiant n’apparaît pas'),
          top100Card([
            Text('Nombres agrégés, sans jamais nommer personne. Ils reflètent l’état actuel des comptes.', style: mst(12, c: kGrey)),
            const SizedBox(height: 6),
            for (final x in exclusions)
              top100Line(tStr(x['label']), x['masked'] == true ? 'moins de 5 (non affiché)' : tNum(x['count'])),
            top100Line('Étudiants éligibles aujourd’hui', tNum(d['eligible_now'])),
          ]),
          TextButton(onPressed: () => GoRouter.of(context).push('/top100/regles'), child: const Text('Voir toutes les règles du score')),
        ]);
      }),
    );
  }
}

// ------------------------------------------------------------------ Cohérence du score (étudiant)

const _severity = {'error': ('À corriger', kRed), 'warning': ('À examiner', Color(0xFF8F5400)), 'info': ('Information', kGrey)};
const _family = {
  'skills': 'Compétences',
  'badges': 'Badges',
  'replays': 'Replays et lives',
  'collaborations': 'Collaborations',
  'projects': 'Projets',
  'events': 'Événements',
  'score': 'Score',
  'ranking': 'Classement',
  'profile': 'Profil',
};

class MyTalentConsistencyScreen extends ConsumerWidget {
  const MyTalentConsistencyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MarchePage(
        title: 'Cohérence de mon score',
        child: top100Async(ref.watch(myTalentConsistencyProvider), () => ref.invalidate(myTalentConsistencyProvider), (d) {
          if (d['applicable'] == false) return mNote(tStr(d['reason']).isEmpty ? 'Cette vérification est réservée aux comptes étudiants.' : tStr(d['reason']));
          final sum = tMap(d['summary']);
          final issues = tList(d['issues']);
          return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
            Text('Le serveur compare vos compétences, badges, collaborations, replays, projets et présences avec les points de votre score. Il ne corrige rien tout seul : un écart est examiné par la modération.', style: mst(12.5, c: kGrey).copyWith(height: 1.5)),
            const SizedBox(height: 10),
            top100Card([
              Text(d['consistent'] == true ? 'Aucun écart à signaler' : 'Des écarts sont signalés', style: mst(16, w: FontWeight.w800, c: d['consistent'] == true ? kGreen : kInk)),
              top100Line('Écarts à corriger', tNum(sum['errors'])),
              top100Line('Écarts à examiner', tNum(sum['warnings'])),
              top100Line('Informations', tNum(sum['infos'])),
              top100Line('Total du score', '${tNum(tMap(d['score'])['total'])} pts'),
              top100Line('Somme des points tracés', '${tNum(tMap(d['score'])['ledger_sum'])} pts'),
            ]),
            if (issues.isEmpty && d['consistent'] != true) mNote('Aucun détail n’est disponible.'),
            for (final i in issues)
              top100Card([
                Row(children: [
                  top100Pill(_severity[tStr(i['severity'])]?.$1 ?? tStr(i['severity']), bg: (_severity[tStr(i['severity'])]?.$2 ?? kGrey).withValues(alpha: 0.12), fg: _severity[tStr(i['severity'])]?.$2 ?? kGrey),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_family[tStr(i['family'])] ?? tStr(i['family']), style: mst(13, w: FontWeight.w800))),
                  Text('× ${tNum(i['count'])}', style: mst(12.5, c: kGrey)),
                ]),
                const SizedBox(height: 4),
                Text(tStr(i['message']), style: mst(12.5, c: kGrey).copyWith(height: 1.45)),
              ]),
            TextButton(onPressed: () => GoRouter.of(context).push('/top100/mon-score/activites'), child: const Text('Contester une activité')),
          ]);
        }),
      );
}

// ------------------------------------------------------------------ Pointage : étudiant

/// Bloc de pointage d'une inscription (ligne « Mes événements »). Rien n'est affiché si le serveur ne confirme pas (compte non étudiant, panne) : aucune présence inventée.
class EventAttendanceStudentBlock extends ConsumerWidget {
  const EventAttendanceStudentBlock({super.key, required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(myEventAttendanceProvider).value;
    final x = rows?.where((r) => tStr(r['event']) == eventId).firstOrNull;
    if (x == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final opens = DateTime.tryParse(tStr(x['opens_at']));
    final closes = DateTime.tryParse(tStr(x['closes_at']));
    final attended = x['attended'] == true;
    final open = x['window_open'] == true;
    final before = !open && opens != null && now.isBefore(opens);
    final after = !open && closes != null && now.isAfter(closes);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (attended) Text('Présence enregistrée le ${_when(x['checked_in_at'])}.', style: mst(12.5, w: FontWeight.w700, c: kGreen))
        else if (open) mButton('Pointer ma présence', () => showEventCheckIn(context, ref, x), icon: Icons.qr_code_2)
        else if (before) Text('Le pointage ouvre le ${_when(x['opens_at'])}.', style: mst(12, c: kGrey))
        else if (after) Text('Fenêtre de pointage terminée : votre présence n’a pas été enregistrée.', style: mst(12, c: kGrey)),
      ]),
    );
  }
}

Future<void> showEventCheckIn(BuildContext context, WidgetRef ref, Map<String, dynamic> x) async {
  final code = TextEditingController();
  String? error;
  var busy = false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(builder: (c, set) {
      Future<void> send() async {
        set(() {
          busy = true;
          error = null;
        });
        final r = await marcheCall('event_attendance_check_in', {'p_event': x['event'], 'p_code': code.text});
        if (!c.mounted) return;
        if (r.error != null) {
          set(() {
            busy = false;
            error = top100ErrorText(r.error!);
          });
          return;
        }
        final d = tMap(r.data);
        if (d['ok'] != true) {
          set(() {
            busy = false;
            error = '${tStr(d['message']).isEmpty ? 'Code incorrect' : tStr(d['message'])}${d['remaining_attempts'] == null ? '' : ' · essais restants : ${tNum(d['remaining_attempts'])}'}';
          });
          return;
        }
        Navigator.pop(c, true);
      }

      return AlertDialog(
        title: Text('Pointer à « ${x['title']} »', style: mst(16, w: FontWeight.w800)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Saisissez le code de 8 caractères donné par l’organisateur sur place.', style: mst(13, c: kGrey)),
          const SizedBox(height: 10),
          TextField(controller: code, autofocus: true, textCapitalization: TextCapitalization.characters, maxLength: 9, decoration: const InputDecoration(labelText: 'Code de pointage', border: OutlineInputBorder())),
          if (error != null) Text(error!, style: mst(12.5, w: FontWeight.w700, c: kRed)),
        ]),
        actions: [
          TextButton(onPressed: busy ? null : () => Navigator.pop(c, false), child: Text('Fermer', style: mst(14, c: kGrey))),
          TextButton(onPressed: busy ? null : send, child: Text(busy ? 'Envoi…' : 'Valider', style: mst(14, w: FontWeight.w800, c: kViolet))),
        ],
      );
    }),
  );
  if (ok == true) {
    ref.invalidate(myEventAttendanceProvider);
    if (context.mounted) gToast(context, 'Présence enregistrée');
  }
}

// ------------------------------------------------------------------ Pointage : organisateur

final _attendanceListProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, event) => top100Map('event_attendance_list', {'p_event': event}), retry: (_, _) => null);

Future<void> showEventAttendanceSheet(BuildContext context, Map<String, dynamic> event) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
      builder: (_) => EventAttendanceSheet(event: event),
    );

class EventAttendanceSheet extends ConsumerStatefulWidget {
  const EventAttendanceSheet({super.key, required this.event});
  final Map<String, dynamic> event;

  @override
  ConsumerState<EventAttendanceSheet> createState() => _EventAttendanceSheetState();
}

class _EventAttendanceSheetState extends ConsumerState<EventAttendanceSheet> {
  Map<String, dynamic>? _code;
  String? _error;
  bool _busy = false;

  Future<void> _generate({bool renew = false}) async {
    if (renew) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('Renouveler le code ?', style: mst(16, w: FontWeight.w800)),
          content: Text('L’ancien code ne fonctionnera plus. Les présences déjà enregistrées sont conservées.', style: mst(13, c: kGrey)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Retour', style: mst(14, c: kGrey))),
            TextButton(onPressed: () => Navigator.pop(c, true), child: Text('Renouveler', style: mst(14, w: FontWeight.w800, c: kViolet))),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await top100Write('event_attendance_code_generate', {'p_event': widget.event['id'], 'p_renew': renew});
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r.error != null) {
        _error = r.error;
      } else {
        _code = tMap(r.data);
      }
    });
    if (r.error == null) ref.invalidate(_attendanceListProvider('${widget.event['id']}'));
  }

  @override
  Widget build(BuildContext context) {
    final id = '${widget.event['id']}';
    final async = ref.watch(_attendanceListProvider(id));
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Pointage · ${widget.event['title']}', style: mst(17, w: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Donnez le code à voix haute ou affichez-le sur place : seuls les inscrits qui le saisissent pendant l’événement sont comptés présents.', style: mst(12.5, c: kGrey).copyWith(height: 1.45)),
              const SizedBox(height: 10),
              if (_code != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFF2EFF6), borderRadius: BorderRadius.circular(8)),
                  child: Column(children: [
                    Text('${_code!['code_display']}', style: mst(30, w: FontWeight.w800, c: kViolet)),
                    Text('Valable de ${_when(_code!['opens_at'])} à ${_when(_code!['closes_at'])}', style: mst(12, c: kGrey), textAlign: TextAlign.center),
                  ]),
                ),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_error!, style: mst(12.5, w: FontWeight.w700, c: kRed))),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                mButton(_code == null ? 'Afficher le code' : 'Actualiser', _busy ? null : () => _generate(), busy: _busy),
                if (_code != null) mButton('Renouveler le code', _busy ? null : () => _generate(renew: true), dark: false),
              ]),
              const SizedBox(height: 12),
              top100Async(async, () => ref.invalidate(_attendanceListProvider(id)), (d) {
                final items = tList(d['items']);
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  top100Line('Fenêtre de pointage', d['window_open'] == true ? 'Ouverte' : 'Fermée'),
                  top100Line('Inscrits valables', tNum(d['registered'])),
                  top100Line('Présents confirmés', tNum(d['present'])),
                  const SizedBox(height: 6),
                  Text('Présences', style: mst(14, w: FontWeight.w800)),
                  if (items.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('Aucune présence enregistrée pour le moment.', style: mst(12.5, c: kGrey))),
                  for (final p in items)
                    top100Line('${p['name']} · ${_when(p['checked_in_at'])}', p['status'] == 'confirmed' ? 'Présent(e)' : 'Annulée${tStr(p['cancel_reason']).isEmpty ? '' : ' : ${p['cancel_reason']}'}', color: p['status'] == 'confirmed' ? kGreen : kGrey),
                ]);
              }),
            ]),
          ),
        ),
      ),
    );
  }
}
