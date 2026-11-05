import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth.dart';
import 'backend.dart';
import 'console.dart';
import 'home_live.dart';
import 'store.dart' show fcfa;

/// Espace entreprise (écrans 91, 93, 95, 96, 98, 99) : besoins publiés, propositions reçues, devis, défis et collaborations lus sur
/// le serveur. Chargement, état vide et erreur explicites ; aucune personne ni aucun montant de maquette hors démonstration.

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

/// Lecture directe d'une table protégée par RLS (le serveur ne renvoie que ce que le compte peut voir).
class TableRows extends RpcRows {
  TableRows(this.table, this.select, {this.order, this.ascending = false, this.neq}) : super('table:$table');
  final String table, select;
  final String? order;
  final bool ascending;
  final Map<String, Object>? neq;

  @override
  Future<void> refresh() async {
    final r = await Backend.rows(table, select, order: order, ascending: ascending, limit: 50);
    if (!ref.mounted) return;
    error = r.error != null;
    state = [for (final x in r.rows) x];
  }
}

final companyProposalsProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => RpcRows('company_proposals'));
final companyMissionsProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => RpcRows('company_missions'));
final contestsListProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('contests', 'title,prize,reg_close_at,places,status,city', order: 'reg_close_at', ascending: true));
final quotesListProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('quote_requests', 'brief,budget,status,quote_amount,quote_delay_days,created_at', order: 'created_at'));

final projectsCatalogProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('projects', 'title,summary,department,status,created_at', order: 'created_at'));
final certificatesProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('certificates', 'subject_title,code,subject_kind,issued_at,revoked,holder_name', order: 'issued_at'));
final campaignsProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('campaigns', 'project,goal,status,kind,duration_days,created_at', order: 'created_at'));

const _mois = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
String dateCourte(Object? iso) {
  final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
  return d == null ? '—' : '${d.day} ${_mois[d.month - 1]} ${d.year}';
}

String proposalStatus(Object? s) => switch ('$s') { 'accepted' => 'Acceptée', 'rejected' || 'declined' => 'Refusée', 'pending' => 'Reçue', _ => '$s' };
String missionStatus(Object? s) => switch ('$s') {
      'published' => 'Publié',
      'assigned' => 'Attribué',
      'in_progress' => 'En cours',
      'delivered' => 'Livré',
      'closed' || 'completed' || 'released' => 'Clôturé',
      'draft' => 'Brouillon',
      _ => '$s'
    };
String quoteStatus(Object? s) => switch ('$s') { 'requested' => 'Demandé', 'quoted' => 'Devis reçu', 'accepted' => 'Accepté', 'refused' || 'declined' => 'Refusé', _ => '$s' };

class MobileList extends ConsumerWidget {
  const MobileList({super.key, required this.provider, required this.title, required this.subtitle, this.trailing, required this.emptyText, this.onTap, this.where, this.width = 342, this.height = 520});
  final NotifierProvider<RpcRows, List<Map<String, dynamic>>?> provider;
  final String Function(Map<String, dynamic>) title, subtitle;
  final String Function(Map<String, dynamic>)? trailing;
  final bool Function(Map<String, dynamic>)? where;
  final VoidCallback? onTap;
  final String emptyText;
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget note(String t) => Container(
          width: width,
          height: 190,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(color: const Color(0x66FFFFFF), borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFECE8F2))),
          child: Text(t, textAlign: TextAlign.center, style: _st(13, c: _grey).copyWith(height: 1.5)),
        );
    if (ref.watch(authProvider.select((a) => a.current == null))) return note('Connectez-vous pour voir cette liste.');
    final all = ref.watch(provider);
    if (all == null) return note('Chargement…');
    if (ref.read(provider.notifier).error) return note('Cette liste ne peut pas être chargée pour le moment.');
    final rows = [for (final r in all) if (where == null || where!(r)) r];
    if (rows.isEmpty) return note(emptyText);
    return SizedBox(
      width: width,
      height: height,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: rows.length,
        separatorBuilder: (_, _) => const Divider(height: 22, thickness: 1, color: Color(0xFFF2EFF6)),
        itemBuilder: (_, i) {
          final r = rows[i];
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title(r), maxLines: 2, overflow: TextOverflow.ellipsis, style: _st(13.5, w: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(subtitle(r), maxLines: 2, overflow: TextOverflow.ellipsis, style: _st(11.5, c: _grey)),
                ]),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 10),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFEEE9FF), borderRadius: BorderRadius.circular(11)), child: Text(trailing!(r), style: _st(11, w: FontWeight.w600, c: const Color(0xFF5A3FE0)))),
              ],
            ]),
          );
        },
      ),
    );
  }
}

String _money(Object? v) => fcfa(((v as num?) ?? 0).toInt());

Widget proposalsList() => MobileList(
      provider: companyProposalsProvider,
      title: (r) => '${r['author']}',
      subtitle: (r) => '${_money(r['amount'])} · ${r['delay_days']} jours · ${r['mission']}',
      trailing: (r) => proposalStatus(r['status']),
      emptyText: 'Aucune proposition reçue pour le moment.\nLes propositions apparaissent ici quand des étudiants répondent à vos besoins.',
    );

Widget missionsHistory() => MobileList(
      provider: companyMissionsProvider,
      title: (r) => '${r['title']}',
      subtitle: (r) => 'Publié le ${dateCourte(r['created_at'])} · ${r['proposals']} proposition${(r['proposals'] as num?) == 1 ? '' : 's'}',
      trailing: (r) => missionStatus(r['status']),
      emptyText: 'Vous n’avez publié aucun besoin pour le moment.',
    );

Widget collaborationsList() => MobileList(
      provider: companyMissionsProvider,
      where: (r) => const ['assigned', 'in_progress', 'delivered'].contains('${r['status']}'),
      title: (r) => '${r['title']}',
      subtitle: (r) => ('${r['team']}'.isEmpty ? 'Équipe en cours d’attribution' : 'Équipe : ${r['team']}') + (r['deadline'] == null ? '' : ' · pour le ${dateCourte(r['deadline'])}'),
      trailing: (r) => missionStatus(r['status']),
      emptyText: 'Aucune collaboration en cours.\nUn besoin attribué à une équipe apparaît ici.',
    );

Widget quotesListWidget() => MobileList(
      provider: quotesListProvider,
      title: (r) => '${r['brief']}',
      subtitle: (r) => r['quote_amount'] == null ? 'En attente de devis' : '${_money(r['quote_amount'])} · ${r['quote_delay_days'] ?? '—'} jours',
      trailing: (r) => quoteStatus(r['status']),
      emptyText: 'Aucune demande de devis pour le moment.',
    );

Widget contestsListWidget() => MobileList(
      provider: contestsListProvider,
      title: (r) => '${r['title']}',
      subtitle: (r) => [if (r['prize'] != null && '${r['prize']}'.isNotEmpty) 'Prix : ${r['prize']}', if (r['reg_close_at'] != null) 'Inscriptions jusqu’au ${dateCourte(r['reg_close_at'])}', if (r['places'] != null) '${r['places']} places'].join(' · '),
      emptyText: 'Aucun défi ouvert pour le moment.',
    );

/// Recherche de talents (écran 91) : les vrais profils étudiants, avec accès à leur profil public.
class TalentSearchList extends ConsumerWidget {
  const TalentSearchList({super.key, this.width = 342, this.height = 500});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) => CommunityMembers(width: width, height: height);
}

String projectStatus(Object? s) => switch ('$s') { 'approved' => 'Validé', 'submitted' => 'À valider', 'draft' => 'Brouillon', 'rejected' => 'Refusé', _ => '$s' };
String campaignStatus(Object? s) => switch ('$s') { 'approved' => 'Ouverte', 'submitted' => 'À valider', 'draft' => 'Brouillon', 'rejected' => 'Refusée', _ => '$s' };

Widget projectsCatalogList() => MobileList(
      provider: projectsCatalogProvider,
      title: (r) => '${r['title']}',
      subtitle: (r) => [if ('${r['department'] ?? ''}'.isNotEmpty) '${r['department']}', '${r['summary'] ?? ''}'].where((e) => e.isNotEmpty).join(' · '),
      trailing: (r) => projectStatus(r['status']),
      emptyText: 'Aucun projet validé pour le moment.\nLes projets des étudiants apparaissent ici après validation.',
    );

Widget innovationRegistryList() => MobileList(
      provider: certificatesProvider,
      title: (r) => '${r['subject_title']}',
      subtitle: (r) => 'Certificat n° ${r['code']} · délivré le ${dateCourte(r['issued_at'])}',
      trailing: (r) => r['revoked'] == true ? 'Révoqué' : 'Certifié',
      emptyText: 'Aucun certificat enregistré pour le moment.',
    );

Widget campaignsListWidget() => MobileList(
      provider: campaignsProvider,
      title: (r) => '${r['project']}',
      subtitle: (r) => 'Objectif : ${r['goal'] ?? '—'}${r['duration_days'] == null ? '' : ' · ${r['duration_days']} jours'}',
      trailing: (r) => campaignStatus(r['status']),
      emptyText: 'Aucune campagne pour le moment.\nLes sommes collectées ne sont pas encore suivies en ligne.',
    );

Widget quotesListWidgetWide() => MobileList(
      provider: quotesListProvider,
      title: (r) => '${r['brief']}',
      subtitle: (r) => r['quote_amount'] == null ? 'En attente de devis' : '${_money(r['quote_amount'])} · ${r['quote_delay_days'] ?? '—'} jours',
      trailing: (r) => quoteStatus(r['status']),
      emptyText: 'Aucune demande de devis pour le moment.',
      width: 984,
      height: 640,
    );
