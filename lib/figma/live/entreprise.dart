import 'dart:async' show unawaited;

import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../nav.dart' show gOpen;
import 'auth.dart';
import 'backend.dart';
import 'company_screens.dart' show companyContextProvider;
import 'console.dart';
import 'project_cards.dart' show InnovationRegistry;
import 'talent_search_panel.dart' show TalentSearchPanel;
import 'store.dart' show fcfa;

/// Espace entreprise (écrans 91, 93, 95, 96, 98, 99) : besoins publiés, propositions reçues, devis, défis et collaborations lus sur
/// le serveur. Chargement, état vide et erreur explicites ; aucune personne ni aucun montant de maquette hors démonstration.

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

/// Lecture directe d'une table protégée par RLS (le serveur ne renvoie que ce que le compte peut voir).
class TableRows extends RpcRows {
  TableRows(this.table, this.select, {this.order, this.ascending = false, this.neq, this.eq = const {}, this.limit = 50, this.ownerColumn, this.anyOf, bool publicRead = false}) : super('table:$table', const {}, publicRead);
  final String table, select;
  final String? order;
  final bool ascending;
  final Map<String, Object>? neq;

  /// Filtres d'égalité appliqués par le serveur (évite de lire les 50 dernières lignes de toute la table puis de filtrer dans l'application).
  final Map<String, Object> eq;
  final int limit;

  /// Colonne qui désigne le propriétaire : la lecture est filtrée sur le compte connecté (lu à chaque lecture, la liste se reconstruit au changement de compte).
  final String? ownerColumn;

  /// Colonne et valeurs admises (une lecture serveur par valeur, résultats fusionnés et triés) : sert aux statuts publics multiples.
  final (String, List<Object>)? anyOf;

  @override
  List<Map<String, dynamic>>? build() {
    if (publicRead || ownerColumn != null) ref.watch(authProvider.select((a) => a.current?.email));
    return super.build();
  }

  @override
  Future<void> refresh() async {
    final uid = Backend.userId;
    if (ownerColumn != null && uid == null) {
      error = false;
      state = const [];
      return;
    }
    final base = {...eq, if (ownerColumn != null) ownerColumn!: uid!};
    final rows = <Map<String, dynamic>>[];
    var failed = false;
    for (final v in anyOf?.$2 ?? const <Object?>[null]) {
      final r = await Backend.rows(table, select, eq: {...base, if (v != null) anyOf!.$1: v}, order: order, ascending: ascending, limit: limit);
      if (r.error != null) failed = true;
      rows.addAll(r.rows);
    }
    if (!ref.mounted) return;
    if (anyOf != null && order != null) {
      rows.sort((a, b) => ascending ? '${a[order]}'.compareTo('${b[order]}') : '${b[order]}'.compareTo('${a[order]}'));
    }
    error = failed;
    state = rows.length > limit ? rows.sublist(0, limit) : rows;
  }
}

/// Lecture serveur propre à l'entreprise consultée : celle du contexte (membre d'équipe) ou la sienne ; se relit au changement d'entreprise.
class CompanyRows extends RpcRows {
  CompanyRows(super.fn);

  @override
  List<Map<String, dynamic>>? build() {
    ref.watch(companyContextProvider);
    return super.build();
  }

  @override
  Map<String, dynamic> callArgs() {
    final ctx = ref.read(companyContextProvider);
    return {'p_owner': ?ctx};
  }
}

/// Listes de l'espace entreprise : libérées quand plus aucun écran ne les affiche (relues à la prochaine ouverture) et relisibles à la demande.
final companyProposalsProvider = NotifierProvider.autoDispose<RpcRows, List<Map<String, dynamic>>?>(() => CompanyRows('company_proposals'));
final companyMissionsProvider = NotifierProvider.autoDispose<RpcRows, List<Map<String, dynamic>>?>(() => CompanyRows('company_missions'));
final defisListProvider = NotifierProvider.autoDispose<RpcRows, List<Map<String, dynamic>>?>(() => RpcRows('defis_list', const {'p_limit': 100}));
final contestsListProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('contests', 'title,prize,reg_close_at,places,status,city', order: 'reg_close_at', ascending: true, publicRead: true));
final quotesListProvider = NotifierProvider.autoDispose<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('quote_requests', 'id,brief,budget,status,quote_amount,quote_delay_days,created_at', order: 'created_at'));

/// Propositions cochées pour la comparaison (écran 93 → 94) et proposition ouverte en fiche (écran 93b).
class ProposalSelection extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};
  void toggle(String id) => state = state.contains(id) ? ({...state}..remove(id)) : {...state, id};
  void clear() => state = const {};
}

final proposalSelectionProvider = NotifierProvider<ProposalSelection, Set<String>>(ProposalSelection.new);

class OpenedProposal extends Notifier<String> {
  @override
  String build() => '';
  void set(String id) => state = id;
}

final openedProposalProvider = NotifierProvider<OpenedProposal, String>(OpenedProposal.new);

/// Relit les besoins, propositions, devis et défis de l'entreprise (après une publication, une décision, une annulation, un devis… ou à la demande).
/// Renvoie vrai quand TOUTES les lectures ont réussi ; les listes affichées se mettent à jour d'elles-mêmes.
Future<bool> refreshCompanyData(ProviderContainer c) async {
  final providers = [companyProposalsProvider, companyMissionsProvider, quotesListProvider, defisListProvider];
  final subs = [for (final p in providers) c.listen(p, (_, _) {})];
  try {
    await Future.wait([for (final p in providers) c.read(p.notifier).refresh()]);
    return providers.every((p) => !c.read(p.notifier).error);
  } catch (_) {
    return false;
  } finally {
    for (final s in subs) {
      s.close();
    }
  }
}

/// Ouvre la fiche d'une proposition (écran 93b) ; sans identifiant (lecture incomplète), ne fait rien.
void openProposal(BuildContext context, WidgetRef ref, Map<String, dynamic> row) {
  final id = '${row['id'] ?? ''}';
  if (id.isEmpty) return;
  ref.read(openedProposalProvider.notifier).set(id);
  gOpen(context, '93b');
}

/// À appeler après une action qui change les besoins, propositions ou devis (publication, décision, annulation, clôture, jalon, devis) :
/// les listes affichées se relisent sans attendre. Sans attente ni erreur visible : la lecture se fait en arrière-plan.
void invalidateCompanyData(BuildContext context) {
  try {
    unawaited(refreshCompanyData(ProviderScope.containerOf(context, listen: false)));
  } catch (_) {}
}

/// Indicateurs réels du tableau de bord : besoins publiés (ni brouillon, ni annulé, ni mission sur mesure), propositions actives et à examiner,
/// échéances des sept prochains jours (date réelle calculée par le serveur).
class CompanyCounters {
  const CompanyCounters({this.needs = 0, this.proposals = 0, this.toReview = 0, this.deadlines = 0, this.collaborations = 0});
  final int needs, proposals, toReview, deadlines, collaborations;
}

CompanyCounters companyCounters(List<Map<String, dynamic>> missions, List<Map<String, dynamic>> props, DateTime now) {
  bool isNeed(Map<String, dynamic> m) => m['is_need'] is bool ? m['is_need'] as bool : ('${m['kind']}' != 'mission' && !const {'draft', 'cancelled'}.contains('${m['status']}'));
  final live = [for (final p in props) if ('${p['mission_status']}' != 'cancelled') p];
  final today = DateTime(now.year, now.month, now.day);
  var soon = 0;
  for (final m in missions) {
    if (!const {'published', 'assigned', 'in_progress'}.contains('${m['status']}')) continue;
    final d = deadlineOf(m);
    if (d == null) continue;
    final days = DateTime(d.year, d.month, d.day).difference(today).inDays;
    if (days >= 0 && days <= 7) soon++;
  }
  return CompanyCounters(
    needs: missions.where(isNeed).length,
    proposals: live.where((p) => const {'submitted', 'pending', 'accepted'}.contains('${p['status']}')).length,
    toReview: live.where((p) => const {'submitted', 'pending'}.contains('${p['status']}')).length,
    deadlines: soon,
    collaborations: missions.where((m) => const {'assigned', 'in_progress', 'delivered'}.contains('${m['status']}')).length,
  );
}

final projectsCatalogProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => RpcRows('public_projects', const {'p_limit': 100}, true));
final certificatesProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('certificates', 'subject_title,code,subject_kind,issued_at,revoked,holder_name', order: 'issued_at'));
final campaignsProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('campaigns', 'project,goal,status,kind,duration_days,created_at', order: 'created_at', publicRead: true));

const _mois = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
const _moisCourts = ['jan', 'fev', 'mar', 'avr', 'mai', 'jui', 'jui', 'aou', 'sep', 'oct', 'nov', 'dec'];

/// Date d'une échéance : ISO, « jj/mm/aaaa » ou « 30 nov. 2026 » (le texte libre des anciens besoins) ; null si ce n'est pas une date.
DateTime? parseDate(Object? v) {
  final s = '${v ?? ''}'.trim();
  if (s.isEmpty) return null;
  final iso = DateTime.tryParse(s);
  if (iso != null) return iso.toLocal();
  final fr = RegExp(r'^(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4})$').firstMatch(s);
  if (fr != null) return _valid(int.parse(fr.group(3)!), int.parse(fr.group(2)!), int.parse(fr.group(1)!));
  final txt = RegExp(r'^(\d{1,2})(?:er)?\s+([A-Za-zÀ-ÿ]+)\.?\s+(\d{4})$').firstMatch(s);
  if (txt != null) {
    final w = txt.group(2)!.toLowerCase().replaceAll(RegExp('[éèê]'), 'e').replaceAll('û', 'u').replaceAll('ô', 'o');
    var m = _moisCourts.indexOf(w.length >= 3 ? w.substring(0, 3) : w) + 1;
    if (w.startsWith('juil')) m = 7;
    if (w.startsWith('juin')) m = 6;
    if (m > 0) return _valid(int.parse(txt.group(3)!), m, int.parse(txt.group(1)!));
  }
  return null;
}

DateTime? _valid(int y, int m, int d) {
  final t = DateTime(y, m, d);
  return t.year == y && t.month == m && t.day == d ? t : null;
}

/// Échéance d'un besoin : la date réelle calculée par le serveur, à défaut le texte saisi.
DateTime? deadlineOf(Map<String, dynamic> m) => parseDate(m['deadline_date']) ?? parseDate(m['deadline']);

String dateCourte(Object? iso) {
  final d = parseDate(iso);
  return d == null ? '—' : '${d.day} ${_mois[d.month - 1]} ${d.year}';
}

/// « 1 jour », « 7 jours » ; « — » quand le délai est inconnu.
String daysLabel(Object? n) {
  final v = n is num ? n.toInt() : int.tryParse('$n');
  return v == null ? '—' : '$v jour${v > 1 ? 's' : ''}';
}

String proposalStatus(Object? s) => switch ('$s') { 'accepted' => 'Acceptée', 'rejected' || 'declined' => 'Refusée', 'pending' || 'submitted' => 'Reçue', 'withdrawn' => 'Retirée', _ => '$s' };
String missionStatus(Object? s) => switch ('$s') {
      'published' => 'Publié',
      'assigned' => 'Attribué',
      'in_progress' => 'En cours',
      'delivered' => 'Livré',
      'closed' || 'completed' || 'released' => 'Clôturé',
      'draft' => 'Brouillon',
      'cancelled' => 'Annulé',
      _ => '$s'
    };
String quoteStatus(Object? s) => switch ('$s') {
      'requested' => 'Demandé',
      'quoted' => 'Devis reçu',
      'accepted' => 'Accepté',
      'refused' || 'declined' || 'rejected' => 'Refusé',
      'cancelled' => 'Annulé',
      'expired' => 'Expiré',
      _ => '$s'
    };

class MobileList extends ConsumerWidget {
  const MobileList({
    super.key,
    required this.provider,
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.emptyText,
    this.onTap,
    this.onRow,
    this.where,
    this.selection,
    this.onToggle,
    this.width = 342,
    this.height = 520,
  });
  final NotifierProvider<RpcRows, List<Map<String, dynamic>>?> provider;
  final String Function(Map<String, dynamic>) title, subtitle;
  final String Function(Map<String, dynamic>)? trailing;
  final bool Function(Map<String, dynamic>)? where;
  final VoidCallback? onTap;

  /// Action d'une ligne (ouvrir la fiche) ; la ligne est alors annoncée comme un bouton.
  final void Function(BuildContext context, WidgetRef ref, Map<String, dynamic> row)? onRow;

  /// Cases à cocher (comparaison) : identifiants cochés et bascule d'une ligne ; les lignes sans identifiant n'ont pas de case.
  final Set<String>? selection;
  final void Function(String id)? onToggle;
  final String emptyText;
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget note(String t, {bool retry = false}) => Container(
          width: width,
          height: 190,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(t, textAlign: TextAlign.center, style: _st(13, c: _grey).copyWith(height: 1.5)),
            if (retry) TextButton(style: TextButton.styleFrom(minimumSize: const Size(48, 48)), onPressed: () => ref.invalidate(provider), child: Text('Réessayer', style: _st(13, w: FontWeight.w700, c: const Color(0xFF5A3FE0)))),
          ]),
        );
    final isPublic = ref.read(provider.notifier).publicRead;
    if (!isPublic && ref.watch(authProvider.select((a) => a.current == null))) return note('Connectez-vous pour voir cette liste.');
    final all = ref.watch(provider);
    if (all == null) return note('Chargement…');
    if (ref.read(provider.notifier).error) return note('Cette liste ne peut pas être chargée pour le moment.', retry: true);
    final rows = [for (final r in all) if (where == null || where!(r)) r];
    if (rows.isEmpty) return note(emptyText);
    return SizedBox(
      width: width,
      height: height,
      child: RefreshIndicator(
        onRefresh: () => ref.read(provider.notifier).refresh(),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: rows.length,
          separatorBuilder: (_, _) => const Divider(height: 4, thickness: 1, color: Color(0xFFF2EFF6)),
          itemBuilder: (_, i) {
            final r = rows[i];
            final id = '${r['id'] ?? ''}';
            final content = ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Row(children: [
                if (selection != null && onToggle != null && id.isNotEmpty)
                  SizedBox(width: 44, height: 48, child: Checkbox(value: selection!.contains(id), onChanged: (_) => onToggle!(id), semanticLabel: 'Sélectionner ${title(r)}')),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title(r), maxLines: 2, overflow: TextOverflow.ellipsis, style: _st(13.5, w: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(subtitle(r), maxLines: 3, overflow: TextOverflow.ellipsis, style: _st(11.5, c: _grey)),
                    ]),
                  ),
                ),
                if (trailing != null && trailing!(r).isNotEmpty) ...[
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFEEE9FF), borderRadius: BorderRadius.circular(11)), child: Text(trailing!(r), maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(11, w: FontWeight.w600, c: const Color(0xFF5A3FE0)))),
                  ),
                ],
                if (onRow != null) const Icon(Icons.chevron_right, size: 20, color: _grey),
              ]),
            );
            if (onRow == null && onTap == null) return content;
            return Semantics(
              button: true,
              child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onRow != null ? () => onRow!(context, ref, r) : onTap, child: content),
            );
          },
        ),
      ),
    );
  }
}

String _money(Object? v) => fcfa(((v as num?) ?? 0).toInt());

Widget proposalsList({double height = 520}) => MobileList(
      provider: companyProposalsProvider,
      height: height,
      title: (r) => '${r['author']}',
      subtitle: (r) => '${_money(r['amount'])} · ${daysLabel(r['delay_days'])} · ${r['mission']}',
      trailing: (r) => proposalStatus(r['status']),
      onRow: openProposal,
      emptyText: 'Aucune proposition reçue pour le moment.\nLes propositions apparaissent ici quand des étudiants répondent à vos besoins.',
    );

/// Date d'une ligne de besoin : brouillon créé, ou publié le…
String needDateLine(Map<String, dynamic> r) => '${'${r['status']}' == 'draft' ? 'Brouillon créé' : 'Publié'} le ${dateCourte(r['created_at'])}';

String proposalsCount(Object? n) {
  final v = n is num ? n.toInt() : int.tryParse('$n') ?? 0;
  return '$v proposition${v > 1 ? 's' : ''}';
}

Widget missionsHistory({double height = 520}) => MobileList(
      provider: companyMissionsProvider,
      height: height,
      title: (r) => '${r['title']}',
      subtitle: (r) => '${needDateLine(r)} · ${proposalsCount(r['proposals'])}',
      trailing: (r) => missionStatus(r['status']),
      emptyText: 'Vous n’avez publié aucun besoin pour le moment.',
    );

Widget collaborationsList({double height = 520}) => MobileList(
      provider: companyMissionsProvider,
      height: height,
      where: (r) => const ['assigned', 'in_progress', 'delivered'].contains('${r['status']}'),
      title: (r) => '${r['title']}',
      subtitle: (r) => ('${r['team']}'.isEmpty ? 'Équipe en cours d’attribution' : 'Équipe : ${r['team']}') + (deadlineOf(r) == null ? '' : ' · pour le ${dateCourte(deadlineOf(r))}'),
      trailing: (r) => missionStatus(r['status']),
      emptyText: 'Aucune collaboration en cours.\nUn besoin attribué à une équipe apparaît ici.',
    );

Widget quotesListWidget({double height = 520}) => MobileList(
      provider: quotesListProvider,
      height: height,
      title: (r) => '${r['brief']}',
      subtitle: (r) => r['quote_amount'] == null ? 'En attente de devis' : '${_money(r['quote_amount'])} · ${daysLabel(r['quote_delay_days'])}',
      trailing: (r) => quoteStatus(r['status']),
      emptyText: 'Aucune demande de devis pour le moment.',
    );

Widget contestsListWidget() => MobileList(
      provider: contestsListProvider,
      title: (r) => '${r['title']}',
      subtitle: (r) => [if (r['prize'] != null && '${r['prize']}'.isNotEmpty && '${r['prize']}' != '0') 'Prix : ${_money(r['prize'])}', if (r['reg_close_at'] != null) 'Inscriptions jusqu’au ${dateCourte(r['reg_close_at'])}', if (r['places'] != null) '${r['places']} places'].join(' · '),
      emptyText: 'Aucun défi ouvert pour le moment.',
    );

/// Recherche de talents (écran 91) : remplacée par le panneau réel [TalentSearchPanel] (recherche, filtres, pagination, vivier).
class TalentSearchList extends StatelessWidget {
  const TalentSearchList({super.key, this.width = 342, this.height = 500});
  final double width, height;

  @override
  Widget build(BuildContext context) => SizedBox(width: width, height: height, child: const TalentSearchPanel());
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

Widget innovationRegistryList() => const InnovationRegistry(width: 342, height: 548);

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
