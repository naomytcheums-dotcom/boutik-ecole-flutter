import 'form_options.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../gen.dart' show gToast;
import '../i18n.dart' show Text;
import 'auth.dart';
import 'backend.dart';
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';
import 'share.dart' show openUrl, shareText, siteUrl;
import 'social_posts.dart' show uploadPostMedia;
import '../gdata.dart' show gNetImage;

/// Opportunités : stages, emplois, missions, défis, bénévolat et formations publiés par des entreprises, ONG, startups ou l'IUT.
/// Cartes qui permettent de décider en 10 secondes, fiche complète, candidature dans l'application ou par WhatsApp, favoris, rappel, alerte filière, recrutés.
/// Tout vient du serveur (migration 20261114001300) ; aucune offre n'est inventée.

const oppKinds = {
  '': 'Tous les types',
  'stage': 'Stage',
  'emploi': 'Emploi',
  'mission': 'Projet ou mission',
  'defi': 'Défi ou hackathon',
  'benevolat': 'Bénévolat ou association',
  'formation': 'Formation ou atelier',
};
const oppModes = {'': 'Tous les modes', 'onsite': 'Présentiel', 'online': 'En ligne', 'hybrid': 'Hybride'};

String oppModeLabel(String m) => oppModes[m] ?? m;

/// « Il reste 5 jours », « Dernier jour », « Clôturée » ; « Sans date limite » si elle n'est pas fixée.
String oppDeadlineLabel(DateTime? deadline, DateTime now) {
  if (deadline == null) return 'Sans date limite';
  final d = DateTime(deadline.year, deadline.month, deadline.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  if (d < 0) return 'Clôturée';
  if (d == 0) return 'Dernier jour';
  return 'Il reste $d jour${d > 1 ? 's' : ''}';
}

/// « Rémunéré 50 000 FCFA par mois », « Non rémunéré mais attestation », « À négocier ».
String oppPayLabel(Map<String, dynamic> o) {
  final note = '${o['pay_note'] ?? ''}'.trim();
  return switch ('${o['pay_kind']}') {
    'paid' => o['pay_amount'] == null ? 'Rémunéré' : 'Rémunéré ${mFcfa(o['pay_amount'])} par mois',
    'unpaid' => note.isEmpty ? 'Non rémunéré' : 'Non rémunéré mais $note',
    _ => 'À négocier',
  };
}

class OppQuery {
  const OppQuery({this.kind = '', this.mode = '', this.paid = false, this.iut = false, this.q = '', this.section = ''});
  final String kind, mode, q, section;
  final bool paid, iut;
  OppQuery copy({String? kind, String? mode, bool? paid, bool? iut, String? q, String? section}) => OppQuery(kind: kind ?? this.kind, mode: mode ?? this.mode, paid: paid ?? this.paid, iut: iut ?? this.iut, q: q ?? this.q, section: section ?? this.section);
  bool get filtered => kind.isNotEmpty || mode.isNotEmpty || paid || iut || q.trim().isNotEmpty;
  Map<String, dynamic> get params => {
        if (kind.isNotEmpty) 'p_kind': kind,
        if (mode.isNotEmpty) 'p_mode': mode,
        if (paid) 'p_paid_only': true,
        if (iut) 'p_iut_only': true,
        if (q.trim().isNotEmpty) 'p_q': q.trim(),
        if (section.isNotEmpty) 'p_section': section,
        'p_limit': 40,
      };
  @override
  bool operator ==(Object o) => o is OppQuery && o.kind == kind && o.mode == mode && o.paid == paid && o.iut == iut && o.q == q && o.section == section;
  @override
  int get hashCode => Object.hash(kind, mode, paid, iut, q, section);
}

Future<List<Map<String, dynamic>>> _list(String fn, Map<String, dynamic> p) async {
  final r = await marcheCall(fn, p);
  if (r.error != null) throw MarcheException(r.error);
  return [for (final x in (r.data as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
}

final oppsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, OppQuery>((ref, q) {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  return _list('opps_list', q.params);
});
final oppHiredProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => _list('opp_hired_list', const {'p_limit': 10}));
final oppMyApplicationsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => _list('opp_my_applications', const {}));
final oppMyPostedProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => _list('opp_my_posted', const {}));
/// Statistiques de mes offres (vues, favoris, candidatures, taux de réponse), indexées par l'identifiant de l'offre.
final oppStatsProvider = FutureProvider.autoDispose<Map<String, Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  if (!Backend.ready) return const {};
  final r = await marcheCall('opp_stats', const {});
  if (r.error != null || r.data is! List) return const {};
  return {for (final x in r.data as List) '${(x as Map)['id']}': Map<String, dynamic>.from(x)};
});

final oppDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final r = await marcheCall('opp_detail', {'p_id': id});
  if (r.error != null) throw MarcheException(r.error);
  return Map<String, dynamic>.from(r.data as Map);
});
final oppAlertProvider = FutureProvider.autoDispose<bool>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  if (!Backend.ready) return false;
  final r = await marcheCall('opp_my_alert', const {});
  return r.data == true;
});

Widget _box(Widget child, {EdgeInsets margin = const EdgeInsets.fromLTRB(16, 0, 16, 10)}) => Container(margin: margin, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: kLine)), child: child);

Widget _pill(String s, Color c) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)), child: Text(s, style: mst(10.5, w: FontWeight.w700, c: c)));

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

/// Carte d'une offre : organisation avec badge Vérifié, poste, lieu et mode, durée, rémunération, compte à rebours, compétences, favori.
class OpportunityCard extends StatelessWidget {
  const OpportunityCard({super.key, required this.o, this.onTap, this.onSave, this.now});
  final Map<String, dynamic> o;
  final VoidCallback? onTap, onSave;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final t = now ?? DateTime.now();
    final deadline = DateTime.tryParse('${o['deadline']}');
    final left = oppDeadlineLabel(deadline, t);
    final urgent = deadline != null && deadline.difference(DateTime(t.year, t.month, t.day)).inDays <= 3;
    final skills = [for (final s in (o['skills'] as List? ?? const [])) '$s'];
    final where = [if ('${o['location']}'.isNotEmpty) '${o['location']}', oppModeLabel('${o['mode']}')].join(' · ');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if ('${o['media_path'] ?? ''}'.isNotEmpty && '${o['media_path']}' != 'null')
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: o['media_kind'] == 'video' ? () => openUrl(context, Backend.postMediaUrl('${o['media_path']}')) : onTap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: o['media_kind'] == 'video'
                      ? Stack(fit: StackFit.expand, children: [
                          const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2A2833), Color(0xFF0E0F14)]))),
                          const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 48)),
                          Positioned(left: 10, bottom: 8, child: Text('Vidéo de présentation', style: mst(11.5, w: FontWeight.w700, c: Colors.white))),
                        ])
                      : gNetImage(Backend.postMediaUrl('${o['media_path']}'), fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFEDE9F6))),
                ),
              ),
            ),
          ),
        Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(4), child: SizedBox(width: 36, height: 36, child: MImage('${o['logo'] ?? ''}', icon: Icons.business_outlined))),
          const SizedBox(width: 10),
          Expanded(
            child: Row(children: [
              Flexible(child: Text('${o['org']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: mst(12.5, w: FontWeight.w700, c: kGrey))),
              if (o['verified'] == true) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified_rounded, size: 16, color: kViolet)),
            ]),
          ),
          if (onSave != null) GestureDetector(behavior: HitTestBehavior.opaque, onTap: onSave, child: Padding(padding: const EdgeInsets.all(4), child: Icon(o['saved'] == true ? Icons.bookmark : Icons.bookmark_border, color: o['saved'] == true ? kViolet : kGrey))),
        ]),
        const SizedBox(height: 8),
        Text('${o['title']}', style: mst(15, w: FontWeight.w800)),
        const SizedBox(height: 2),
        Text([oppKinds['${o['kind']}'] ?? '', if ('${o['contract']}'.isNotEmpty) '${o['contract']}', where, if ('${o['duration']}'.isNotEmpty) '${o['duration']}'].where((e) => e.isNotEmpty).join(' · '), style: mst(12, c: kGrey)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 4, children: [
          _pill(oppPayLabel(o), o['pay_kind'] == 'paid' ? kGreen : kGrey),
          _pill(left, urgent ? kRed : kViolet),
          if (o['iut_only'] == true) _pill('Réservé IUT', const Color(0xFF0F2E4E)),
          if (o['applied'] == true) _pill('Candidature envoyée', kGreen),
        ]),
        if (skills.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Wrap(spacing: 6, runSpacing: 4, children: [for (final s in skills.take(5)) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFF2EFF6), borderRadius: BorderRadius.circular(4)), child: Text(s, style: mst(11, w: FontWeight.w600)))])),
      ])),
    );
  }
}

// ------------------------------------------------------------------ liste des opportunités

class OpportunitiesScreen extends ConsumerStatefulWidget {
  const OpportunitiesScreen({super.key});

  @override
  ConsumerState<OpportunitiesScreen> createState() => _OppsState();
}

class _OppsState extends ConsumerState<OpportunitiesScreen> {
  final _q = TextEditingController();
  OppQuery _query = const OppQuery();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _set(OppQuery q) => setState(() => _query = q);

  Future<void> _save(Map<String, dynamic> o) async {
    if (!await requireLogin(context, ref, 'enregistrer une offre') || !mounted) return;
    if (await _call(context, 'opp_save_toggle', {'p_id': o['id']})) ref.invalidate(oppsProvider);
  }

  Future<void> _alert(bool on) async {
    if (!await requireLogin(context, ref, 'activer l’alerte filière') || !mounted) return;
    final dept = ref.read(authProvider).current?.department ?? '';
    if (await _call(context, 'opp_alert_set', {'p_department': dept, 'p_on': on}, ok: on ? 'Alerte activée : vous serez prévenu des nouvelles offres de votre filière.' : 'Alerte désactivée.')) {
      ref.invalidate(oppAlertProvider);
    }
  }

  Widget _section(String title, OppQuery q, {int max = 3}) {
    final async = ref.watch(oppsProvider(q));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (l) => l.isEmpty
          ? const SizedBox.shrink()
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              mSectionTitle(title, trailing: l.length > max ? GestureDetector(onTap: () => _set(_query.copy(section: q.section)), child: Text('Voir tout', style: mst(12.5, w: FontWeight.w600, c: kViolet))) : null),
              for (final o in l.take(max)) OpportunityCard(o: o, onTap: () => context.push('/opportunites/${o['id']}'), onSave: () => _save(o)),
            ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alert = ref.watch(oppAlertProvider).value ?? false;
    final nNew = ref.watch(oppsProvider(const OppQuery(section: 'new'))).value?.length ?? 0;
    final nClosing = ref.watch(oppsProvider(const OppQuery(section: 'closing'))).value?.length ?? 0;
    final nMine = ref.watch(oppsProvider(const OppQuery(section: 'foryou'))).value?.length ?? 0;
    final browsing = !_query.filtered && _query.section.isEmpty;
    Widget check(String t) => Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [const Icon(Icons.check_circle_outline, size: 18, color: Colors.white), const SizedBox(width: 8), Expanded(child: Text(t, style: mst(12, w: FontWeight.w500, c: Colors.white)))]));
    return MarchePage(
      title: 'Opportunités',
      actions: [
        IconButton(tooltip: 'Mes candidatures et favoris', onPressed: () => context.push('/opportunites/mes'), icon: const Icon(Icons.inbox_outlined)),
      ],
      child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
        // Assistant Opportunités : l'icône de l'application, des lignes calculées sur les vraies offres
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0F2E4E), Color(0xFF1E4A80)]), borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 44, height: 44, padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)), child: Image.asset('assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png', fit: BoxFit.contain)),
              const SizedBox(width: 12),
              Expanded(child: Text('Assistant Opportunités', style: mst(15, w: FontWeight.w800, c: Colors.white))),
            ]),
            const SizedBox(height: 6),
            Text('Il repère les offres de votre filière et vous alerte avant les dates limites.', style: mst(12, c: const Color(0xFFE9E4F5)).copyWith(height: 1.4)),
            check(nMine == 0 ? 'Aucune offre dans votre filière pour le moment' : '$nMine offre${nMine > 1 ? 's' : ''} dans votre filière'),
            check(nClosing == 0 ? 'Aucune date limite dans les 3 jours' : '$nClosing offre${nClosing > 1 ? 's' : ''} se termine${nClosing > 1 ? 'nt' : ''} dans 3 jours'),
            check(nNew == 0 ? 'Aucune nouvelle offre cette semaine' : '$nNew nouvelle${nNew > 1 ? 's' : ''} offre${nNew > 1 ? 's' : ''} cette semaine'),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Row(children: [
            Expanded(child: Text('M’alerter des nouvelles offres de ma filière', style: mst(13, w: FontWeight.w600))),
            Switch(value: alert, onChanged: _alert),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(controller: _q, textInputAction: TextInputAction.search, onSubmitted: (v) => _set(_query.copy(q: v)), decoration: InputDecoration(hintText: 'Stage Flutter, assistant communication, Excel…', prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 12))),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(children: [
            Row(children: [
              Expanded(child: MDropdown(label: 'Type', value: _query.kind, items: oppKinds, onChanged: (v) => _set(_query.copy(kind: v)))),
              const SizedBox(width: 10),
              Expanded(child: MDropdown(label: 'Mode', value: _query.mode, items: oppModes, onChanged: (v) => _set(_query.copy(mode: v)))),
            ]),
            Row(children: [
              Expanded(child: Row(children: [Switch(value: _query.paid, onChanged: (v) => _set(_query.copy(paid: v))), Flexible(child: Text('Rémunérées', style: mst(12.5)))])),
              Expanded(child: Row(children: [Switch(value: _query.iut, onChanged: (v) => _set(_query.copy(iut: v))), Flexible(child: Text('Réservées IUT', style: mst(12.5)))])),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Row(children: [
            Expanded(child: mButton('Publier une offre', () => context.push('/opportunites/publier'), dark: false, icon: Icons.add)),
            if (!browsing) ...[const SizedBox(width: 10), SizedBox(width: 130, child: mButton('Tout afficher', () { _q.clear(); _set(const OppQuery()); }, dark: false))],
          ]),
        ),
        if (browsing) ...[
          _section('Pour vous', const OppQuery(section: 'foryou')),
          _section('Date limite proche', const OppQuery(section: 'closing')),
          _section('Nouvelles opportunités', const OppQuery(section: 'new')),
          _section('Rémunérées en premier', const OppQuery(paid: true)),
          _section('Opportunités IUT', const OppQuery(section: 'iut')),
          mSectionTitle('Toutes les opportunités'),
          mAsync<List<Map<String, dynamic>>>(
            ref.watch(oppsProvider(const OppQuery())),
            (l) => l.isEmpty
                ? mNote('Aucune opportunité publiée pour le moment.\nLes stages, emplois et missions proposés par les entreprises apparaîtront ici.')
                : Column(children: [for (final o in l) OpportunityCard(o: o, onTap: () => context.push('/opportunites/${o['id']}'), onSave: () => _save(o))]),
          ),
          mSectionTitle('Ils ont été recrutés'),
          mAsync<List<Map<String, dynamic>>>(
            ref.watch(oppHiredProvider),
            (l) => l.isEmpty
                ? Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('Les étudiants de l’IUT recrutés grâce à une opportunité apparaîtront ici, avec leur accord.', style: mst(13, c: kGrey)))
                : Column(children: [for (final h in l) _box(Text('${h['name']}${'${h['department']}'.isEmpty ? '' : ', ${h['department']}'}, recruté(e) : ${h['role']} chez ${h['org']}', style: mst(13.5, w: FontWeight.w600).copyWith(height: 1.4)))]),
          ),
        ] else ...[
          mSectionTitle(_query.section == 'saved' ? 'Mes favoris' : 'Résultats'),
          mAsync<List<Map<String, dynamic>>>(
            ref.watch(oppsProvider(_query)),
            (l) => l.isEmpty ? mNote('Aucune opportunité ne correspond à votre recherche.') : Column(children: [for (final o in l) OpportunityCard(o: o, onTap: () => context.push('/opportunites/${o['id']}'), onSave: () => _save(o))]),
          ),
        ],
      ]),
    );
  }
}

// ------------------------------------------------------------------ fiche complète

class OpportunityDetailScreen extends ConsumerWidget {
  const OpportunityDetailScreen({super.key, required this.id});
  final String id;

  Future<void> _apply(BuildContext context, WidgetRef ref, Map<String, dynamic> o) async {
    if (!await requireLogin(context, ref, 'postuler') || !context.mounted) return;
    final msg = TextEditingController(), cv = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(c).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Postuler : ${o['title']}', style: mst(17, w: FontWeight.w800)),
            Text('${o['org']}', style: mst(12.5, c: kGrey)),
            const SizedBox(height: 12),
            TextField(controller: msg, maxLines: 6, maxLength: 3000, decoration: InputDecoration(labelText: 'Lettre de motivation', hintText: 'Présentez-vous et expliquez pourquoi cette offre vous intéresse', border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 10),
            TextField(controller: cv, keyboardType: TextInputType.url, decoration: InputDecoration(labelText: 'Lien vers votre CV (facultatif)', hintText: 'https://…', border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: mButton('Annuler', () => Navigator.pop(c, false), dark: false)),
              const SizedBox(width: 10),
              Expanded(child: mButton('Envoyer', () => Navigator.pop(c, true))),
            ]),
          ]),
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    if (await _call(context, 'opp_apply', {'p_id': id, 'p_message': msg.text, 'p_cv_link': cv.text}, ok: 'Candidature envoyée.')) {
      ref.invalidate(oppDetailProvider(id));
      ref.invalidate(oppsProvider);
    }
  }

  Future<void> _whatsapp(BuildContext context, Map<String, dynamic> o) async {
    final digits = '${o['apply_whatsapp']}'.replaceAll(RegExp(r'[^0-9]'), '');
    final number = digits.length == 9 ? '237$digits' : digits;
    final text = Uri.encodeComponent('Bonjour, je souhaite postuler à l’offre « ${o['title']} » publiée sur Boutik-École. $siteUrl/#/opportunites/$id');
    await openUrl(context, 'https://wa.me/$number?text=$text');
  }

  static final _tracked = <String>{};

  /// Enregistre la vue une seule fois par ouverture de l'écran (le serveur la compte une fois par personne et par jour).
  static void _trackView(String id) {
    if (!Backend.ready || !_tracked.add(id)) return;
    marcheCall('opp_view_track', {'p_id': id});
  }

  Widget _list(String title, List items) => items.isEmpty
      ? const SizedBox.shrink()
      : _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: mst(14, w: FontWeight.w800)),
          const SizedBox(height: 6),
          for (final i in items) Padding(padding: const EdgeInsets.only(top: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('• ', style: mst(13, w: FontWeight.w800)), Expanded(child: Text('$i', style: mst(13).copyWith(height: 1.4)))])),
        ]));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MarchePage(
      title: 'Offre',
      child: mAsync<Map<String, dynamic>>(ref.watch(oppDetailProvider(id)), (o) {
        if (o['mine'] != true && o['status'] == 'published') _trackView(id);
        final app = o['my_application'] is Map ? Map<String, dynamic>.from(o['my_application'] as Map) : null;
        final wa = '${o['apply_whatsapp']}';
        final deadline = DateTime.tryParse('${o['deadline']}');
        final closed = o['status'] != 'published' || (deadline != null && oppDeadlineLabel(deadline, DateTime.now()) == 'Clôturée');
        return ListView(padding: const EdgeInsets.only(bottom: 90), children: [
          OpportunityCard(o: o),
          if (o['status'] == 'pending') _box(Text('Cette offre est en attente de validation par l’équipe.', style: mst(13, w: FontWeight.w700, c: const Color(0xFFB45309)))),
          if (o['status'] == 'rejected') _box(Text('Offre refusée${'${o['review_note'] ?? ''}'.isEmpty ? '' : ' : ${o['review_note']}'}', style: mst(13, w: FontWeight.w700, c: kRed))),
          if ('${o['description']}'.isNotEmpty) _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Description', style: mst(14, w: FontWeight.w800)), const SizedBox(height: 6), Text('${o['description']}', style: mst(13.5).copyWith(height: 1.5))])),
          _list('Missions', o['missions'] as List? ?? const []),
          if ('${o['profile_wanted']}'.isNotEmpty || '${o['department_target']}'.isNotEmpty || '${o['level']}'.isNotEmpty)
            _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Profil recherché', style: mst(14, w: FontWeight.w800)),
              if ('${o['department_target']}'.isNotEmpty) Text('Filière : ${o['department_target']}', style: mst(13)),
              if ('${o['level']}'.isNotEmpty) Text('Niveau : ${o['level']}', style: mst(13)),
              if ('${o['profile_wanted']}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${o['profile_wanted']}', style: mst(13).copyWith(height: 1.4))),
            ])),
          _list('Ce que vous gagnez', o['gains'] as List? ?? const []),
          if (app != null)
            _box(Text('Votre candidature : ${const {'sent': 'envoyée', 'viewed': 'consultée', 'shortlisted': 'retenue', 'rejected': 'non retenue', 'hired': 'recrutement confirmé'}['${app['status']}'] ?? '${app['status']}'}', style: mst(13.5, w: FontWeight.w800, c: app['status'] == 'rejected' ? kRed : kGreen)))
          else if (!closed && o['mine'] != true)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Column(children: [
                if (o['apply_in_app'] == true) mButton('Postuler dans l’application', () => _apply(context, ref, o), width: double.infinity),
                if (wa.isNotEmpty) ...[const SizedBox(height: 8), mButton('Postuler sur WhatsApp', () => _whatsapp(context, o), dark: o['apply_in_app'] != true, icon: Icons.chat_outlined, width: double.infinity)],
              ]),
            )
          else if (closed)
            _box(Text('Les candidatures sont closes.', style: mst(13.5, w: FontWeight.w700, c: kRed))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(children: [
              Expanded(
                child: mButton(o['saved'] == true ? 'Enregistrée' : 'Enregistrer', () async {
                  if (!await requireLogin(context, ref, 'enregistrer une offre') || !context.mounted) return;
                  if (await _call(context, 'opp_save_toggle', {'p_id': id})) ref.invalidate(oppDetailProvider(id));
                }, dark: false, icon: o['saved'] == true ? Icons.bookmark : Icons.bookmark_border),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: mButton(o['reminder'] == true ? 'Rappel activé' : 'Me rappeler', deadline == null ? null : () async {
                  if (!await requireLogin(context, ref, 'activer un rappel') || !context.mounted) return;
                  if (await _call(context, 'opp_remind', {'p_id': id, 'p_on': o['reminder'] != true}, ok: o['reminder'] == true ? 'Rappel retiré.' : 'Rappel activé : vous serez prévenu 2 jours avant la fin.')) ref.invalidate(oppDetailProvider(id));
                }, dark: false, icon: Icons.notifications_none_outlined),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: mButton('Partager (WhatsApp, statut, lien)', () => shareText(context, 'Opportunité : ${o['title']} chez ${o['org']}. $siteUrl/#/opportunites/$id', subject: '${o['title']}'), dark: false, icon: Icons.share_outlined, width: double.infinity),
          ),
          if ('${o['about_org']}'.isNotEmpty || (o['other_offers'] as List? ?? const []).isNotEmpty)
            _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('À propos de ${o['org']}', style: mst(14, w: FontWeight.w800)),
              if ('${o['about_org']}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${o['about_org']}', style: mst(13).copyWith(height: 1.4))),
              if ((o['other_offers'] as List? ?? const []).isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Anciennes et autres offres', style: mst(12.5, w: FontWeight.w700, c: kGrey)),
                for (final x in (o['other_offers'] as List)) GestureDetector(onTap: () => context.push('/opportunites/${(x as Map)['id']}'), child: Padding(padding: const EdgeInsets.only(top: 4), child: Text('${x['title']}', style: mst(13, w: FontWeight.w600, c: kViolet)))),
              ],
            ])),
        ]);
      }),
    );
  }
}

// ------------------------------------------------------------------ mes candidatures, favoris, mes offres

class MyOpportunitiesScreen extends ConsumerWidget {
  const MyOpportunitiesScreen({super.key});

  static const _status = {'sent': 'Envoyée', 'viewed': 'Consultée', 'shortlisted': 'Retenue', 'rejected': 'Non retenue', 'hired': 'Recrutement confirmé'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posted = ref.watch(oppMyPostedProvider).value ?? const <Map<String, dynamic>>[];
    final staff = (ref.watch(authProvider).current?.staff ?? '').isNotEmpty;
    return MarchePage(
      title: 'Mes opportunités',
      child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
        mSectionTitle('Mes candidatures'),
        mAsync<List<Map<String, dynamic>>>(
          ref.watch(oppMyApplicationsProvider),
          (l) => l.isEmpty
              ? Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('Vous n’avez pas encore postulé.', style: mst(13, c: kGrey)))
              : Column(children: [
                  for (final a in l)
                    GestureDetector(
                      onTap: () => context.push('/opportunites/${a['opportunity_id']}'),
                      child: _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${a['title']}', style: mst(14, w: FontWeight.w800)),
                        Text('${a['org']} · ${_status['${a['status']}'] ?? a['status']}', style: mst(12.5, c: a['status'] == 'rejected' ? kRed : (a['status'] == 'hired' ? kGreen : kGrey))),
                        if (a['status'] == 'hired' && a['published'] != true) Padding(padding: const EdgeInsets.only(top: 8), child: mButton('Partager mon recrutement', () async {
                          if (await _call(context, 'opp_hire_publish', {'p_application': a['id']}, ok: 'Merci : votre réussite apparaît dans « Ils ont été recrutés ».')) ref.invalidate(oppMyApplicationsProvider);
                        }, dark: false)),
                      ])),
                    ),
                ]),
        ),
        mSectionTitle('Mes favoris'),
        mAsync<List<Map<String, dynamic>>>(
          ref.watch(oppsProvider(const OppQuery(section: 'saved'))),
          (l) => l.isEmpty ? Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('Aucune offre enregistrée.', style: mst(13, c: kGrey))) : Column(children: [for (final o in l) OpportunityCard(o: o, onTap: () => context.push('/opportunites/${o['id']}'))]),
        ),
        if (posted.isNotEmpty) ...[
          mSectionTitle(staff ? 'Offres publiées et à valider' : 'Mes offres'),
          for (final o in posted) _PostedCard(o: o),
        ],
      ]),
    );
  }
}

class _PostedCard extends ConsumerWidget {
  const _PostedCard({required this.o});
  final Map<String, dynamic> o;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = o['status'] == 'pending';
    return _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${o['org']}${'${o['poster'] ?? ''}'.isEmpty ? '' : ' · ${o['poster']}'}', style: mst(12, w: FontWeight.w700, c: kGrey)),
      Text('${o['title']}', style: mst(14.5, w: FontWeight.w800)),
      Text('${const {'pending': 'En attente de validation', 'published': 'Publiée', 'rejected': 'Refusée', 'closed': 'Clôturée'}['${o['status']}']} · ${mInt(o['applications'])} candidature${mInt(o['applications']) > 1 ? 's' : ''}', style: mst(12.5, c: pending ? const Color(0xFFB45309) : kGrey)),
      Builder(builder: (context) {
        final st = ref.watch(oppStatsProvider).asData?.value['${o['id']}'];
        if (st == null || pending) return const SizedBox.shrink();
        Widget cell(String v, String l) => Expanded(child: Column(children: [Text(v, style: mst(16, w: FontWeight.w800)), Text(l, textAlign: TextAlign.center, style: mst(10.5, c: kGrey))]));
        String pct(Object? x) => x == null ? '—' : '${(x as num).round()} %';
        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFFF7F4FA), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            cell('${mInt(st['views'])}', 'Vues'),
            cell('${mInt(st['saves'])}', 'Favoris'),
            cell('${mInt(st['applications'])}', 'Candidatures'),
            cell(pct(st['response_rate']), 'Réponses'),
            cell('${mInt(st['hired'])}', 'Recrutés'),
          ]),
        );
      }),
      const SizedBox(height: 8),
      if (pending && (ref.watch(authProvider).current?.staff ?? '').isNotEmpty)
        Row(children: [
          Expanded(child: mButton('Refuser', () async {
            if (await _call(context, 'opp_decide', {'p_id': o['id'], 'p_approve': false, 'p_note': 'Offre non conforme aux règles de publication'}, ok: 'Offre refusée.')) ref.invalidate(oppMyPostedProvider);
          }, dark: false)),
          const SizedBox(width: 8),
          Expanded(child: mButton('Publier', () async {
            if (await _call(context, 'opp_decide', {'p_id': o['id'], 'p_approve': true, 'p_verified': false}, ok: 'Offre publiée.')) ref.invalidate(oppMyPostedProvider);
          })),
          const SizedBox(width: 8),
          Expanded(child: mButton('Vérifiée', () async {
            if (await _call(context, 'opp_decide', {'p_id': o['id'], 'p_approve': true, 'p_verified': true}, ok: 'Offre publiée avec le badge Vérifié.')) ref.invalidate(oppMyPostedProvider);
          })),
        ])
      else
        Row(children: [
          Expanded(child: mButton('Voir', () => context.push('/opportunites/${o['id']}'), dark: false)),
          if (o['status'] == 'published') ...[
            const SizedBox(width: 8),
            Expanded(child: mButton('Candidatures', () => context.push('/opportunites/${o['id']}/candidatures'), dark: false)),
            const SizedBox(width: 8),
            Expanded(child: mButton('Clôturer', () async {
              if (await _call(context, 'opp_close', {'p_id': o['id']}, ok: 'Offre clôturée.')) ref.invalidate(oppMyPostedProvider);
            }, dark: false)),
          ],
        ]),
    ]));
  }
}

/// Candidatures reçues sur une offre : lettre, filière, lien du CV, et décision (retenir, refuser, recruter).
class OpportunityApplicationsScreen extends ConsumerStatefulWidget {
  const OpportunityApplicationsScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<OpportunityApplicationsScreen> createState() => _AppsState();
}

/// Pastille « Correspondance 85 % » avec le détail (compétences, filière, disponibilité) : une aide au tri, jamais une décision.
Widget matchBadge(Object? raw) {
  if (raw is! Map) return const SizedBox.shrink();
  final m = Map<String, dynamic>.from(raw);
  final score = mInt(m['score']);
  final color = score >= 75 ? kGreen : (score >= 50 ? kViolet : kGrey);
  final wanted = mInt(m['skills_wanted']);
  final detail = [
    if (wanted > 0) 'Compétences ${mInt(m['skills_found'])}/$wanted',
    if (mInt(m['department']) >= 25) 'Filière ✓',
    if (mInt(m['availability']) >= 15) 'Disponible',
  ].join(' · ');
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(100)), child: Text('Correspondance $score %', style: mst(11.5, w: FontWeight.w800, c: color))),
      if (detail.isNotEmpty) Flexible(child: Padding(padding: const EdgeInsets.only(left: 8), child: Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: mst(11, c: kGrey)))),
    ]),
  );
}

class _AppsState extends ConsumerState<OpportunityApplicationsScreen> {
  List<Map<String, dynamic>>? _apps;
  List<Map<String, dynamic>> _suggested = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await marcheCall('opp_applications_for', {'p_id': widget.id});
    if (!mounted) return;
    final list = r.error != null ? <Map<String, dynamic>>[] : [for (final x in (r.data as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
    // les candidats qui correspondent le mieux d'abord (à égalité : les plus récents)
    list.sort((a, b) => mInt((b['match'] as Map?)?['score']).compareTo(mInt((a['match'] as Map?)?['score'])));
    setState(() => _apps = list);
    final sg = await marcheCall('opp_suggested_students', {'p_id': widget.id, 'p_limit': 8});
    if (!mounted) return;
    setState(() => _suggested = sg.error != null ? const [] : [for (final x in (sg.data as List? ?? const [])) Map<String, dynamic>.from(x as Map)]);
  }

  Future<void> _decide(Map<String, dynamic> a, String status) async {
    if (await _call(context, 'opp_application_decide', {'p_id': a['id'], 'p_status': status}, ok: 'Décision enregistrée : le candidat est prévenu.')) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final apps = _apps;
    return MarchePage(
      title: 'Candidatures',
      child: apps == null
          ? const Center(child: CircularProgressIndicator())
          : (apps.isEmpty && _suggested.isEmpty)
              ? mNote('Aucune candidature pour le moment.')
              : ListView(padding: const EdgeInsets.only(bottom: 90), children: [
                  if (apps.isEmpty) mNote('Aucune candidature pour le moment.'),
                  for (final a in apps)
                    _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${a['name']}${'${a['department'] ?? ''}'.isEmpty ? '' : ' · ${a['department']}'}', style: mst(14, w: FontWeight.w800)),
                      Text('Statut : ${MyOpportunitiesScreen._status['${a['status']}'] ?? a['status']}', style: mst(12, c: kGrey)),
                      matchBadge(a['match']),
                      const SizedBox(height: 6),
                      Text('${a['message']}', style: mst(13).copyWith(height: 1.45)),
                      if ('${a['cv_link']}'.isNotEmpty) GestureDetector(onTap: () => openUrl(context, '${a['cv_link']}'), child: Padding(padding: const EdgeInsets.only(top: 6), child: Text('Voir le CV', style: mst(12.5, w: FontWeight.w700, c: kViolet)))),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: mButton('Refuser', () => _decide(a, 'rejected'), dark: false)),
                        const SizedBox(width: 8),
                        Expanded(child: mButton('Retenir', () => _decide(a, 'shortlisted'), dark: false)),
                        const SizedBox(width: 8),
                        Expanded(child: mButton('Recruter', () => _decide(a, 'hired'))),
                      ]),
                    ])),
                  if (_suggested.isNotEmpty) ...[
                    mSectionTitle('Étudiants qui correspondent'),
                    for (final st in _suggested)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => context.push('/etudiant/${st['id']}'),
                        child: _box(Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${st['name']}${'${st['department'] ?? ''}'.isEmpty ? '' : ' · ${st['department']}'}', style: mst(14, w: FontWeight.w800)),
                              matchBadge(st['match']),
                            ]),
                          ),
                          const Icon(Icons.chevron_right, color: kGrey),
                        ])),
                      ),
                  ],
                ]),
    );
  }
}

// ------------------------------------------------------------------ publier une offre

class OpportunityEditScreen extends ConsumerStatefulWidget {
  const OpportunityEditScreen({super.key});

  @override
  ConsumerState<OpportunityEditScreen> createState() => _EditState();
}

class _EditState extends ConsumerState<OpportunityEditScreen> {
  final _c = {for (final k in ['org', 'title', 'contract', 'location', 'duration', 'amount', 'payNote', 'skills', 'description', 'missions', 'profile', 'department', 'level', 'gains', 'whatsapp', 'about']) k: TextEditingController()};
  String _kind = 'stage', _mode = 'onsite', _pay = 'paid';
  bool _inApp = true, _iut = false, _busy = false;
  DateTime? _deadline;
  PlatformFile? _media;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _split(String s, Pattern sep) => [for (final x in s.split(sep)) if (x.trim().isNotEmpty) x.trim()];

  Future<void> _pickMedia() async {
    final p = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'mp4', 'mov']);
    if (p.isEmpty || !mounted) return;
    setState(() => _media = p.first);
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    ({String path, String kind, String mime})? up;
    if (_media != null) {
      up = await uploadPostMedia(context, _media!);
      if (!mounted) return;
      if (up == null) {
        setState(() => _busy = false);
        return;
      }
    }
    final r = await marcheCall('opp_save', {
      'p_org': _c['org']!.text,
      'p_kind': _kind,
      'p_contract': _c['contract']!.text,
      'p_title': _c['title']!.text,
      'p_location': _c['location']!.text,
      'p_mode': _mode,
      'p_duration': _c['duration']!.text,
      'p_pay_kind': _pay,
      'p_pay_amount': _pay == 'paid' ? int.tryParse(_c['amount']!.text.replaceAll(RegExp(r'[^0-9]'), '')) : null,
      'p_pay_note': _c['payNote']!.text,
      'p_deadline': _deadline?.toIso8601String().substring(0, 10),
      'p_skills': _split(_c['skills']!.text, ','),
      'p_description': _c['description']!.text,
      'p_missions': _split(_c['missions']!.text, '\n'),
      'p_profile': _c['profile']!.text,
      'p_department': _c['department']!.text,
      'p_level': _c['level']!.text,
      'p_gains': _split(_c['gains']!.text, ','),
      'p_whatsapp': _c['whatsapp']!.text,
      'p_in_app': _inApp,
      'p_about': _c['about']!.text,
      'p_iut_only': _iut,
    });
    if (!mounted) return;
    if (r.error == null && up != null) {
      final m = await marcheCall('opp_media_set', {'p_id': '${r.data}', 'p_path': up.path, 'p_kind': up.kind});
      if (!mounted) return;
      if (m.error != null) gToast(context, 'Offre envoyée, mais le média n’a pas pu être ajouté : ${Backend.userMessage('${m.error}')}');
    } else if (r.error != null && up != null) {
      try {
        await Supabase.instance.client.storage.from('post-media').remove([up.path]);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _busy = false);
    gToast(context, r.error != null ? Backend.userMessage('${r.error}') : 'Offre envoyée : elle sera visible après validation par l’équipe.');
    if (r.error == null) {
      ref.invalidate(oppMyPostedProvider);
      context.pop();
    }
  }

  InputDecoration _deco(String l, {String? hint}) => InputDecoration(labelText: l, hintText: hint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)), filled: true, fillColor: Colors.white);

  Widget _f(String k, String label, {String? hint, int lines = 1, bool number = false}) => Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: _c[k], maxLines: lines, keyboardType: number ? TextInputType.number : null, decoration: _deco(label, hint: hint)));

  @override
  Widget build(BuildContext context) {
    return MarchePage(
      title: 'Publier une offre',
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 90), children: [
        Text('Réservé aux entreprises, ONG, startups et à l’équipe de l’IUT. Votre offre est relue avant d’être publiée.', style: mst(13, c: kGrey).copyWith(height: 1.5)),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Expanded(child: mButton(_media == null ? 'Ajouter une image ou une vidéo' : _media!.name, _busy ? null : _pickMedia, dark: false, icon: Icons.add_photo_alternate_outlined)),
            if (_media != null) IconButton(tooltip: 'Retirer', onPressed: () => setState(() => _media = null), icon: const Icon(Icons.close, size: 18)),
          ]),
        ),
        _f('org', 'Organisation', hint: 'Orange Cameroun, ONG, startup…'),
        MDropdown(label: 'Type', value: _kind, items: {for (final e in oppKinds.entries) if (e.key.isNotEmpty) e.key: e.value}, onChanged: (v) => setState(() => _kind = v)),
        const SizedBox(height: 10),
        _f('contract', 'Précision (facultatif)', hint: 'Académique, vacances, CDD, CDI, temps partiel, job étudiant'),
        _f('title', 'Poste ou mission', hint: 'Stagiaire développeur Flutter'),
        _f('location', 'Lieu', hint: 'Douala, Yaoundé…'),
        MDropdown(label: 'Mode', value: _mode, items: {for (final e in oppModes.entries) if (e.key.isNotEmpty) e.key: e.value}, onChanged: (v) => setState(() => _mode = v)),
        const SizedBox(height: 10),
        _f('duration', 'Durée', hint: '2 mois, 6 mois, mission de 2 semaines'),
        MDropdown(label: 'Rémunération', value: _pay, items: const {'paid': 'Rémunéré', 'unpaid': 'Non rémunéré', 'negotiable': 'À négocier'}, onChanged: (v) => setState(() => _pay = v)),
        const SizedBox(height: 10),
        if (_pay == 'paid') _f('amount', 'Montant par mois (FCFA)', hint: '50000', number: true),
        _f('payNote', 'Précision sur la rémunération', hint: 'Ex. attestation de stage'),
        mButton(_deadline == null ? 'Choisir la date limite' : 'Date limite : ${_deadline!.day}/${_deadline!.month}/${_deadline!.year}', () async {
          final d = await pickDate(context: context, initialDate: DateTime.now().add(const Duration(days: 14)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 730)));
          if (d != null) setState(() => _deadline = d);
        }, dark: false, width: double.infinity),
        const SizedBox(height: 10),
        MultiPickField(label: 'Compétences demandées', options: commonSkills, value: _c['skills']!.text, emptyText: 'Choisir dans la liste', onChanged: (v) => setState(() => _c['skills']!.text = v)),
        _f('description', 'Description', lines: 5),
        _f('missions', 'Missions (une par ligne)', lines: 4),
        _f('profile', 'Profil recherché', lines: 3),
        MultiPickField(label: 'Filières visées', options: studyFields, value: _c['department']!.text, emptyText: 'Toutes les filières', onChanged: (v) => setState(() => _c['department']!.text = v)),
        _f('level', 'Niveau (facultatif)', hint: 'Licence 2'),
        _f('gains', 'Ce que l’étudiant gagne', hint: 'Séparés par des virgules : Attestation de stage, Expérience, Possibilité d’embauche'),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: Text('Postuler dans l’application', style: mst(13.5)), value: _inApp, onChanged: (v) => setState(() => _inApp = v)),
        _f('whatsapp', 'Numéro WhatsApp pour postuler (facultatif)', hint: '+237 6XX XX XX XX'),
        _f('about', 'À propos de l’organisation', lines: 3),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: Text('Réservé aux étudiants de l’IUT de Douala', style: mst(13.5)), value: _iut, onChanged: (v) => setState(() => _iut = v)),
        mButton(_busy ? 'Envoi…' : 'Envoyer pour validation', _busy ? null : _send, width: double.infinity),
      ]),
    );
  }
}
