import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:go_router/go_router.dart';

import '../../core/router/paths.dart' show screenPath;

import '../gen.dart';
import '../nav.dart';
import 'access.dart' show canOpen, roleKey;
import 'auth.dart';
import '../gdata.dart' show GData;
import 'backend.dart';
import 'retry_note.dart';
import 'certificates_page.dart' show CertificatesPage;
import 'messages.dart' show selectedConversationProvider, conversationsProvider, contactOrderSeller;
import 'missions.dart' show selectedMissionIdProvider, missionProvider;
import 'services.dart' show quotesDialog;
import 'quote_negotiation.dart' show openQuoteNegotiation;
import 'paiement_messagerie.dart' show selectedPaymentProvider;
import 'seller.dart' show selectedSellerOrderProvider;
import 'store.dart' show StrV, ordersProvider, selectedOrderIdProvider;

/// Notifications réelles (table `notifications`, isolée par utilisateur) et compteurs de non-lus.
class NotificationItem {
  const NotificationItem({required this.id, required this.kind, required this.title, required this.body, required this.createdAt, required this.read, this.data = const {}});
  final String id, kind, title, body;
  final DateTime createdAt;
  final bool read;

  /// Données jointes par le serveur (numéro de commande, conversation, paiement, opportunité…).
  final Map<String, dynamic> data;

  NotificationItem asRead() => NotificationItem(id: id, kind: kind, title: title, body: body, createdAt: createdAt, read: true, data: data);

  factory NotificationItem.fromRow(Map<String, dynamic> r) => NotificationItem(
        id: (r['id'] ?? '').toString(),
        kind: (r['kind'] ?? '').toString(),
        title: (r['title'] ?? '').toString(),
        body: (r['body'] ?? '').toString(),
        createdAt: DateTime.tryParse((r['created_at'] ?? '').toString())?.toLocal() ?? DateTime.now(),
        read: r['read_at'] != null,
        data: r['data'] is Map ? Map<String, dynamic>.from(r['data'] as Map) : const {},
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
    final rows = await Backend.notificationsOrNull();
    if (!ref.mounted) return;
    if (rows == null) {
      // lecture échouée : la liste déjà affichée est conservée, jamais remplacée par « aucune notification »
      ref.read(notifsStatusProvider.notifier).set(LoadStatus.failed);
      return;
    }
    state = [for (final r in rows) NotificationItem.fromRow(r)];
    ref.read(notifsStatusProvider.notifier).set(LoadStatus.ok);
    ref.invalidate(unreadProvider);
  }

  Future<void> markAllRead() async {
    state = [for (final n in state) n.asRead()];
    await Backend.markNotificationsRead();
    if (ref.mounted) ref.invalidate(unreadProvider);
  }

  /// Marque seulement cette notification comme lue.
  Future<void> markRead(String id) async {
    if (!state.any((n) => n.id == id && !n.read)) return;
    state = [for (final n in state) n.id == id ? n.asRead() : n];
    await Backend.markNotificationRead(id);
    if (ref.mounted) ref.invalidate(unreadProvider);
  }
}

/// Notification affichée sur l'écran de détail (identifiant serveur).
final selectedNotificationProvider = NotifierProvider<StrV, String>(StrV.new);

final notifsProvider = NotifierProvider<Notifs, List<NotificationItem>>(Notifs.new);

/// Résultat de la dernière lecture des notifications : « chargement » tant qu'aucune lecture n'a abouti pour le compte connecté.
class NotifsStatus extends Notifier<LoadStatus> {
  @override
  LoadStatus build() => ref.watch(authProvider.select((a) => a.current?.serverId ?? '')).isEmpty ? LoadStatus.ok : LoadStatus.loading;
  void set(LoadStatus s) => state = s;
}

final notifsStatusProvider = NotifierProvider<NotifsStatus, LoadStatus>(NotifsStatus.new);

/// Liste vide : chargement ou échec de lecture (avec « Réessayer ») selon l'état ; null quand la liste est réellement vide.
Widget? _notifsUnavailable(WidgetRef ref, List<NotificationItem> items) {
  if (items.isNotEmpty || !Backend.ready) return null;
  return switch (ref.watch(notifsStatusProvider)) {
    LoadStatus.loading => const LoadingNote('Chargement de vos notifications…'),
    LoadStatus.failed => RetryNote(message: 'Vos notifications ne peuvent pas être chargées pour le moment. Vérifiez votre connexion.', onRetry: () => ref.read(notifsProvider.notifier).refresh()),
    LoadStatus.ok => null,
  };
}

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

/// Filtre de l'écran : 0 toutes · 1 commandes et paiements · 2 messages · 3 autres.
class NotifFilter extends Notifier<int> {
  @override
  int build() => 0;
  void set(int v) => state = v;
}

final notifFilterProvider = NotifierProvider<NotifFilter, int>(NotifFilter.new);

/// Groupe d'une notification : 1 commandes (commande, paiement, réclamation, litige, devis, argent), 2 messages, 3 autres.
int notifGroup(String kind) => switch (kind) {
      'order' || 'payment' || 'claim' || 'dispute' || 'money' || 'quote' || 'payout' || 'refund' => 1,
      'message' || 'teammate_message' => 2,
      _ => 3,
    };

bool _inGroup(NotificationItem n, int f) => f == 0 || notifGroup(n.kind) == f;

typedef ReadFn = T Function<T>(ProviderListenable<T> provider);

/// Destination d'une notification d'après son type et ses données. Renvoie vrai si un écran a été ouvert ;
/// faux si ce type n'a pas d'écran propre (le détail de la notification est alors la bonne destination).
/// [router] et [reader] permettent de l'appeler après que l'écran appelant a été retiré (ouverture depuis un clic sur une notification du navigateur).
bool openNotification(BuildContext context, WidgetRef? ref, NotificationItem n, {GoRouter? router, ReadFn? reader}) {
  final r = router ?? GoRouter.of(context);
  final read = reader ?? ref!.read;
  void gOpen(BuildContext _, String id) => r.push(screenPath(id));
  void gOpenProfile(BuildContext _, String user) => r.push('${screenPath('247')}?user=${Uri.encodeQueryComponent(user)}');
  final d = n.data;
  String s(String k) => '${d[k] ?? ''}'.trim();
  String first(List<String> ks) => ks.map(s).firstWhere((v) => v.isNotEmpty, orElse: () => '');
  final account = read(authProvider).current;
  String clean(String v) => v.replaceAll('#', '').trim();
  switch (n.kind) {
    case 'payout':
      if (const {'finance', 'admin'}.contains(roleKey(account))) {
        r.push('/admin/sequestre');
        return true;
      }
      if (!canOpen(account, '66')) return false;
      gOpen(context, '66');
      return true;
    case 'refund' when const {'finance', 'admin'}.contains(roleKey(account)):
      r.push('/admin/sequestre');
      return true;
    case 'order' || 'refund':
      final num = clean(first(['order_number', 'order']));
      if (num.isEmpty) {
        gOpen(context, '28');
        return true;
      }
      final orders = read(ordersProvider);
      final mine = orders.where((o) => clean(o.id) == num);
      if (mine.isNotEmpty) {
        read(selectedOrderIdProvider.notifier).set(mine.first.id);
        gOpen(context, '09');
      } else if (canOpen(account, '64')) {
        read(selectedSellerOrderProvider.notifier).set(num);
        gOpen(context, '64');
      } else {
        gOpen(context, '28');
      }
      return true;
    case 'message' || 'teammate_message':
      final cid = s('conversation_id');
      if (n.kind == 'teammate_message') {
        gOpen(context, '163');
        return true;
      }
      if (cid.isEmpty) {
        gOpen(context, '52');
        return true;
      }
      read(selectedConversationProvider.notifier).set(cid);
      read(conversationsProvider.notifier).refresh();
      gOpen(context, '53');
      return true;
    case 'listing':
      if (!canOpen(account, '61')) return false;
      gOpen(context, '61');
      return true;
    case 'money':
      if (!canOpen(account, '66')) return false;
      gOpen(context, '66');
      return true;
    case 'payment':
      final pid = first(['payment_id', 'payment']);
      if (pid.isEmpty) {
        r.push('/paiements');
      } else {
        read(selectedPaymentProvider.notifier).select(pid);
        r.push('/paiement');
      }
      return true;
    case 'claim' || 'dispute':
      r.push('/litiges');
      return true;
    case 'mission':
      final mid = s('mission_id');
      if (mid.isNotEmpty) {
        read(selectedMissionIdProvider.notifier).set(mid);
        read(missionProvider.notifier).refresh();
      }
      gOpen(context, '194');
      return true;
    case 'quote':
      if (ref == null) return false;
      final quoteId = first(['quote_id', 'quote']);
      if (quoteId.isNotEmpty) {
        openQuoteNegotiation(context, ref, {'id': quoteId});
      } else {
        quotesDialog(context, ref);
      }
      return true;
    case 'opportunity_reminder' || 'opportunity_alert' || 'opportunity_review' || 'opportunity_application' || 'opportunity_invite':
      final id = first(['opportunity', 'opportunity_id']);
      r.push(id.isEmpty ? '/opportunites' : '/opportunites/$id');
      return true;
    case 'mentor_request':
      r.push('/mentors/demandes');
      return true;
    case 'mentor_profile':
      r.push('/mentors/profil');
      return true;
    case 'document':
      gOpen(context, '154');
      return true;
    case 'contest_reminder' || 'contest_review' || 'contest_prize' || 'contest':
      final id = first(['announcement', 'announcement_id']);
      r.push(id.isEmpty ? '/concours' : '/concours/$id');
      return true;
    case 'review' || 'question' || 'alert':
      final id = first(['listing_id', 'listing']);
      if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id)) return false;
      r.push('/marche/produit/$id');
      return true;
    case 'follow':
      final uid = first(['user', 'follower']);
      if (uid.isEmpty) return false;
      gOpenProfile(context, uid);
      return true;
    case 'post' || 'comment':
      final pid = first(['post', 'post_id']);
      final target = n.kind == 'comment' && pid.isNotEmpty ? screenPath('252') : screenPath('244');
      r.push(pid.isEmpty ? target : '$target?post=${Uri.encodeQueryComponent(pid)}');
      return true;
    case 'post_review':
      if (!const {'dept', 'admin', 'support'}.contains(roleKey(account))) return false;
      r.push('/moderation/reseau');
      return true;
    case 'report':
      if (!const {'dept', 'admin', 'support'}.contains(roleKey(account)) || first(['post', 'comment', 'story']).isEmpty) return false;
      r.push('/moderation/reseau');
      return true;
    case 'shop':
      final slug = first(['shop']);
      if (slug.isEmpty) return false;
      r.push('/marche/boutique/$slug');
      return true;
    case 'live':
      gOpen(context, 'L1');
      return true;
    case 'event':
      if (s('event').isEmpty) {
        gOpen(context, '101');
      } else if (n.title.startsWith('Nouvelle inscription') && const {'dept', 'direction', 'finance', 'admin'}.contains(roleKey(account))) {
        r.push('/evenements/gerer');
      } else {
        r.push('/evenements/mes');
      }
      return true;
    case 'institution':
      // Partenariats et validations institutionnelles : seuls la direction, les départements et l'administration ont l'écran (une organisation liée n'a que la notification).
      if (const {'direction', 'dept', 'admin'}.contains(roleKey(account))) r.push(s('partnership').isNotEmpty ? '/direction/partenariats' : '/direction/validations');
      return true;
    case 'department':
      if (roleKey(account) == 'admin' && (d['type'] == 'unassigned' || d['type'] == 'unassigned_summary')) {
        r.push('/departement/rattachements');
      } else if (const {'dept', 'admin'}.contains(roleKey(account))) {
        r.push('/departement');
      }
      return true;
    case 'partnership':
      if (const {'direction', 'dept', 'admin'}.contains(roleKey(account))) r.push('/departement/partenariats');
      return true;
    case 'project':
      final staff = const {'dept', 'admin'}.contains(roleKey(account));
      if (n.title.startsWith('Accompagnement') || n.title.startsWith('Demande d’accompagnement') || n.title.startsWith('Demande d\'accompagnement')) {
        r.push('/accompagnement');
      } else if (d['invitation'] == true || n.title.contains('équipe') || n.title.startsWith('Invitation')) {
        gOpen(context, '81');
      } else if (staff) {
        r.push('/departement/validations');
      } else {
        gOpen(context, '205');
      }
      return true;
    case 'campaign':
      if (const {'dept', 'admin'}.contains(roleKey(account))) {
        r.push('/departement/validations');
      } else {
        gOpen(context, '86');
      }
      return true;
    case 'sos':
      r.push('/innovations/sos');
      return true;
    case 'victory':
      r.push('/innovations/victoires');
      return true;
    case 'skill':
      r.push('/innovations/competences');
      return true;
    case 'challenge':
      r.push('/innovations/defis');
      return true;
    case 'points':
      r.push('/innovations/points');
      return true;
    case 'support':
      r.push('/aide/demandes');
      return true;
    case 'support_ticket' || 'message_report':
      r.push('/support/boite');
      return true;
    case String k when k.startsWith('community'):
      final cid = first(['community']);
      r.push(RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(cid) ? '/communaute/$cid' : '/communautes');
      return true;
    case 'company_plan':
      // administrateur : demandes de forfait à activer ; entreprise : accueil entreprise (forfait, paiement)
      r.push(roleKey(account) == 'admin' && s('owner').isNotEmpty ? '/admin/forfaits' : '/s/03');
      return true;
    case 'company_team':
      // invitation reçue : « Mes entreprises » permet de la rejoindre ou de la décliner ; sinon la liste de l'équipe
      r.push(d['invitation'] == true || n.title.startsWith('Invitation à rejoindre') ? '/mes-entreprises' : '/entreprise/equipe');
      return true;
    case 'company_review':
      // administrateur : file de vérification ; organisation : sa fiche (statut, motif)
      r.push(roleKey(account) == 'admin' && s('owner').isNotEmpty && s('status').isEmpty ? '/admin/entreprises' : '/entreprise/profil');
      return true;
    case 'org_partnership':
      // partenariat décidé avec l'établissement : le titulaire l'accepte ou le conteste ; un administrateur d'équipe passe par l'espace partagé de l'organisation
      r.push(s('owner').isNotEmpty && s('owner') != (account?.serverId ?? '') ? '/entreprise/espace/${s('owner')}' : '/entreprise/partenariats');
      return true;
    case 'talent_contact':
      final from = first(['from']);
      if (from.isEmpty) return false;
      gOpenProfile(context, from);
      return true;
    case 'cv_shared':
      final token = first(['cv_token']);
      if (token.isEmpty) return false;
      r.push('/cv/${Uri.encodeComponent(token)}');
      return true;
    case 'study_room':
      final rid = first(['community']);
      if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(rid)) return false;
      r.push('/communaute/$rid');
      return true;
    case 'certification':
      // l'étudiant retrouve l'état de sa certification (et peut la redemander) dans l'espace vendeur ; la file de revue des demandes est ailleurs
      if (const {'dept', 'admin'}.contains(roleKey(account)) || !canOpen(account, '73')) return false;
      r.push('/marche/vendeur');
      return true;
    case 'verification':
      if (s('document').isEmpty || !canOpen(account, '154')) return false;
      gOpen(context, '154');
      return true;
    case 'certificate':
      if (!context.mounted) return false;
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CertificatesPage()));
      return true;
    case 'security':
      gOpen(context, '148-2');
      return true;
    case 'account_deletion':
      if (const {'admin', 'support'}.contains(roleKey(account))) return false;
      gOpen(context, '148-1');
      return true;
    case 'moderation':
      gOpen(context, '244');
      return true;
    case 'listing_review':
      if (!const {'dept', 'admin', 'support'}.contains(roleKey(account))) return false;
      r.push('/marche/moderation');
      return true;
    case 'teammate_invite':
      gOpen(context, '163');
      return true;
    case 'wish':
      final wid = s('wish_id');
      if (RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(wid)) {
        r.push('${screenPath('217')}?wish=${Uri.encodeQueryComponent(wid)}');
      } else {
        gOpen(context, '216');
      }
      return true;
    case 'duel':
      gOpen(context, '220');
      return true;
    case 'referral':
      if (!canOpen(account, '240')) return false;
      gOpen(context, '240');
      return true;
    case 'subscription':
      r.push('/offres');
      return true;
    case 'live_reminder':
      gOpen(context, 'L1');
      return true;
  }
  return false;
}

/// Libellé du bouton d'action du détail ; null quand le type n'a pas d'écran propre.
String? notificationActionLabel(NotificationItem n) => switch (n.kind) {
      'order' => 'Voir la commande',
      'message' || 'teammate_message' => 'Ouvrir la conversation',
      'listing' => 'Mon catalogue',
      'money' => 'Voir mes revenus',
      'payment' => 'Voir le paiement',
      'claim' || 'dispute' => 'Voir mon litige',
      'mission' => 'Voir la mission',
      'quote' => 'Voir mes devis',
      'opportunity_reminder' || 'opportunity_alert' || 'opportunity_review' || 'opportunity_application' || 'opportunity_invite' => 'Voir l’opportunité',
      'contest_reminder' || 'contest_review' || 'contest_prize' || 'contest' => 'Voir le concours',
      'mentor_request' => 'Voir mes demandes de mentor',
      'mentor_profile' => 'Voir mon profil mentor',
      'document' => 'Voir mon dossier',
      'review' || 'question' || 'alert' => 'Voir le produit',
      'follow' => 'Voir le profil',
      'company_plan' => 'Voir le forfait',
      'company_team' => 'Voir l’équipe ou l’invitation',
      'company_review' => 'Voir la vérification',
      'talent_contact' => 'Voir qui vous contacte',
      'cv_shared' => 'Voir le CV',
      'post' || 'comment' => 'Voir la publication',
      'post_review' => 'Valider les publications',
      'report' => 'Voir les signalements',
      'shop' => 'Voir la boutique',
      'study_room' => 'Ouvrir la communauté',
      'payout' => 'Voir mes retraits',
      'refund' => 'Voir la commande',
      'certification' => 'Voir ma certification',
      'verification' => 'Voir mon dossier',
      'certificate' => 'Voir mes certificats',
      'security' => 'Sécurité du compte',
      'account_deletion' => 'Voir mes réglages',
      'moderation' => 'Voir le réseau',
      'listing_review' => 'Valider les annonces',
      'teammate_invite' => 'Voir mes coéquipiers',
      'wish' => 'Voir le marché des vœux',
      'duel' => 'Voir le duel',
      'referral' => 'Voir mon parrainage',
      'subscription' => 'Voir les offres',
      'live_reminder' => 'Voir les lives',
      'live' => 'Voir les lives',
      'event' => 'Voir l’événement',
      'project' => 'Voir mon projet',
      'campaign' => 'Voir la campagne',
      'sos' => 'Voir le SOS',
      'victory' => 'Voir le mur des victoires',
      'skill' => 'Voir le marché des compétences',
      'challenge' => 'Voir les défis',
      'points' => 'Voir mes points',
      'support' => 'Mes demandes d’aide',
      'support_ticket' => 'Ouvrir la boîte du support',
      'message_report' => 'Voir les signalements',
      String k when k.startsWith('community') => 'Voir les communautés',
      _ => null,
    };

/// Ouvre l'écran pertinent pour une notification touchée dans une liste, ou son détail à défaut ; marque seulement celle-ci comme lue.
void tapNotification(BuildContext context, WidgetRef ref, NotificationItem n) {
  ref.read(notifsProvider.notifier).markRead(n.id);
  if (notificationActionLabel(n) != null && openNotification(context, ref, n)) return;
  ref.read(selectedNotificationProvider.notifier).set(n.id);
  gOpen(context, '51');
}

String _ago(DateTime d) {
  final m = DateTime.now().difference(d).inMinutes;
  if (m < 1) return 'À l’instant';
  if (m < 60) return 'Il y a $m min';
  if (m < 1440) return 'Il y a ${m ~/ 60} h';
  return 'Il y a ${m ~/ 1440} j';
}

TextStyle _t(double size, FontWeight w, Color c) => TextStyle(inherit: false, fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c, textBaseline: TextBaseline.alphabetic);

String _glyph(String kind) => switch (notifGroup(kind)) { 1 => '€', 2 => '✉', _ => kind == 'listing' ? '★' : '•' };

Widget _row(BuildContext context, WidgetRef ref, NotificationItem n) => InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => tapNotification(context, ref, n),
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
              Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _t(13.5, n.read ? FontWeight.w500 : FontWeight.w700, const Color(0xFF111015))),
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

/// Liste réelle des notifications, dessinée dans le style de l'écran 50.
Widget notificationsPanel() => gP(
      24, 196, 342, 540,
      Consumer(builder: (context, ref, _) {
        final f = ref.watch(notifFilterProvider);
        final all = ref.watch(notifsProvider);
        final items = [for (final n in all) if (_inGroup(n, f)) n];
        final unavailable = _notifsUnavailable(ref, all);
        if (unavailable != null) return unavailable;
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 80),
            child: Align(alignment: Alignment.topCenter, child: Text(f == 0 ? 'Aucune notification pour le moment.' : 'Aucune notification dans cette catégorie.', style: _t(13.5, FontWeight.w500, const Color(0xFF57545F)))),
          );
        }
        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 64, color: Color(0xFFF2EFF6)),
          itemBuilder: (context, i) => _row(context, ref, items[i]),
        );
      }),
      show: !demoContent, // hors connexion (aperçu, tests) : les lignes d'exemple de la maquette restent affichées
    );

/// « Tout lire » : visible seulement quand il reste des notifications non lues.
Widget markAllReadLink() => gP(
      296, 164, 70, 28,
      Consumer(builder: (context, ref, _) {
        final unread = ref.watch(notifsProvider.select((l) => l.any((n) => !n.read)));
        if (!unread) return const SizedBox.shrink();
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => ref.read(notifsProvider.notifier).markAllRead(),
          child: Align(alignment: Alignment.centerRight, child: Text('Tout lire', style: _t(12, FontWeight.w600, const Color(0xFF5A3FE0)))),
        );
      }),
      show: !demoContent,
    );

/// Toutes les notifications du compte (écrans 51, 155 et 254) : rafraîchies automatiquement, cliquables, avec le marquage lu.
Widget notificationsFeed({double width = 342, double height = 600}) => SizedBox(
      width: width,
      height: height,
      child: Consumer(builder: (context, ref, _) {
        if (ref.watch(authProvider.select((a) => a.current == null))) {
          return Center(child: Text('Connectez-vous pour voir vos notifications.', textAlign: TextAlign.center, style: _t(13, FontWeight.w500, const Color(0xFF57545F))));
        }
        final items = ref.watch(notifsProvider);
        final unavailable = _notifsUnavailable(ref, items);
        if (unavailable != null) return unavailable;
        if (items.isEmpty) return Center(child: Text('Aucune notification pour le moment.', textAlign: TextAlign.center, style: _t(13, FontWeight.w500, const Color(0xFF57545F))));
        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 64, color: Color(0xFFF2EFF6)),
          itemBuilder: (context, i) => _row(context, ref, items[i]),
        );
      }),
    );

/// Détail de la notification touchée (écran 51) : texte complet, date, et l'action adaptée à son type.
/// Sans notification choisie, la liste complète est proposée.
Widget notificationDetail({double width = 342, double height = 620}) => SizedBox(width: width, height: height, child: const _NotificationDetail());

class _NotificationDetail extends ConsumerStatefulWidget {
  const _NotificationDetail();
  @override
  ConsumerState<_NotificationDetail> createState() => _NotificationDetailState();
}

class _NotificationDetailState extends ConsumerState<_NotificationDetail> {
  String _marked = '';

  String _when(DateTime d) {
    const mois = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.day} ${mois[d.month - 1]} ${d.year} · ${two(d.hour)}:${two(d.minute)}';
  }

  Widget _button(String label, VoidCallback onTap, {bool dark = true}) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: dark ? const Color(0xFF111015) : Colors.transparent, border: dark ? null : Border.all(color: const Color(0xFFD9D3E6), width: 1.5), borderRadius: BorderRadius.circular(25)),
          child: Text(label, style: _t(14, FontWeight.w600, dark ? Colors.white : const Color(0xFF111015))),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final id = ref.watch(selectedNotificationProvider);
    final all = ref.watch(notifsProvider);
    NotificationItem? n;
    for (final x in all) {
      if (x.id == id) n = x;
    }
    if (n == null) {
      if (id.isEmpty) return notificationsFeed(height: 620);
      final unavailable = _notifsUnavailable(ref, all);
      return unavailable ?? Center(child: Text('Cette notification n’existe plus.', style: _t(13, FontWeight.w500, const Color(0xFF57545F))));
    }
    if (_marked != n.id) {
      _marked = n.id;
      Future.microtask(() => ref.read(notifsProvider.notifier).markRead(n!.id));
    }
    final action = notificationActionLabel(n);
    final orderNum = n.kind == 'order' ? '${n.data['order_number'] ?? n.data['order'] ?? ''}'.replaceAll('#', '').trim() : '';
    final myOrder = orderNum.isEmpty ? null : ref.watch(ordersProvider).where((o) => o.id.replaceAll('#', '') == orderNum).firstOrNull;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 8),
      Row(children: [
        Container(width: 44, height: 44, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFFF1EEFB), borderRadius: BorderRadius.circular(14)), child: Text(_glyph(n.kind), style: _t(18, FontWeight.w600, const Color(0xFF5A3FE0)))),
        const SizedBox(width: 12),
        Expanded(child: Text(n.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: _t(16, FontWeight.w700, const Color(0xFF111015)))),
      ]),
      const SizedBox(height: 10),
      Text(_when(n.createdAt), style: _t(11.5, FontWeight.w400, const Color(0xFF57545F))),
      const SizedBox(height: 16),
      Expanded(child: SingleChildScrollView(child: Text(n.body.isEmpty ? 'Cette notification n’a pas de détail supplémentaire.' : n.body, style: _t(13.5, FontWeight.w400, const Color(0xFF4A4854)).copyWith(height: 1.5)))),
      if (myOrder != null) ...[
        _button('Suivre ma commande', () {
          ref.read(selectedOrderIdProvider.notifier).set(myOrder.id);
          gOpen(context, '46');
        }),
        const SizedBox(height: 10),
        _button('Contacter le vendeur', () {
          ref.read(selectedOrderIdProvider.notifier).set(myOrder.id);
          contactOrderSeller(ref, context);
        }, dark: false),
      ] else if (action != null)
        _button(action, () {
          if (!openNotification(context, ref, n!)) gToast(context, 'Cette page n’est pas disponible pour votre compte.');
        }),
      const SizedBox(height: 10),
      if (n.kind == 'talent_contact' && RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch('${n.data['from'] ?? ''}')) ...[
        _button('Bloquer cet expéditeur', () async {
          final res = await Backend.rpc('block_user', {'p_user': '${n!.data['from']}', 'p_block': true});
          if (context.mounted) gToast(context, res.error == null ? 'Expéditeur bloqué : il ne peut plus vous contacter.' : 'Blocage impossible pour le moment.');
        }, dark: false),
        const SizedBox(height: 10),
      ],
      _button('Réglages des notifications', () => gOpen(context, '56'), dark: false),
      const SizedBox(height: 18),
    ]);
  }
}

/// Compteur de messages non lus, à poser près du titre de la messagerie.
Widget messagesUnreadPill() => Consumer(builder: (context, ref, _) {
      final n = ref.watch(unreadProvider).asData?.value.messages ?? 0;
      if (n <= 0) return const SizedBox.shrink();
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: const Color(0xFF5A3FE0), borderRadius: BorderRadius.circular(12)),
          child: Text(n > 99 ? '99+ non lus' : '$n non lu${n > 1 ? 's' : ''}', style: _t(11, FontWeight.w700, Colors.white)),
        ),
      );
    });

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

/// Ouverture depuis un clic sur une notification du navigateur (adresse `#/notif?n=<identifiant>`) : attend la liste des notifications
/// du compte, affiche la liste puis ouvre l'écran pertinent ; sans compte ou sans réponse, la liste des notifications s'ouvre seule.
class NotificationLauncher extends ConsumerStatefulWidget {
  const NotificationLauncher({super.key, required this.id});
  final String id;
  @override
  ConsumerState<NotificationLauncher> createState() => _NotificationLauncherState();
}

class _NotificationLauncherState extends ConsumerState<NotificationLauncher> {
  Timer? _timeout;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _timeout = Timer(const Duration(seconds: 8), () => _finish(null));
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  void _finish(NotificationItem? n) {
    if (_done || !mounted) return;
    _done = true;
    final router = GoRouter.of(context);
    final container = ProviderScope.containerOf(context);
    router.go(screenPath('50'));
    if (n == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      container.read(notifsProvider.notifier).markRead(n.id);
      if (notificationActionLabel(n) != null && openNotification(context, null, n, router: router, reader: container.read)) return;
      container.read(selectedNotificationProvider.notifier).set(n.id);
      router.push(screenPath('51'));
    });
  }

  @override
  Widget build(BuildContext context) {
    for (final n in ref.watch(notifsProvider)) {
      if (n.id == widget.id) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _finish(n));
        break;
      }
    }
    return const Scaffold(backgroundColor: Color(0xFFF4EFE6), body: Center(child: CircularProgressIndicator()));
  }
}
