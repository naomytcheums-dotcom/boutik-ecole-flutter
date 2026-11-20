import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../nav.dart';
import 'access.dart' show roleKey;
import 'auth.dart' show authProvider;
import 'backend.dart';
import 'missions.dart' show missionFailedProvider, missionLoadedProvider, missionProvider, missionScreens, redirectMissionScreen;
import 'store.dart';

/// Écrans qui décrivent UNE commande (détail, suivi, confirmation, réclamation, paiement, reçu, facture) : sans commande réelle ils n'affichent
/// jamais « #---- », « 0 FCFA » ni un statut inventé ; ils disent que la commande n'est pas disponible (lecture en cours, échec ou aucune commande).
const orderBoundScreens = {'09', '29', '30', '43', '44', '46', '47', '48', '257', '258', '259', '260'};

/// Écrans qui décrivent UNE mission (devis, jalons, suivi, preuve, WhatsApp) : tant que la lecture n'a pas réussi, ni jalon, ni montant, ni pourcentage inventé.
const missionBoundScreens = {'192', '193', '194', '195', '196', '197', '201', '233', '234'};

/// Page d'état d'une lecture : chargement, échec (avec « Réessayer ») ou aucun élément ; jamais un zéro ni une donnée à la place.
class LoadStatePage extends StatelessWidget {
  const LoadStatePage({super.key, required this.title, required this.body, this.onRetry});
  final String title, body;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    const f = 'PlusJakartaSans';
    TextStyle st(double s, FontWeight w, Color c) => TextStyle(inherit: false, fontFamily: f, fontSize: s, fontWeight: w, color: c, textBaseline: TextBaseline.alphabetic);
    Widget button(String label, VoidCallback onTap, {bool dark = true}) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
            decoration: BoxDecoration(color: dark ? const Color(0xFF111015) : Colors.white, borderRadius: BorderRadius.circular(28)),
            child: Text(label, style: st(13.5, FontWeight.w600, dark ? Colors.white : const Color(0xFF111015))),
          ),
        );
    return Scaffold(
      backgroundColor: const Color(0xFFF4EFE6),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(title, textAlign: TextAlign.center, style: st(20, FontWeight.w700, const Color(0xFF111015))),
                const SizedBox(height: 10),
                Text(body, textAlign: TextAlign.center, style: st(13.5, FontWeight.w400, const Color(0xFF4A4854)).copyWith(height: 1.55)),
                const SizedBox(height: 22),
                if (onRetry != null) ...[button('Réessayer', onRetry!), const SizedBox(height: 10)],
                button('Retour', () => gBack(context), dark: false),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class OrderGuard extends ConsumerWidget {
  const OrderGuard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Backend.ready || ref.watch(ordersProvider).isNotEmpty) return child;
    final loaded = ref.watch(ordersLoadedProvider);
    final failed = ref.watch(ordersFailedProvider);
    if (loaded) return const LoadStatePage(title: 'Aucune commande', body: 'Vous n’avez pas encore de commande. Vos achats apparaîtront ici, avec leur suivi.');
    if (failed) {
      return LoadStatePage(
        title: 'Commande indisponible',
        body: 'Vos commandes ne peuvent pas être chargées pour le moment. Vérifiez votre connexion puis réessayez.',
        onRetry: () => ref.read(ordersProvider.notifier).refresh(),
      );
    }
    return const LoadStatePage(title: 'Chargement de votre commande…', body: 'Un instant, nous relisons vos commandes.');
  }
}

class MissionGuard extends ConsumerWidget {
  const MissionGuard({super.key, required this.id, required this.child});
  final String id;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Backend.ready) return child;
    final m = ref.watch(missionProvider);
    if (ref.watch(missionLoadedProvider)) {
      // sans mission, l'application renvoie vers « Votre besoin » (191) : en attendant, aucun zéro de suivi n'est dessiné
      final leaving = missionScreens.contains(id) && redirectMissionScreen(ready: true, loaded: true, mission: m, screen: id, role: roleKey(ref.watch(authProvider).current));
      return leaving ? const LoadStatePage(title: 'Aucune mission en cours', body: 'Décrivez votre besoin pour démarrer une mission : son suivi apparaîtra ici.') : child;
    }
    if (m.real) return child;
    if (ref.watch(missionFailedProvider)) {
      return LoadStatePage(
        title: 'Mission indisponible',
        body: 'Votre mission ne peut pas être chargée pour le moment. Vérifiez votre connexion puis réessayez.',
        onRetry: () => ref.read(missionProvider.notifier).refresh(),
      );
    }
    return const LoadStatePage(title: 'Chargement de votre mission…', body: 'Un instant, nous relisons vos missions.');
  }
}
