import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../i18n.dart' show Text;
import '../nav.dart' show gOpen;
import 'l8_common.dart';
import 'marche/marche_data.dart';
import 'opportunites_screens.dart';

/// Écrans 157 et 158 pour l'ÉTUDIANT : « Résumé de mes candidatures » et « Propositions reçues » (invitations des recruteurs).
/// Tout vient des RPC opp_my_applications, opp_my_invites et opps_list (favoris) ; rien n'est inventé.

const _applicationOpen = {'sent', 'viewed', 'shortlisted'};

Widget _loading(double w, double h) => SizedBox(width: w, height: h, child: const Center(child: CircularProgressIndicator()));

String _err(Object e) => e is MarcheException ? '$e' : marcheErrorText('$e');

Widget _line(BuildContext context, {required String title, required String sub, required String pill, required Color color, required String id}) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/opportunites/$id'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: kLine)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, style: l8St(14, w: FontWeight.w700))),
            l8Pill(pill, bg: color.withValues(alpha: 0.12), fg: color),
          ]),
          const SizedBox(height: 3),
          Text(sub, style: l8St(12, c: l8Grey).copyWith(height: 1.4)),
        ]),
      ),
    );

/// 157 (étudiant) : résumé de mes candidatures, de mes invitations et de mes favoris proches de leur date limite.
class StudentApplicationsSummary extends ConsumerWidget {
  const StudentApplicationsSummary({super.key, this.width = 342, this.height = 560});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(oppMyApplicationsProvider);
    final invites = ref.watch(oppMyInvitesProvider);
    final saved = ref.watch(oppsProvider(const OppQuery(section: 'saved')));
    if (apps.hasError) return l8Note(width, _err(apps.error!), height: 150, action: 'Réessayer', onAction: () => ref.invalidate(oppMyApplicationsProvider));
    if (apps.isLoading) return _loading(width, 150);
    final l = apps.value ?? const <Map<String, dynamic>>[];
    final inProgress = l.where((a) => _applicationOpen.contains('${a['status']}')).length;
    final good = l.where((a) => const {'shortlisted', 'hired'}.contains('${a['status']}')).length;
    final toAnswer = (invites.value ?? const <Map<String, dynamic>>[]).where((i) => i['status'] == 'invited' && i['open'] == true).length;
    final now = DateTime.now();
    final soon = (saved.value ?? const <Map<String, dynamic>>[]).where((o) {
      final d = DateTime.tryParse('${o['deadline'] ?? ''}');
      return d != null && !d.isBefore(DateTime(now.year, now.month, now.day)) && d.difference(now).inDays <= 7;
    }).length;
    Widget tile(String label, String v) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFECE8F2))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: l8St(11.5, c: l8Grey)), const SizedBox(height: 6), Text(v, style: l8St(22, w: FontWeight.w800))]),
          ),
        );
    return SizedBox(
      width: width,
      height: height,
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [tile('Candidatures envoyées', '${l.length}'), const SizedBox(width: 12), tile('En cours', '$inProgress')]),
          const SizedBox(height: 12),
          Row(children: [tile('Retenues ou recrutées', '$good'), const SizedBox(width: 12), tile('Propositions à traiter', '$toAnswer')]),
          const SizedBox(height: 12),
          Row(children: [tile('Favoris : échéance sous 7 jours', '$soon'), const SizedBox(width: 12), const Expanded(child: SizedBox())]),
          const SizedBox(height: 22),
          Text('Dernières candidatures', style: l8St(15, w: FontWeight.w700)),
          const SizedBox(height: 10),
          if (l.isEmpty)
            Text('Vous n’avez pas encore postulé. Les offres qui vous correspondent sont dans « Offres pour vous ».', style: l8St(13, c: l8Grey).copyWith(height: 1.4))
          else
            for (final a in l.take(5))
              _line(context,
                  title: '${a['title']}',
                  sub: [if ('${a['org'] ?? ''}'.isNotEmpty) '${a['org']}', if (l8Date(a['created_at']).isNotEmpty) 'Envoyée le ${l8Date(a['created_at'])}'].join(' · '),
                  pill: oppApplicationStatus['${a['status']}'] ?? '${a['status']}',
                  color: a['status'] == 'rejected' ? kRed : (a['status'] == 'hired' ? kGreen : l8Violet),
                  id: '${a['opportunity_id']}'),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            l8Pill('Toutes mes candidatures', onTap: () => gOpen(context, '76')),
            l8Pill('Propositions reçues', onTap: () => gOpen(context, '158')),
            l8Pill('Offres pour vous', onTap: () => gOpen(context, '152')),
          ]),
        ]),
      ),
    );
  }
}

/// 158 (étudiant) : propositions reçues = invitations des recruteurs à postuler, avec le réglage « Me proposer aux recruteurs ».
class StudentProposals extends ConsumerWidget {
  const StudentProposals({super.key, this.width = 342, this.height = 570});
  final double width, height;

  static const _status = {'invited': 'À traiter', 'applied': 'Candidature envoyée', 'declined': 'Déclinée'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invites = ref.watch(oppMyInvitesProvider);
    return SizedBox(
      width: width,
      height: height,
      child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
        const TalentVisibilityCard(),
        invites.when(
          loading: () => _loading(width, 120),
          error: (e, _) => l8Note(width, _err(e), height: 150, action: 'Réessayer', onAction: () => ref.invalidate(oppMyInvitesProvider)),
          data: (l) => l.isEmpty
              ? l8Note(width, 'Aucune proposition reçue pour le moment. Quand une organisation vous invite à postuler à une offre, elle apparaît ici et dans vos notifications.', height: 170, action: 'Voir les offres pour moi', onAction: () => gOpen(context, '152'))
              : Column(children: [
                  for (final i in l)
                    _line(context,
                        title: '${i['title']}',
                        sub: [
                          '${i['org']}',
                          if (l8Date(i['created_at']).isNotEmpty) 'Invitation du ${l8Date(i['created_at'])}',
                          if ('${i['message'] ?? ''}'.isNotEmpty) '« ${i['message']} »',
                          if (i['open'] != true) 'Cette offre n’est plus ouverte.',
                        ].join(' · '),
                        pill: _status['${i['status']}'] ?? '${i['status']}',
                        color: i['status'] == 'declined' ? kGrey : (i['status'] == 'applied' ? kGreen : l8Violet),
                        id: '${i['opportunity_id']}'),
                ]),
        ),
      ]),
    );
  }
}
