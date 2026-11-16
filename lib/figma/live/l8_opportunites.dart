import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../i18n.dart' show Text;
import '../nav.dart' show gOpen;
import 'auth.dart';
import 'l8_actions.dart';
import 'l8_common.dart';
import 'marche/marche_data.dart';
import 'notifs.dart';
import 'opportunites_screens.dart';
import 'store.dart' show IntV, StrV;

/// Écrans Opportunités du compte : offres classées par score réel (152), « Pourquoi cette offre ? » (153), mes candidatures (76), alertes (155).
/// Tout vient du serveur (opps_recommended, opp_my_match, opp_my_applications, notifications) ; rien n'est inventé.

final oppRecommendedProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final r = await marcheCall('opps_recommended', const {'p_limit': 20});
  if (r.error != null) throw MarcheException(r.error);
  return [for (final x in (r.data as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
}, retry: (_, _) => null);

/// Offre dont l'écran 153 détaille la correspondance.
final whyOfferProvider = NotifierProvider<StrV, String>(StrV.new);

/// Ouvre la fiche de l'offre dont l'écran 153 détaille la correspondance (à défaut d'offre choisie : la mieux classée, sinon la liste des offres).
void openWhyOffer(BuildContext context, WidgetRef ref) {
  final id = _whyId(ref.read(whyOfferProvider), ref.read(oppRecommendedProvider).asData?.value);
  context.push(id.isEmpty ? '/opportunites' : '/opportunites/$id');
}

String _whyId(String chosen, List<Map<String, dynamic>>? ranked) => chosen.isNotEmpty ? chosen : (ranked != null && ranked.isNotEmpty ? '${ranked.first['id']}' : '');

final oppMatchProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final r = await marcheCall('opp_my_match', {'p_id': id});
  if (r.error != null) throw MarcheException(r.error);
  return r.data is Map ? Map<String, dynamic>.from(r.data as Map) : <String, dynamic>{};
}, retry: (_, _) => null);

Widget _loading(double w, double h) => SizedBox(width: w, height: h, child: const Center(child: CircularProgressIndicator()));

String _error(Object e) => e is MarcheException ? '$e' : marcheErrorText('$e');

Widget _signIn(BuildContext context, WidgetRef ref, double w, double h, String text, String need) => l8Note(w, text, height: h, action: 'Se connecter', onAction: () => requireLogin(context, ref, need));

/// 152 : offres ouvertes, classées par le score de correspondance calculé par le serveur avec le profil de la personne.
class RecommendedOpportunities extends ConsumerWidget {
  const RecommendedOpportunities({super.key, this.width = 342, this.height = 640});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authProvider.select((a) => a.current == null))) return _signIn(context, ref, width, height, 'Connectez-vous pour voir les offres classées selon votre profil.', 'voir les offres pour vous');
    return ref.watch(oppRecommendedProvider).when(
          loading: () => _loading(width, height),
          error: (e, _) => l8Note(width, _error(e), height: height, action: 'Réessayer', onAction: () => ref.invalidate(oppRecommendedProvider)),
          data: (l) => SizedBox(
            width: width,
            height: height,
            child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text('Offres ouvertes classées selon votre profil : compétences, filière, disponibilité et profil renseigné. Ce classement aide à trier, il ne décide de rien.', style: l8St(12, c: l8Grey).copyWith(height: 1.5)),
              ),
              if (l.isEmpty)
                l8Note(width, 'Aucune offre à vous proposer pour le moment : toutes les offres ouvertes sont déjà candidatées ou ne vous sont pas destinées.', height: 150, action: 'Voir toutes les opportunités', onAction: () => context.push('/opportunites'))
              else ...[
                for (final o in l) ...[
                  OpportunityCard(o: o, onTap: () => context.push('/opportunites/${o['id']}')),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Row(children: [
                      Expanded(child: matchBadge(o['match'])),
                      l8Pill('Pourquoi cette offre ?', onTap: () {
                        ref.read(whyOfferProvider.notifier).set('${o['id']}');
                        gOpen(context, '153');
                      }),
                    ]),
                  ),
                ],
                Center(child: l8Pill('Toutes les opportunités', bg: l8Ink, fg: Colors.white, onTap: () => context.push('/opportunites'))),
              ],
            ]),
          ),
        );
  }
}

Widget _bar(String label, String detail, int value, int max) {
  final ratio = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(label, style: l8St(13, w: FontWeight.w600))),
        Text(detail, style: l8St(12, c: l8Grey)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(children: [
          Container(height: 8, color: const Color(0xFFE6E1EE)),
          FractionallySizedBox(widthFactor: ratio, child: Container(height: 8, color: l8Violet)),
        ]),
      ),
    ]),
  );
}

/// 153 : détail du score de correspondance (compétences retrouvées ou manquantes, filière, disponibilité, profil), calculé par le serveur.
class WhyOffer extends ConsumerWidget {
  const WhyOffer({super.key, this.width = 342, this.height = 560});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chosen = ref.watch(whyOfferProvider);
    if (ref.watch(authProvider.select((a) => a.current == null))) return _signIn(context, ref, width, height, 'Connectez-vous pour voir pourquoi une offre vous correspond.', 'voir le détail de correspondance');
    // Ouverture directe ou rechargement : sans offre choisie, l'offre la mieux classée pour la personne est détaillée.
    final id = _whyId(chosen, chosen.isEmpty ? ref.watch(oppRecommendedProvider).asData?.value : null);
    if (id.isEmpty && chosen.isEmpty && ref.watch(oppRecommendedProvider).isLoading) return _loading(width, height);
    if (id.isEmpty) return l8Note(width, 'Aucune offre à détailler pour le moment : choisissez une offre dans « Offres pour vous ».', height: height, action: 'Voir les offres pour moi', onAction: () => gOpen(context, '152'));
    return ref.watch(oppMatchProvider(id)).when(
          loading: () => _loading(width, height),
          error: (e, _) => l8Note(width, _error(e), height: height, action: 'Voir les offres pour moi', onAction: () => gOpen(context, '152')),
          data: (m) {
            final score = mInt(m['score']);
            final wanted = mInt(m['skills_wanted']);
            final skills = [for (final s in (m['skills_detail'] as List? ?? const [])) if (s is Map) Map<String, dynamic>.from(s)];
            final missing = [for (final s in skills) if (s['found'] != true) '${s['skill']}'];
            final noDept = '${m['my_department'] ?? ''}'.trim().isEmpty;
            final profilePoints = mInt(m['profile']);
            return SizedBox(
              width: width,
              height: height,
              child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
                Text('${m['title']}', style: l8St(17, w: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('${m['org']}', style: l8St(12.5, c: l8Grey)),
                const SizedBox(height: 14),
                Row(children: [
                  Text('$score %', style: l8St(32, w: FontWeight.w800, c: score >= 75 ? kGreen : (score >= 50 ? l8Violet : l8Grey))),
                  const SizedBox(width: 10),
                  Expanded(child: Text('de correspondance avec votre profil. Ce score aide à trier les offres ; il ne décide de rien.', style: l8St(12, c: l8Grey).copyWith(height: 1.4))),
                ]),
                const SizedBox(height: 16),
                _bar('Compétences', wanted > 0 ? '${mInt(m['skills_found'])}/$wanted retrouvées' : 'aucune exigée', mInt(m['skills']), 50),
                _bar('Filière', mInt(m['department']) >= 25 ? 'correspond' : 'ne correspond pas', mInt(m['department']), 25),
                _bar('Disponibilité', mInt(m['availability']) >= 15 ? 'compatible' : 'non précisée ou différente', mInt(m['availability']), 15),
                _bar('Profil renseigné', '$profilePoints/10', profilePoints, 10),
                if (skills.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Compétences demandées', style: l8St(14, w: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final s in skills)
                      l8Pill('${s['found'] == true ? '✓' : '✗'} ${s['skill']}', bg: s['found'] == true ? const Color(0xFFE2F4EC) : const Color(0xFFF2EFF6), fg: s['found'] == true ? kGreen : l8Grey),
                  ]),
                ],
                if (missing.isNotEmpty || noDept || profilePoints < 10) ...[
                  const SizedBox(height: 18),
                  Text('Points à améliorer', style: l8St(14, w: FontWeight.w700)),
                  const SizedBox(height: 4),
                  if (missing.isNotEmpty) _tip('Ajoutez à votre profil : ${missing.take(4).join(', ')}.', 'Ajouter une compétence', () => gOpen(context, '72')),
                  if (noDept) _tip('Renseignez votre filière dans votre profil.', 'Renseigner ma filière', () => gOpen(context, '18b')),
                  if (profilePoints < 10) _tip('Complétez votre présentation et votre photo de profil.', 'Compléter mon profil', () => gOpen(context, '18b')),
                ],
              ]),
            );
          },
        );
  }

  Widget _tip(String text, String action, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(children: [
          Expanded(child: Text(text, style: l8St(12.5).copyWith(height: 1.4))),
          const SizedBox(width: 8),
          l8Pill(action, onTap: onTap),
        ]),
      );
}

/// 159 : récapitulatif de la dernière candidature envoyée depuis cet écran d'offre (offre, organisation, date, correspondance réelle).
class ApplicationSentCard extends ConsumerWidget {
  const ApplicationSentCard({super.key, this.width = 342});
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var a = ref.watch(lastApplicationProvider);
    // Ouverture directe ou rechargement : la dernière candidature est relue sur le serveur.
    if (a == null) {
      final mine = ref.watch(oppMyApplicationsProvider).asData?.value;
      if (mine != null && mine.isNotEmpty) a = {'title': mine.first['title'], 'org': mine.first['org'], 'sent_at': mine.first['created_at']};
    }
    if (a == null) return l8Note(width, 'Aucune candidature envoyée pour le moment : retrouvez les vôtres dans « Mes candidatures ».', height: 120);
    Widget row(String l, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l, style: l8St(12.5, c: l8Grey)),
            const SizedBox(width: 12),
            Expanded(child: Text(v, textAlign: TextAlign.right, style: l8St(12.5, w: FontWeight.w600))),
          ]),
        );
    final score = a['score'];
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: kLine)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        row('Offre', '${a['title']}'),
        if ('${a['org'] ?? ''}'.isNotEmpty) row('Organisation', '${a['org']}'),
        row('Envoyée le', l8Date(a['sent_at'])),
        if (score != null) row('Correspondance', '${mInt(score)} %'),
      ]),
    );
  }
}

/// Nom de l'organisation ou, à défaut, du recruteur, pour intituler un message.
String _recruiter(Map<String, dynamic> a) => '${a['org'] ?? ''}'.trim().isEmpty ? 'le recruteur' : '${a['org']}';

/// 76 : mes vraies candidatures (table des candidatures aux offres), avec retrait, message au recruteur et ouverture de l'offre.
class MyApplicationsPanel extends ConsumerWidget {
  const MyApplicationsPanel({super.key, this.width = 342, this.height = 620});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authProvider.select((a) => a.current == null))) return _signIn(context, ref, width, height, 'Connectez-vous pour voir vos candidatures.', 'voir vos candidatures');
    return ref.watch(oppMyApplicationsProvider).when(
          loading: () => _loading(width, height),
          error: (e, _) => l8Note(width, _error(e), height: height, action: 'Réessayer', onAction: () => ref.invalidate(oppMyApplicationsProvider)),
          data: (l) => l.isEmpty
              ? l8Note(width, 'Aucune candidature pour le moment.', height: height, action: 'Voir les opportunités', onAction: () => context.push('/opportunites'))
              : SizedBox(
                  width: width,
                  height: height,
                  child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [for (final a in l) _card(context, ref, a)]),
                ),
        );
  }

  Widget _card(BuildContext context, WidgetRef ref, Map<String, dynamic> a) {
    final status = '${a['status']}';
    final open = const {'sent', 'viewed', 'shortlisted'}.contains(status);
    final color = status == 'rejected' ? kRed : (status == 'hired' ? kGreen : l8Violet);
    final poster = '${a['poster_id'] ?? ''}';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: kLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push('/opportunites/${a['opportunity_id']}'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('${a['title']}', style: l8St(14, w: FontWeight.w700))),
              l8Pill(oppApplicationStatus[status] ?? status, bg: color.withValues(alpha: 0.12), fg: color),
            ]),
            const SizedBox(height: 3),
            Text([_recruiter(a) == 'le recruteur' ? '' : '${a['org']}', if (l8Date(a['created_at']).isNotEmpty) 'Envoyée le ${l8Date(a['created_at'])}'].where((e) => e.isNotEmpty).join(' · '), style: l8St(12, c: l8Grey)),
            if ('${a['offer_status']}' != 'published' && '${a['offer_status']}'.isNotEmpty && '${a['offer_status']}' != 'null') Padding(padding: const EdgeInsets.only(top: 4), child: Text('Cette offre n’est plus ouverte.', style: l8St(11.5, c: l8Grey))),
          ]),
        ),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: [
          if (poster.isNotEmpty) l8Pill('Écrire', onTap: () => l8WriteTo(context, ref, poster, _recruiter(a), need: 'écrire au recruteur')),
          if (open) l8Pill('Retirer', bg: const Color(0xFFFBE9EA), fg: kRed, onTap: () => withdrawApplication(context, ref, a)),
        ]),
      ]),
    );
  }
}

/// Filtre de l'écran 155 : 0 toutes · 1 dossier · 2 offres · 3 dates limites.
final alertsFilterProvider = NotifierProvider<IntV, int>(IntV.new);

bool _alertInGroup(NotificationItem n, int f) => switch (f) {
      1 => n.kind.startsWith('document') || n.kind.startsWith('profile') || n.kind == 'dossier',
      2 => n.kind.startsWith('opportunity') && n.kind != 'opportunity_reminder',
      3 => n.kind == 'opportunity_reminder' || n.kind == 'contest_reminder' || n.kind.contains('deadline'),
      _ => true,
    };

/// 155 : notifications du compte, filtrées par les puces (dossier, offres, dates limites) ; une ligne ouvre l'écran concerné.
class AlertsFeed extends ConsumerWidget {
  const AlertsFeed({super.key, this.width = 342, this.height = 590});
  final double width, height;

  static const _empty = ['Aucune notification pour le moment.', 'Aucune alerte de dossier pour le moment.', 'Aucune alerte d’offre pour le moment.', 'Aucun rappel de date limite pour le moment.'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authProvider.select((a) => a.current == null))) return _signIn(context, ref, width, height, 'Connectez-vous pour voir vos alertes.', 'voir vos alertes');
    final f = ref.watch(alertsFilterProvider);
    final items = [for (final n in ref.watch(notifsProvider)) if (_alertInGroup(n, f)) n];
    if (items.isEmpty) return l8Note(width, _empty[f.clamp(0, 3)], height: height);
    return SizedBox(
      width: width,
      height: height,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: items.length,
        separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF2EFF6)),
        itemBuilder: (context, i) {
          final n = items[i];
          return InkWell(
            onTap: () => tapNotification(context, ref, n),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: l8St(13.5, w: n.read ? FontWeight.w500 : FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: l8St(11.5, c: l8Grey)),
                    const SizedBox(height: 3),
                    Text(l8Date(n.createdAt.toIso8601String()), style: l8St(10.5, c: l8Grey)),
                  ]),
                ),
                if (!n.read) Padding(padding: const EdgeInsets.only(left: 8, top: 4), child: l8Pill('Nouveau')),
              ]),
            ),
          );
        },
      ),
    );
  }
}
