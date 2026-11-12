import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../gen.dart' show gToast;
import '../i18n.dart' show Text;
import 'auth.dart';
import 'backend.dart';
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';
import 'share.dart' show openUrl;

/// Innovations des communautés : points et badges IUT, SOS Cours, défis hebdomadaires, marché des compétences, mur des victoires,
/// communautés éphémères. Tout est lu et écrit par des fonctions serveur (migration 20261114001200).

const levelLabels = {'none': 'Pas encore de niveau', 'bronze': 'Aidant Bronze', 'silver': 'Aidant Argent', 'gold': 'Aidant Or', 'legend': 'Légende IUT'};
const levelColors = {'none': Color(0xFF57545F), 'bronze': Color(0xFFB4713B), 'silver': Color(0xFF7A8794), 'gold': Color(0xFFD99A00), 'legend': Color(0xFF5A3FE0)};

Future<List<Map<String, dynamic>>> _list(String fn, Map<String, dynamic> p) async {
  final r = await marcheCall(fn, p);
  if (r.error != null) throw MarcheException(r.error);
  return [for (final x in (r.data as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
}

final myPointsProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  if (!Backend.ready) return null;
  final r = await marcheCall('my_points', const {});
  return r.error != null || r.data is! Map ? null : Map<String, dynamic>.from(r.data as Map);
});
final topHelpersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => _list('top_helpers', const {'p_limit': 10}));
final sosProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, scope) => _list('sos_list', {'p_scope': scope}));
final challengesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => _list('challenges_list', const {}));
final skillsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, kind) => _list('skills_list', {if (kind.isNotEmpty) 'p_kind': kind}));
final victoriesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => _list('victories_list', const {'p_limit': 40}));

Widget _box(Widget child) => Container(margin: const EdgeInsets.fromLTRB(16, 0, 16, 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: kLine)), child: child);

InputDecoration _deco(String l, {String? hint}) => InputDecoration(labelText: l, hintText: hint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)), filled: true, fillColor: Colors.white);

Future<bool> _sheet(BuildContext context, String title, List<Widget> fields, String ok) async {
  final r = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
    builder: (c) => Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(c).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: mst(18, w: FontWeight.w800)),
          const SizedBox(height: 12),
          ...fields,
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: mButton('Annuler', () => Navigator.pop(c, false), dark: false)),
            const SizedBox(width: 10),
            Expanded(child: mButton(ok, () => Navigator.pop(c, true))),
          ]),
        ]),
      ),
    ),
  );
  return r == true;
}

int? _digits(String s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), ''));

Future<bool> _call(BuildContext context, String fn, Map<String, dynamic> params, {String? ok}) async {
  final r = await marcheCall(fn, params);
  if (!context.mounted) return false;
  if (r.error != null) {
    gToast(context, Backend.userMessage('${r.error}'));
    return false;
  }
  if (ok != null) gToast(context, ok);
  return true;
}

// ------------------------------------------------------------------ accueil des innovations

class InnovationsScreen extends ConsumerWidget {
  const InnovationsScreen({super.key});

  Future<void> _ephemeral(BuildContext context, WidgetRef ref) async {
    if (!await requireLogin(context, ref, 'créer une communauté') || !context.mounted) return;
    final name = TextEditingController(), desc = TextEditingController(), days = TextEditingController(text: '7');
    if (!await _sheet(context, 'Communauté éphémère', [
      Text('Pour un examen, un projet ou un événement : elle se supprime toute seule à la fin.', style: mst(12.5, c: kGrey)),
      const SizedBox(height: 10),
      TextField(controller: name, maxLength: 60, decoration: _deco('Nom', hint: 'Révision Examen Réseaux - 15 Nov')),
      TextField(controller: desc, maxLines: 3, decoration: _deco('Description (facultatif)')),
      const SizedBox(height: 10),
      TextField(controller: days, keyboardType: TextInputType.number, decoration: _deco('Durée en jours (1 à 14)')),
    ], 'Créer') || !context.mounted) {
      return;
    }
    final r = await marcheCall('create_ephemeral_community', {'p_name': name.text, 'p_description': desc.text, 'p_days': _digits(days.text) ?? 7, 'p_privacy': 'public'});
    if (!context.mounted) return;
    gToast(context, r.error != null ? Backend.userMessage('${r.error}') : 'Communauté créée : elle se supprimera après ${_digits(days.text) ?? 7} jours.');
  }

  Widget _tile(BuildContext context, IconData icon, String title, String sub, VoidCallback onTap) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: _box(Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFF1EEFB), borderRadius: BorderRadius.circular(4)), child: Icon(icon, color: kViolet)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: mst(14.5, w: FontWeight.w800)), Text(sub, style: mst(12, c: kGrey).copyWith(height: 1.35))])),
          const Icon(Icons.chevron_right_rounded, color: kGrey),
        ])),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pts = ref.watch(myPointsProvider).value;
    final level = '${pts?['level'] ?? 'none'}';
    return MarchePage(
      title: 'Innovations',
      child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: Text('Entraide, défis et réussites de la communauté IUT.', style: mst(13, c: kGrey))),
        if (pts != null) _tile(context, Icons.military_tech_outlined, '${mInt(pts['total'])} points · ${levelLabels[level]}', 'Points et badges IUT : chaque aide, partage ou réponse compte.', () => context.push('/innovations/points')),
        _tile(context, Icons.sos_outlined, 'SOS Cours', 'Bloqué sur un TP ? Toute votre filière est prévenue ; le premier qui répond gagne des points.', () => context.push('/innovations/sos')),
        _tile(context, Icons.emoji_events_outlined, 'Défis hebdomadaires', 'Un défi par semaine : réalisez, votez, le gagnant est mis en avant.', () => context.push('/innovations/defis')),
        _tile(context, Icons.swap_horiz_rounded, 'Marché des compétences', 'Je cherche quelqu’un qui sait faire… je paie ou j’échange un service.', () => context.push('/innovations/competences')),
        _tile(context, Icons.celebration_outlined, 'Mur des victoires', 'Stage obtenu, hackathon gagné, 18/20 : ici, on ne poste que les réussites.', () => context.push('/innovations/victoires')),
        _tile(context, Icons.timer_outlined, 'Communauté éphémère', 'Examen, projet ou événement : un groupe qui se supprime tout seul.', () => _ephemeral(context, ref)),
        _tile(context, Icons.school_outlined, 'Mentors', 'Demandez de l’aide à un ancien, ou devenez mentor.', () => context.push('/mentors')),
      ]),
    );
  }
}

// ------------------------------------------------------------------ points et badges

class PointsScreen extends ConsumerWidget {
  const PointsScreen({super.key});

  static const _kinds = {
    'sos_first': 'Première réponse à un SOS',
    'sos_solved': 'Réponse retenue (SOS)',
    'qa_accepted': 'Réponse retenue (question)',
    'mentor_review': 'Bon avis de mentoré',
    'challenge_entry': 'Participation à un défi',
    'challenge_win': 'Victoire à un défi',
    'victory': 'Réussite partagée',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pts = ref.watch(myPointsProvider).value;
    final level = '${pts?['level'] ?? 'none'}';
    final next = pts?['next_at'] as num?;
    final total = mInt(pts?['total']);
    return MarchePage(
      title: 'Points et badges',
      child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
        _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$total points', style: mst(26, w: FontWeight.w800)),
          Row(children: [Icon(Icons.military_tech, color: levelColors[level]), const SizedBox(width: 6), Text(levelLabels[level] ?? level, style: mst(14, w: FontWeight.w800, c: levelColors[level]!))]),
          const SizedBox(height: 8),
          if (next != null) ...[
            ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(minHeight: 8, value: (total / next.toDouble()).clamp(0.0, 1.0), backgroundColor: const Color(0xFFF2EFF6), color: levelColors[level] == levelColors['none'] ? kViolet : levelColors[level])),
            const SizedBox(height: 4),
            Text('Encore ${next.toInt() - total} points pour le niveau suivant.', style: mst(12, c: kGrey)),
          ] else
            Text('Niveau maximum atteint : bravo !', style: mst(12.5, w: FontWeight.w700, c: kGreen)),
          const SizedBox(height: 8),
          Text('Bronze 50 · Argent 150 · Or 400 · Légende IUT 1 000', style: mst(11.5, c: kGrey)),
        ])),
        mSectionTitle('Mes derniers points'),
        if (pts == null || (pts['events'] as List).isEmpty)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('Aucun point pour le moment : répondez à un SOS, relevez un défi ou partagez une réussite.', style: mst(13, c: kGrey)))
        else
          for (final e in pts['events'] as List) _box(Row(children: [Expanded(child: Text(_kinds['${(e as Map)['kind']}'] ?? '${e['kind']}', style: mst(13, w: FontWeight.w600))), Text('+${e['points']}', style: mst(14, w: FontWeight.w800, c: kGreen))])),
        mSectionTitle('Les plus aidants'),
        mAsync<List<Map<String, dynamic>>>(
          ref.watch(topHelpersProvider),
          (l) => l.isEmpty
              ? Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('Le classement apparaîtra dès les premiers points.', style: mst(13, c: kGrey)))
              : Column(children: [for (var i = 0; i < l.length; i++) _box(Row(children: [SizedBox(width: 28, child: Text('${i + 1}', style: mst(15, w: FontWeight.w800, c: kViolet))), Expanded(child: Text('${l[i]['name']}', style: mst(13.5, w: FontWeight.w700))), Text('${levelLabels['${l[i]['level']}']} · ${l[i]['total']}', style: mst(12, c: levelColors['${l[i]['level']}'] ?? kGrey))]))]),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ SOS Cours

class SosScreen extends ConsumerWidget {
  const SosScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    if (!await requireLogin(context, ref, 'lancer un SOS') || !context.mounted) return;
    final subject = TextEditingController(), details = TextEditingController();
    if (!await _sheet(context, 'Lancer un SOS Cours', [
      TextField(controller: subject, maxLength: 100, decoration: _deco('Ma matière ou mon TP', hint: 'Ex. TP de réseaux : routage')),
      TextField(controller: details, maxLines: 3, maxLength: 800, decoration: _deco('Ce qui me bloque (facultatif)')),
    ], 'Prévenir ma filière') || !context.mounted) {
      return;
    }
    if (await _call(context, 'sos_create', {'p_subject': subject.text, 'p_details': details.text}, ok: 'SOS envoyé : votre filière est prévenue.')) {
      ref.invalidate(sosProvider('mine'));
    }
  }

  Future<void> _answer(BuildContext context, WidgetRef ref, Map<String, dynamic> s) async {
    final body = TextEditingController();
    if (!await _sheet(context, 'Aider sur « ${s['subject']} »', [TextField(controller: body, maxLines: 4, maxLength: 1000, decoration: _deco('Votre aide'))], 'Répondre') || !context.mounted) return;
    if (await _call(context, 'sos_answer', {'p_sos': s['id'], 'p_body': body.text}, ok: 'Réponse envoyée.')) {
      ref.invalidate(sosProvider('filiere'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MarchePage(
      title: 'SOS Cours',
      child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: mButton('Lancer un SOS', () => _create(context, ref), icon: Icons.sos_outlined)),
        mSectionTitle('Mes SOS'),
        mAsync<List<Map<String, dynamic>>>(
          ref.watch(sosProvider('mine')),
          (l) => l.isEmpty
              ? Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('Aucun SOS lancé.', style: mst(13, c: kGrey)))
              : Column(children: [
                  for (final s in l)
                    _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [Expanded(child: Text('${s['subject']}', style: mst(14, w: FontWeight.w800))), Text(s['status'] == 'solved' ? 'Résolu' : 'Ouvert', style: mst(11.5, w: FontWeight.w700, c: s['status'] == 'solved' ? kGreen : kViolet))]),
                      for (final a in (s['answers'] as List? ?? const [])) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: (a as Map)['accepted'] == true ? const Color(0xFFEFFAF4) : const Color(0xFFF7F4FA), borderRadius: BorderRadius.circular(4)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${a['author']}${a['accepted'] == true ? ' · réponse retenue' : ''}', style: mst(11.5, w: FontWeight.w700, c: a['accepted'] == true ? kGreen : kGrey)),
                            Text('${a['body']}', style: mst(13).copyWith(height: 1.4)),
                            if (s['status'] != 'solved')
                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onTap: () async {
                                    if (await _call(context, 'sos_solve', {'p_sos': s['id'], 'p_answer': a['id']}, ok: 'SOS résolu : merci à ${a['author']} !')) ref.invalidate(sosProvider('mine'));
                                  },
                                  child: Padding(padding: const EdgeInsets.only(top: 4), child: Text('Cette réponse m’a aidé', style: mst(12, w: FontWeight.w700, c: kViolet))),
                                ),
                              ),
                          ]),
                        ),
                      ],
                    ])),
                ]),
        ),
        mSectionTitle('SOS de ma filière'),
        mAsync<List<Map<String, dynamic>>>(
          ref.watch(sosProvider('filiere')),
          (l) => l.isEmpty
              ? Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('Aucun SOS ouvert dans votre filière. Renseignez votre filière dans votre profil pour être prévenu.', style: mst(13, c: kGrey)))
              : Column(children: [
                  for (final s in l)
                    _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${s['author']}', style: mst(12, w: FontWeight.w700, c: kViolet)),
                      Text('${s['subject']}', style: mst(14, w: FontWeight.w800)),
                      if ('${s['details']}'.isNotEmpty) Text('${s['details']}', maxLines: 3, overflow: TextOverflow.ellipsis, style: mst(12.5, c: kGrey)),
                      const SizedBox(height: 4),
                      Text('${(s['answers'] as List).length} réponse${(s['answers'] as List).length > 1 ? 's' : ''}${(s['answers'] as List).isEmpty ? ' · soyez le premier : +15 points' : ''}', style: mst(11.5, c: kGrey)),
                      const SizedBox(height: 8),
                      mButton('Je peux aider', () => _answer(context, ref, s), dark: false),
                    ])),
                ]),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ défis hebdomadaires

class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  String _left(DateTime end) {
    final d = end.difference(DateTime.now());
    if (d.isNegative) return 'Terminé';
    return d.inDays >= 1 ? 'Il reste ${d.inDays} j' : 'Il reste ${d.inHours} h';
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController(), desc = TextEditingController(), days = TextEditingController(text: '7');
    var kind = 'design';
    if (!await _sheet(context, 'Nouveau défi', [
      TextField(controller: title, maxLength: 120, decoration: _deco('Titre', hint: 'Défi Design : refais le logo de Boutik-École')),
      TextField(controller: desc, maxLines: 3, decoration: _deco('Consignes')),
      const SizedBox(height: 10),
      StatefulBuilder(builder: (c, set) => MDropdown(label: 'Type', value: kind, items: const {'design': 'Design', 'code': 'Code', 'other': 'Autre'}, onChanged: (v) => set(() => kind = v))),
      const SizedBox(height: 10),
      TextField(controller: days, keyboardType: TextInputType.number, decoration: _deco('Durée en jours')),
    ], 'Lancer le défi') || !context.mounted) {
      return;
    }
    if (await _call(context, 'challenge_create', {'p_title': title.text, 'p_description': desc.text, 'p_kind': kind, 'p_days': _digits(days.text) ?? 7}, ok: 'Défi lancé.')) {
      ref.invalidate(challengesProvider);
    }
  }

  Future<void> _submit(BuildContext context, WidgetRef ref, Map<String, dynamic> c) async {
    if (!await requireLogin(context, ref, 'participer à un défi') || !context.mounted) return;
    final title = TextEditingController(), desc = TextEditingController(), url = TextEditingController();
    if (!await _sheet(context, 'Ma réalisation', [
      TextField(controller: title, maxLength: 120, decoration: _deco('Titre')),
      TextField(controller: desc, maxLines: 3, decoration: _deco('Description (facultatif)')),
      const SizedBox(height: 10),
      TextField(controller: url, keyboardType: TextInputType.url, decoration: _deco('Lien (facultatif)', hint: 'https://…')),
    ], 'Envoyer') || !context.mounted) {
      return;
    }
    if (await _call(context, 'challenge_submit', {'p_challenge': c['id'], 'p_title': title.text, 'p_description': desc.text, 'p_url': url.text}, ok: 'Réalisation envoyée : +5 points.')) {
      ref.invalidate(challengesProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider.select((a) => a.current?.staff ?? ''));
    final canCreate = role.isNotEmpty;
    return MarchePage(
      title: 'Défis hebdomadaires',
      child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
        if (canCreate) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: mButton('Lancer un défi', () => _create(context, ref), icon: Icons.add)),
        mAsync<List<Map<String, dynamic>>>(
          ref.watch(challengesProvider),
          (l) => l.isEmpty
              ? mNote('Aucun défi pour le moment.\nChaque semaine, un nouveau défi : Design, Code…')
              : Column(children: [
                  for (final c in l)
                    _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${c['kind']}'.toUpperCase() + ' · ' + _left(DateTime.parse('${c['ends_at']}').toLocal()), style: mst(11, w: FontWeight.w700, c: c['ended'] == true ? kGrey : kViolet)),
                      Text('${c['title']}', style: mst(15, w: FontWeight.w800)),
                      if ('${c['description']}'.isNotEmpty) Text('${c['description']}', style: mst(12.5, c: kGrey).copyWith(height: 1.4)),
                      const SizedBox(height: 8),
                      if (c['ended'] != true && c['i_entered'] != true) mButton('Participer', () => _submit(context, ref, c), dark: false),
                      for (final e in (c['entries'] as List? ?? const []))
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: (e as Map)['winner'] == true ? const Color(0xFFFFF6DC) : const Color(0xFFF7F4FA), borderRadius: BorderRadius.circular(4)),
                          child: Row(children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: '${e['url']}'.isEmpty ? null : () => openUrl(context, '${e['url']}'),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('${e['winner'] == true ? '🏆 ' : ''}${e['title']}', style: mst(13.5, w: FontWeight.w800)),
                                  Text('${e['author']}${'${e['url']}'.isEmpty ? '' : ' · lien'}', style: mst(11.5, c: kGrey)),
                                ]),
                              ),
                            ),
                            Text('${e['votes']} vote${mInt(e['votes']) > 1 ? 's' : ''}', style: mst(12, w: FontWeight.w700)),
                            if (c['ended'] != true && e['mine'] != true) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () async {
                                  if (await _call(context, 'challenge_vote', {'p_entry': e['id']}, ok: 'Vote enregistré.')) ref.invalidate(challengesProvider);
                                },
                                child: Icon(c['my_vote'] == e['id'] ? Icons.how_to_vote : Icons.how_to_vote_outlined, color: kViolet),
                              ),
                            ],
                          ]),
                        ),
                    ])),
                ]),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ marché des compétences

class SkillsScreen extends ConsumerStatefulWidget {
  const SkillsScreen({super.key});

  @override
  ConsumerState<SkillsScreen> createState() => _SkillsState();
}

class _SkillsState extends ConsumerState<SkillsScreen> {
  String _kind = '';

  static const kinds = {'': 'Toutes', 'seek': 'Je cherche', 'offer': 'Je propose', 'swap': 'J’échange'};

  Future<void> _post() async {
    if (!await requireLogin(context, ref, 'publier une annonce') || !mounted) return;
    final title = TextEditingController(), desc = TextEditingController(), price = TextEditingController(), swap = TextEditingController();
    var kind = 'seek';
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(c).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Nouvelle annonce', style: mst(18, w: FontWeight.w800)),
              const SizedBox(height: 12),
              MDropdown(label: 'Type', value: kind, items: const {'seek': 'Je cherche quelqu’un qui sait faire…', 'offer': 'Je propose mes compétences', 'swap': 'J’échange un service'}, onChanged: (v) => set(() => kind = v)),
              const SizedBox(height: 10),
              TextField(controller: title, maxLength: 100, decoration: _deco('Titre', hint: 'Ex. Un poster pour mon projet')),
              TextField(controller: desc, maxLines: 3, maxLength: 500, decoration: _deco('Détails (facultatif)')),
              const SizedBox(height: 10),
              if (kind != 'swap') TextField(controller: price, keyboardType: TextInputType.number, decoration: _deco(kind == 'seek' ? 'Je paie (FCFA)' : 'Mon tarif (FCFA)', hint: '5000')),
              if (kind == 'swap') TextField(controller: swap, decoration: _deco('En échange de', hint: 'Ex. Aide en anglais')),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: mButton('Annuler', () => Navigator.pop(c, false), dark: false)),
                const SizedBox(width: 10),
                Expanded(child: mButton('Publier', () => Navigator.pop(c, true))),
              ]),
            ]),
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    if (await _call(context, 'skill_post', {'p_kind': kind, 'p_title': title.text, 'p_description': desc.text, 'p_price': kind == 'swap' ? null : _digits(price.text), 'p_swap_for': swap.text}, ok: 'Annonce publiée.')) {
      ref.invalidate(skillsProvider(_kind));
    }
  }

  Future<void> _respond(Map<String, dynamic> s) async {
    if (!await requireLogin(context, ref, 'répondre à une annonce') || !mounted) return;
    final msg = TextEditingController();
    if (!await _sheet(context, 'Répondre à « ${s['title']} »', [TextField(controller: msg, maxLines: 3, maxLength: 500, decoration: _deco('Votre message'))], 'Envoyer') || !mounted) return;
    if (await _call(context, 'skill_respond', {'p_id': s['id'], 'p_message': msg.text}, ok: 'Réponse envoyée : ${s['author']} est prévenu(e).')) {
      ref.invalidate(skillsProvider(_kind));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MarchePage(
      title: 'Marché des compétences',
      child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: mButton('Publier une annonce', _post, icon: Icons.add)),
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: MDropdown(label: 'Type d’annonce', value: _kind, items: kinds, onChanged: (v) => setState(() => _kind = v))),
        mAsync<List<Map<String, dynamic>>>(
          ref.watch(skillsProvider(_kind)),
          (l) => l.isEmpty
              ? mNote('Aucune annonce pour le moment.\n« Je cherche quelqu’un qui sait faire un poster, je paie 5 000 FCFA » ou « Je t’aide en maths, tu m’aides en anglais » : publiez la première.')
              : Column(children: [
                  for (final s in l)
                    _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(const {'seek': 'JE CHERCHE', 'offer': 'JE PROPOSE', 'swap': 'J’ÉCHANGE'}['${s['kind']}'] ?? '', style: mst(10.5, w: FontWeight.w800, c: kViolet)),
                      Text('${s['title']}', style: mst(14.5, w: FontWeight.w800)),
                      if ('${s['description']}'.isNotEmpty) Text('${s['description']}', style: mst(12.5, c: kGrey).copyWith(height: 1.4)),
                      const SizedBox(height: 4),
                      Text([
                        '${s['author']}',
                        if (s['price'] != null) mFcfa(s['price']),
                        if ('${s['swap_for']}'.isNotEmpty) 'contre : ${s['swap_for']}',
                        if (s['mine'] == true) '${mInt(s['responses'])} réponse${mInt(s['responses']) > 1 ? 's' : ''}',
                      ].join(' · '), style: mst(12, c: kGrey)),
                      const SizedBox(height: 8),
                      if (s['mine'] == true)
                        mButton('Clôturer mon annonce', () async {
                          if (await _call(context, 'skill_close', {'p_id': s['id']})) ref.invalidate(skillsProvider(_kind));
                        }, dark: false)
                      else
                        mButton(s['responded'] == true ? 'Réponse envoyée' : 'Répondre', s['responded'] == true ? null : () => _respond(s), dark: false),
                    ])),
                ]),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ mur des victoires

class VictoriesScreen extends ConsumerWidget {
  const VictoriesScreen({super.key});

  static const kinds = {'internship': 'Stage obtenu', 'hackathon': 'Hackathon gagné', 'grade': 'Bonne note', 'other': 'Autre réussite'};

  Future<void> _post(BuildContext context, WidgetRef ref) async {
    if (!await requireLogin(context, ref, 'partager une réussite') || !context.mounted) return;
    final body = TextEditingController();
    var kind = 'internship';
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(c).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Partager une réussite', style: mst(18, w: FontWeight.w800)),
            const SizedBox(height: 12),
            MDropdown(label: 'Type', value: kind, items: kinds, onChanged: (v) => set(() => kind = v)),
            const SizedBox(height: 10),
            TextField(controller: body, maxLines: 3, maxLength: 400, decoration: _deco('Ma réussite', hint: 'J’ai eu mon stage, j’ai eu 18/20…')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: mButton('Annuler', () => Navigator.pop(c, false), dark: false)),
              const SizedBox(width: 10),
              Expanded(child: mButton('Partager', () => Navigator.pop(c, true))),
            ]),
          ]),
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    if (await _call(context, 'victory_post', {'p_kind': kind, 'p_body': body.text}, ok: 'Bravo ! Votre réussite est sur le mur.')) {
      ref.invalidate(victoriesProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MarchePage(
      title: 'Mur des victoires',
      child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: mButton('Partager une réussite', () => _post(context, ref), icon: Icons.celebration_outlined)),
        mAsync<List<Map<String, dynamic>>>(
          ref.watch(victoriesProvider),
          (l) => l.isEmpty
              ? mNote('Le mur est vide pour le moment.\nStage obtenu, hackathon gagné, 18/20 : ici, on ne poste que les réussites.')
              : Column(children: [
                  for (final v in l)
                    _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${kinds['${v['kind']}'] ?? ''} · ${v['author']}', style: mst(11.5, w: FontWeight.w700, c: kViolet)),
                      const SizedBox(height: 4),
                      Text('${v['body']}', style: mst(14.5, w: FontWeight.w700).copyWith(height: 1.4)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () async {
                          if (await _call(context, 'victory_cheer', {'p_id': v['id']})) ref.invalidate(victoriesProvider);
                        },
                        child: Row(children: [Icon(v['cheered'] == true ? Icons.celebration : Icons.celebration_outlined, size: 20, color: v['cheered'] == true ? const Color(0xFFD99A00) : kGrey), const SizedBox(width: 6), Text('${v['cheers']} félicitation${mInt(v['cheers']) > 1 ? 's' : ''}', style: mst(12.5, w: FontWeight.w700))]),
                      ),
                    ])),
                ]),
        ),
      ]),
    );
  }
}
