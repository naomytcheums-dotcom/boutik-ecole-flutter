import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/paths.dart' show screenPath;
import '../gen.dart' show GChoiceGroup, GPos, GScreen, gConfirm, gP, gTap, gToast;
import '../i18n.dart' show Text;
import '../nav.dart';
import 'auth.dart';
import 'backend.dart';
import 'company_home.dart' show companyDashboardProvider;
import 'console.dart' show RpcRows;
import 'download_stub.dart' if (dart.library.js_interop) 'download_web.dart' show saveTextFile;
import 'entreprise.dart' show companyMissionsProvider, companyProposalsProvider, quotesListProvider;
import 'quote_negotiation.dart';
import 'store.dart' show fcfa;
import 'talent_search_panel.dart';
import 'tp_ui.dart';

/// Espace B2B de l'entreprise (écrans 187 Tableau de bord, 188 Recherche de talents, 189 Propositions reçues, 190 Devis et négociations,
/// 262 Accueil B2B). Sur téléphone (< 700 px) : vraie mise en page mobile (cartes et listes défilantes, cibles d'au moins 48 dp, aucun
/// défilement horizontal) sur les données réelles ; sur grand écran, la toile Figma est conservée mais débarrassée en production de tout
/// élément de maquette (voir [b2bProdCanvas]). Aucun chiffre ni nom de maquette : tout vient du serveur.

/// Devis envoyés ou reçus du compte (fonction serveur my_quotes : prestataire, validité, état de la commande).
final b2bQuotesProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => RpcRows('my_quotes'));

/// Appels serveur de cet espace, remplaçables dans les tests.
class B2bApi {
  const B2bApi();

  /// Décision sur une proposition reçue (decide_proposal) : null si le serveur a confirmé, sinon le message d'erreur.
  Future<String?> decide(String id, bool accept) async {
    final r = await Backend.rpc('decide_proposal', {'p_id': id, 'p_accept': accept});
    if (r.error != null) return Backend.userMessage(r.error!);
    final expected = accept ? 'accepted' : 'declined';
    return r.data == expected ? null : 'Le serveur n’a pas confirmé la décision. Actualisez la liste avant de réessayer.';
  }

  /// Fiche complète d'une proposition (auteur, message, budget du besoin) ; null si indisponible.
  Future<Map<String, dynamic>?> proposalDetail(String id) async {
    final r = await Backend.rpc('company_proposal_detail', {'p_id': id});
    return r.error == null && r.data is Map ? Map<String, dynamic>.from(r.data as Map) : null;
  }

  /// Enregistre un fichier texte ; vrai si le navigateur l'a téléchargé, faux si le contenu a seulement été copié.
  Future<bool> saveText(String name, String content, String mime) => saveTextFile(name, content, mime);
}

final b2bApiProvider = Provider<B2bApi>((ref) => const B2bApi());

// ------------------------------------------------------------------ libellés et formats

/// « 80 000 FCFA » ; « — » quand le montant est inconnu.
String b2bMoney(Object? v) {
  final n = v is num ? v : num.tryParse('$v');
  return n == null ? '—' : fcfa(n);
}

/// « 1 jour », « 7 jours ».
String b2bDays(Object? v) {
  final n = v is num ? v.toInt() : int.tryParse('$v');
  return n == null ? '—' : '$n jour${n > 1 ? 's' : ''}';
}

String b2bProposalStatus(Object? s) => switch ('$s') {
      'submitted' || 'pending' => 'À examiner',
      'accepted' => 'Acceptée',
      'declined' || 'rejected' => 'Refusée',
      'withdrawn' => 'Retirée',
      _ => 'Statut non reconnu',
    };

String b2bMissionStatus(Object? s) => switch ('$s') {
      'published' => 'Ouvert',
      'assigned' => 'Attribué',
      'in_progress' => 'En cours',
      'delivered' => 'Livré',
      'closed' || 'completed' || 'released' => 'Clôturé',
      'draft' => 'Brouillon',
      'cancelled' => 'Annulé',
      _ => 'Statut non reconnu',
    };

String b2bQuoteStatus(Object? s) => switch ('$s') {
      'requested' => 'Demandé',
      'quoted' => 'Devis reçu',
      'accepted' => 'Accepté',
      'declined' => 'Refusé',
      'rejected' => 'Décliné par le prestataire',
      'cancelled' => 'Annulé',
      'expired' => 'Expiré',
      _ => 'Statut non reconnu',
    };

enum _Tone { ok, warn, bad, info, neutral }

_Tone _toneOf(String s) => switch (s) {
      'accepted' || 'published' || 'closed' || 'delivered' => _Tone.ok,
      'submitted' || 'pending' || 'quoted' || 'requested' => _Tone.warn,
      'declined' || 'rejected' || 'cancelled' || 'expired' => _Tone.bad,
      'assigned' || 'in_progress' => _Tone.info,
      _ => _Tone.neutral,
    };

const _mois = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

/// « 20 nov. 2026 » ; vide quand la date est absente.
String b2bDate(Object? iso) {
  final d = DateTime.tryParse('${iso ?? ''}');
  if (d == null) return '';
  final l = iso.toString().length > 10 ? d.toLocal() : d;
  return '${l.day} ${_mois[l.month - 1]} ${l.year}';
}

// ------------------------------------------------------------------ indicateurs réels

/// Indicateurs calculés sur les besoins, propositions et devis réellement reçus du serveur.
class B2bStats {
  const B2bStats({
    required this.needsOpen,
    required this.needsFilled,
    required this.needsDraft,
    required this.proposalsTotal,
    required this.proposalsPending,
    required this.proposalsAccepted,
    required this.proposalsDeclined,
    required this.deadlinesSoon,
    this.quotesWaiting,
    this.quotesReceived,
  });

  /// Besoins publiés et ouverts aux propositions.
  final int needsOpen;

  /// Besoins pourvus : attribués, en cours, livrés ou clôturés.
  final int needsFilled;
  final int needsDraft, proposalsTotal, proposalsPending, proposalsAccepted, proposalsDeclined;

  /// Besoins attribués ou ouverts dont l'échéance tombe dans les 7 jours.
  final int deadlinesSoon;

  /// Demandes sans réponse / devis reçus à valider ; null quand la liste des devis n'a pas pu être lue.
  final int? quotesWaiting, quotesReceived;

  factory B2bStats.from({required List<Map<String, dynamic>> missions, required List<Map<String, dynamic>> proposals, List<Map<String, dynamic>>? quotes, DateTime? now}) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    int count(Iterable<Map<String, dynamic>> l, bool Function(String s) f) => l.where((m) => f('${m['status']}')).length;
    final live = missions.where((m) => '${m['status']}' != 'cancelled').toList();
    final soon = live.where((m) {
      if (!const {'published', 'assigned', 'in_progress'}.contains('${m['status']}')) return false;
      final d = DateTime.tryParse('${m['deadline'] ?? ''}');
      if (d == null) return false;
      final day = DateTime(d.year, d.month, d.day);
      return !day.isBefore(today) && day.difference(today).inDays <= 7;
    }).length;
    return B2bStats(
      needsOpen: count(live, (s) => s == 'published'),
      needsFilled: count(live, const {'assigned', 'in_progress', 'delivered', 'closed', 'completed', 'released'}.contains),
      needsDraft: count(live, (s) => s == 'draft'),
      proposalsTotal: proposals.length,
      proposalsPending: count(proposals, (s) => s == 'submitted' || s == 'pending'),
      proposalsAccepted: count(proposals, (s) => s == 'accepted'),
      proposalsDeclined: count(proposals, (s) => s == 'declined' || s == 'rejected'),
      deadlinesSoon: soon,
      quotesWaiting: quotes == null ? null : count(quotes, (s) => s == 'requested'),
      quotesReceived: quotes == null ? null : count(quotes, (s) => s == 'quoted'),
    );
  }
}

/// Devis demandés par le compte (ceux où il est prestataire relèvent de l'espace vendeur).
List<Map<String, dynamic>> b2bMyQuotes(List<Map<String, dynamic>> all) {
  final me = Backend.userId;
  if (me == null) return all;
  return [for (final q in all) if (q['requester_id'] == null || '${q['requester_id']}' == me) q];
}

/// Nom de l'entreprise (fiche vérifiée ou en cours), à défaut le nom du compte.
String b2bCompanyName(WidgetRef ref) {
  final d = ref.watch(companyDashboardProvider).asData?.value;
  final n = '${d?['company_name'] ?? ''}'.trim();
  if (n.isNotEmpty) return n;
  return ref.watch(profileAccountProvider).name.trim();
}

// ------------------------------------------------------------------ actualisation réelle

/// Relit réellement besoins, propositions et devis ; vrai si toutes les lectures ont réussi.
Future<bool> b2bReload(WidgetRef ref) async {
  final m = ref.read(companyMissionsProvider.notifier);
  final p = ref.read(companyProposalsProvider.notifier);
  final q = ref.read(b2bQuotesProvider.notifier);
  final l = ref.read(quotesListProvider.notifier);
  ref.invalidate(companyDashboardProvider);
  await Future.wait([m.refresh(), p.refresh(), q.refresh(), l.refresh()]);
  return !(m.error || p.error || q.error || l.error);
}

String _hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// « Actualiser » : le message de réussite n'est affiché qu'après une relecture réelle.
Future<void> b2bRefresh(BuildContext context, WidgetRef ref) async {
  if (!Backend.ready) return gToast(context, 'Données d’exemple : aucun serveur à relire.');
  if (ref.read(authProvider).current == null) return gToast(context, 'Connectez-vous pour actualiser vos données.');
  final ok = await b2bReload(ref);
  if (!context.mounted) return;
  gToast(context, ok ? 'Données relues sur le serveur à ${_hm(DateTime.now())}' : 'Actualisation incomplète : une liste n’a pas pu être relue. Réessayez dans un instant.');
}

// ------------------------------------------------------------------ export CSV

String b2bCsv(List<String> header, List<List<String>> rows) {
  String cell(String v) {
    final safe = v.startsWith('=') || v.startsWith('+') || v.startsWith('-') || v.startsWith('@') ? '\'$v' : v;
    return '"${safe.replaceAll('"', '""')}"';
  }

  return [header, ...rows].map((r) => r.map(cell).join(';')).join('\r\n');
}

Future<void> _export(BuildContext context, WidgetRef ref, String file, List<String> header, List<List<String>> rows) async {
  if (rows.isEmpty) return gToast(context, 'Aucune donnée à exporter pour le moment.');
  final saved = await ref.read(b2bApiProvider).saveText(file, b2bCsv(header, rows), 'text/csv');
  if (!context.mounted) return;
  gToast(context, saved ? 'Fichier $file téléchargé (${rows.length} ligne${rows.length > 1 ? 's' : ''}).' : 'Téléchargement indisponible sur cet appareil : le contenu CSV a été copié dans le presse-papiers.');
}

Future<void> b2bExportProposals(BuildContext context, WidgetRef ref) => _export(context, ref, 'propositions-recues.csv', ['Auteur', 'Besoin', 'Montant (FCFA)', 'Délai (jours)', 'Statut', 'Reçue le'], [
      for (final r in ref.read(companyProposalsProvider) ?? const <Map<String, dynamic>>[])
        ['${r['author'] ?? ''}', '${r['mission'] ?? ''}', '${(r['amount'] as num?)?.toInt() ?? ''}', '${r['delay_days'] ?? ''}', b2bProposalStatus(r['status']), b2bDate(r['created_at'])]
    ]);

Future<void> b2bExportNeeds(BuildContext context, WidgetRef ref) => _export(context, ref, 'besoins-publies.csv', ['Besoin', 'Statut', 'Propositions', 'Publié le', 'Échéance'], [
      for (final r in ref.read(companyMissionsProvider) ?? const <Map<String, dynamic>>[])
        if ('${r['status']}' != 'cancelled') ['${r['title'] ?? ''}', b2bMissionStatus(r['status']), '${r['proposals'] ?? 0}', b2bDate(r['created_at']), b2bDate(r['deadline'])]
    ]);

Future<void> b2bExportQuotes(BuildContext context, WidgetRef ref) => _export(context, ref, 'devis.csv', ['Demande', 'Prestataire', 'Montant (FCFA)', 'Délai (jours)', 'Statut', 'Demandé le'], [
      for (final r in b2bMyQuotes(ref.read(b2bQuotesProvider) ?? const <Map<String, dynamic>>[]))
        [_quoteTitle(r), '${r['provider_name'] ?? ''}', '${(r['quote_amount'] as num?)?.toInt() ?? ''}', '${r['quote_delay_days'] ?? ''}', b2bQuoteStatus(r['status']), b2bDate(r['created_at'])]
    ]);

String _quoteTitle(Map<String, dynamic> q) {
  final l = q['listings'];
  final t = l is Map ? '${l['title'] ?? ''}'.trim() : '';
  return t.isNotEmpty ? t : '${q['brief'] ?? 'Demande de devis'}';
}

// ------------------------------------------------------------------ briques d'interface

/// Zone tactile d'au moins 48 × 48 dp, avec libellé pour les lecteurs d'écran.
class B2bTap extends StatelessWidget {
  const B2bTap({super.key, required this.onTap, required this.child, this.label, this.minHeight = 48});
  final VoidCallback? onTap;
  final Widget child;
  final String? label;
  final double minHeight;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: ConstrainedBox(constraints: BoxConstraints(minHeight: minHeight, minWidth: 48), child: child)),
      );
}

Widget _pill(String label, _Tone tone) {
  final (bg, fg) = switch (tone) {
    _Tone.ok => (const Color(0xFFE8F7EE), tpGreen),
    _Tone.warn => (const Color(0xFFFFF3D6), const Color(0xFF8A5A00)),
    _Tone.bad => (const Color(0xFFFDE8E6), tpRed),
    _Tone.info => (const Color(0xFFEEE9FF), tpViolet),
    _Tone.neutral => (const Color(0xFFEFEEEC), tpGrey),
  };
  return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)), child: Text(label, style: tpSt(12, w: FontWeight.w600, c: fg)));
}

class _Note extends StatelessWidget {
  const _Note(this.text, {this.action, this.onAction});
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 12),
        child: Column(children: [
          Text(text, textAlign: TextAlign.center, style: tpSt(13.5, c: tpGrey, h: 1.5)),
          if (action != null && onAction != null) ...[const SizedBox(height: 16), TpButton(action!, onAction, dark: false)],
        ]),
      );
}

/// Liste défilante avec « tirer pour actualiser » (relecture réelle).
class _Scroll extends ConsumerWidget {
  const _Scroll({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) => RefreshIndicator(
        onRefresh: () => b2bReload(ref),
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: children),
      );
}

typedef _Feed = ({List<Map<String, dynamic>>? rows, bool failed});

_Feed _feed(WidgetRef ref, NotifierProvider<RpcRows, List<Map<String, dynamic>>?> p) {
  final rows = ref.watch(p);
  return (rows: rows, failed: rows != null && ref.read(p.notifier).error);
}

/// Message à la place du contenu quand le serveur ou le compte manque ; null quand les données peuvent être lues.
Widget? _gate(WidgetRef ref) {
  if (!Backend.ready) return const _Scroll(children: [_Note('Cet écran affiche vos données réelles : il nécessite la connexion au serveur.')]);
  if (ref.watch(authProvider.select((a) => a.current == null))) return const _Scroll(children: [_Note('Connectez-vous avec votre compte organisation pour voir cet écran.')]);
  return null;
}

Widget _loading() => const _Scroll(children: [_Note('Chargement…')]);

Widget _failed(WidgetRef ref) => _Scroll(children: [_Note('Cette liste ne peut pas être chargée pour le moment.', action: 'Réessayer', onAction: () => b2bReload(ref))]);

Widget _section(String title, {String? action, VoidCallback? onAction}) => Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(children: [
        Expanded(child: Text(title, style: tpSt(15.5, w: FontWeight.w700))),
        if (action != null) B2bTap(onTap: onAction, label: action, child: Padding(padding: const EdgeInsets.only(left: 12), child: Align(alignment: Alignment.centerRight, widthFactor: 1, child: Text(action, style: tpSt(13, w: FontWeight.w700, c: tpViolet))))),
      ]),
    );

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, required this.hint, required this.onTap, required this.width});
  final String label, value, hint;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: B2bTap(
          onTap: onTap,
          label: '$label : $value',
          minHeight: 96,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xCCFFFFFF), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white, width: 1.5)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: tpSt(12.5, c: tpGrey)),
              const SizedBox(height: 4),
              Text(value, style: tpSt(26, w: FontWeight.w800)),
              Text(hint, maxLines: 2, overflow: TextOverflow.ellipsis, style: tpSt(12, c: tpGrey)),
            ]),
          ),
        ),
      );
}

Widget _tiles(List<(String label, String value, String hint, VoidCallback onTap)> items) => LayoutBuilder(builder: (context, box) {
      final cols = box.maxWidth >= 860 ? 3 : 2;
      final w = (box.maxWidth - 12 * (cols - 1)) / cols;
      return Wrap(spacing: 12, runSpacing: 12, children: [for (final t in items) _Tile(label: t.$1, value: t.$2, hint: t.$3, onTap: t.$4, width: w)]);
    });

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.label, required this.hint, required this.onTap, required this.width, this.dark = false});
  final IconData icon;
  final String label, hint;
  final VoidCallback onTap;
  final double width;
  final bool dark;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: B2bTap(
          onTap: onTap,
          label: label,
          minHeight: 84,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: dark ? tpInk : const Color(0xCCFFFFFF), borderRadius: BorderRadius.circular(20), border: Border.all(color: dark ? tpInk : Colors.white, width: 1.5)),
            child: Row(children: [
              Icon(icon, size: 24, color: dark ? Colors.white : tpViolet),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: tpSt(14, w: FontWeight.w700, c: dark ? Colors.white : tpInk)),
                  Text(hint, maxLines: 2, overflow: TextOverflow.ellipsis, style: tpSt(12, c: dark ? const Color(0xFFD9D5E2) : tpGrey)),
                ]),
              ),
            ]),
          ),
        ),
      );
}

Widget _actions(List<(IconData, String, String, VoidCallback, bool)> items) => LayoutBuilder(builder: (context, box) {
      final cols = box.maxWidth >= 860 ? 3 : 2;
      final w = (box.maxWidth - 12 * (cols - 1)) / cols;
      return Wrap(spacing: 12, runSpacing: 12, children: [for (final a in items) _ActionCard(icon: a.$1, label: a.$2, hint: a.$3, onTap: a.$4, width: w, dark: a.$5)]);
    });

class _Chips extends StatelessWidget {
  const _Chips({required this.items, required this.selected, required this.onSelect});
  final List<(String id, String label)> items;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, children: [
        for (final (id, label) in items)
          B2bTap(
            onTap: () => onSelect(id),
            label: label,
            child: Center(
              widthFactor: 1,
              child: Container(
                height: 36,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: id == selected ? tpInk : const Color(0xB3FFFFFF), borderRadius: BorderRadius.circular(18), border: Border.all(color: id == selected ? tpInk : tpLine)),
                child: Text(label, style: tpSt(12.5, w: FontWeight.w600, c: id == selected ? Colors.white : tpInk)),
              ),
            ),
          ),
      ]);
}

Widget _row({required String title, required List<String> lines, required String status, required String statusKey, VoidCallback? onTap, String? semantics}) => B2bTap(
      onTap: onTap,
      label: semantics ?? title,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xCCFFFFFF), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white, width: 1.5)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: tpSt(14.5, w: FontWeight.w700)),
              for (final l in lines) if (l.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(l, maxLines: 2, overflow: TextOverflow.ellipsis, style: tpSt(12.5, c: tpGrey))),
            ]),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 120), child: _pill(status, _toneOf(statusKey))),
        ]),
      ),
    );

// ------------------------------------------------------------------ propositions

Widget _proposalRow(BuildContext context, WidgetRef ref, Map<String, dynamic> r) => _row(
      title: '${r['author'] ?? 'Candidat'}',
      lines: ['${r['mission'] ?? ''}', '${b2bMoney(r['amount'])} · ${b2bDays(r['delay_days'])}', if (b2bDate(r['created_at']).isNotEmpty) 'Reçue le ${b2bDate(r['created_at'])}'],
      status: b2bProposalStatus(r['status']),
      statusKey: '${r['status']}',
      semantics: 'Proposition de ${r['author']} pour ${r['mission']}',
      onTap: () => showB2bProposal(context, ref, r),
    );

/// Fiche d'une proposition : détails réels, profil de l'auteur, Accepter / Refuser avec confirmation.
Future<void> showB2bProposal(BuildContext context, WidgetRef ref, Map<String, dynamic> row) {
  final router = GoRouter.maybeOf(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFFF7F4FA),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _ProposalSheet(row: row, outer: context, router: router),
  );
}

class _ProposalSheet extends ConsumerStatefulWidget {
  const _ProposalSheet({required this.row, required this.outer, required this.router});
  final Map<String, dynamic> row;
  final BuildContext outer;
  final GoRouter? router;

  @override
  ConsumerState<_ProposalSheet> createState() => _ProposalSheetState();
}

class _ProposalSheetState extends ConsumerState<_ProposalSheet> {
  Map<String, dynamic>? _detail;
  bool _loaded = false, _busy = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final d = await ref.read(b2bApiProvider).proposalDetail('${widget.row['id']}');
      if (!mounted) return;
      setState(() {
        _detail = d;
        _loaded = true;
      });
    });
  }

  Map<String, dynamic> get _p => {...widget.row, ...?_detail};

  Future<void> _decide(bool accept) async {
    final p = _p;
    final who = '${p['author'] ?? 'ce talent'}';
    final ok = await gConfirm(
      context,
      accept ? 'Accepter cette proposition ?' : 'Refuser cette proposition ?',
      accept
          ? '$who sera retenu pour « ${p['mission']} » à ${b2bMoney(p['amount'])} en ${b2bDays(p['delay_days'])}. Le besoin lui est attribué.'
          : 'La proposition de $who pour « ${p['mission']} » sera refusée et son auteur en sera informé. Cette décision est définitive.',
      yes: accept ? 'Accepter' : 'Refuser',
    );
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    final err = await ref.read(b2bApiProvider).decide('${p['id']}', accept);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _err = err;
      });
      return;
    }
    await b2bReload(ref);
    if (!mounted) return;
    Navigator.of(context).pop();
    if (widget.outer.mounted) gToast(widget.outer, accept ? 'Proposition acceptée : le besoin est attribué.' : 'Proposition refusée : son auteur est prévenu.');
  }

  Widget _info(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 108, child: Text(k, style: tpSt(13, c: tpGrey))),
          Expanded(child: Text(v, style: tpSt(13.5, w: FontWeight.w600))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final status = '${p['status']}';
    final authorId = '${p['author_id'] ?? ''}';
    final msg = '${p['message'] ?? ''}'.trim();
    final min = p['budget_min'], max = p['budget_max'];
    final budget = min == null && max == null ? '' : (min != null && max != null ? '${b2bMoney(min)} – ${b2bMoney(max)}' : b2bMoney(max ?? min));
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(child: Text('${p['author'] ?? 'Candidat'}', style: tpSt(20, w: FontWeight.w800))),
            B2bTap(onTap: () => Navigator.of(context).pop(), label: 'Fermer', child: const Center(widthFactor: 1, child: Icon(Icons.close_rounded, size: 24, color: tpInk))),
          ]),
          Text('${p['mission'] ?? ''}', style: tpSt(14, c: tpGrey)),
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerLeft, child: _pill(b2bProposalStatus(status), _toneOf(status))),
          const SizedBox(height: 10),
          _info('Montant proposé', b2bMoney(p['amount'])),
          _info('Délai', b2bDays(p['delay_days'])),
          if (budget.isNotEmpty) _info('Budget du besoin', budget),
          if (b2bDate(p['deadline']).isNotEmpty) _info('Échéance du besoin', b2bDate(p['deadline'])),
          if (b2bDate(p['created_at']).isNotEmpty) _info('Reçue le', b2bDate(p['created_at'])),
          if (b2bDate(p['decided_at']).isNotEmpty) _info('Décidée le', b2bDate(p['decided_at'])),
          const SizedBox(height: 8),
          Text('Message du talent', style: tpSt(13, w: FontWeight.w700)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: tpLine)),
            child: Text(msg.isNotEmpty ? msg : (!_loaded ? 'Chargement du message…' : (_detail == null ? 'Le message n’a pas pu être chargé pour le moment.' : 'Aucun message joint à cette proposition.')), style: tpSt(13.5, c: msg.isEmpty ? tpGrey : tpInk, h: 1.45)),
          ),
          const SizedBox(height: 16),
          if (authorId.isNotEmpty && widget.router != null) ...[
            TpButton('Voir le profil', () => widget.router!.push('/etudiant/$authorId'), dark: false, icon: Icons.person_outline_rounded),
            const SizedBox(height: 10),
          ],
          if (_err != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFDE8E6), borderRadius: BorderRadius.circular(14)),
              child: Text(_err!, style: tpSt(13, w: FontWeight.w600, c: tpRed, h: 1.4)),
            ),
            const SizedBox(height: 10),
          ],
          if (status == 'submitted' || status == 'pending') ...[
            TpButton('Accepter la proposition', _busy ? null : () => _decide(true), busy: _busy, icon: Icons.check_rounded),
            const SizedBox(height: 10),
            TpButton('Refuser', _busy ? null : () => _decide(false), dark: false, danger: true),
          ] else
            Text('Cette proposition est déjà traitée : aucune décision n’est possible.', style: tpSt(12.5, c: tpGrey, h: 1.4)),
        ]),
      ),
    );
  }
}

/// 189 : propositions reçues, filtrées par statut.
class B2bProposalsContent extends ConsumerStatefulWidget {
  const B2bProposalsContent({super.key});
  @override
  ConsumerState<B2bProposalsContent> createState() => _B2bProposalsContentState();
}

class _B2bProposalsContentState extends ConsumerState<B2bProposalsContent> {
  String _filter = 'all';

  bool _match(Map<String, dynamic> r) {
    final s = '${r['status']}';
    return switch (_filter) {
      'pending' => s == 'submitted' || s == 'pending',
      'accepted' => s == 'accepted',
      'declined' => s == 'declined' || s == 'rejected',
      'withdrawn' => s == 'withdrawn',
      _ => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final gate = _gate(ref);
    if (gate != null) return gate;
    final f = _feed(ref, companyProposalsProvider);
    if (f.rows == null) return _loading();
    if (f.failed) return _failed(ref);
    final all = f.rows!;
    int n(bool Function(Map<String, dynamic>) t) => all.where(t).length;
    final st = B2bStats.from(missions: const [], proposals: all);
    final shown = [for (final r in all) if (_match(r)) r];
    return _Scroll(children: [
      _Chips(
        selected: _filter,
        onSelect: (v) => setState(() => _filter = v),
        items: [
          ('all', 'Toutes (${all.length})'),
          ('pending', 'À examiner (${st.proposalsPending})'),
          ('accepted', 'Acceptées (${st.proposalsAccepted})'),
          ('declined', 'Refusées (${st.proposalsDeclined})'),
          if (n((r) => '${r['status']}' == 'withdrawn') > 0) ('withdrawn', 'Retirées (${n((r) => '${r['status']}' == 'withdrawn')})'),
        ],
      ),
      const SizedBox(height: 12),
      if (all.isEmpty)
        TpEmpty(title: 'Aucune proposition reçue', text: 'Les propositions apparaissent ici quand des étudiants répondent à vos besoins.', action: 'Publier un besoin', onAction: () => gOpen(context, '90'), icon: Icons.inbox_outlined)
      else if (shown.isEmpty)
        const _Note('Aucune proposition dans cette catégorie.')
      else
        for (final r in shown) _proposalRow(context, ref, r),
    ]);
  }
}

// ------------------------------------------------------------------ devis

/// 190 : devis demandés, avec onglets par statut réel.
class B2bQuotesContent extends ConsumerStatefulWidget {
  const B2bQuotesContent({super.key});
  @override
  ConsumerState<B2bQuotesContent> createState() => _B2bQuotesContentState();
}

class _B2bQuotesContentState extends ConsumerState<B2bQuotesContent> {
  String _filter = 'all';

  bool _match(Map<String, dynamic> r) {
    final s = '${r['status']}';
    return switch (_filter) {
      'requested' => s == 'requested',
      'quoted' => s == 'quoted',
      'accepted' => s == 'accepted',
      'closed' => const {'declined', 'rejected', 'cancelled', 'expired'}.contains(s),
      _ => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final gate = _gate(ref);
    if (gate != null) return gate;
    final f = _feed(ref, b2bQuotesProvider);
    if (f.rows == null) return _loading();
    if (f.failed) return _failed(ref);
    final all = b2bMyQuotes(f.rows!);
    int n(bool Function(String s) t) => all.where((r) => t('${r['status']}')).length;
    final shown = [for (final r in all) if (_match(r)) r];
    return _Scroll(children: [
      _Chips(
        selected: _filter,
        onSelect: (v) => setState(() => _filter = v),
        items: [
          ('all', 'Tous (${all.length})'),
          ('requested', 'En attente (${n((s) => s == 'requested')})'),
          ('quoted', 'Devis reçus (${n((s) => s == 'quoted')})'),
          ('accepted', 'Acceptés (${n((s) => s == 'accepted')})'),
          ('closed', 'Clos (${n(const {'declined', 'rejected', 'cancelled', 'expired'}.contains)})'),
        ],
      ),
      const SizedBox(height: 12),
      if (all.isEmpty)
        const TpEmpty(title: 'Aucune demande de devis', text: 'Vos demandes de devis aux prestataires de services, et leurs réponses, apparaissent ici.', icon: Icons.request_quote_outlined)
      else if (shown.isEmpty)
        const _Note('Aucun devis dans cette catégorie.')
      else
        for (final r in shown)
          _row(
            title: _quoteTitle(r),
            lines: [
              if ('${r['provider_name'] ?? ''}'.isNotEmpty) 'Prestataire : ${r['provider_name']}',
              r['quote_amount'] == null ? 'En attente de la réponse du prestataire' : '${b2bMoney(r['quote_amount'])} · ${b2bDays(r['quote_delay_days'])}',
              if ('${r['status']}' == 'quoted' && b2bDate(r['valid_until']).isNotEmpty) 'Valable jusqu’au ${b2bDate(r['valid_until'])}',
              if ('${r['status']}' == 'rejected' && '${r['decline_reason'] ?? ''}'.isNotEmpty) 'Motif : ${r['decline_reason']}',
              if (b2bDate(r['created_at']).isNotEmpty) 'Demandé le ${b2bDate(r['created_at'])}',
            ],
            status: b2bQuoteStatus(r['status']),
            statusKey: '${r['status']}',
            semantics: 'Devis ${_quoteTitle(r)}',
            onTap: () => openQuoteNegotiation(context, ref, r),
          ),
    ]);
  }
}

// ------------------------------------------------------------------ tableau de bord (187) et accueil B2B (262)

Widget _needRow(Map<String, dynamic> r) => _row(
      title: '${r['title'] ?? ''}',
      lines: [
        '${r['proposals'] ?? 0} proposition${((r['proposals'] as num?) ?? 0) > 1 ? 's' : ''}${b2bDate(r['created_at']).isEmpty ? '' : ' · publié le ${b2bDate(r['created_at'])}'}',
        if (b2bDate(r['deadline']).isNotEmpty) 'Échéance : ${b2bDate(r['deadline'])}',
      ],
      status: b2bMissionStatus(r['status']),
      statusKey: '${r['status']}',
    );

/// Résumé réel : indicateurs, accès rapides, dernières propositions et besoins. [home] : version « Accueil B2B » (262) avec les accès de publication.
class B2bSummaryContent extends ConsumerWidget {
  const B2bSummaryContent({super.key, this.home = false});
  final bool home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gate = _gate(ref);
    if (gate != null) return gate;
    final m = _feed(ref, companyMissionsProvider), p = _feed(ref, companyProposalsProvider);
    if (m.rows == null || p.rows == null) return _loading();
    if (m.failed && p.failed) return _failed(ref);
    final q = _feed(ref, b2bQuotesProvider);
    final quotes = q.rows == null || q.failed ? null : b2bMyQuotes(q.rows!);
    // Une liste illisible n'invente aucun chiffre : ses indicateurs affichent « — » et l'autre liste reste visible.
    final mRows = m.failed ? const <Map<String, dynamic>>[] : m.rows!, pRows = p.failed ? const <Map<String, dynamic>>[] : p.rows!;
    final st = B2bStats.from(missions: mRows, proposals: pRows, quotes: quotes);
    String qn(int? v) => v == null ? '—' : '$v';
    String mn(int v) => m.failed ? '—' : '$v';
    String pn(int v) => p.failed ? '—' : '$v';
    final needs = [for (final r in mRows) if ('${r['status']}' != 'cancelled') r];
    final upcoming = [
      for (final r in needs)
        if (const {'published', 'assigned', 'in_progress'}.contains('${r['status']}') && DateTime.tryParse('${r['deadline'] ?? ''}') != null) r
    ]..sort((a, b) => '${a['deadline']}'.compareTo('${b['deadline']}'));
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final future = [for (final r in upcoming) if ('${r['deadline']}'.substring(0, 10).compareTo(today) >= 0) r];
    final nothing = !m.failed && !p.failed && needs.isEmpty && pRows.isEmpty;
    return _Scroll(children: [
      if (home) ...[
        _actions([
          (Icons.add_circle_outline_rounded, 'Publier un besoin', 'Décrivez votre projet', () => gOpen(context, '90'), true),
          (Icons.groups_2_outlined, 'Rechercher des talents', 'Par compétence ou filière', () => gTab(context, '188'), false),
          (Icons.emoji_events_outlined, 'Lancer un défi', 'Concours ou hackathon', () => GoRouter.of(context).push('/concours/publier'), false),
          (Icons.work_outline_rounded, 'Publier une offre', 'Stage ou recrutement', () => GoRouter.of(context).push('/opportunites/publier'), false),
        ]),
        const SizedBox(height: 16),
      ],
      _tiles([
        ('Propositions à examiner', pn(st.proposalsPending), p.failed ? 'lecture impossible' : '${st.proposalsTotal} reçue${st.proposalsTotal > 1 ? 's' : ''} au total', () => gTab(context, '189')),
        ('Besoins ouverts', mn(st.needsOpen), m.failed ? 'lecture impossible' : (st.needsDraft > 0 ? '${st.needsDraft} brouillon${st.needsDraft > 1 ? 's' : ''}' : 'publiés'), () => gOpen(context, '99')),
        ('Besoins pourvus', mn(st.needsFilled), 'attribués ou terminés', () => gOpen(context, '98')),
        ('Devis reçus', qn(st.quotesReceived), 'à valider', () => gTab(context, '190')),
        ('Devis en attente', qn(st.quotesWaiting), 'sans réponse', () => gTab(context, '190')),
        ('Échéances sous 7 jours', mn(st.deadlinesSoon), 'besoins à suivre', () => gOpen(context, '99')),
      ]),
      if (pRows.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text('Propositions : ${st.proposalsPending} à examiner · ${st.proposalsAccepted} acceptée${st.proposalsAccepted > 1 ? 's' : ''} · ${st.proposalsDeclined} refusée${st.proposalsDeclined > 1 ? 's' : ''}', style: tpSt(12.5, c: tpGrey, h: 1.4)),
      ],
      if (!home && !nothing) ...[
        const SizedBox(height: 16),
        _actions([
          (Icons.add_circle_outline_rounded, 'Publier un besoin', 'Décrivez votre projet', () => gOpen(context, '90'), true),
          (Icons.groups_2_outlined, 'Rechercher des talents', 'Par compétence ou filière', () => gTab(context, '188'), false),
        ]),
      ],
      if (nothing)
        TpEmpty(title: 'Rien à suivre pour le moment', text: 'Publiez votre premier besoin : les étudiants et équipes vous répondent par des propositions.', action: 'Publier un besoin', onAction: () => gOpen(context, '90'), icon: Icons.rocket_launch_outlined)
      else ...[
        LayoutBuilder(builder: (context, box) {
          final props = <Widget>[
            _section('Dernières propositions', action: pRows.isEmpty ? null : 'Voir tout', onAction: () => gTab(context, '189')),
            const SizedBox(height: 8),
            if (p.failed) _Note('Les propositions n’ont pas pu être chargées.', action: 'Réessayer', onAction: () => b2bReload(ref)) else if (pRows.isEmpty) const _Note('Aucune proposition reçue pour le moment.') else for (final r in pRows.take(home ? 5 : 3)) _proposalRow(context, ref, r),
          ];
          if (home) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: props);
          final needsCol = <Widget>[
            _section('Besoins récents', action: needs.isEmpty ? null : 'Voir tout', onAction: () => gOpen(context, '99')),
            const SizedBox(height: 8),
            if (m.failed) _Note('Les besoins n’ont pas pu être chargés.', action: 'Réessayer', onAction: () => b2bReload(ref)) else if (needs.isEmpty) const _Note('Vous n’avez publié aucun besoin pour le moment.') else for (final r in needs.take(5)) _needRow(r),
            if (future.isNotEmpty) ...[
              _section('Prochaines échéances'),
              const SizedBox(height: 8),
              for (final r in future.take(3)) _row(title: '${r['title']}', lines: ['Pour le ${b2bDate(r['deadline'])}'], status: b2bMissionStatus(r['status']), statusKey: '${r['status']}'),
            ],
          ];
          // Grand écran : besoins et propositions côte à côte ; téléphone : l'un sous l'autre.
          if (box.maxWidth >= 860) {
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: needsCol)),
              const SizedBox(width: 20),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: props)),
            ]);
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [...props, ...needsCol]);
        }),
      ],
    ]);
  }
}

// ------------------------------------------------------------------ recherche de talents (188)

/// 188 : recherche de talents réelle ([TalentSearchPanel] : champ de recherche, filtres, pagination, listes du vivier). Aucune carte inventée.
class B2bTalentsContent extends ConsumerWidget {
  const B2bTalentsContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gate = _gate(ref);
    if (gate != null) return gate;
    return const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 0), child: TalentSearchPanel());
  }
}

// ------------------------------------------------------------------ coque téléphone

/// Entrées du menu « Plus » : route (écran de la maquette ou chemin) et libellé.
const _moreEntries = <(IconData, String, String)>[
  (Icons.add_circle_outline_rounded, 'Publier un besoin', '90'),
  (Icons.manage_search_rounded, 'Recherche de talents plein écran', '91'),
  (Icons.home_work_outlined, 'Accueil B2B', '262'),
  (Icons.list_alt_rounded, 'Besoins publiés', '99'),
  (Icons.handshake_outlined, 'Collaborations', '98'),
  (Icons.emoji_events_outlined, 'Défis et hackathons', '96'),
  (Icons.how_to_reg_outlined, 'Recrutement', '97'),
  (Icons.business_rounded, 'Fiche de l’organisation', '/entreprise/profil'),
  (Icons.groups_outlined, 'Équipe de l’organisation', '/entreprise/equipe'),
  (Icons.settings_outlined, 'Paramètres', '/parametres/informations'),
  (Icons.help_outline_rounded, 'Aide et retours', '/aide/contact'),
  (Icons.apps_rounded, 'Toutes mes rubriques', '/espace'),
];

void showB2bMenu(BuildContext context) {
  final router = GoRouter.of(context);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFFF7F4FA),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheet) => ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
      Padding(padding: const EdgeInsets.only(bottom: 8, left: 4), child: Text('Espace organisation', style: tpSt(17, w: FontWeight.w800))),
      for (final (icon, label, target) in _moreEntries)
        B2bTap(
          label: label,
          minHeight: 56,
          onTap: () {
            Navigator.of(sheet).pop();
            router.push(target.startsWith('/') ? target : screenPath(target));
          },
          child: Row(children: [
            Icon(icon, size: 22, color: tpViolet),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: tpSt(14.5, w: FontWeight.w600))),
            const Icon(Icons.chevron_right_rounded, color: tpGrey),
          ]),
        ),
    ]),
  );
}

/// Mise en page mobile native des écrans entreprise : en-tête (titre, actualiser, exporter), contenu défilant, barre de navigation du bas.
class B2bPhoneShell extends ConsumerWidget {
  const B2bPhoneShell({super.key, required this.current, required this.title, required this.subtitle, required this.child, this.onExport});

  /// Écran affiché : '187', '189', '190', '188' ou '262' (menu « Plus »).
  final String current;
  final String title, subtitle;
  final Widget child;
  final void Function(BuildContext, WidgetRef)? onExport;

  static const _tabs = <(String id, IconData icon, String label)>[
    ('187', Icons.dashboard_outlined, 'Tableau'),
    ('189', Icons.inbox_outlined, 'Propositions'),
    ('190', Icons.request_quote_outlined, 'Devis'),
    ('188', Icons.groups_2_outlined, 'Talents'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inTabs = _tabs.any((t) => t.$1 == current);
    return Scaffold(
      backgroundColor: const Color(0xFFF4EFE6),
      resizeToAvoidBottomInset: true,
      body: DecoratedBox(
        decoration: tpBackground,
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 4, 2),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: tpSt(21, w: FontWeight.w800)),
                    if (subtitle.isNotEmpty) Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: tpSt(12.5, c: tpGrey)),
                  ]),
                ),
                if (onExport != null) B2bTap(onTap: () => onExport!(context, ref), label: 'Exporter en CSV', child: const Center(widthFactor: 1, child: Icon(Icons.file_download_outlined, color: tpInk))),
                B2bTap(onTap: () => b2bRefresh(context, ref), label: 'Actualiser', child: const Center(widthFactor: 1, child: Icon(Icons.refresh_rounded, color: tpInk))),
              ]),
            ),
            Expanded(child: child),
            Container(
              decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: tpLine))),
              child: Row(children: [
                for (final (id, icon, label) in _tabs) Expanded(child: _tab(context, icon, label, id == current, id == current ? null : () => gTab(context, id))),
                Expanded(child: _tab(context, Icons.more_horiz_rounded, 'Plus', !inTabs, () => showB2bMenu(context))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, IconData icon, String label, bool on, VoidCallback? onTap) => B2bTap(
        onTap: onTap,
        label: label,
        minHeight: 60,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 24, color: on ? tpViolet : tpGrey),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tpSt(12, w: on ? FontWeight.w700 : FontWeight.w500, c: on ? tpViolet : tpGrey)),
        ]),
      );
}

/// Vrai sur téléphone : la mise en page native remplace la toile Figma (les captures de maquette gardent la toile).
bool b2bIsPhone(BuildContext context) => !GScreen.mockupFrame && MediaQuery.sizeOf(context).width < 700;

// ------------------------------------------------------------------ toile large : retrait des éléments de maquette en production

Rect? _rectOf(Widget w) {
  if (w is GPos) return w.rect;
  if (w is Positioned && w.left != null && w.top != null && w.width != null && w.height != null) return Rect.fromLTWH(w.left!, w.top!, w.width!, w.height!);
  return null;
}

/// Toile de bureau en production : retire les zones [drop] (décors de maquette, cadres vides, avatars, faux boutons), le contenu
/// fictif de [content], tous les liens du menu latéral ([sideWidth]) pour les remplacer par de vrais liens, et les groupes de pastilles.
List<Widget> b2bProdCanvas(List<Widget> src, {required Rect content, required double sideWidth, List<Rect> drop = const []}) {
  final out = <Widget>[];
  for (final w in src) {
    if (w is Positioned && w.child is GChoiceGroup) continue;
    final r = _rectOf(w);
    if (r == null) {
      out.add(w);
      continue;
    }
    final c = r.center;
    if (content.contains(c) || drop.any((d) => d.contains(c))) continue;
    if (w is GPos && w.tap && c.dx < sideWidth && r.top >= 56) continue;
    out.add(w);
  }
  return out;
}

/// Liens réels du menu latéral : (ordonnée du libellé, destination).
List<Widget> b2bSideTaps(BuildContext context, double width, List<(double, String)> items) => [
      for (final (y, id) in items) gTap(8, y - 9, width - 16, 34, () => id.startsWith('/') ? GoRouter.of(context).push(id) : (const {'187', '188', '189', '190', '262'}.contains(id) ? gTab(context, id) : gOpen(context, id))),
    ];

/// Carte utilisateur du menu latéral : nom de l'entreprise puis nom du compte.
Widget b2bSideUser(double x, double y) => gP(
      x,
      y,
      120,
      32,
      Consumer(builder: (context, ref, _) {
        final company = b2bCompanyName(ref);
        final account = ref.watch(profileAccountProvider).name.trim();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(company.isEmpty ? 'Mon organisation' : company, maxLines: 1, overflow: TextOverflow.ellipsis, style: tpSt(11.5, w: FontWeight.w600)),
          Text(account == company ? 'Compte organisation' : account, maxLines: 1, overflow: TextOverflow.ellipsis, style: tpSt(9.5, c: tpGrey)),
        ]);
      }),
    );

/// Bouton « Exporter » réel de l'en-tête (remplace la pastille sans effet de la maquette).
Widget b2bExportPill(double x, void Function(BuildContext, WidgetRef) action) => gP(
      x,
      10,
      120,
      36,
      Consumer(
        builder: (context, ref, _) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => action(context, ref),
          child: Container(alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFF0B0B0D), borderRadius: BorderRadius.circular(18)), child: Text('Exporter en CSV', style: tpSt(12, w: FontWeight.w600, c: Colors.white))),
        ),
      ),
    );

/// Contenu réel de la toile large : posé dans la zone libérée, avec défilement propre.
Widget b2bWide(double x, double y, double w, double h, Widget content) => gP(x, y, w, h, ClipRect(child: DefaultTextStyle(style: tpSt(14), child: content)));
