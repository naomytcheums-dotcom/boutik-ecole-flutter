import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../gen.dart' show gAlert, gToast;
import '../i18n.dart' show Text;
import 'auth.dart';
import 'backend.dart';
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';
import 'form_options.dart';
import 'opportunites_screens.dart' show oppDeadlineLabel, oppModes;
import 'share.dart' show openUrl, shareText, siteUrl;
import 'tara_payment.dart';
import 'access.dart' show roleKey;

/// Concours, bourses, hackathons et appels à projets : fiche complète pour décider en 10 secondes, filtres, rappel 3 jours avant la date limite,
/// partage WhatsApp et section « Ils ont gagné ». Tout vient du serveur (migration 20261114001400) ; aucune annonce n'est inventée.

const annKinds = {
  '': 'Tous les types',
  'contest': 'Concours',
  'scholarship': 'Bourse',
  'hackathon': 'Hackathon',
  'call': 'Appel à projets',
  'internship': 'Stage',
  'job': 'Emploi',
  'training': 'Formation gratuite',
};
const annDomains = {
  '': 'Tous les domaines',
  'tech': 'Tech',
  'entrepreneurship': 'Entrepreneuriat',
  'design': 'Design',
  'agriculture': 'Agriculture',
  'health': 'Santé',
  'environment': 'Environnement',
  'scholarship': 'Bourse d’étude',
  'other': 'Autre',
};
const annOrganizers = {'university': 'Université', 'company': 'Entreprise', 'ngo': 'ONG', 'government': 'Gouvernement', 'other': 'Autre'};
const annCosts = {'': 'Gratuit ou payant', 'free': 'Gratuit', 'paid': 'Payant'};
const annWithin = {'': 'Toute date limite', '7': 'Dans 7 jours', '30': 'Dans 30 jours'};

/// Badges d'une annonce : Vérifié, Nouveau (moins de 7 jours), Bientôt expiré (7 jours ou moins), Populaire.
List<String> annBadges(Map<String, dynamic> a, DateTime now) {
  final created = DateTime.tryParse('${a['created_at']}');
  final deadline = DateTime.tryParse('${a['deadline']}');
  final today = DateTime(now.year, now.month, now.day);
  return [
    if (a['verified'] == true) 'Vérifié',
    if (created != null && now.difference(created).inDays < 7) 'Nouveau',
    if (deadline != null && !DateTime(deadline.year, deadline.month, deadline.day).isBefore(today) && DateTime(deadline.year, deadline.month, deadline.day).difference(today).inDays <= 7) 'Bientôt expiré',
    if (a['popular'] == true) 'Populaire',
  ];
}

/// « Gratuit » ou « Payant : 5 000 FCFA ».
String annCostLabel(Map<String, dynamic> a) => a['free'] == false ? (a['cost_amount'] == null ? 'Payant' : 'Payant : ${a['cost_amount']} ${a['cost_currency']}') : 'Gratuit';

/// Qui peut postuler : niveau, âge, filière, pays éligible, et si c'est réservé à l'IUT ou ouvert à tous.
String annEligibility(Map<String, dynamic> a) {
  final parts = [for (final k in ['eligible_level', 'eligible_age', 'eligible_department', 'eligible_country']) if ('${a[k] ?? ''}'.trim().isNotEmpty) '${a[k]}'.trim()];
  parts.add(a['iut_only'] == true ? 'Réservé aux étudiants de l’IUT' : 'Ouvert à tous');
  return parts.join(' · ');
}

class AnnQuery {
  const AnnQuery({this.kind = '', this.domain = '', this.cost = '', this.place = '', this.within = '', this.country = '', this.q = '', this.saved = false});
  final String kind, domain, cost, place, within, country, q;
  final bool saved;
  AnnQuery copy({String? kind, String? domain, String? cost, String? place, String? within, String? country, String? q, bool? saved}) =>
      AnnQuery(kind: kind ?? this.kind, domain: domain ?? this.domain, cost: cost ?? this.cost, place: place ?? this.place, within: within ?? this.within, country: country ?? this.country, q: q ?? this.q, saved: saved ?? this.saved);
  Map<String, dynamic> get params => {
        if (kind.isNotEmpty) 'p_kind': kind,
        if (domain.isNotEmpty) 'p_domain': domain,
        if (cost.isNotEmpty) 'p_free': cost,
        if (place.isNotEmpty) 'p_place': place,
        if (within.isNotEmpty) 'p_within_days': int.tryParse(within),
        if (country.trim().isNotEmpty) 'p_country': country.trim(),
        if (q.trim().isNotEmpty) 'p_q': q.trim(),
        if (saved) 'p_saved': true,
        'p_limit': 40,
      };
  @override
  bool operator ==(Object o) => o is AnnQuery && o.kind == kind && o.domain == domain && o.cost == cost && o.place == place && o.within == within && o.country == country && o.q == q && o.saved == saved;
  @override
  int get hashCode => Object.hash(kind, domain, cost, place, within, country, q, saved);
}

Future<List<Map<String, dynamic>>> _list(String fn, Map<String, dynamic> p) async {
  final r = await marcheCall(fn, p);
  if (r.error != null) throw MarcheException(r.error);
  return [for (final x in (r.data as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
}

final annsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, AnnQuery>((ref, q) {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  return _list('anns_list', q.params);
});
final annWinsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => _list('ann_wins_list', const {'p_limit': 10}));
final annPostedProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => _list('ann_my_posted', const {}));
final annDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final r = await marcheCall('ann_detail', {'p_id': id});
  if (r.error != null) throw MarcheException(r.error);
  return Map<String, dynamic>.from(r.data as Map);
});

Widget _box(Widget child) => Container(margin: const EdgeInsets.fromLTRB(16, 0, 16, 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: kLine)), child: child);

Widget _pill(String s, Color c) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)), child: Text(s, style: mst(10.5, w: FontWeight.w700, c: c)));

Color _badgeColor(String b) => switch (b) {
      'Vérifié' => kViolet,
      'Nouveau' => kGreen,
      'Bientôt expiré' => kRed,
      _ => const Color(0xFF8F5400),
    };

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

/// Carte d'une annonce : de quoi décider en 10 secondes (date limite, gain, qui peut postuler, coût).
class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({super.key, required this.a, this.onTap, this.onSave, this.now});
  final Map<String, dynamic> a;
  final VoidCallback? onTap, onSave;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final t = now ?? DateTime.now();
    final deadline = DateTime.tryParse('${a['deadline']}');
    final where = [if ('${a['country']}'.isNotEmpty) '${a['country']}', if ('${a['place']}'.isNotEmpty) '${a['place']}', oppModes['${a['place_kind']}'] ?? ''].where((e) => e.isNotEmpty).join(' · ');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${a['organizer']} · ${annOrganizers['${a['organizer_kind']}'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: mst(12, w: FontWeight.w700, c: kGrey))),
          if (onSave != null) GestureDetector(behavior: HitTestBehavior.opaque, onTap: onSave, child: Padding(padding: const EdgeInsets.all(4), child: Icon(a['saved'] == true ? Icons.bookmark : Icons.bookmark_border, color: a['saved'] == true ? kViolet : kGrey))),
        ]),
        const SizedBox(height: 4),
        Text('${a['title']}', style: mst(15, w: FontWeight.w800)),
        const SizedBox(height: 2),
        Text([annKinds['${a['kind']}'] ?? '', annDomains['${a['domain']}'] ?? '', where].where((e) => e.isNotEmpty).join(' · '), style: mst(12, c: kGrey)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 4, children: [
          _pill(oppDeadlineLabel(deadline, t), deadline != null && deadline.difference(DateTime(t.year, t.month, t.day)).inDays <= 3 ? kRed : kViolet),
          _pill(annCostLabel(a), a['free'] == false ? const Color(0xFF8F5400) : kGreen),
          if (mInt(a['prize_amount']) > 0 && ['held', 'awarded'].contains('${a['prize_status']}')) _pill('Récompense garantie ${mFcfa(mInt(a['prize_amount']))}', kGreen),
          for (final b in annBadges(a, t)) _pill(b, _badgeColor(b)),
        ]),
        if ('${a['reward']}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Gain : ${a['reward']}', style: mst(13, w: FontWeight.w700))),
        Padding(padding: const EdgeInsets.only(top: 4), child: Text('Qui peut postuler : ${annEligibility(a)}', style: mst(12, c: kGrey).copyWith(height: 1.35))),
      ])),
    );
  }
}

// ------------------------------------------------------------------ liste

class ContestAnnouncementsScreen extends ConsumerStatefulWidget {
  const ContestAnnouncementsScreen({super.key});

  @override
  ConsumerState<ContestAnnouncementsScreen> createState() => _AnnsState();
}

class _AnnsState extends ConsumerState<ContestAnnouncementsScreen> {
  final _q = TextEditingController(), _country = TextEditingController();
  AnnQuery _query = const AnnQuery();

  @override
  void dispose() {
    _q.dispose();
    _country.dispose();
    super.dispose();
  }

  void _set(AnnQuery q) => setState(() => _query = q);

  Future<void> _save(Map<String, dynamic> a) async {
    if (!await requireLogin(context, ref, 'enregistrer un concours') || !mounted) return;
    if (await _call(context, 'ann_save_toggle', {'p_id': a['id']})) ref.invalidate(annsProvider);
  }

  Future<void> _won() async {
    if (!await requireLogin(context, ref, 'partager une victoire') || !mounted) return;
    final title = TextEditingController(), prize = TextEditingController(), year = TextEditingController(text: '${DateTime.now().year}'), proof = TextEditingController();
    InputDecoration deco(String l, {String? hint}) => InputDecoration(labelText: l, hintText: hint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)));
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(c).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('J’ai gagné un concours', style: mst(18, w: FontWeight.w800)),
            Text('Votre victoire est publiée après vérification de la preuve par l’équipe.', style: mst(12.5, c: kGrey)),
            const SizedBox(height: 12),
            TextField(controller: title, decoration: deco('Concours gagné', hint: 'Hackathon Orange Digital Center')),
            const SizedBox(height: 10),
            TextField(controller: prize, decoration: deco('Prix', hint: '1er prix, bourse…')),
            const SizedBox(height: 10),
            TextField(controller: year, keyboardType: TextInputType.number, decoration: deco('Année')),
            const SizedBox(height: 10),
            TextField(controller: proof, keyboardType: TextInputType.url, decoration: deco('Lien de preuve', hint: 'Article, photo ou page officielle : https://…')),
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
    if (ok != true || !mounted) return;
    await _call(context, 'ann_win_submit', {'p_title': title.text, 'p_prize': prize.text, 'p_year': int.tryParse(year.text), 'p_proof': proof.text}, ok: 'Merci ! Votre victoire sera publiée après vérification.');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(annsProvider(_query));
    return MarchePage(
      title: 'Concours et bourses',
      actions: [IconButton(tooltip: 'Mes annonces', onPressed: () => context.push('/concours/mes'), icon: const Icon(Icons.inbox_outlined))],
      child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(controller: _q, textInputAction: TextInputAction.search, onSubmitted: (v) => _set(_query.copy(q: v)), decoration: InputDecoration(hintText: 'Bourse, hackathon, appel à projets…', prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 12))),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(children: [
            Row(children: [
              Expanded(child: MDropdown(label: 'Type', value: _query.kind, items: annKinds, onChanged: (v) => _set(_query.copy(kind: v)))),
              const SizedBox(width: 10),
              Expanded(child: MDropdown(label: 'Domaine', value: _query.domain, items: annDomains, onChanged: (v) => _set(_query.copy(domain: v)))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: MDropdown(label: 'Coût', value: _query.cost, items: annCosts, onChanged: (v) => _set(_query.copy(cost: v)))),
              const SizedBox(width: 10),
              Expanded(child: MDropdown(label: 'Lieu', value: _query.place, items: oppModes, onChanged: (v) => _set(_query.copy(place: v)))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: MDropdown(label: 'Date limite', value: _query.within, items: annWithin, onChanged: (v) => _set(_query.copy(within: v)))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _country, onSubmitted: (v) => _set(_query.copy(country: v)), decoration: InputDecoration(hintText: 'Pays (Cameroun, Canada…)', isDense: true, filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: kLine)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)))),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Row(children: [
            Expanded(child: mButton(_query.saved ? 'Toutes les annonces' : 'Mes enregistrés', () => _set(_query.copy(saved: !_query.saved)), dark: false, icon: Icons.bookmark_border)),
            const SizedBox(width: 10),
            Expanded(child: mButton('Publier', () => context.push('/concours/publier'), dark: false, icon: Icons.add)),
          ]),
        ),
        mSectionTitle(_query.saved ? 'Mes enregistrés' : 'À venir'),
        mAsync<List<Map<String, dynamic>>>(
          async,
          (l) => l.isEmpty
              ? mNote(_query.saved ? 'Aucune annonce enregistrée.' : 'Aucune annonce ne correspond pour le moment.\nBourses, hackathons et appels à projets apparaîtront ici dès leur publication.')
              : Column(children: [for (final a in l) AnnouncementCard(a: a, onTap: () => context.push('/concours/${a['id']}'), onSave: () => _save(a))]),
        ),
        mSectionTitle('Ils ont gagné', trailing: GestureDetector(onTap: _won, child: Text('J’ai gagné', style: mst(12.5, w: FontWeight.w700, c: kViolet)))),
        mAsync<List<Map<String, dynamic>>>(
          ref.watch(annWinsProvider),
          (l) => l.isEmpty
              ? Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('Les étudiants de l’IUT qui ont gagné un concours apparaîtront ici, avec leur preuve.', style: mst(13, c: kGrey)))
              : Column(children: [
                  for (final w in l)
                    _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${w['name']}${'${w['department'] ?? ''}'.isEmpty ? '' : ', ${w['department']}'}', style: mst(13.5, w: FontWeight.w800)),
                      Text('${w['title']}${'${w['prize']}'.isEmpty ? '' : ' · ${w['prize']}'}${w['year'] == null ? '' : ' · ${w['year']}'}', style: mst(13, c: kGrey)),
                      GestureDetector(onTap: () => openUrl(context, '${w['proof_url']}'), child: Padding(padding: const EdgeInsets.only(top: 4), child: Text('Voir la preuve', style: mst(12.5, w: FontWeight.w700, c: kViolet)))),
                    ])),
                ]),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ fiche complète

class AnnouncementDetailScreen extends ConsumerWidget {
  const AnnouncementDetailScreen({super.key, required this.id});
  final String id;

  String _date(Object? v) {
    final d = DateTime.tryParse('$v');
    return d == null ? '' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Widget _list(String title, List items, {bool numbered = false}) => items.isEmpty
      ? const SizedBox.shrink()
      : _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: mst(14, w: FontWeight.w800)),
          const SizedBox(height: 6),
          for (var i = 0; i < items.length; i++) Padding(padding: const EdgeInsets.only(top: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(numbered ? 'Étape ${i + 1} · ' : '• ', style: mst(13, w: FontWeight.w800)), Expanded(child: Text('${items[i]}', style: mst(13).copyWith(height: 1.4)))])),
        ]));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MarchePage(
      title: 'Annonce',
      child: mAsync<Map<String, dynamic>>(ref.watch(annDetailProvider(id)), (a) {
        final link = '$siteUrl/#/concours/$id';
        final dates = [
          if (a['opens_on'] != null) 'Ouverture : ${_date(a['opens_on'])}',
          if (a['deadline'] != null) 'Date limite : ${_date(a['deadline'])}',
          if (a['results_on'] != null) 'Résultats : ${_date(a['results_on'])}',
          if (a['program_start'] != null) 'Début du programme : ${_date(a['program_start'])}',
        ];
        return ListView(padding: const EdgeInsets.only(bottom: 90), children: [
          AnnouncementCard(a: a),
          if (a['status'] == 'pending') _box(Text('Cette annonce est en attente de validation par l’équipe.', style: mst(13, w: FontWeight.w700, c: const Color(0xFFB45309)))),
          if (a['status'] == 'rejected') _box(Text('Annonce refusée${'${a['review_note'] ?? ''}'.isEmpty ? '' : ' : ${a['review_note']}'}', style: mst(13, w: FontWeight.w700, c: kRed))),
          if ('${a['description']}'.isNotEmpty) _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('De quoi s’agit-il ?', style: mst(14, w: FontWeight.w800)), const SizedBox(height: 6), Text('${a['description']}', style: mst(13.5).copyWith(height: 1.5)), if ('${a['why']}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Pourquoi : ${a['why']}', style: mst(13, c: kGrey).copyWith(height: 1.45)))])),
          _list('Conditions d’éligibilité', a['conditions'] as List? ?? const []),
          _list('Documents à fournir', a['documents'] as List? ?? const []),
          _list('Comment postuler', a['steps'] as List? ?? const [], numbered: true),
          _list('Critères de sélection', a['criteria'] as List? ?? const []),
          if (dates.isNotEmpty) _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Dates clés', style: mst(14, w: FontWeight.w800)), for (final d in dates) Padding(padding: const EdgeInsets.only(top: 4), child: Text(d, style: mst(13)))])),
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: mButton('Postuler sur le site officiel', () => openUrl(context, '${a['official_url']}'), width: double.infinity, icon: Icons.open_in_new)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              Expanded(
                child: mButton(a['saved'] == true ? 'Enregistré' : 'Enregistrer', () async {
                  if (!await requireLogin(context, ref, 'enregistrer un concours') || !context.mounted) return;
                  if (await _call(context, 'ann_save_toggle', {'p_id': id})) ref.invalidate(annDetailProvider(id));
                }, dark: false, icon: a['saved'] == true ? Icons.bookmark : Icons.bookmark_border),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: mButton(a['reminder'] == true ? 'Rappel activé' : 'Rappel 3 jours avant', a['deadline'] == null ? null : () async {
                  if (!await requireLogin(context, ref, 'activer un rappel') || !context.mounted) return;
                  if (await _call(context, 'ann_remind', {'p_id': id, 'p_on': a['reminder'] != true}, ok: a['reminder'] == true ? 'Rappel retiré.' : 'Rappel activé : vous serez prévenu 3 jours avant la date limite.')) ref.invalidate(annDetailProvider(id));
                }, dark: false, icon: Icons.notifications_none_outlined),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              Expanded(child: mButton('WhatsApp', () => openUrl(context, 'https://wa.me/?text=${Uri.encodeComponent('${a['title']} : $link')}'), dark: false, icon: Icons.chat_outlined)),
              const SizedBox(width: 8),
              Expanded(child: mButton('Partager', () => shareText(context, '${a['title']} (${a['organizer']}) : $link', subject: '${a['title']}'), dark: false, icon: Icons.share_outlined)),
              const SizedBox(width: 8),
              Expanded(
                child: mButton('Copier le lien', () async {
                  await Clipboard.setData(ClipboardData(text: link));
                  if (context.mounted) gToast(context, 'Lien copié');
                }, dark: false, icon: Icons.link),
              ),
            ]),
          ),
        ]);
      }),
    );
  }
}

// ------------------------------------------------------------------ mes annonces et validation par l'équipe

/// Paiement de la récompense : la somme est conservée par Boutik-École jusqu'à l'attribution au gagnant.
Future<void> payPrize(BuildContext context, WidgetRef ref, String annId, {String? title}) async {
  final r = await marcheCall('ann_prize_checkout', {'p_ann': annId});
  if (!context.mounted) return;
  if (r.error != null) {
    await gAlert(context, 'Paiement impossible', Backend.userMessage('${r.error}'));
    return;
  }
  final tx = Map<String, dynamic>.from(r.data as Map);
  await payWithTara(context, ref, reference: '${tx['reference']}', amount: (tx['amount'] as num).toInt(), label: 'la récompense « ${title ?? tx['title']} »');
  ref.invalidate(annPostedProvider);
}

Future<void> awardPrize(BuildContext context, WidgetRef ref, Map<String, dynamic> a) async {
  final email = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('Attribuer ${mFcfa(mInt(a['prize_amount']))}'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Adresse e-mail du compte étudiant gagnant. La somme lui est réservée en entier ; l’équipe Boutik-École la débloque sur son solde.', style: mst(12.5, c: kGrey)),
        const SizedBox(height: 10),
        TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail du gagnant', hintText: 'prenom.nom@…')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Annuler')), TextButton(onPressed: () => Navigator.pop(c, true), child: Text('Attribuer'))],
    ),
  );
  final mail = email.text.trim();
  email.dispose();
  if (ok != true || !context.mounted || mail.isEmpty) return;
  final r = await marcheCall('ann_prize_award', {'p_ann': a['id'], 'p_winner_email': mail});
  if (!context.mounted) return;
  if (r.error != null) {
    await gAlert(context, 'Attribution impossible', Backend.userMessage('${r.error}'));
    return;
  }
  await gAlert(context, 'Récompense attribuée', 'Le gagnant est prévenu. L’équipe Boutik-École débloque la somme sur son solde.');
  ref.invalidate(annPostedProvider);
}

/// État et actions de la récompense sous séquestre, sous une annonce.
List<Widget> prizeActions(BuildContext context, WidgetRef ref, Map<String, dynamic> a, {required bool staff, required bool admin}) {
  final amount = mInt(a['prize_amount']);
  final st = '${a['prize_status'] ?? 'none'}';
  if (amount <= 0 || st == 'none') return const [];
  final label = switch (st) {
    'awaiting' => 'Récompense ${mFcfa(amount)} : à payer pour pouvoir publier',
    'held' => 'Récompense ${mFcfa(amount)} : sous séquestre',
    'awarded' => 'Récompense ${mFcfa(amount)} : attribuée à ${a['prize_winner_name'] ?? 'un étudiant'}',
    'refunded' => 'Récompense ${mFcfa(amount)} : remboursée à l’organisateur',
    _ => '',
  };
  return [
    Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 6), child: Row(children: [const Icon(Icons.lock_outline, size: 16, color: kViolet), const SizedBox(width: 6), Expanded(child: Text(label, style: mst(12.5, w: FontWeight.w700, c: st == 'awaiting' ? const Color(0xFFB45309) : kInk)))])),
    if (!staff && st == 'awaiting') Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: mButton('Payer la récompense (${mFcfa(amount)})', () => payPrize(context, ref, '${a['id']}', title: '${a['title']}'), icon: Icons.phone_android)),
    if (!staff && st == 'held' && a['status'] == 'published') Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: mButton('Attribuer la récompense', () => awardPrize(context, ref, a), icon: Icons.emoji_events_outlined)),
    if (admin && st == 'held') Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: mButton('Rembourser l’organisateur (aucun gagnant)', () async {
      if (await _call(context, 'ann_prize_refund', {'p_ann': a['id'], 'p_note': 'Aucun gagnant désigné'}, ok: 'Récompense marquée remboursée : effectuez le remboursement Mobile Money.')) ref.invalidate(annPostedProvider);
    }, dark: false)),
  ];
}

class MyAnnouncementsScreen extends ConsumerWidget {
  const MyAnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = (ref.watch(authProvider).current?.staff ?? '').isNotEmpty;
    final admin = roleKey(ref.watch(authProvider).current) == 'admin';
    return MarchePage(
      title: staff ? 'Annonces à valider' : 'Mes annonces',
      child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
        mAsync<List<Map<String, dynamic>>>(
          ref.watch(annPostedProvider),
          (l) => l.isEmpty
              ? mNote('Aucune annonce pour le moment.')
              : Column(children: [
                  for (final a in l)
                    Column(children: [
                      AnnouncementCard(a: a, onTap: () => context.push('/concours/${a['id']}')),
                      ...prizeActions(context, ref, a, staff: staff, admin: admin),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: a['status'] == 'pending' && staff
                            ? Row(children: [
                                Expanded(child: mButton('Refuser', () async {
                                  if (await _call(context, 'ann_decide', {'p_id': a['id'], 'p_approve': false, 'p_note': 'Annonce non conforme aux règles de publication'}, ok: 'Annonce refusée.')) ref.invalidate(annPostedProvider);
                                }, dark: false)),
                                const SizedBox(width: 8),
                                Expanded(child: mButton('Publier', () async {
                                  if (await _call(context, 'ann_decide', {'p_id': a['id'], 'p_approve': true, 'p_verified': false}, ok: 'Annonce publiée.')) ref.invalidate(annPostedProvider);
                                })),
                                const SizedBox(width: 8),
                                Expanded(child: mButton('Vérifiée', () async {
                                  if (await _call(context, 'ann_decide', {'p_id': a['id'], 'p_approve': true, 'p_verified': true}, ok: 'Annonce publiée avec le badge Vérifié.')) ref.invalidate(annPostedProvider);
                                })),
                              ])
                            : Row(children: [
                                Expanded(child: Text(const {'pending': 'En attente de validation', 'published': 'Publiée', 'rejected': 'Refusée', 'closed': 'Clôturée'}['${a['status']}'] ?? '', style: mst(12.5, w: FontWeight.w700, c: kGrey))),
                                if (a['status'] == 'published') SizedBox(width: 120, child: mButton('Clôturer', () async {
                                  if (await _call(context, 'ann_close', {'p_id': a['id']}, ok: 'Annonce clôturée.')) ref.invalidate(annPostedProvider);
                                }, dark: false)),
                              ]),
                      ),
                    ]),
                ]),
        ),
        mSectionTitle('Victoires à valider'),
        const _WinsToValidate(),
      ]),
    );
  }
}

class _WinsToValidate extends ConsumerStatefulWidget {
  const _WinsToValidate();

  @override
  ConsumerState<_WinsToValidate> createState() => _WinsState();
}

class _WinsState extends ConsumerState<_WinsToValidate> {
  List<Map<String, dynamic>>? _l;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await marcheCall('ann_wins_list', {'p_limit': 20, 'p_pending': true});
    if (!mounted) return;
    setState(() => _l = r.error != null ? const [] : [for (final x in (r.data as List? ?? const [])) Map<String, dynamic>.from(x as Map)]);
  }

  @override
  Widget build(BuildContext context) {
    final l = _l;
    if (l == null) return const SizedBox.shrink();
    if (l.isEmpty) return Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('Aucune victoire en attente (réservé à l’équipe).', style: mst(13, c: kGrey)));
    return Column(children: [
      for (final w in l)
        _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${w['name']} · ${w['title']}', style: mst(13.5, w: FontWeight.w800)),
          GestureDetector(onTap: () => openUrl(context, '${w['proof_url']}'), child: Text('Voir la preuve', style: mst(12.5, w: FontWeight.w700, c: kViolet))),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: mButton('Refuser', () async {
              if (await _call(context, 'ann_win_decide', {'p_id': w['id'], 'p_approve': false})) await _load();
            }, dark: false)),
            const SizedBox(width: 8),
            Expanded(child: mButton('Publier', () async {
              if (await _call(context, 'ann_win_decide', {'p_id': w['id'], 'p_approve': true}, ok: 'Victoire publiée.')) await _load();
            })),
          ]),
        ])),
    ]);
  }
}

// ------------------------------------------------------------------ publier une annonce

class AnnouncementEditScreen extends ConsumerStatefulWidget {
  const AnnouncementEditScreen({super.key});

  @override
  ConsumerState<AnnouncementEditScreen> createState() => _AnnEditState();
}

class _AnnEditState extends ConsumerState<AnnouncementEditScreen> {
  final _c = {for (final k in ['title', 'organizer', 'country', 'place', 'description', 'why', 'conditions', 'documents', 'steps', 'criteria', 'reward', 'prize', 'level', 'age', 'department', 'eligCountry', 'cost', 'url']) k: TextEditingController()};
  String _kind = 'contest', _domain = 'tech', _orgKind = 'university', _placeKind = 'online';
  String _currency = 'FCFA';
  bool _free = true, _iut = false, _busy = false;
  DateTime? _opens, _deadline, _results, _start;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _lines(String s) => [for (final x in s.split('\n')) if (x.trim().isNotEmpty) x.trim()];
  String? _iso(DateTime? d) => d?.toIso8601String().substring(0, 10);

  Future<void> _send() async {
    setState(() => _busy = true);
    final r = await marcheCall('ann_save', {
      'p': {
        'title': _c['title']!.text,
        'organizer': _c['organizer']!.text,
        'organizer_kind': _orgKind,
        'country': _c['country']!.text,
        'place_kind': _placeKind,
        'place': _c['place']!.text,
        'domain': _domain,
        'kind': _kind,
        'description': _c['description']!.text,
        'why': _c['why']!.text,
        'conditions': _lines(_c['conditions']!.text),
        'documents': _lines(_c['documents']!.text),
        'steps': _lines(_c['steps']!.text),
        'criteria': _lines(_c['criteria']!.text),
        'opens_on': _iso(_opens),
        'deadline': _iso(_deadline),
        'results_on': _iso(_results),
        'program_start': _iso(_start),
        'reward': _c['reward']!.text,
        'eligible_level': _c['level']!.text,
        'eligible_age': _c['age']!.text,
        'eligible_department': _c['department']!.text,
        'eligible_country': _c['eligCountry']!.text,
        'iut_only': _iut,
        'free': _free,
        'cost_amount': _free ? null : int.tryParse(_c['cost']!.text.replaceAll(RegExp(r'[^0-9]'), '')),
        'cost_currency': _currency,
        'official_url': _c['url']!.text,
      },
    });
    if (!mounted) return;
    final prize = int.tryParse(_c['prize']!.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (r.error == null && prize > 0) {
      final ps = await marcheCall('ann_prize_set', {'p_ann': '${r.data}', 'p_amount': prize});
      if (!mounted) return;
      setState(() => _busy = false);
      if (ps.error != null) {
        await gAlert(context, 'Récompense non enregistrée', Backend.userMessage('${ps.error}'));
      } else {
        ref.invalidate(annPostedProvider);
        final pay = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text('Mettre la récompense sous séquestre ?'),
            content: Text('${mFcfa(prize)} sont payés maintenant par Mobile Money et conservés par Boutik-École jusqu’à l’attribution au gagnant. Votre annonce ne peut pas être publiée avant ce paiement.'),
            actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Plus tard')), TextButton(onPressed: () => Navigator.pop(c, true), child: Text('Payer maintenant'))],
          ),
        );
        if (pay == true && mounted) await payPrize(context, ref, '${r.data}', title: _c['title']!.text);
      }
      if (!mounted) return;
      gToast(context, 'Annonce envoyée : elle sera visible après le paiement de la récompense et la validation par l’équipe.');
      context.pop();
      return;
    }
    setState(() => _busy = false);
    gToast(context, r.error != null ? Backend.userMessage('${r.error}') : 'Annonce envoyée : elle sera visible après validation par l’équipe.');
    if (r.error == null) {
      ref.invalidate(annPostedProvider);
      context.pop();
    }
  }

  InputDecoration _deco(String l, {String? hint}) => InputDecoration(labelText: l, hintText: hint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)), filled: true, fillColor: Colors.white);

  Widget _f(String k, String label, {String? hint, int lines = 1}) => Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: _c[k], maxLines: lines, decoration: _deco(label, hint: hint)));

  Widget _date(String label, DateTime? v, ValueChanged<DateTime> set) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: mButton(v == null ? label : '$label : ${v.day}/${v.month}/${v.year}', () async {
          final d = await pickDate(context: context, initialDate: v ?? DateTime.now().add(const Duration(days: 14)), firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now().add(const Duration(days: 1095)));
          if (d != null) setState(() => set(d));
        }, dark: false, width: double.infinity),
      );

  @override
  Widget build(BuildContext context) {
    return MarchePage(
      title: 'Publier une annonce',
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 90), children: [
        Text('Réservé à l’équipe, aux départements, aux entreprises et aux ONG. L’annonce est relue avant d’être publiée.', style: mst(13, c: kGrey).copyWith(height: 1.5)),
        const SizedBox(height: 12),
        _f('title', 'Titre', hint: 'Bourse Canada, Hackathon…'),
        _f('organizer', 'Organisateur', hint: 'Université, entreprise, ONG…'),
        MDropdown(label: 'Type d’organisateur', value: _orgKind, items: annOrganizers, onChanged: (v) => setState(() => _orgKind = v)),
        const SizedBox(height: 10),
        MDropdown(label: 'Type', value: _kind, items: {for (final e in annKinds.entries) if (e.key.isNotEmpty) e.key: e.value}, onChanged: (v) => setState(() => _kind = v)),
        const SizedBox(height: 10),
        MDropdown(label: 'Domaine', value: _domain, items: {for (final e in annDomains.entries) if (e.key.isNotEmpty) e.key: e.value}, onChanged: (v) => setState(() => _domain = v)),
        const SizedBox(height: 10),
        MDropdown(label: 'Pays ou zone', value: _c['country']!.text, items: countryOrZoneItems, onChanged: (v) => setState(() => _c['country']!.text = v)),
        const SizedBox(height: 10),
        MDropdown(label: 'Lieu', value: _placeKind, items: {for (final e in oppModes.entries) if (e.key.isNotEmpty) e.key: e.value}, onChanged: (v) => setState(() => _placeKind = v)),
        const SizedBox(height: 10),
        _f('place', 'Ville ou plateforme (facultatif)'),
        _f('description', 'Description', lines: 5),
        _f('why', 'Pourquoi ce concours existe, quel problème il résout', lines: 3),
        _f('conditions', 'Conditions d’éligibilité (une par ligne)', lines: 4),
        _f('documents', 'Documents à fournir (un par ligne)', lines: 3),
        _f('steps', 'Étapes pour postuler (une par ligne)', lines: 4),
        _f('criteria', 'Critères de sélection (un par ligne)', lines: 3),
        _date('Ouverture', _opens, (d) => _opens = d),
        _date('Date limite', _deadline, (d) => _deadline = d),
        _date('Résultats', _results, (d) => _results = d),
        _date('Début du programme', _start, (d) => _start = d),
        const SizedBox(height: 4),
        _f('reward', 'Gain ou récompense', hint: 'Bourse complète, voyage, stage…'),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(controller: _c['prize'], keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: _deco('Récompense en argent (FCFA, facultatif)', hint: '100000').copyWith(helperText: 'Payée à l’avance et conservée sous séquestre jusqu’à l’attribution au gagnant.', helperMaxLines: 2)),
        ),
        _f('level', 'Niveau (facultatif)'),
        _f('age', 'Âge (facultatif)'),
        MultiPickField(label: 'Filières concernées', options: studyFields, value: _c['department']!.text, emptyText: 'Toutes les filières', onChanged: (v) => setState(() => _c['department']!.text = v)),
        MultiPickField(label: 'Pays éligibles', options: africanCountries, value: _c['eligCountry']!.text, emptyText: 'Tous les pays', onChanged: (v) => setState(() => _c['eligCountry']!.text = v)),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: Text('Réservé aux étudiants de l’IUT', style: mst(13.5)), value: _iut, onChanged: (v) => setState(() => _iut = v)),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: Text('Participation gratuite', style: mst(13.5)), value: _free, onChanged: (v) => setState(() => _free = v)),
        if (!_free) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 3, child: Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: _c['cost'], keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: _deco('Montant', hint: '5000')))),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: MDropdown(label: 'Devise', value: _currency, items: currencyItems, onChanged: (v) => setState(() => _currency = v))),
          ]),
          const SizedBox(height: 10),
        ],
        _f('url', 'Lien officiel', hint: 'https://…'),
        mButton(_busy ? 'Envoi…' : 'Envoyer pour validation', _busy ? null : _send, width: double.infinity),
      ]),
    );
  }
}
