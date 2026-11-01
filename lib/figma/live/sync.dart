import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gToast;
import 'backend.dart';
import 'seller.dart' show platformListingsProvider;
import 'store.dart';

/// Résultat d'une resynchronisation réelle (écran 150-1 « Synchronisation »).
class SyncReport {
  const SyncReport({this.running = false, this.at, this.favorites, this.messages, this.orders});
  final bool running;

  /// Heure de la dernière resynchronisation terminée (null : jamais dans cette session).
  final DateTime? at;

  /// null : pas encore vérifié ; vrai : relu sur le serveur ; faux : lecture échouée.
  final bool? favorites, messages, orders;

  /// Panier (conservé sur l'appareil, toujours à jour), favoris et messages : éléments à jour sur 3.
  int get upToDate => 1 + (favorites == true ? 1 : 0) + (messages == true ? 1 : 0);
  int get percent => (upToDate * 100 / 3).round();
  bool get allOk => favorites == true && messages == true && orders == true;
}

class SyncNotifier extends Notifier<SyncReport> {
  @override
  SyncReport build() => const SyncReport();

  /// Relit les données du compte sur le serveur ; rien n'est annoncé « synchronisé » sans réponse du serveur.
  Future<SyncReport> run() async {
    if (state.running) return state;
    state = SyncReport(running: true, at: state.at, favorites: state.favorites, messages: state.messages, orders: state.orders);
    final fav = await Backend.probe('favorites');
    final msg = await Backend.probe('messages');
    final ord = await Backend.myOrders() != null;
    if (fav) ref.invalidate(favoritesProvider);
    if (ord) await ref.read(ordersProvider.notifier).refresh();
    await ref.read(platformListingsProvider.notifier).refresh();
    if (!ref.mounted) return state;
    final now = DateTime.now();
    if (fav && msg && ord) ref.read(lastSyncProvider.notifier).set(now);
    state = SyncReport(at: now, favorites: fav, messages: msg, orders: ord);
    return state;
  }
}

final syncProvider = NotifierProvider<SyncNotifier, SyncReport>(SyncNotifier.new);

/// « Synchroniser maintenant » (150-1) : le message dit ce qui a réellement été relu.
Future<void> syncNowAction(BuildContext context, WidgetRef ref) async {
  if (!Backend.ready) {
    gToast(context, 'Aucun serveur joint : rien à synchroniser.');
    return;
  }
  final r = await ref.read(syncProvider.notifier).run();
  if (!context.mounted) return;
  gToast(context, r.allOk ? 'Synchronisation terminée' : 'Synchronisation incomplète : vérifiez votre connexion puis réessayez.');
}

/// Libellé d'un élément : « Synchronisé », « Échec de la lecture », « Non vérifié ».
String syncLabel(bool? ok) => ok == null ? 'Non vérifié' : (ok ? 'Synchronisé' : 'Échec de la lecture');

/// « Aujourd’hui 10:24 », « 31/10 18:05 », ou « Jamais » si aucune lecture n'a abouti.
String syncTime(DateTime? t, DateTime now) {
  if (t == null) return 'Jamais';
  String two(int v) => v.toString().padLeft(2, '0');
  final hm = '${two(t.hour)}:${two(t.minute)}';
  return (t.year == now.year && t.month == now.month && t.day == now.day) ? 'Aujourd’hui $hm' : '${two(t.day)}/${two(t.month)} $hm';
}
