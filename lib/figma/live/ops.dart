import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart';
import '../nav.dart';
import 'audit.dart';
import 'auth.dart';
import 'backend.dart';
import 'feedback.dart';
import 'seller.dart';
import 'store.dart';
import 'talents.dart';

/// Exploitation : signalements (131, 170), commissions (135), supervision des commandes (132),
/// validation des projets (111).

const _st = TextStyle(inherit: false, fontFamily: 'PlusJakartaSans', fontSize: 13, color: Color(0xFF111015), textBaseline: TextBaseline.alphabetic);

// ------------------------------------------------------------------ signalements

class Report {
  const Report(this.title, this.type, this.received, this.assignee, this.status, {this.listing = '', this.id = '', this.listingId = ''});
  final String title, type, received, assignee, status, listing;

  /// Annonce signalée (listings.id), pour son retrait par la modération.
  final String listingId;

  /// Identifiant serveur (listing_reports.id) ; vide pour les signalements d'exemple hors connexion.
  final String id;
  Report copy({String? assignee, String? status}) => Report(title, type, received, assignee ?? this.assignee, status ?? this.status, listing: listing, id: id, listingId: listingId);
}

/// Statuts serveur (listing_reports.status) et libellés affichés.
const _reportStatusLabels = {'open': 'Ouvert', 'reviewing': 'En traitement', 'closed': 'Résolu'};
const _reportReasonLabels = {'fraud': 'Fraude', 'copied': 'Propriété', 'price': 'Prix', 'other': 'Contenu'};

String _received(String iso) {
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  final m = DateTime.now().difference(d).inMinutes;
  if (m < 60) return 'Il y a ${m < 1 ? 1 : m} min';
  if (m < 1440) return 'Il y a ${m ~/ 60} h';
  return 'Il y a ${m ~/ 1440} j';
}

/// Signalements réels lus par la modération (support, département, administration).
class ServerReports extends Notifier<List<Report>> {
  @override
  List<Report> build() {
    if (Backend.ready) Future.microtask(refresh);
    return const [];
  }

  Future<void> refresh() async {
    final rows = await Backend.moderationReports();
    if (rows == null) return;
    state = [
      for (final r in rows)
        Report(
          'Annonce « ${(r['listings'] is Map ? r['listings']['title'] : null) ?? 'supprimée'} »',
          _reportReasonLabels[r['reason']] ?? 'Autre',
          _received('${r['created_at'] ?? ''}'),
          'Non assigné',
          _reportStatusLabels[r['status']] ?? 'Ouvert',
          listing: '${(r['listings'] is Map ? r['listings']['title'] : null) ?? ''}',
          id: '${r['id'] ?? ''}',
          listingId: '${r['listing_id'] ?? ''}',
        ),
    ];
  }
}

final serverReportsProvider = NotifierProvider<ServerReports, List<Report>>(ServerReports.new);

const _seedReports = [
  Report('Annonce frauduleuse', 'Fraude', 'Il y a 1 h', 'Support 01', 'Urgent'),
  Report('Avis injurieux', 'Contenu', 'Il y a 3 h', 'Support 02', 'En traitement'),
  Report('Photo copiée', 'Propriété', 'Hier', 'Support 01', 'En traitement'),
  Report('Vendeur injoignable', 'Service', 'Hier', 'Support 03', 'Ouvert'),
];

class Reports extends Notifier<List<Report>> {
  @override
  List<Report> build() => const [];
  void add(Report r) => state = [r, ...state];
  void replace(Report old, Report r) => state = [for (final x in state) identical(x, old) ? r : x];
}

final reportsProvider = NotifierProvider<Reports, List<Report>>(Reports.new);

/// Statuts modifiés sur les signalements de démonstration (titre → (statut, assigné)).
class ReportEdits extends Notifier<Map<String, (String, String)>> {
  @override
  Map<String, (String, String)> build() => const {};
  void set(String title, String status, String who) => state = {...state, title: (status, who)};
}

final reportEditsProvider = NotifierProvider<ReportEdits, Map<String, (String, String)>>(ReportEdits.new);

/// Avec le serveur : les signalements réels uniquement. Hors connexion (tests, aperçu) : signalements d'exemple de la maquette.
final allReportsProvider = Provider<List<Report>>((ref) {
  if (Backend.ready) return ref.watch(serverReportsProvider);
  final edits = ref.watch(reportEditsProvider);
  return [
    ...ref.watch(reportsProvider),
    for (final r in _seedReports) edits.containsKey(r.title) ? r.copy(status: edits[r.title]!.$1, assignee: edits[r.title]!.$2) : r,
  ];
});

int _count(List<Report> l, String s) => l.where((r) => r.status == s || (s == 'Ouvert' && r.status == 'Urgent')).length;

/// Compteurs : avec le serveur, décompte exact des signalements réels ; hors connexion, compteurs de la maquette
/// (27 ouverts, 11 en traitement, 142 résolus) ajustés par les changements.
({int open, int work, int done}) reportCounters(List<Report> all) {
  if (Backend.ready) return (open: _count(all, 'Ouvert'), work: _count(all, 'En traitement'), done: _count(all, 'Résolu'));
  final base = _seedReports;
  return (
    open: 27 + _count(all, 'Ouvert') - _count(base, 'Ouvert'),
    work: 11 + _count(all, 'En traitement') - _count(base, 'En traitement'),
    done: 142 + _count(all, 'Résolu'),
  );
}

Color reportFill(String s) => switch (s) {
      'Urgent' => const Color(0xFFFDE6E7),
      'Résolu' => const Color(0xFFDDF5EC),
      'En traitement' => const Color(0xFFEFEBFA),
      _ => const Color(0xFFEEE9FF),
    };

Color reportInk(String s) => switch (s) {
      'Urgent' => const Color(0xFFE5484D),
      'Résolu' => const Color(0xFF0F7A52),
      'En traitement' => const Color(0xFF5A3FE0),
      _ => const Color(0xFF8F5400),
    };

final reportReasonProvider = NotifierProvider<IntV, int>(IntV.new);
const reportReasons = [('Fraude', 'Annonce frauduleuse ou arnaque'), ('Propriété', 'Photos ou description copiées'), ('Prix', 'Prix anormal ou demande suspecte'), ('Contenu', 'Contenu inapproprié')];

Future<void> submitReport(WidgetRef ref, BuildContext context) async {
  final p = ref.read(selectedProductProvider);
  final i = ref.read(reportReasonProvider).clamp(0, 3);
  final reason = reportReasons[i];
  if (Backend.ready) {
    if (!await requireLogin(context, ref, 'signaler une annonce')) return;
    final err = await Backend.reportListing(p.title, reportReasonCodes[i], ref.read(formProvider)['report_details'] ?? '');
    if (!context.mounted) return;
    if (err != null) return gAlert(context, 'Signalement non envoyé', err);
    ref.read(formProvider.notifier).clear(const ['report_details']);
  }
  final me = ref.read(profileAccountProvider).name;
  ref.read(reportsProvider.notifier).add(Report('Annonce « ${p.title} »', reason.$1, 'À l’instant', 'Non assigné', 'Ouvert', listing: p.title));
  ref.read(auditProvider.notifier).log(me, 'Signalement envoyé', p.title, 'Modération', level: 'Sensible');
  if (!context.mounted) return;
  gToast(context, 'Signalement envoyé : ${reason.$2}');
  gOpen(context, '49');
}

Future<void> reportDialog(BuildContext context, WidgetRef ref, Report r) {
  var status = r.status == 'Urgent' ? 'Ouvert' : r.status;
  var who = r.assignee == 'Non assigné' ? 'Support 01' : r.assignee;
  var remove = false;
  final canRemove = Backend.ready ? r.listingId.isNotEmpty : r.listing.isNotEmpty && ref.read(listingsProvider).any((l) => l.title == r.listing);
  return gDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(r.title, style: _st.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 340,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Type : ${r.type} · Reçu : ${r.received}', style: _st.copyWith(color: const Color(0xFF66636E))),
            const SizedBox(height: 10),
            DropdownButton<String>(
              value: status,
              isExpanded: true,
              style: _st,
              items: [for (final s in const ['Ouvert', 'En traitement', 'Résolu']) DropdownMenuItem(value: s, child: Text('Statut : $s', style: _st))],
              onChanged: (v) => set(() => status = v ?? status),
            ),
            if (!Backend.ready)
              DropdownButton<String>(
                value: who,
                isExpanded: true,
                style: _st,
                items: [for (final s in const ['Support 01', 'Support 02', 'Support 03']) DropdownMenuItem(value: s, child: Text('Assigné à : $s', style: _st))],
                onChanged: (v) => set(() => who = v ?? who),
              ),
            if (canRemove)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: remove,
                onChanged: (v) => set(() => remove = v ?? false),
                title: Text('Retirer l’annonce du catalogue', style: _st),
              ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Annuler', style: _st)),
          TextButton(
            onPressed: () async {
              if (Backend.ready) {
                // Statut enregistré par le serveur ; rien n'est annoncé sans sa confirmation.
                if (r.id.isEmpty) return;
                final code = _reportStatusLabels.entries.firstWhere((e) => e.value == status, orElse: () => const MapEntry('open', 'Ouvert')).key;
                final err = await Backend.setReportStatus(r.id, code);
                if (!ctx.mounted) return;
                if (err != null) {
                  await gAlert(ctx, 'Signalement non modifié', err);
                  return;
                }
                var removed = false;
                if (remove) {
                  final e2 = await Backend.decideListing(r.listingId, false, 'Retirée par la modération à la suite d’un signalement');
                  if (!ctx.mounted) return;
                  if (e2 != null) await gAlert(ctx, 'Annonce non retirée', e2);
                  removed = e2 == null;
                }
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                await ref.read(serverReportsProvider.notifier).refresh();
                if (context.mounted) gToast(context, removed ? 'Statut enregistré, annonce retirée du catalogue' : 'Statut enregistré par le serveur');
                return;
              }
              final rn = ref.read(reportsProvider.notifier);
              if (ref.read(reportsProvider).any((x) => identical(x, r))) {
                rn.replace(r, r.copy(status: status, assignee: who));
              } else {
                ref.read(reportEditsProvider.notifier).set(r.title, status, who);
              }
              ref.read(auditProvider.notifier).log(who, 'Signalement : $status', r.title, 'Modération', level: 'Sensible');
              if (remove) {
                ref.read(listingsProvider.notifier).review(r.listing, false);
                ref.read(auditProvider.notifier).log(who, 'Contenu retiré', r.listing, 'Modération', level: 'Sensible');
              }
              Navigator.of(ctx).pop();
              gToast(context, remove ? 'Signalement mis à jour, annonce retirée' : 'Signalement mis à jour');
            },
            child: Text('Enregistrer', style: _st.copyWith(color: const Color(0xFF5A3FE0), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ),
  );
}

// ------------------------------------------------------------------ commissions (135)

class Rules {
  const Rules({this.product = 5, this.service = 7, this.financing = 4, this.threshold = 10000, this.updated = '01 sept. 2026'});
  final int product, service, financing, threshold;
  final String updated;
}

class RulesNotifier extends Notifier<Rules> {
  @override
  Rules build() => const Rules();
  void set(Rules r) => state = r;
}

final rulesConfigProvider = NotifierProvider<RulesNotifier, Rules>(RulesNotifier.new);

Future<void> commissionDialog(BuildContext context, WidgetRef ref) {
  final r = ref.read(rulesConfigProvider);
  final c1 = TextEditingController(text: '${r.product}');
  final c2 = TextEditingController(text: '${r.service}');
  final c3 = TextEditingController(text: '${r.financing}');
  final c4 = TextEditingController(text: '${r.threshold}');
  String? error;
  Widget field(String label, TextEditingController c) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(controller: c, keyboardType: TextInputType.number, style: _st, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true)),
      );
  return gDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Modifier les commissions', style: _st.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 340,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            field('Commission produits (%)', c1),
            field('Commission services (%)', c2),
            field('Financement participatif (%)', c3),
            field('Seuil de paiement vendeur (FCFA)', c4),
            if (error != null) Text(error!, style: _st.copyWith(color: const Color(0xFFD92D20), fontSize: 12)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Annuler', style: _st)),
          TextButton(
            onPressed: () {
              final p = int.tryParse(c1.text), s = int.tryParse(c2.text), f = int.tryParse(c3.text), t = int.tryParse(c4.text);
              if ([p, s, f].any((v) => v == null || v < 0 || v > 30) || t == null || t < 0) {
                set(() => error = 'Taux entre 0 et 30 %, seuil positif.');
                return;
              }
              final now = auditNow().split(' ').take(2).join(' ');
              ref.read(rulesConfigProvider.notifier).set(Rules(product: p!, service: s!, financing: f!, threshold: t, updated: '$now 2026'));
              ref.read(auditProvider.notifier).log('Super admin', 'Commission modifiée', 'Produits $p %', 'Paramètres', level: 'Critique');
              Navigator.of(ctx).pop();
              gToast(context, 'Règles enregistrées : effet immédiat sur les nouvelles factures');
            },
            child: Text('Enregistrer', style: _st.copyWith(color: const Color(0xFF5A3FE0), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ),
  );
}

// ------------------------------------------------------------------ supervision des commandes (132)

class OrderRow {
  const OrderRow(this.id, this.client, this.seller, this.amount, this.status, {this.real = false});
  final String id, client, seller, status;
  final int amount;
  final bool real;
}

const _seedOrderRows = [
  OrderRow('#BE-2026-0142', 'Y. Mouanga', 'M. Essono', 25000, 'Livrée'),
  OrderRow('#BE-2026-0138', 'A. Bello', 'B. Ndoumbe', 17000, 'En retard'),
  OrderRow('#BE-2026-0127', 'K. Tagne', 'A. Bello', 45000, 'Incident'),
  OrderRow('#BE-2026-0119', 'C. Mbarga', 'Y. Mouanga', 28000, 'Annulée'),
];

final orderRowsProvider = Provider<List<OrderRow>>((ref) {
  return [
    for (final o in ref.watch(ordersProvider)) OrderRow(o.id, 'M. Essono', 'Vendeurs', o.total, statusLabel(o.status), real: true),
    ..._seedOrderRows,
  ];
});

Color orderRowFill(String s) => switch (s) {
      'Livrée' => const Color(0xFFDDF5EC),
      'Annulée' => const Color(0xFFF2EFF6),
      'Incident' => const Color(0xFFFDE6E7),
      'En retard' => const Color(0xFFEEE9FF),
      _ => const Color(0xFFEFEBFA),
    };

Color orderRowInk(String s) => switch (s) {
      'Livrée' => const Color(0xFF0F7A52),
      'Annulée' => const Color(0xFF66636E),
      'Incident' => const Color(0xFFE5484D),
      'En retard' => const Color(0xFF8F5400),
      _ => const Color(0xFF5A3FE0),
    };

// ------------------------------------------------------------------ validation des projets (111)

/// Projets à valider d'abord, puis les projets déjà publiés.
final projectQueueProvider = Provider<List<Project>>((ref) {
  final all = ref.watch(projectsProvider);
  return [...all.where((p) => p.review != 'Validé'), ...all.where((p) => p.review == 'Validé')];
});

Color decisionFill(String s) => switch (s) {
      'Validé' => const Color(0xFFDDF5EC),
      'À corriger' => const Color(0xFFFDE6E7),
      _ => const Color(0xFFEEE9FF),
    };

Color decisionInk(String s) => switch (s) {
      'Validé' => const Color(0xFF0F7A52),
      'À corriger' => const Color(0xFFE5484D),
      _ => const Color(0xFF8F5400),
    };

Future<void> projectReviewDialog(BuildContext context, WidgetRef ref, Project p) {
  final note = TextEditingController();
  return gDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text(p.title, style: _st.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 340,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${p.dept} · ${p.stage} · ${p.progress} %\nChef de projet : ${p.lead}\n${p.desc}', style: _st.copyWith(height: 1.55, color: const Color(0xFF66636E))),
          const SizedBox(height: 10),
          TextField(controller: note, style: _st, decoration: const InputDecoration(hintText: 'Motif (obligatoire pour « À corriger »)', border: OutlineInputBorder())),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (note.text.trim().length < 5) {
              gToast(ctx, 'Indiquez ce qui doit être corrigé (5 caractères minimum).');
              return;
            }
            ref.read(projectsProvider.notifier).setReview(p.title, 'À corriger');
            ref.read(auditProvider.notifier).log('Dr Mbarga', 'Projet renvoyé à corriger', p.title, 'Validations', level: 'Sensible');
            Navigator.of(ctx).pop();
            gToast(context, 'Projet renvoyé à l’équipe');
          },
          child: Text('À corriger', style: _st.copyWith(color: const Color(0xFFE5484D), fontWeight: FontWeight.w600)),
        ),
        TextButton(
          onPressed: () {
            ref.read(projectsProvider.notifier).setReview(p.title, 'Validé');
            ref.read(auditProvider.notifier).log('Dr Mbarga', 'Projet validé', p.title, 'Validations');
            Navigator.of(ctx).pop();
            gToast(context, 'Projet validé : visible dans le catalogue');
          },
          child: Text('Valider', style: _st.copyWith(color: const Color(0xFF0F7A52), fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}
