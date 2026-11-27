import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gToast;
import '../i18n.dart' show Text;
import 'auth.dart' show requireLogin;
import 'backend.dart';
import 'evenements.dart' show AppEvent, eventDetail;
import 'marche/marche_data.dart' show kInk, kViolet, marcheCall, mst;
import 'marche/marche_screens.dart' show ProductPageScreen;
import 'mission_proposal_sheet.dart' show openMissionProposal;
import 'opportunites_screens.dart' show OpportunityDetailScreen;
import 'project_cards.dart' show ProjectDetailPage;
import 'referral.dart' show ReferralShareKit;

/// Action Unique d'un live (migration 20261127500000) : un seul bouton, choisi par l'hôte avant le live, qui ouvre le parcours EXISTANT correspondant dans une feuille modale,
/// sans quitter le live. Aucun paiement n'est géré ici : achat, devis, réservation, inscription payante et cadeaux passent par leurs parcours habituels (confirmations serveur comprises).
/// Si le serveur dit que l'action n'est plus disponible, ou s'il n'existe aucun parcours pour elle, le bouton est ABSENT (jamais décoratif).

/// Libellé du bouton par action.
const kLiveActionLabels = {
  'acheter': 'Acheter',
  'soutenir': 'Soutenir',
  'parrainer': 'Parrainer',
  'postuler': 'Postuler',
  's_inscrire': 'S’inscrire',
  'voter': 'Voter',
  'telecharger': 'Télécharger',
  'noter': 'Noter',
  'demander_devis': 'Demander un devis',
  'encourager': 'Encourager',
  'offrir': 'Offrir',
  'reserver': 'Réserver',
};

const kLiveActionIcons = {
  'acheter': Icons.shopping_bag_outlined,
  'soutenir': Icons.favorite_border,
  'parrainer': Icons.group_add_outlined,
  'postuler': Icons.work_outline,
  's_inscrire': Icons.event_available_outlined,
  'voter': Icons.how_to_vote_outlined,
  'telecharger': Icons.download_outlined,
  'noter': Icons.star_border,
  'demander_devis': Icons.request_quote_outlined,
  'encourager': Icons.emoji_events_outlined,
  'offrir': Icons.card_giftcard,
  'reserver': Icons.event_seat_outlined,
};

/// Parcours existants. `null` : aucun parcours pour cette combinaison (« Postuler » sur une mission ouvre la feuille de proposition, mission_proposal_sheet.dart).
enum LiveActionRoute { product, opportunity, mission, event, project, gift, referral }

LiveActionRoute? liveActionRoute(String? action, String? kind, {String? status, bool canGift = false}) {
  switch (action) {
    case 'acheter' || 'reserver' || 'demander_devis' || 'telecharger' || 'noter':
      return kind == 'listing' ? LiveActionRoute.product : null;
    case 'postuler':
      return kind == 'opportunity' ? LiveActionRoute.opportunity : (kind == 'mission' ? LiveActionRoute.mission : null);
    case 's_inscrire':
      return kind == 'event' ? LiveActionRoute.event : null;
    case 'voter' || 'soutenir' || 'encourager':
      return kind == 'project' ? LiveActionRoute.project : null;
    case 'offrir':
      return status == 'live' && canGift ? LiveActionRoute.gift : null;
    case 'parrainer':
      return LiveActionRoute.referral;
  }
  return null;
}

/// Réglages publics d'un live (live_settings_get) : null si le live n'est pas lisible par l'appelant.
final liveSettingsProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, id) async {
  final r = await marcheCall('live_settings_get', {'p_live': id});
  if (r.error != null) throw Exception('${r.error}');
  return r.data is Map ? Map<String, dynamic>.from(r.data as Map) : null;
}, retry: (_, _) => null);

Future<void> _sheet(BuildContext context, Widget child) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFFF7F4FA),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SizedBox(height: MediaQuery.of(ctx).size.height * 0.92, child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(22)), child: child)),
    );

/// Fiche de l'événement (inscription gratuite ou payante, parcours existant des événements) : ouverte depuis l'Action Unique « S'inscrire » et depuis un live à billet.
Future<void> openEventRegistration(BuildContext context, WidgetRef ref, String eventId) async {
  final r = await Backend.rpc('events_upcoming', {'p_limit': 100, 'p_kind': null});
  if (!context.mounted) return;
  final found = r.error == null && r.data is List ? [for (final x in r.data as List) if (x is Map && '${x['id']}' == eventId) AppEvent.fromRow(x)].firstOrNull : null;
  if (found == null) return gToast(context, r.error != null ? Backend.userMessage(r.error!) : 'Cet événement n’accepte plus d’inscriptions.');
  return eventDetail(context, ref, found);
}

Future<void> openLiveAction(BuildContext context, WidgetRef ref, Map<String, dynamic> s, {String? hostId, VoidCallback? onGift}) async {
  final action = s['main_action'] as String?;
  final kind = s['action_target_kind'] as String?;
  final id = '${s['action_target_id'] ?? ''}';
  final route = liveActionRoute(action, kind, status: '${s['status']}', canGift: onGift != null);
  if (route == null) return;
  switch (route) {
    case LiveActionRoute.product:
      return _sheet(context, ProductPageScreen(id: id));
    case LiveActionRoute.opportunity:
      return _sheet(context, OpportunityDetailScreen(id: id));
    case LiveActionRoute.mission:
      return openMissionProposal(context, ref, id, (w) => _sheet(context, w));
    case LiveActionRoute.project:
      return _sheet(context, ProjectDetailPage(projectId: id));
    case LiveActionRoute.event:
      return openEventRegistration(context, ref, id);
    case LiveActionRoute.gift:
      if (!await requireLogin(context, ref, 'offrir un cadeau') || !context.mounted) return;
      return onGift!();
    case LiveActionRoute.referral:
      if (!await requireLogin(context, ref, 'parrainer des proches') || !context.mounted) return;
      return _sheet(
        context,
        Scaffold(
          backgroundColor: const Color(0xFFF7F4FA),
          appBar: AppBar(backgroundColor: const Color(0xFFF7F4FA), elevation: 0, title: Text('Parrainer', style: mst(18, w: FontWeight.w800)), automaticallyImplyLeading: false, actions: [IconButton(tooltip: 'Fermer', icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).maybePop())]),
          body: const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 0), child: ReferralShareKit(width: 358)),
        ),
      );
  }
}

/// Bouton unique : absent tant que le serveur n'a pas confirmé une action disponible et qu'un parcours existant la porte.
class LiveActionButton extends ConsumerWidget {
  const LiveActionButton({super.key, required this.liveId, this.hostId, this.dark = false, this.onGift});
  final String liveId;
  final String? hostId;
  final bool dark;
  final VoidCallback? onGift;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(liveSettingsProvider(liveId)).value;
    if (s == null || s['action_available'] != true) return const SizedBox.shrink();
    final action = '${s['main_action']}';
    if (liveActionRoute(action, s['action_target_kind'] as String?, status: '${s['status']}', canGift: onGift != null) == null) return const SizedBox.shrink();
    final label = kLiveActionLabels[action] ?? action;
    final target = '${s['action_target_title'] ?? ''}'.trim();
    return Semantics(
      button: true,
      label: target.isEmpty ? label : '$label : $target',
      child: FilledButton.icon(
        key: const Key('live-action-unique'),
        onPressed: () => openLiveAction(context, ref, s, hostId: hostId, onGift: onGift),
        style: FilledButton.styleFrom(backgroundColor: dark ? Colors.white : kViolet, foregroundColor: dark ? kInk : Colors.white, minimumSize: const Size(0, 48), padding: const EdgeInsets.symmetric(horizontal: 18)),
        icon: Icon(kLiveActionIcons[action] ?? Icons.touch_app_outlined, size: 20),
        label: Text(target.isEmpty ? label : '$label · $target', maxLines: 1, overflow: TextOverflow.ellipsis, style: mst(14, w: FontWeight.w800, c: dark ? kInk : Colors.white)),
      ),
    );
  }
}
