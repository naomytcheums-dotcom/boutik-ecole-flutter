import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../gen.dart' show gToast;
import '../i18n.dart' show Text;
import 'auth.dart';
import 'backend.dart';
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';

/// Réseau des mentors : anciens qui travaillent déjà et peuvent aider. Annuaire, match automatique, fiche, demande de mentor, avis et histoires de réussite.
/// Tout vient du serveur (migration 20261114001100) ; rien n'est affiché tant qu'aucun mentor ne s'est inscrit.

const availabilityLabels = {'this_week': 'Disponible cette semaine', 'available': 'Disponible', 'busy': 'Pas disponible'};

Color availabilityColor(String a) => switch (a) {
      'this_week' => kGreen,
      'available' => kViolet,
      _ => kRed,
    };

Future<List<Map<String, dynamic>>> _list(String fn, Map<String, dynamic> p) async {
  final r = await marcheCall(fn, p);
  if (r.error != null) throw MarcheException(r.error);
  return [for (final x in (r.data as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
}

final mentorsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, topic) => _list('mentors_list', {if (topic.isNotEmpty) 'p_topic': topic}));
final mentorStoriesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => _list('mentor_stories', const {'p_limit': 20}));
final myMentorProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  if (!Backend.ready) return null;
  final r = await marcheCall('my_mentor', const {});
  return r.error != null || r.data is! Map ? null : Map<String, dynamic>.from(r.data as Map);
});
final mentorDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final r = await marcheCall('mentor_detail', {'p_user': id});
  if (r.error != null) throw MarcheException(r.error);
  return Map<String, dynamic>.from(r.data as Map);
});
final mentorRequestsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, role) => _list('my_mentor_requests', {'p_role': role}));

Widget _box(Widget child) => Container(margin: const EdgeInsets.fromLTRB(16, 0, 16, 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: kLine)), child: child);

Widget _pill(String label, Color c) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)), child: Text(label, style: mst(10.5, w: FontWeight.w700, c: c)));

String stars(num? rating) => rating == null ? 'Pas encore noté' : '★ $rating';

/// Carte d'un mentor : nom, promo et filière, employeur actuel, sujets, disponibilité et note.
class MentorCard extends StatelessWidget {
  const MentorCard({super.key, required this.m, this.onTap});
  final Map<String, dynamic> m;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final topics = [for (final t in (m['topics'] as List? ?? const [])) '$t'];
    final avail = '${m['availability']}';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: _box(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipOval(child: SizedBox(width: 48, height: 48, child: MImage('${m['avatar_url'] ?? ''}', icon: Icons.person_outline))),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${m['name']}', style: mst(14.5, w: FontWeight.w800)),
            Text([if ('${m['promo']}'.isNotEmpty) '${m['promo']}', if ('${m['department'] ?? ''}'.isNotEmpty) '${m['department']}'].join(' · '), style: mst(12, c: kGrey)),
            Text('Travaille chez ${m['works_at']}', style: mst(12.5, w: FontWeight.w600)),
            if (topics.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Je peux aider : ${topics.join(', ')}', maxLines: 2, overflow: TextOverflow.ellipsis, style: mst(12, c: kGrey))),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: [
              _pill(availabilityLabels[avail] ?? avail, availabilityColor(avail)),
              _pill(stars(m['rating'] as num?) + (mInt(m['reviews']) > 0 ? ' (${m['reviews']})' : ''), const Color(0xFF8F5400)),
              if (m['score'] != null) _pill('Compatibilité : ${m['score']}', kGreen),
            ]),
          ]),
        ),
      ])),
    );
  }
}

// ------------------------------------------------------------------ annuaire, match, histoires

class MentorsScreen extends ConsumerStatefulWidget {
  const MentorsScreen({super.key});

  @override
  ConsumerState<MentorsScreen> createState() => _MentorsState();
}

class _MentorsState extends ConsumerState<MentorsScreen> {
  final _want = TextEditingController(), _topic = TextEditingController();
  bool _evening = false, _busy = false;
  String _topicFilter = '';
  List<Map<String, dynamic>>? _match;

  @override
  void dispose() {
    _want.dispose();
    _topic.dispose();
    super.dispose();
  }

  Future<void> _doMatch() async {
    if (!await requireLogin(context, ref, 'trouver un mentor') || !mounted) return;
    setState(() => _busy = true);
    final r = await marcheCall('mentor_match', {'p_topic': _want.text, 'p_evening': _evening, 'p_limit': 3});
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.error != null) return gToast(context, Backend.userMessage('${r.error}'));
    setState(() => _match = [for (final x in (r.data as List? ?? const [])) Map<String, dynamic>.from(x as Map)]);
  }

  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(myMentorProvider).value;
    return MarchePage(
      title: 'Mentors',
      child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Text('Des anciens qui travaillent déjà et peuvent vous aider : entretien d’embauche, Flutter, premier emploi…', style: mst(13, c: kGrey).copyWith(height: 1.5)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(children: [
            Expanded(child: mButton(mine == null ? 'Devenir mentor' : 'Mon profil mentor', () => context.push('/mentors/profil'), dark: false, icon: Icons.volunteer_activism_outlined)),
            const SizedBox(width: 10),
            Expanded(child: mButton('Mes demandes', () => context.push('/mentors/demandes'), dark: false, icon: Icons.inbox_outlined)),
          ]),
        ),
        _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Trouver mon mentor', style: mst(15, w: FontWeight.w800)),
          const SizedBox(height: 8),
          TextField(controller: _want, decoration: InputDecoration(hintText: 'Je veux apprendre… (ex. Flutter)', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)))),
          Row(children: [Expanded(child: Text('Je suis disponible le soir', style: mst(13))), Switch(value: _evening, onChanged: (v) => setState(() => _evening = v))]),
          mButton('Proposer 3 mentors', _busy ? null : _doMatch, width: double.infinity),
        ])),
        if (_match != null) ...[
          mSectionTitle(_match!.isEmpty ? 'Aucun mentor ne correspond pour le moment' : 'Vos mentors les plus compatibles'),
          for (final m in _match!) MentorCard(m: m, onTap: () => context.push('/mentors/${m['user_id']}')),
        ],
        mSectionTitle('Tous les mentors'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(controller: _topic, textInputAction: TextInputAction.search, onSubmitted: (v) => setState(() => _topicFilter = v.trim()), decoration: InputDecoration(hintText: 'Chercher par sujet : Flutter, design, entretien…', prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 12))),
        ),
        mAsync<List<Map<String, dynamic>>>(
          ref.watch(mentorsProvider(_topicFilter)),
          (l) => l.isEmpty ? mNote('Aucun mentor pour le moment.\nLes anciens qui souhaitent aider apparaîtront ici : devenez le premier mentor !') : Column(children: [for (final m in l) MentorCard(m: m, onTap: () => context.push('/mentors/${m['user_id']}'))]),
        ),
        mSectionTitle('Histoires de réussite'),
        mAsync<List<Map<String, dynamic>>>(
          ref.watch(mentorStoriesProvider),
          (l) => l.isEmpty
              ? Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('Les parcours des anciens, de l’IUT à leur premier emploi, apparaîtront ici.', style: mst(13, c: kGrey)))
              : Column(children: [
                  for (final s in l)
                    _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${s['title']}', style: mst(14.5, w: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('${s['body']}', maxLines: 6, overflow: TextOverflow.ellipsis, style: mst(13).copyWith(height: 1.45)),
                      const SizedBox(height: 6),
                      Text('${s['author']}${'${s['company']}'.isEmpty ? '' : ' · ${s['company']}'}', style: mst(12, w: FontWeight.w700, c: kViolet)),
                    ])),
                ]),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ fiche d'un mentor

class MentorDetailScreen extends ConsumerWidget {
  const MentorDetailScreen({super.key, required this.id});
  final String id;

  Future<void> _request(BuildContext context, WidgetRef ref, Map<String, dynamic> m) async {
    if (!await requireLogin(context, ref, 'demander un mentor') || !context.mounted) return;
    final topic = TextEditingController(), msg = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(c).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Demander ${m['name']} comme mentor', style: mst(17, w: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(controller: topic, decoration: InputDecoration(labelText: 'Ce que je veux apprendre', hintText: 'Ex. Flutter, entretien d’embauche', border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 10),
            TextField(controller: msg, maxLines: 4, maxLength: 600, decoration: InputDecoration(labelText: 'Message (facultatif)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: mButton('Annuler', () => Navigator.pop(c, false), dark: false)),
              const SizedBox(width: 10),
              Expanded(child: mButton('Envoyer la demande', () => Navigator.pop(c, true))),
            ]),
          ]),
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final r = await marcheCall('mentor_request', {'p_mentor': id, 'p_topic': topic.text, 'p_message': msg.text});
    if (!context.mounted) return;
    gToast(context, r.error != null ? Backend.userMessage('${r.error}') : 'Demande envoyée : ${m['name']} vous répondra.');
    ref.invalidate(mentorDetailProvider(id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MarchePage(
      title: 'Mentor',
      child: mAsync<Map<String, dynamic>>(ref.watch(mentorDetailProvider(id)), (m) {
        final reviews = [for (final r in (m['review_list'] as List? ?? const [])) Map<String, dynamic>.from(r as Map)];
        final req = m['my_request'] is Map ? Map<String, dynamic>.from(m['my_request'] as Map) : null;
        final avail = '${m['availability']}';
        return ListView(padding: const EdgeInsets.only(bottom: 90, top: 4), children: [
          MentorCard(m: m),
          if ('${m['bio']}'.isNotEmpty) _box(Text('${m['bio']}', style: mst(13.5).copyWith(height: 1.5))),
          _box(Text('${mInt(m['helped'])} accompagnement${mInt(m['helped']) > 1 ? 's' : ''} accepté${mInt(m['helped']) > 1 ? 's' : ''}${m['evening'] == true ? ' · disponible le soir' : ''}', style: mst(12.5, c: kGrey))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: req != null && req['status'] == 'requested'
                ? Text('Votre demande est en attente de réponse.', style: mst(13, w: FontWeight.w700, c: kViolet))
                : req != null && req['status'] == 'accepted'
                    ? Text('Demande acceptée : écrivez à ${m['name']} pour convenir d’un moment.', style: mst(13, w: FontWeight.w700, c: kGreen))
                    : mButton(avail == 'busy' ? 'Pas disponible pour le moment' : 'Demander un mentor', avail == 'busy' ? null : () => _request(context, ref, m), width: double.infinity),
          ),
          mSectionTitle('Avis'),
          if (reviews.isEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('Pas encore d’avis : les étudiants aidés pourront noter ce mentor.', style: mst(13, c: kGrey))),
          for (final r in reviews)
            _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${'★' * mInt(r['rating'])}  ${r['author']}', style: mst(13, w: FontWeight.w800, c: const Color(0xFF8F5400))),
              if ('${r['comment']}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${r['comment']}', style: mst(13).copyWith(height: 1.4))),
            ])),
        ]);
      }),
    );
  }
}

// ------------------------------------------------------------------ mes demandes (envoyées et reçues)

class MentorRequestsScreen extends ConsumerWidget {
  const MentorRequestsScreen({super.key});

  static const _status = {'requested': 'En attente', 'accepted': 'Acceptée', 'declined': 'Déclinée', 'cancelled': 'Annulée'};

  Future<void> _decide(BuildContext context, WidgetRef ref, Map<String, dynamic> q, bool accept) async {
    final r = await marcheCall('mentor_request_decide', {'p_id': q['id'], 'p_accept': accept});
    if (!context.mounted) return;
    gToast(context, r.error != null ? Backend.userMessage('${r.error}') : (accept ? 'Demande acceptée : l’étudiant est prévenu.' : 'Demande déclinée.'));
    ref.invalidate(mentorRequestsProvider('mentor'));
  }

  Future<void> _review(BuildContext context, WidgetRef ref, Map<String, dynamic> q) async {
    var rating = 5;
    final comment = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(c).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Noter ${q['other']}', style: mst(17, w: FontWeight.w800)),
            const SizedBox(height: 8),
            Row(children: [for (var i = 1; i <= 5; i++) IconButton(tooltip: '$i étoile${i > 1 ? 's' : ''}', onPressed: () => set(() => rating = i), icon: Icon(i <= rating ? Icons.star_rounded : Icons.star_outline_rounded, color: const Color(0xFFF5A524), size: 32))]),
            TextField(controller: comment, maxLines: 3, maxLength: 400, decoration: InputDecoration(labelText: 'Votre avis (facultatif)', hintText: 'Il m’a beaucoup aidé…', border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 10),
            mButton('Publier mon avis', () => Navigator.pop(c, true), width: double.infinity),
          ]),
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final r = await marcheCall('mentor_review', {'p_request': q['id'], 'p_rating': rating, 'p_comment': comment.text});
    if (!context.mounted) return;
    gToast(context, r.error != null ? Backend.userMessage('${r.error}') : 'Merci pour votre avis.');
    ref.invalidate(mentorRequestsProvider('student'));
  }

  Widget _list(BuildContext context, WidgetRef ref, String role) => mAsync<List<Map<String, dynamic>>>(
        ref.watch(mentorRequestsProvider(role)),
        (l) => l.isEmpty
            ? Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(role == 'mentor' ? 'Aucune demande reçue pour le moment.' : 'Vous n’avez pas encore demandé de mentor.', style: mst(13, c: kGrey)))
            : Column(children: [
                for (final q in l)
                  _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('${q['other']}', style: mst(14, w: FontWeight.w800))),
                      _pill(_status['${q['status']}'] ?? '${q['status']}', q['status'] == 'accepted' ? kGreen : (q['status'] == 'requested' ? kViolet : kRed)),
                    ]),
                    Text('Sujet : ${q['topic']}', style: mst(13, w: FontWeight.w600)),
                    if ('${q['message']}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${q['message']}', style: mst(12.5, c: kGrey).copyWith(height: 1.4))),
                    if (role == 'mentor' && q['status'] == 'requested') ...[
                      const SizedBox(height: 10),
                      Row(children: [Expanded(child: mButton('Décliner', () => _decide(context, ref, q, false), dark: false)), const SizedBox(width: 10), Expanded(child: mButton('Accepter', () => _decide(context, ref, q, true)))]),
                    ],
                    if (role == 'student' && q['status'] == 'accepted') ...[
                      const SizedBox(height: 10),
                      q['reviewed'] == true ? Text('Avis publié', style: mst(12.5, w: FontWeight.w700, c: kGreen)) : mButton('Noter ce mentor', () => _review(context, ref, q), dark: false),
                    ],
                  ])),
              ]),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMentor = ref.watch(myMentorProvider).value != null;
    return MarchePage(
      title: 'Mes demandes',
      child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
        mSectionTitle('Mes demandes de mentor'),
        _list(context, ref, 'student'),
        if (isMentor) ...[mSectionTitle('Demandes reçues'), _list(context, ref, 'mentor')],
      ]),
    );
  }
}

// ------------------------------------------------------------------ devenir mentor (profil) et raconter son parcours

class MentorProfileScreen extends ConsumerStatefulWidget {
  const MentorProfileScreen({super.key});

  @override
  ConsumerState<MentorProfileScreen> createState() => _MentorProfileState();
}

class _MentorProfileState extends ConsumerState<MentorProfileScreen> {
  final _works = TextEditingController(), _promo = TextEditingController(), _topics = TextEditingController(), _bio = TextEditingController();
  final _storyTitle = TextEditingController(), _storyBody = TextEditingController(), _storyCompany = TextEditingController();
  String _avail = 'available';
  bool _evening = false, _active = true, _loaded = false, _busy = false;

  @override
  void dispose() {
    for (final c in [_works, _promo, _topics, _bio, _storyTitle, _storyBody, _storyCompany]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(Map<String, dynamic>? m) {
    if (_loaded || m == null) return;
    _loaded = true;
    _works.text = '${m['works_at']}';
    _promo.text = '${m['promo']}';
    _topics.text = [for (final t in (m['topics'] as List? ?? const [])) '$t'].join(', ');
    _bio.text = '${m['bio']}';
    _avail = '${m['availability']}';
    _evening = m['evening'] == true;
    _active = m['active'] != false;
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final r = await marcheCall('mentor_save', {
      'p_works_at': _works.text,
      'p_promo': _promo.text,
      'p_topics': [for (final t in _topics.text.split(',')) if (t.trim().isNotEmpty) t.trim()],
      'p_bio': _bio.text,
      'p_availability': _avail,
      'p_evening': _evening,
      'p_active': _active,
    });
    if (!mounted) return;
    setState(() => _busy = false);
    gToast(context, r.error != null ? Backend.userMessage('${r.error}') : 'Profil mentor enregistré.');
    if (r.error == null) {
      ref.invalidate(myMentorProvider);
      ref.invalidate(mentorsProvider);
    }
  }

  Future<void> _story() async {
    final r = await marcheCall('mentor_story_save', {'p_title': _storyTitle.text, 'p_body': _storyBody.text, 'p_company': _storyCompany.text});
    if (!mounted) return;
    gToast(context, r.error != null ? Backend.userMessage('${r.error}') : 'Votre histoire est publiée.');
    if (r.error == null) {
      _storyTitle.clear();
      _storyBody.clear();
      _storyCompany.clear();
      ref.invalidate(mentorStoriesProvider);
    }
  }

  InputDecoration _deco(String l, {String? hint}) => InputDecoration(labelText: l, hintText: hint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)), filled: true, fillColor: Colors.white);

  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(myMentorProvider);
    _fill(mine.value);
    final isMentor = mine.value != null;
    return MarchePage(
      title: isMentor ? 'Mon profil mentor' : 'Devenir mentor',
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 90), children: [
        Text('Les étudiants pourront vous demander de l’aide. Indiquez où vous travaillez et sur quoi vous pouvez aider.', style: mst(13, c: kGrey).copyWith(height: 1.5)),
        const SizedBox(height: 12),
        TextField(controller: _works, decoration: _deco('Où je travaille maintenant', hint: 'Ex. Orange Cameroun')),
        const SizedBox(height: 10),
        TextField(controller: _promo, decoration: _deco('Ma promo', hint: 'Ex. Promo 2021')),
        const SizedBox(height: 10),
        TextField(controller: _topics, decoration: _deco('Je peux aider en…', hint: 'Séparés par des virgules : Flutter, entretien d’embauche')),
        const SizedBox(height: 10),
        TextField(controller: _bio, maxLines: 4, maxLength: 600, decoration: _deco('Présentation')),
        MDropdown(label: 'Disponibilité', value: _avail, items: availabilityLabels, onChanged: (v) => setState(() => _avail = v)),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: Text('Disponible le soir', style: mst(13.5)), value: _evening, onChanged: (v) => setState(() => _evening = v)),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: Text('Visible dans l’annuaire', style: mst(13.5)), value: _active, onChanged: (v) => setState(() => _active = v)),
        mButton(_busy ? 'Enregistrement…' : (isMentor ? 'Enregistrer' : 'Devenir mentor'), _busy ? null : _save, width: double.infinity),
        if (isMentor) ...[
          mSectionTitle('Raconter mon parcours'),
          Text('Une histoire de réussite : de l’IUT à votre emploi. Elle sera visible dans le réseau des mentors.', style: mst(12.5, c: kGrey)),
          const SizedBox(height: 10),
          TextField(controller: _storyTitle, decoration: _deco('Titre', hint: 'De l’IUT à Orange Cameroun')),
          const SizedBox(height: 10),
          TextField(controller: _storyCompany, decoration: _deco('Entreprise (facultatif)')),
          const SizedBox(height: 10),
          TextField(controller: _storyBody, maxLines: 6, maxLength: 2000, decoration: _deco('Mon histoire')),
          mButton('Publier mon histoire', _story, dark: false, width: double.infinity),
        ],
      ]),
    );
  }
}
