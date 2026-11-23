import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gDialog, gToast;
import 'admin.dart';
import 'audit.dart' show levelInk;
import 'auth.dart';
import 'backend.dart';
import 'console.dart';
import 'entreprise.dart' show TableRows, dateCourte;
import 'download_stub.dart' if (dart.library.js_interop) 'download_web.dart';
import 'ops.dart';
import 'review.dart';
import 'store.dart' show IntV, StrV, fcfa, ordersProvider;

/// Listes et compteurs réels de la console d'administration (écrans 128, 130, 131, 132) : remplacent, une fois connecté, les lignes d'exemple
/// figées de la maquette. Chargement, état vide et erreur explicites ; chaque ligne ouvre l'action serveur correspondante.

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

Widget _note(double w, String t, {double h = 140}) => Container(width: w, height: h, alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(t, textAlign: TextAlign.center, style: _st(13, c: _grey).copyWith(height: 1.5)));

class _Cell {
  const _Cell(this.x, this.w, this.text, {this.bold = false, this.color});
  final double x, w;
  final String text;
  final bool bold;
  final Color? color;
}

/// Lignes de 44 px, colonnes à abscisses fixes (celles de l'en-tête de la maquette), défilantes : aucune limite aux premières lignes.
class _Grid extends StatelessWidget {
  const _Grid({required this.width, required this.height, required this.count, required this.cells, required this.onTap});
  final double width, height;
  final int count;
  final List<_Cell> Function(int i) cells;
  final void Function(int i) onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: height,
        child: ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: count,
          separatorBuilder: (_, _) => const Divider(height: 1, thickness: 1, color: Color(0xFFF2EFF6)),
          itemBuilder: (_, i) => InkWell(
            onTap: () => onTap(i),
            child: SizedBox(
              height: 43,
              child: Stack(children: [
                for (final c in cells(i))
                  Positioned(left: c.x, width: c.w, top: 14, child: Text(c.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(12.5, w: c.bold ? FontWeight.w600 : FontWeight.w500, c: c.color ?? (c.bold ? _ink : const Color(0xFF4A4854))))),
              ]),
            ),
          ),
        ),
      );
}

// ------------------------------------------------------------------ comptes (128)

/// Tous les comptes lus par l'administrateur ; toucher une ligne ouvre le rôle et la suspension (`admin_set_account`).
class AdminUsersList extends ConsumerWidget {
  const AdminUsersList({super.key, this.width = 646, this.height = 600});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authProvider.select((a) => a.current == null))) return _note(width, 'Connectez-vous avec un compte de gestion pour voir les comptes.');
    final list = ref.watch(adminUsersProvider);
    if (!ref.watch(serverAccountsProvider.notifier).loaded) return _note(width, ref.watch(serverAccountsProvider.notifier).failed ? 'Accès réservé à la gestion, ou liste indisponible pour le moment.' : 'Chargement…');
    if (list.isEmpty) return _note(width, 'Aucun compte pour le moment.');
    return _Grid(
      width: width,
      height: height,
      count: list.length,
      onTap: (i) => userDialog(context, ref, list[i]),
      cells: (i) {
        final a = list[i];
        return [
          _Cell(16, 170, a.name, bold: true),
          _Cell(200, 130, a.roleLabel),
          _Cell(335, 150, a.institution),
          _Cell(495, 90, a.suspended ? 'Suspendu' : 'Actif', color: statusInk(a.suspended)),
        ];
      },
    );
  }
}

/// Remplace le panneau « permissions » de la maquette (interrupteurs sans effet) : ce que fait réellement l'écran.
class AdminRolesNote extends StatelessWidget {
  const AdminRolesNote({super.key, this.width = 323});
  final double width;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), border: Border.all(color: const Color(0xFFEEECE8))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('Rôle et suspension', style: _st(14, w: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Touchez un compte pour changer son rôle ou le suspendre. L’opération est appliquée et journalisée par le serveur ; la liste est ensuite rechargée.', style: _st(12, c: _grey).copyWith(height: 1.5)),
          const SizedBox(height: 10),
          Text('Les droits des équipes Finance, Support, Sécurité et Technique se règlent dans « Équipes et permissions » du centre d’administration.', style: _st(12, c: _grey).copyWith(height: 1.5)),
        ]),
      );
}

// ------------------------------------------------------------------ signalements (131)

/// Tous les signalements d'annonces ; toucher une ligne ouvre la décision (statut, retrait de l'annonce).
class ReportsList extends ConsumerWidget {
  const ReportsList({super.key, this.width = 984, this.height = 540});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authProvider.select((a) => a.current == null))) return _note(width, 'Connectez-vous avec un compte de modération pour voir les signalements.');
    final list = ref.watch(allReportsProvider);
    if (!ref.watch(serverReportsProvider.notifier).loaded) return _note(width, 'Chargement…');
    if (list.isEmpty) return _note(width, 'Aucun signalement pour le moment.');
    return _Grid(
      width: width,
      height: height,
      count: list.length,
      onTap: (i) => reportDialog(context, ref, list[i]),
      cells: (i) {
        final r = list[i];
        return [_Cell(16, 270, r.title, bold: true), _Cell(301, 150, r.type), _Cell(473, 120, r.received), _Cell(606, 170, r.assignee), _Cell(797, 150, r.status, bold: true, color: reportInk(r.status))];
      },
    );
  }
}

// ------------------------------------------------------------------ modération des annonces (130)

/// Annonces soumises et en attente de décision (`listing_review_queue`) : « Examiner » ouvre la validation ou le refus motivé.
class ModerationQueue extends ConsumerWidget {
  const ModerationQueue({super.key, this.width = 984, this.height = 600});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authProvider.select((a) => a.current == null))) return _note(width, 'Connectez-vous avec un compte de modération pour voir la file.');
    final list = ref.watch(pendingReviewsProvider);
    if (list.isEmpty) return _note(width, 'Aucune annonce en attente de validation.');
    return _Grid(
      width: width,
      height: height,
      count: list.length,
      onTap: (i) => reviewDialog(context, ref, list[i]),
      cells: (i) {
        final r = list[i];
        return [_Cell(16, 270, r.title, bold: true), _Cell(301, 190, r.seller), _Cell(492, 200, 'À valider · ${r.category}'), _Cell(701, 120, r.submitted), _Cell(815, 100, 'Examiner', bold: true, color: const Color(0xFF5A3FE0))];
      },
    );
  }
}

// ------------------------------------------------------------------ commandes (132)

/// Commandes de toute la plateforme, lues par la fonction `admin_orders` (administrateur, finance ou support de commandes).
final adminOrdersProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => RpcRows('admin_orders', const {'p_limit': 200}));

String adminOrderStatus(Map<String, dynamic> o) {
  if (o['cancelled'] == true) return 'Annulée';
  if (o['paid'] != true) return 'En attente de paiement';
  return const ['Confirmée', 'En préparation', 'Expédiée', 'Livrée'][((o['status'] as num?)?.toInt() ?? 0).clamp(0, 3)];
}

/// Compteur de l'écran 132 : 0 du jour, 1 en préparation, 2 expédiées, 3 annulées. « — » tant que le serveur n'a pas répondu ; chiffres de la maquette hors connexion.
String adminOrderCount(WidgetRef ref, int which) {
  if (!Backend.ready) {
    final orders = ref.watch(ordersProvider);
    return ['${212 + orders.length}', '${64 + orders.where((o) => o.status < 3).length}', '7', '9'][which];
  }
  final rows = ref.watch(adminOrdersProvider);
  if (rows == null || ref.read(adminOrdersProvider.notifier).error) return '—';
  final now = DateTime.now();
  bool today(Object? iso) {
    final d = DateTime.tryParse('$iso')?.toLocal();
    return d != null && d.year == now.year && d.month == now.month && d.day == now.day;
  }

  final n = switch (which) {
    0 => rows.where((o) => today(o['created_at'])).length,
    1 => rows.where((o) => adminOrderStatus(o) == 'En préparation').length,
    2 => rows.where((o) => adminOrderStatus(o) == 'Expédiée').length,
    _ => rows.where((o) => o['cancelled'] == true).length,
  };
  return '$n';
}

class AdminOrdersTable extends ConsumerWidget {
  const AdminOrdersTable({super.key, this.width = 984, this.height = 540});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authProvider.select((a) => a.current == null))) return _note(width, 'Connectez-vous avec un compte de gestion pour voir les commandes.');
    final rows = ref.watch(adminOrdersProvider);
    if (rows == null) return _note(width, 'Chargement…');
    if (ref.read(adminOrdersProvider.notifier).error) return _note(width, 'Accès réservé à la gestion, ou commandes indisponibles pour le moment.');
    if (rows.isEmpty) return _note(width, 'Aucune commande pour le moment.');
    return _Grid(
      width: width,
      height: height,
      count: rows.length,
      onTap: (i) => _orderDialog(context, rows[i]),
      cells: (i) {
        final o = rows[i];
        final st = adminOrderStatus(o);
        return [
          _Cell(16, 170, '#${o['number']}', bold: true),
          _Cell(187, 190, '${o['buyer'] ?? ''}'),
          _Cell(378, 190, '${o['sellers'] ?? ''}'),
          _Cell(568, 130, fcfa(((o['total'] as num?) ?? 0).toInt()).replaceAll(' FCFA', '')),
          _Cell(720, 200, st, bold: true, color: st == 'Annulée' ? _grey : const Color(0xFF5A3FE0)),
        ];
      },
    );
  }
}

Future<void> _orderDialog(BuildContext context, Map<String, dynamic> o) => gDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Commande #${o['number']}', style: _st(16, w: FontWeight.w700)),
        content: Text(
            'Client : ${o['buyer'] ?? '—'}\nVendeur(s) : ${o['sellers'] ?? '—'}\nMontant : ${fcfa(((o['total'] as num?) ?? 0).toInt())}\nPaiement : ${o['method'] ?? '—'}${o['paid'] == true ? ' (payé)' : ' (non payé)'}\nÉtat : ${adminOrderStatus(o)}\nPassée le ${dateCourte(o['created_at'])}',
            style: _st(13, c: _grey).copyWith(height: 1.6)),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Fermer', style: _st(13)))],
      ),
    );

// ------------------------------------------------------------------ catalogue des permissions (181, 281)

final adminTeamsCatalogProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('admin_teams', 'code,name,description,position', order: 'position', ascending: true, limit: 20));
final adminPermissionsCatalogProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('admin_permissions', 'code,team_code,label,description,sensitive,position', order: 'position', ascending: true, limit: 100));

/// Permissions réelles des équipes internes (catalogue du serveur, lecture seule) à la place des matrices « Oui / Valide » de la maquette.
class PermissionCatalog extends ConsumerWidget {
  const PermissionCatalog({super.key, this.width = 984, this.height = 560});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authProvider.select((a) => a.current == null))) return _note(width, 'Connectez-vous avec un compte de gestion pour voir les permissions.');
    final teams = ref.watch(adminTeamsCatalogProvider);
    final perms = ref.watch(adminPermissionsCatalogProvider);
    if (teams == null || perms == null) return _note(width, 'Chargement…');
    if (ref.read(adminTeamsCatalogProvider.notifier).error || ref.read(adminPermissionsCatalogProvider.notifier).error) return _note(width, 'Permissions indisponibles pour le moment.');
    if (perms.isEmpty) return _note(width, 'Aucune permission définie pour le moment.');
    return SizedBox(
      width: width,
      height: height,
      child: ListView(padding: EdgeInsets.zero, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text('Droits des équipes internes. L’administrateur global dispose de tous ; un agent n’a que les permissions qui lui sont attribuées dans « Équipes et permissions ».', style: _st(12, c: _grey).copyWith(height: 1.5)),
        ),
        for (final t in teams) ...[
          Padding(padding: const EdgeInsets.only(top: 10, bottom: 4), child: Text('${t['name']}', style: _st(14, w: FontWeight.w700))),
          for (final p in perms.where((p) => p['team_code'] == t['code']))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${p['label']}${p['sensitive'] == true ? ' · sensible' : ''}', style: _st(12.5, w: FontWeight.w600)),
                Text('${p['description'] ?? ''}', style: _st(11.5, c: _grey).copyWith(height: 1.4)),
              ]),
            ),
        ],
      ]),
    );
  }
}

// ------------------------------------------------------------------ journal d'audit global (137)

/// Journal d'audit du serveur (`audit_log`), les 300 dernières entrées ; la lecture est réservée à l'administration (et à la permission « journal »).
final auditServerProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('audit_log', 'actor,action,target,category,level,created_at', order: 'created_at', limit: 300));

const _auditTabs = <Set<String>?>[
  null,
  {'Comptes', 'Connexions'},
  {'Finances'},
  {'Modération', 'Validations'},
  {'Paramètres', 'Réglages', 'Configuration'},
];

final _uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');

/// Onglet (0 tout · 1 comptes · 2 finances · 3 modération · 4 configuration) et recherche du journal global (propres à l'écran 137).
final globalAuditTabProvider = NotifierProvider<IntV, int>(IntV.new);
final globalAuditQueryProvider = NotifierProvider<StrV, String>(StrV.new);

/// Lignes du journal filtrées par l'onglet et la recherche de l'écran ; l'auteur enregistré comme identifiant est remplacé par le nom du compte quand il est connu.
List<Map<String, String>>? auditServerRows(WidgetRef ref) {
  final all = ref.watch(auditServerProvider);
  if (all == null) return null;
  final cats = _auditTabs[ref.watch(globalAuditTabProvider).clamp(0, _auditTabs.length - 1)];
  final q = ref.watch(globalAuditQueryProvider).trim().toLowerCase();
  final names = {for (final a in ref.watch(adminUsersProvider)) a.serverId: a.name};
  final out = <Map<String, String>>[];
  for (final r in all) {
    final actorRaw = '${r['actor'] ?? ''}';
    final row = {
      'date': dateCourte(r['created_at']),
      'actor': _uuid.hasMatch(actorRaw) ? (names[actorRaw] ?? 'Compte') : actorRaw,
      'action': '${r['action'] ?? ''}',
      'target': '${r['target'] ?? ''}',
      'cat': '${r['category'] ?? ''}',
      'level': '${r['level'] ?? ''}',
    };
    if (cats != null && !cats.contains(row['cat'])) continue;
    if (q.isNotEmpty && !'${row['actor']} ${row['action']} ${row['target']}'.toLowerCase().contains(q)) continue;
    out.add(row);
  }
  return out;
}

class AuditTable extends ConsumerWidget {
  const AuditTable({super.key, this.width = 984, this.height = 560});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authProvider.select((a) => a.current == null))) return _note(width, 'Connectez-vous avec un compte d’administration pour voir le journal.');
    final rows = auditServerRows(ref);
    if (rows == null) return _note(width, 'Chargement…');
    if (ref.read(auditServerProvider.notifier).error) return _note(width, 'Lecture réservée à l’administration, ou journal indisponible pour le moment.');
    if (rows.isEmpty) return _note(width, 'Aucune entrée dans le journal pour ce filtre.');
    return _Grid(
      width: width,
      height: height,
      count: rows.length,
      onTap: (_) {},
      cells: (i) {
        final r = rows[i];
        return [
          _Cell(16, 130, r['date']!, bold: true),
          _Cell(149, 150, r['actor']!),
          _Cell(302, 260, r['action']!),
          _Cell(568, 180, r['target']!),
          _Cell(758, 120, r['cat']!),
          _Cell(886, 90, r['level']!, bold: true, color: levelInk(r['level']!)),
        ];
      },
    );
  }
}

String _csv(String v) => '"${v.replaceAll('"', '""')}"';

/// « Exporter » : enregistre un fichier CSV des entrées affichées (téléchargement dans le navigateur, copie dans le presse-papiers ailleurs).
Future<void> exportAuditCsv(BuildContext context, WidgetRef ref) async {
  final rows = auditServerRows(ref);
  if (rows == null || ref.read(auditServerProvider.notifier).error) return gToast(context, 'Journal indisponible : rien à exporter.');
  if (rows.isEmpty) return gToast(context, 'Aucune entrée à exporter pour ce filtre.');
  final b = StringBuffer('Date;Acteur;Action;Cible;Catégorie;Niveau\r\n');
  for (final r in rows) {
    b.write('${[r['date'], r['actor'], r['action'], r['target'], r['cat'], r['level']].map((v) => _csv(v!)).join(';')}\r\n');
  }
  final downloaded = await saveTextFile('journal-audit.csv', b.toString(), 'text/csv');
  if (!context.mounted) return;
  gToast(context, downloaded ? '${rows.length} entrée${rows.length > 1 ? 's' : ''} exportée${rows.length > 1 ? 's' : ''} (journal-audit.csv)' : '${rows.length} entrée${rows.length > 1 ? 's' : ''} copiée${rows.length > 1 ? 's' : ''} dans le presse-papiers (CSV)');
}