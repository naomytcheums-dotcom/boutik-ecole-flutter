import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart';
import '../nav.dart';
import 'auth.dart';
import '../gdata.dart' show GData;
import 'backend.dart';

/// Notifications réelles (table `notifications`, isolée par utilisateur) et compteurs de non-lus.
class NotificationItem {
  const NotificationItem({required this.id, required this.kind, required this.title, required this.body, required this.createdAt, required this.read});
  final String id, kind, title, body;
  final DateTime createdAt;
  final bool read;

  factory NotificationItem.fromRow(Map<String, dynamic> r) => NotificationItem(
        id: (r['id'] ?? '').toString(),
        kind: (r['kind'] ?? '').toString(),
        title: (r['title'] ?? '').toString(),
        body: (r['body'] ?? '').toString(),
        createdAt: DateTime.tryParse((r['created_at'] ?? '').toString())?.toLocal() ?? DateTime.now(),
        read: r['read_at'] != null,
      );
}

class Notifs extends Notifier<List<NotificationItem>> {
  @override
  List<NotificationItem> build() {
    if (!Backend.ready) return const [];
    final uid = ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
    if (uid.isNotEmpty) {
      Future.microtask(refresh);
      final t = Timer.periodic(const Duration(seconds: 20), (_) => refresh());
      ref.onDispose(t.cancel);
    }
    return const [];
  }

  Future<void> refresh() async {
    final rows = await Backend.notifications();
    if (!ref.mounted) return;
    state = [for (final r in rows) NotificationItem.fromRow(r)];
    ref.invalidate(unreadProvider);
  }

  Future<void> markAllRead() async {
    state = [for (final n in state) NotificationItem(id: n.id, kind: n.kind, title: n.title, body: n.body, createdAt: n.createdAt, read: true)];
    await Backend.markNotificationsRead();
    if (ref.mounted) ref.invalidate(unreadProvider);
  }
}

final notifsProvider = NotifierProvider<Notifs, List<NotificationItem>>(Notifs.new);

/// Compteurs de non-lus (notifications, messages) lus sur le serveur.
final unreadProvider = FutureProvider<({int notifications, int messages})>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  // Mise à jour automatique : le chiffre suit les nouvelles notifications sans recharger la page.
  final t = Timer(const Duration(seconds: 25), () async {
    // « Wi-Fi uniquement » : pas d'actualisation automatique sur données mobiles ; « Jamais » : aucune. Le réseau est revérifié avant chaque actualisation.
    if (await GData.syncAllowed() && ref.mounted) ref.invalidateSelf();
  });
  ref.onDispose(t.cancel);
  return Backend.unreadCounts();
});

/// Pastille de la cloche : le nombre de notifications non lues, mis à jour à chaque nouvelle notification ; rien quand il n'y en a plus.
/// Hors connexion au serveur (aperçu), le point de la maquette est conservé.
class NotifBadge extends ConsumerWidget {
  const NotifBadge({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Backend.ready) return const Align(alignment: Alignment.topLeft, child: SizedBox(width: 9, height: 9, child: DecoratedBox(decoration: BoxDecoration(color: Color(0xFFE5484D), shape: BoxShape.circle))));
    final n = ref.watch(unreadProvider).value?.notifications ?? 0;
    if (n <= 0) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: const Color(0xFFE5484D), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white, width: 1.2)),
        child: Text(n > 99 ? '99+' : '$n', style: const TextStyle(inherit: false, fontFamily: 'PlusJakartaSans', fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white, height: 1.1)),
      ),
    );
  }
}

/// Filtre de l'écran : 0 toutes · 1 commandes · 2 messages · 3 autres.
class NotifFilter extends Notifier<int> {
  @override
  int build() => 0;
  void set(int v) => state = v;
}

final notifFilterProvider = NotifierProvider<NotifFilter, int>(NotifFilter.new);

String _ago(DateTime d) {
  final m = DateTime.now().difference(d).inMinutes;
  if (m < 1) return 'À l’instant';
  if (m < 60) return 'Il y a $m min';
  if (m < 1440) return 'Il y a ${m ~/ 60} h';
  return 'Il y a ${m ~/ 1440} j';
}

TextStyle _t(double size, FontWeight w, Color c) => TextStyle(inherit: false, fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c, textBaseline: TextBaseline.alphabetic);

String _glyph(String kind) => switch (kind) { 'order' => '€', 'message' => '✉', 'listing' => '★', _ => '•' };

/// Liste réelle des notifications, dessinée dans le style de l'écran 50.
Widget notificationsPanel() => gP(
      24, 196, 342, 540,
      Consumer(builder: (context, ref, _) {
        final f = ref.watch(notifFilterProvider);
        final all = ref.watch(notifsProvider);
        final items = [
          for (final n in all)
            if (f == 0 || (f == 1 && n.kind == 'order') || (f == 2 && n.kind == 'message') || (f == 3 && n.kind != 'order' && n.kind != 'message')) n,
        ];
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 80),
            child: Align(alignment: Alignment.topCenter, child: Text('Aucune notification pour le moment.', style: _t(13.5, FontWeight.w500, const Color(0xFF57545F)))),
          );
        }
        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 64, color: Color(0xFFF2EFF6)),
          itemBuilder: (context, i) {
            final n = items[i];
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                ref.read(notifsProvider.notifier).markAllRead();
                gOpen(context, switch (n.kind) { 'message' => '52', 'order' => '28', 'listing' => '61', _ => '51' });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: const Color(0xFFF1EEFB), borderRadius: BorderRadius.circular(13)),
                    alignment: Alignment.center,
                    child: Text(_glyph(n.kind), style: _t(16, FontWeight.w600, const Color(0xFF5A3FE0))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _t(13.5, FontWeight.w600, const Color(0xFF111015))),
                      const SizedBox(height: 3),
                      Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: _t(11.5, FontWeight.w400, const Color(0xFF57545F))),
                      const SizedBox(height: 3),
                      Text(_ago(n.createdAt), style: _t(10.5, FontWeight.w400, const Color(0xFF57545F))),
                    ]),
                  ),
                  if (!n.read)
                    Container(
                      margin: const EdgeInsets.only(top: 4, left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFEFEBFA), borderRadius: BorderRadius.circular(11)),
                      child: Text('Nouveau', style: _t(11, FontWeight.w600, const Color(0xFF5A3FE0))),
                    ),
                ]),
              ),
            );
          },
        );
      }),
      show: !demoContent, // hors connexion (aperçu, tests) : les lignes d'exemple de la maquette restent affichées
    );

/// Compteur rouge de non-lus à poser sur une icône (affiche rien quand tout est lu ou hors connexion).
Widget unreadBadge(double x, double y, {bool messages = false}) => gP(
      x, y, 18, 18,
      Consumer(builder: (context, ref, _) {
        final u = ref.watch(unreadProvider).asData?.value;
        final n = u == null ? 0 : (messages ? u.messages : u.notifications);
        if (n <= 0) return const SizedBox.shrink();
        return Container(
          decoration: const BoxDecoration(color: Color(0xFFE5484D), shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(n > 9 ? '9+' : '$n', style: _t(10, FontWeight.w700, Colors.white)),
        );
      }),
    );
