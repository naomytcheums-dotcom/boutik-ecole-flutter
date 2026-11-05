import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth.dart';
import 'backend.dart';
import 'console.dart';
import 'entreprise.dart';
import 'finance.dart' show financeJournalProvider;
import 'store.dart';

/// Bornes, annonces à modérer, notifications, commandes, rôles et registres (lot de 20 écrans) : tout est lu sur le serveur ou dans les
/// données du compte ; chargement, état vide et erreur explicites, aucune ligne de maquette hors démonstration.

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

final kiosksProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('kiosks', 'id,name,location,status,updated_at', order: 'id', ascending: true));
final kioskIncidentsProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('kiosk_incidents', 'id,kiosk_id,kind,message,created_at,resolved_at', order: 'created_at'));
final listingsAdminProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('listings', 'title,status,category,price,created_at', order: 'created_at'));

/// Notifications du compte (lecture protégée : chacun ne lit que les siennes).
class NotificationsRows extends RpcRows {
  NotificationsRows() : super('notifications');
  @override
  Future<void> refresh() async {
    final rows = await Backend.notifications();
    if (!ref.mounted) return;
    error = false;
    state = rows;
  }
}

final notificationsListProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(NotificationsRows.new);

String kioskStatus(Object? s) => switch ('$s') { 'online' => 'En ligne', 'offline' => 'Hors ligne', 'fallback' => 'Mode secours', 'maintenance' => 'Maintenance', _ => '$s' };
String incidentKind(Object? s) => switch ('$s') { 'offline' => 'Hors ligne', 'restart' => 'Redémarrage', 'fallback' => 'Mode secours', 'hardware' => 'Matériel', 'payment' => 'Paiement', _ => 'Autre' };
String listingStatus(Object? s) => switch ('$s') { 'approved' => 'Publiée', 'draft' => 'Brouillon', 'removed' => 'Retirée', _ => '$s' };

Widget kiosksListing({double width = 984, double height = 600}) => MobileList(
      provider: kiosksProvider,
      title: (r) => '${r['name']}',
      subtitle: (r) => '${r['location']} · mise à jour ${dateCourte(r['updated_at'])}',
      trailing: (r) => kioskStatus(r['status']),
      emptyText: 'Aucune borne enregistrée pour le moment.',
      width: width,
      height: height,
    );

Widget incidentsListing({bool open = true, double width = 984, double height = 600}) => MobileList(
      provider: kioskIncidentsProvider,
      where: (r) => open ? r['resolved_at'] == null : r['resolved_at'] != null,
      title: (r) => '${r['message']}',
      subtitle: (r) => '${r['kiosk_id']} · ${incidentKind(r['kind'])} · ${dateCourte(r['created_at'])}',
      trailing: (r) => open ? 'Ouvert' : 'Résolu',
      emptyText: open ? 'Aucun incident ouvert.' : 'Aucun incident résolu pour le moment.',
      width: width,
      height: height,
    );

Widget listingsListing({double width = 984, double height = 600, bool onlyPending = false}) => MobileList(
      provider: listingsAdminProvider,
      where: onlyPending ? (r) => '${r['status']}' != 'approved' : null,
      title: (r) => '${r['title']}',
      subtitle: (r) => '${r['category'] ?? ''} · ${fcfa(((r['price'] as num?) ?? 0).toInt())} · ${dateCourte(r['created_at'])}',
      trailing: (r) => listingStatus(r['status']),
      emptyText: onlyPending ? 'Aucune annonce en attente.' : 'Aucune annonce pour le moment.',
      width: width,
      height: height,
    );

Widget notificationsListing({double width = 342, double height = 600}) => MobileList(
      provider: notificationsListProvider,
      title: (r) => '${r['title'] ?? ''}',
      subtitle: (r) => '${r['body'] ?? ''} · ${dateCourte(r['created_at'])}',
      emptyText: 'Aucune notification pour le moment.',
      width: width,
      height: height,
    );

Widget wideContests({double width = 984, double height = 600}) => MobileList(
      provider: contestsListProvider,
      title: (r) => '${r['title']}',
      subtitle: (r) => [if (r['prize'] != null && '${r['prize']}'.isNotEmpty) 'Prix : ${r['prize']}', if (r['reg_close_at'] != null) 'Inscriptions jusqu’au ${dateCourte(r['reg_close_at'])}', if (r['places'] != null) '${r['places']} places'].join(' · '),
      emptyText: 'Aucun concours pour le moment.',
      width: width,
      height: height,
    );

Widget journalListing({double width = 342, double height = 600}) => MobileList(
      provider: financeJournalProvider,
      title: (r) => '${r['label']}',
      subtitle: (r) => '${r['date']} · ${(r['credit'] as num? ?? 0) > 0 ? 'crédit ${fcfa((r['credit'] as num).toInt())}' : 'débit ${fcfa(((r['debit'] as num?) ?? 0).toInt())}'}',
      trailing: (r) => r['reconciled'] == true ? 'Rapproché' : 'À rapprocher',
      emptyText: 'Aucune écriture pour le moment.\nLa lecture est réservée à la finance et à l’administration.',
      width: width,
      height: height,
    );

Widget _note(double w, String t, {double h = 140}) => Container(width: w, height: h, alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFECE8F2))), child: Text(t, textAlign: TextAlign.center, style: _st(13, c: _grey).copyWith(height: 1.5)));

Widget _tile(String l, String v, double w) => Container(width: w, padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFEEECE8))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(l, style: _st(11.5, c: _grey)), const SizedBox(height: 6), Text(v, style: _st(22, w: FontWeight.w700))]));

/// Compteurs des bornes : en ligne, hors ligne ou en secours, en maintenance, incidents ouverts.
class KioskKpis extends ConsumerWidget {
  const KioskKpis({super.key, this.width = 984, this.compact = false});
  final double width;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authProvider.select((a) => a.current == null))) return _note(width, 'Connectez-vous pour voir les bornes.');
    final ks = ref.watch(kiosksProvider);
    final inc = ref.watch(kioskIncidentsProvider);
    if (ks == null || inc == null) return _note(width, 'Chargement…');
    int n(String s) => ks.where((k) => '${k['status']}' == s).length;
    final open = inc.where((r) => r['resolved_at'] == null).length;
    final items = [('En ligne', '${n('online')}'), ('Hors ligne ou secours', '${n('offline') + n('fallback')}'), ('En maintenance', '${n('maintenance')}'), ('Incidents ouverts', '$open')];
    final w = (width - 3 * 12) / 4;
    if (compact) {
      return Wrap(spacing: 12, runSpacing: 12, children: [for (final i in items) _tile(i.$1, i.$2, (width - 12) / 2)]);
    }
    return Row(children: [for (var i = 0; i < 4; i++) ...[if (i > 0) const SizedBox(width: 12), _tile(items[i].$1, items[i].$2, w)]]);
  }
}

/// Nombre de comptes par rôle (écran 180), lu sur la liste des utilisateurs de la gestion.
class RoleCounts extends ConsumerWidget {
  const RoleCounts({super.key, this.width = 984});
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authProvider.select((a) => a.current == null))) return _note(width, 'Connectez-vous avec un compte de gestion pour voir les rôles.');
    final rows = ref.watch(consoleUsersProvider);
    if (rows == null) return _note(width, 'Chargement…');
    if (ref.read(consoleUsersProvider.notifier).error) return _note(width, 'Accès réservé à la gestion, ou liste indisponible.');
    final counts = <String, int>{};
    for (final r in rows) {
      counts['${r['role']}'] = (counts['${r['role']}'] ?? 0) + 1;
    }
    if (counts.isEmpty) return _note(width, 'Aucun compte pour le moment.');
    return Wrap(spacing: 12, runSpacing: 12, children: [for (final e in counts.entries) _tile(roleLabel(e.key), '${e.value} compte${e.value > 1 ? 's' : ''}', 200)]);
  }
}

/// Commandes du compte (écran 183), lues dans la liste serveur déjà chargée.
class MyOrdersList extends ConsumerWidget {
  const MyOrdersList({super.key, this.width = 342, this.height = 600});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authProvider.select((a) => a.current == null))) return _note(width, 'Connectez-vous pour voir vos commandes.');
    final orders = ref.watch(ordersProvider);
    if (orders.isEmpty) return _note(width, 'Aucune commande pour le moment.');
    return SizedBox(
      width: width,
      height: height,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: orders.length,
        separatorBuilder: (_, _) => const Divider(height: 22, color: Color(0xFFF2EFF6)),
        itemBuilder: (_, i) {
          final o = orders[i];
          return Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('#${o.id}', style: _st(13.5, w: FontWeight.w700)), const SizedBox(height: 3), Text('${o.date} · ${fcfa(o.total)}', style: _st(11.5, c: _grey))])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFEEE9FF), borderRadius: BorderRadius.circular(11)), child: Text(o.badge, style: _st(11, w: FontWeight.w600, c: const Color(0xFF5A3FE0)))),
          ]);
        },
      ),
    );
  }
}
