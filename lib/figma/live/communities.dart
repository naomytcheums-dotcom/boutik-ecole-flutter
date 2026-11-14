import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart';
import 'access.dart' show roleKey;
import 'auth.dart';
import 'backend.dart';
import 'communities_screens.dart';
import 'store.dart' show IntV;

export 'communities_screens.dart';

/// Communautés (écran 103 « Communauté », groupes populaires) : annuaire, adhésion et création, reliés au serveur
/// (migration 20261103000100). Hors connexion au serveur, la maquette reste affichée comme démonstration.
/// Les permissions (rôles, bannissement, modération) sont vérifiées par le serveur ; ce module ne fait que les appeler.

class Community {
  const Community({required this.id, required this.name, required this.description, required this.category, required this.privacy, required this.members, this.myStatus, this.myRole, this.status = 'active', this.department = '', this.decisionNote = '', this.kind = 'interest', this.promoYear = '', this.interest = '', this.official = false, this.createdAt, this.lastActivity, this.postsWeek = 0, this.ownerKind = ''});
  final String id, name, description, category, privacy;

  /// Type : filiere, promo, interest (centre d'intérêt), alumni ou project ; promotion et centre d'intérêt selon le type.
  final String kind, promoYear, interest, ownerKind;

  /// Badge « Officiel IUT » posé par l'équipe.
  final bool official;
  final DateTime? createdAt, lastActivity;
  final int postsWeek;

  /// Validation par l'équipe : pending (en attente), active (publiée), rejected (refusée), suspended.
  final String status, department, decisionNote;
  final int members;

  /// État de la personne connectée : active, pending, invited, banned ; null si aucun lien.
  final String? myStatus, myRole;

  bool get isMember => myStatus == 'active';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';
  bool get canManage => myRole == 'owner' || myRole == 'admin' || myRole == 'moderator';

  static Community fromRow(Map x) => Community(
        id: '${x['id']}',
        name: '${x['name']}',
        description: '${x['description'] ?? ''}',
        category: '${x['category'] ?? ''}',
        privacy: '${x['privacy'] ?? 'public'}',
        members: (x['members'] as num?)?.toInt() ?? 0,
        myStatus: x['my_status'] as String?,
        myRole: x['my_role'] as String?,
        status: '${x['status'] ?? 'active'}',
        department: '${x['department'] ?? ''}',
        decisionNote: '${x['decision_note'] ?? ''}',
        kind: '${x['kind'] ?? 'interest'}',
        promoYear: '${x['promo_year'] ?? ''}',
        interest: '${x['interest'] ?? ''}',
        official: x['official'] == true,
        createdAt: DateTime.tryParse('${x['created_at']}')?.toLocal(),
        lastActivity: DateTime.tryParse('${x['last_activity']}')?.toLocal(),
        postsWeek: (x['posts_week'] as num?)?.toInt() ?? 0,
        ownerKind: '${x['owner_kind'] ?? ''}',
      );

  /// Libellé du bouton d'action selon l'état et la confidentialité.
  String get actionLabel => switch (myStatus) {
        'active' => 'Membre',
        'pending' => 'Demande envoyée',
        'invited' => 'Accepter l’invitation',
        'banned' => 'Accès refusé',
        _ => privacy == 'approval' ? 'Demander à rejoindre' : 'Rejoindre',
      };

  String get privacyLabel => switch (privacy) {
        'approval' => 'Privée · sur approbation',
        'invite' => 'Privée · sur invitation',
        _ => 'Publique',
      };

  String get membersLabel => members <= 1 ? '$members membre' : '$members membres';

  String get kindLabel => switch (kind) {
        'filiere' => 'Filière',
        'promo' => promoYear.isEmpty ? 'Promo' : promoYear,
        'alumni' => 'Alumni',
        'project' => 'Projet',
        _ => interest.isEmpty ? 'Centre d’intérêt' : interest,
      };

  /// Qui administre : un étudiant, un enseignant ou l'équipe.
  String get adminLabel => switch (ownerKind) {
        'teacher' => 'Enseignant',
        'student' => 'Étudiant',
        _ => 'Équipe',
      };

  /// Badges : Officiel IUT, Populaire (50 membres ou 10 publications cette semaine), Nouveau (moins de 14 jours).
  List<String> badges(DateTime now) => [
        if (official) 'Officiel IUT',
        if (members >= 50 || postsWeek >= 10) 'Populaire',
        if (createdAt != null && now.difference(createdAt!).inDays < 14) 'Nouveau',
      ];

  /// « Dernière publication il y a 5 min » ; « Aucune publication » sans activité.
  String activityLabel(DateTime now) {
    final t = lastActivity;
    if (t == null) return 'Aucune publication';
    final d = now.difference(t);
    if (d.inMinutes < 1) return 'Dernière publication à l’instant';
    if (d.inMinutes < 60) return 'Dernière publication il y a ${d.inMinutes} min';
    if (d.inHours < 24) return 'Dernière publication il y a ${d.inHours} h';
    return 'Dernière publication il y a ${d.inDays} j';
  }
}

/// Carte d'une communauté avant d'y entrer : nom, type, membres, confidentialité, responsable, dernière activité et badges.
class CommunityCard extends StatelessWidget {
  const CommunityCard({super.key, required this.c, this.onOpen, this.onJoin, this.now});
  final Community c;
  final VoidCallback? onOpen;
  final VoidCallback? onJoin;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    const grey = Color(0xFF57545F);
    final t = now ?? DateTime.now();
    final canJoin = c.status == 'active' && !c.isMember && c.myStatus != 'pending' && c.myStatus != 'banned';
    final own = c.isPending || c.isRejected;
    Widget pill(String s, {Color bg = const Color(0xFFEEE9FF), Color fg = const Color(0xFF5A3FE0)}) => Container(
          margin: const EdgeInsets.only(left: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
          child: Text(s, style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 9.5, fontWeight: FontWeight.w700, color: fg)),
        );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: const Color(0xFFF1EEFB), borderRadius: BorderRadius.circular(13)),
          alignment: Alignment.center,
          child: Text(c.name.characters.first.toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF5A3FE0))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Flexible(child: gText(c.name, 13.5, const Color(0xFF111015), weight: 700, wrap: true, maxLines: 1)),
              for (final b in c.badges(t)) pill(b, bg: b == 'Officiel IUT' ? const Color(0xFF0F2E4E) : (b == 'Nouveau' ? const Color(0xFFDDF5EC) : const Color(0xFFFFF0D6)), fg: b == 'Officiel IUT' ? Colors.white : (b == 'Nouveau' ? const Color(0xFF0F7A52) : const Color(0xFF8F5400))),
            ]),
            const SizedBox(height: 2),
            gText(c.isPending ? 'En attente de validation' : (c.isRejected ? 'Refusée par l’administrateur' : [c.kindLabel, c.membersLabel, c.privacyLabel].join(' · ')), 10.5, c.isRejected ? const Color(0xFFB42318) : grey, wrap: true, maxLines: 1),
            if (!own) gText('Administrateur : ${c.adminLabel} · ${c.activityLabel(t)}', 10, grey, wrap: true, maxLines: 1),
            if (c.description.isNotEmpty && !own) gText(c.description, 10.5, const Color(0xFF111015), wrap: true, maxLines: 1),
          ]),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: canJoin ? onJoin : null,
          child: Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: canJoin ? const Color(0xFF111015) : const Color(0xFFEEE9FF), borderRadius: BorderRadius.circular(100)),
            child: gText(own ? (c.isPending ? 'En attente' : 'Refusée') : c.actionLabel, 10.5, canJoin ? Colors.white : const Color(0xFF5A3FE0), weight: 600, wrap: true),
          ),
        ),
      ]),
    );
  }
}

/// `null` : lecture en cours ou serveur absent ; liste vide : aucune communauté.
class CommunitiesNotifier extends Notifier<List<Community>?> {
  @override
  List<Community>? build() {
    if (!Backend.ready) return null;
    // l'état de la personne (membre, demande en attente…) dépend du compte : la liste est relue à chaque connexion ou déconnexion
    ref.watch(authProvider.select((a) => a.current?.serverId));
    Future.microtask(refresh);
    return null;
  }

  Future<void> refresh([String query = '']) async {
    final r = await Backend.rpc('communities_list', {'p_query': query, 'p_limit': 30});
    if (!ref.mounted) return;
    if (r.error != null || r.data is! List) {
      ref.read(communitiesErrorProvider.notifier).set('Les communautés ne peuvent pas être chargées pour le moment.');
      state = const [];
      return;
    }
    ref.read(communitiesErrorProvider.notifier).set('');
    state = [for (final x in r.data as List) Community.fromRow(x as Map)];
  }
}

final communitiesProvider = NotifierProvider<CommunitiesNotifier, List<Community>?>(CommunitiesNotifier.new);

/// Pastille active de l'écran 103 : 0 Anciens (membres), 1 Mentors (ouvre le réseau des mentors), 2 Groupes (liste des communautés).
final communityTabProvider = NotifierProvider<IntV, int>(IntV.new);

class CommunitiesMessage extends Notifier<String> {
  @override
  String build() => '';
  void set(String v) => state = v;
}

final communitiesErrorProvider = NotifierProvider<CommunitiesMessage, String>(CommunitiesMessage.new);

/// Rejoindre, demander à rejoindre ou accepter l'invitation ; l'issue vient du serveur ('joined', 'pending', 'already').
Future<void> joinCommunity(BuildContext context, WidgetRef ref, Community c) async {
  if (c.isMember || c.myStatus == 'pending' || c.myStatus == 'banned') return;
  if (!await requireLogin(context, ref, 'rejoindre une communauté') || !context.mounted) return;
  final r = await Backend.rpc('join_community', {'p_community': c.id});
  if (!context.mounted) return;
  if (r.error != null) return gAlert(context, 'Adhésion impossible', Backend.userMessage(r.error!));
  await ref.read(communitiesProvider.notifier).refresh();
  if (!context.mounted) return;
  gToast(context, switch ('${r.data}') {
    'pending' => 'Demande envoyée : un responsable de la communauté va l’examiner',
    'already' => 'Vous êtes déjà membre',
    _ => 'Vous avez rejoint « ${c.name} »',
  });
}

Future<void> leaveCommunity(BuildContext context, WidgetRef ref, Community c) async {
  final r = await Backend.rpc('leave_community', {'p_community': c.id});
  if (!context.mounted) return;
  if (r.error != null) return gAlert(context, 'Action impossible', Backend.userMessage(r.error!));
  await ref.read(communitiesProvider.notifier).refresh();
  if (context.mounted) gToast(context, 'Vous avez quitté « ${c.name} »');
}

/// Création : formulaire complet (nom, département du référentiel, description de 500 mots au plus, confidentialité).
/// La communauté est soumise à la validation de l'administrateur avant d'être publiée.
Future<void> createCommunityFlow(BuildContext context, WidgetRef ref) async {
  if (!Backend.ready) return gToast(context, 'La création de communauté nécessite la connexion au serveur.');
  if (!await requireLogin(context, ref, 'créer une communauté') || !context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CommunityCreateScreen()));
}

/// Liste des communautés (écran 103) : chargement, erreur, état vide, puis une ligne par communauté avec son action.
class CommunitiesList extends ConsumerWidget {
  const CommunitiesList({super.key, this.width = 342, this.height = 230});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(communitiesProvider);
    final error = ref.watch(communitiesErrorProvider);
    const grey = Color(0xFF57545F);
    Widget note(String t) => SizedBox(width: width, height: height, child: Center(child: gText(t, 12.5, grey, wrap: true, align: TextAlign.center)));
    if (list == null) return note('Chargement des communautés…');
    if (error.isNotEmpty) return note(error);
    if (list.isEmpty) return note('Aucune communauté pour le moment. Créez la première !');
    final pending = ref.watch(communitiesPendingProvider).asData?.value ?? const <Map<String, dynamic>>[];
    final banner = pending.isEmpty
        ? null
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CommunityPendingScreen())),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFFFFF4E5), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [Expanded(child: gText('${pending.length} communauté${pending.length > 1 ? 's' : ''} à valider', 12, const Color(0xFF111015), weight: 600, wrap: true)), const Icon(Icons.chevron_right, size: 18)]),
            ),
          );
    return SizedBox(
      width: width,
      height: height,
      child: Column(children: [
        if (banner != null) banner,
        Expanded(
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: list.length,
        separatorBuilder: (_, _) => const Divider(height: 16, thickness: 1, color: Color(0xFFF2EFF6)),
        itemBuilder: (_, i) {
          final c = list[i];
          return CommunityCard(
            c: c,
            onOpen: () {
              ref.read(selectedCommunityProvider.notifier).select(c);
              GoRouter.of(context).push('/communaute');
            },
            onJoin: () => joinCommunity(context, ref, c),
          );
        },
      ),
        ),
      ]),
    );
  }
}

/// Communautés en attente de validation (lecture réservée à l'équipe : le serveur renvoie une liste vide aux autres).
final communitiesPendingProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  if (!Backend.ready) return const [];
  // la liste n'est lue que par l'équipe : inutile d'interroger le serveur pour un visiteur ou un compte ordinaire
  if (!const {'admin', 'support'}.contains(roleKey(ref.watch(authProvider.select((a) => a.current))))) return const [];
  final r = await Backend.rpc('communities_pending', {});
  if (r.error != null || r.data is! List) return const [];
  return [for (final x in r.data as List) Map<String, dynamic>.from(x as Map)];
});

// L'écran d'une communauté, la création et la validation sont dans communities_screens.dart.
