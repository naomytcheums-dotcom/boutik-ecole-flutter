import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../gen.dart';
import '../i18n.dart' show Text;
import 'auth.dart';
import 'backend.dart';
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';
import 'reels.dart' show followingIdsProvider;
import 'social_posts.dart' show VerifiedBadge, socialAvatar;
import 'social_profile.dart' show publicProfileProvider, roleLabel;

/// H13.1 · listes « Abonnés » et « Abonnements » d'un profil, et « Créateurs à suivre ».
/// Tout vient du serveur (migration 20261129050000) : pages par curseur, listes refusées quand le profil est privé ou que la personne les a masquées,
/// suggestions fondées sur des signaux réels. Aucune donnée d'exemple ; une panne n'affiche jamais « aucun abonné ».

enum FollowListKind { followers, following }

class FollowEntry {
  const FollowEntry({required this.id, required this.name, required this.avatarUrl, required this.role, required this.certified, required this.iFollow, required this.isMe, this.reason = '', this.followers = 0, this.mutual = 0});
  final String id, name, avatarUrl, role, reason;
  final bool certified, iFollow, isMe;
  final int followers, mutual;

  FollowEntry withFollow(bool v) => FollowEntry(id: id, name: name, avatarUrl: avatarUrl, role: role, certified: certified, iFollow: v, isMe: isMe, reason: reason, followers: followers, mutual: mutual);

  static FollowEntry fromJson(Map x) => FollowEntry(
        id: '${x['id'] ?? ''}',
        name: '${x['name'] ?? ''}'.trim(),
        avatarUrl: '${x['avatar_url'] ?? ''}',
        role: '${x['role'] ?? ''}',
        certified: x['certified'] == true,
        iFollow: x['i_follow'] == true,
        isMe: x['is_me'] == true,
        reason: '${x['reason'] ?? ''}',
        followers: mInt(x['followers_count']),
        mutual: mInt(x['mutual_count']),
      );
}

/// Une page de la liste : `allowed` faux = liste refusée (`reason` : « unavailable » ou « lists_hidden »).
class FollowPage {
  const FollowPage({required this.allowed, required this.reason, required this.items, required this.next, required this.own, required this.listsPublic});
  final bool allowed, own;
  final String reason;
  final List<FollowEntry> items;
  final Map<String, dynamic>? next;
  final bool? listsPublic;
}

String followListErrorText(Object? e) {
  if (e == 'offline') return 'Cette liste est disponible une fois l’application connectée au serveur.';
  if (e == 'missing') return 'Les listes d’abonnés ne sont pas encore installées sur le serveur.';
  return Backend.userMessage('$e');
}

String followDeniedText(String reason) => reason == 'lists_hidden'
    ? 'Cette personne a choisi de ne pas afficher ses abonnés et ses abonnements.'
    : 'Ce profil est privé ou indisponible : ses abonnés et ses abonnements ne sont pas visibles.';

/// Lit une page ; lève une `Exception` au message lisible si le serveur répond en erreur ou de façon illisible.
Future<FollowPage> fetchFollowPage(FollowListKind kind, String userId, {Map<String, dynamic>? cursor, int limit = 20}) async {
  final r = await marcheCall(kind == FollowListKind.followers ? 'followers_list' : 'following_list', {'p_user': userId, 'p_limit': limit, 'p_cursor': cursor});
  if (r.error != null) throw Exception(followListErrorText(r.error));
  final d = r.data;
  if (d is! Map) throw Exception('Réponse illisible du serveur. Réessayez dans un instant.');
  return FollowPage(
    allowed: d['allowed'] == true,
    reason: '${d['reason'] ?? ''}',
    items: [for (final x in (d['items'] as List? ?? const [])) if (x is Map) FollowEntry.fromJson(x)],
    next: d['next'] is Map ? Map<String, dynamic>.from(d['next'] as Map) : null,
    own: d['own'] == true,
    listsPublic: d['lists_public'] is bool ? d['lists_public'] as bool : null,
  );
}

/// Suit ou ne suit plus `id` (appel serveur idempotent). Renvoie l'état réel après l'appel, ou `null` si rien n'a changé (non connecté, refus, panne : message affiché).
Future<bool?> toggleFollowUser(BuildContext context, WidgetRef ref, String id, bool following) async {
  if (!await requireLogin(context, ref, 'suivre une personne') || !context.mounted) return null;
  final r = await Backend.rpc('follow_set', {'p_user': id, 'p_follow': !following});
  if (!context.mounted) return null;
  if (r.error != null) {
    gToast(context, Backend.userMessage(r.error!));
    return null;
  }
  ref.invalidate(followingIdsProvider);
  ref.invalidate(publicProfileProvider(id));
  return r.data is Map && (r.data as Map)['following'] is bool ? (r.data as Map)['following'] as bool : !following;
}

String suggestionReasonText(FollowEntry e) => switch (e.reason) {
      'meme_departement' => 'Même département que vous',
      'meme_etablissement' => 'Même établissement que vous',
      'abonnements_communs' => e.mutual > 1 ? 'Suivi par ${e.mutual} personnes que vous suivez' : 'Suivi par une personne que vous suivez',
      'communautes_communes' => 'Communauté en commun',
      'competences_communes' => 'Compétences en commun',
      'actif_recemment' => 'Actif récemment',
      _ => 'Populaire sur Boutik-École',
    };

/// Ligne d'une personne : avatar, nom, ligne d'information, bouton Suivre / Ne plus suivre. Un appui sur la ligne ouvre son profil créateur.
class FollowRow extends StatelessWidget {
  const FollowRow({super.key, required this.entry, required this.info, required this.busy, required this.onToggle});
  final FollowEntry entry;
  final String info;
  final bool busy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: kLine)),
        child: Row(children: [
          Expanded(
            child: InkWell(
              key: Key('follow-open-${entry.id}'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => GoRouter.of(context).push('/profil-createur/${entry.id}'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                child: Row(children: [
                  socialAvatar(entry.avatarUrl, entry.name, 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Flexible(child: Text(entry.name.isEmpty ? 'Membre' : entry.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: mst(14, w: FontWeight.w700))),
                        if (entry.certified) ...[const SizedBox(width: 5), const VerifiedBadge(size: 14)],
                      ]),
                      if (info.isNotEmpty) Text(info, maxLines: 2, overflow: TextOverflow.ellipsis, style: mst(12, c: kGrey)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
          if (!entry.isMe)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: SizedBox(
                key: Key('follow-btn-${entry.id}'),
                width: 128,
                child: mButton(entry.iFollow ? 'Ne plus suivre' : 'Suivre', onToggle, dark: !entry.iFollow, busy: busy),
              ),
            ),
        ]),
      );
}

/// État d'une liste de personnes chargée par pages (utilisé par les trois écrans).
mixin _ListState<T extends StatefulWidget> on State<T> {
  final List<FollowEntry> items = [];
  final Set<String> busy = {};
  final ScrollController scroll = ScrollController();
  bool loading = true, loadingMore = false;
  String? error, moreError;
  int gen = 0;

  Future<void> loadFirst({bool refresh = false});
  Future<void> loadMore();

  void initScroll() => scroll.addListener(() {
        if (scroll.hasClients && scroll.position.pixels >= scroll.position.maxScrollExtent - 200) loadMore();
      });

  Future<void> toggle(WidgetRef ref, FollowEntry e) async {
    if (busy.contains(e.id)) return;
    setState(() => busy.add(e.id));
    final now = await toggleFollowUser(context, ref, e.id, e.iFollow);
    if (!mounted) return;
    setState(() {
      busy.remove(e.id);
      if (now != null) {
        final i = items.indexWhere((x) => x.id == e.id);
        if (i >= 0) items[i] = items[i].withFollow(now);
      }
    });
  }
}

/// « Abonnés » ou « Abonnements » d'un profil. `userId` vide ou « moi » : son propre profil.
class FollowListScreen extends ConsumerStatefulWidget {
  const FollowListScreen({super.key, required this.userId, required this.kind});
  final String userId;
  final FollowListKind kind;

  @override
  ConsumerState<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends ConsumerState<FollowListScreen> with _ListState<FollowListScreen> {
  Map<String, dynamic>? next;
  String? deniedReason;
  bool own = false, switchBusy = false;
  bool? listsPublic;

  String get _me => ref.read(authProvider).current?.serverId ?? '';
  String get _id => (widget.userId.isEmpty || widget.userId == 'moi') ? _me : widget.userId;
  bool get _followers => widget.kind == FollowListKind.followers;

  @override
  void initState() {
    super.initState();
    initScroll();
    Future.microtask(loadFirst);
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Future<void> loadFirst({bool refresh = false}) async {
    final id = _id;
    final g = ++gen;
    if (id.isEmpty) {
      setState(() => loading = false);
      return;
    }
    setState(() {
      loading = !refresh || items.isEmpty && deniedReason == null && error == null;
      error = null;
      moreError = null;
    });
    try {
      final p = await fetchFollowPage(widget.kind, id);
      if (!mounted || g != gen) return;
      setState(() {
        loading = false;
        deniedReason = p.allowed ? null : (p.reason.isEmpty ? 'unavailable' : p.reason);
        own = p.own;
        listsPublic = p.listsPublic;
        next = p.next;
        items
          ..clear()
          ..addAll(p.items);
      });
    } catch (e) {
      if (!mounted || g != gen) return;
      setState(() {
        loading = false;
        error = '$e'.replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Future<void> loadMore() async {
    final n = next;
    if (n == null || loadingMore || loading) return;
    final g = gen;
    setState(() {
      loadingMore = true;
      moreError = null;
    });
    try {
      final p = await fetchFollowPage(widget.kind, _id, cursor: n);
      if (!mounted || g != gen) return;
      final known = {for (final x in items) x.id};
      setState(() {
        loadingMore = false;
        items.addAll(p.items.where((x) => !known.contains(x.id)));
        next = p.next;
      });
    } catch (e) {
      if (!mounted || g != gen) return;
      setState(() {
        loadingMore = false;
        moreError = '$e'.replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _setLists(bool v) async {
    if (switchBusy) return;
    setState(() => switchBusy = true);
    final r = await Backend.rpc('follow_lists_privacy_set', {'p_public': v});
    if (!mounted) return;
    setState(() {
      switchBusy = false;
      if (r.error == null) listsPublic = r.data is Map && (r.data as Map)['public'] is bool ? (r.data as Map)['public'] as bool : v;
    });
    if (r.error != null) gToast(context, Backend.userMessage(r.error!));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider.select((a) => a.current?.serverId ?? ''), (_, _) => loadFirst(refresh: true));
    final id = _id;
    final title = _followers ? (own ? 'Mes abonnés' : 'Abonnés') : (own ? 'Mes abonnements' : 'Abonnements');
    if (id.isEmpty) {
      return MarchePage(
        title: title,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          mNote('Connectez-vous pour voir vos abonnés et vos abonnements.'),
          mButton('Se connecter', () => requireLogin(context, ref, 'voir vos abonnés et vos abonnements')),
        ]),
      );
    }
    return MarchePage(title: title, child: RefreshIndicator(onRefresh: () => loadFirst(refresh: true), child: ListView(controller: scroll, physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: _children())));
  }

  List<Widget> _children() {
    if (loading) return [const SizedBox(height: 120), const Center(child: CircularProgressIndicator())];
    if (error != null) return [const SizedBox(height: 60), mNote(error!), Center(child: mButton('Réessayer', loadFirst, dark: false))];
    if (deniedReason != null) return [const SizedBox(height: 60), Container(key: const Key('follow-denied'), child: mNote(followDeniedText(deniedReason!)))];
    return [
      if (own && listsPublic != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            key: const Key('follow-lists-privacy'),
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: kLine)),
            clipBehavior: Clip.antiAlias,
            child: SwitchListTile(
              key: const Key('follow-lists-switch'),
              value: listsPublic!,
              onChanged: switchBusy ? null : _setLists,
              title: Text('Afficher mes abonnés et mes abonnements aux autres membres', style: mst(13.5, w: FontWeight.w700)),
              subtitle: Text(listsPublic! ? 'Tout le monde peut voir ces deux listes.' : 'Seul vous voyez ces deux listes. Les compteurs du profil restent visibles.', style: mst(12, c: kGrey)),
            ),
          ),
        ),
      if (items.isEmpty) _empty(),
      for (final e in items) FollowRow(key: ValueKey(e.id), entry: e, info: roleLabel(e.role), busy: busy.contains(e.id), onToggle: () => toggle(ref, e)),
      if (moreError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(moreError!, style: mst(12.5, c: kRed))),
      if (next != null) Padding(padding: const EdgeInsets.only(top: 8), child: mButton('Voir plus', loadingMore ? null : loadMore, dark: false, busy: loadingMore)),
    ];
  }

  Widget _empty() => Column(key: const Key('follow-empty'), children: [
        const SizedBox(height: 40),
        mNote(_followers
            ? (own ? 'Personne ne vous suit pour le moment.' : 'Aucun abonné pour le moment.')
            : (own ? 'Vous ne suivez encore personne.' : 'Cette personne ne suit encore personne.')),
        if (own && !_followers) Center(child: mButton('Découvrir des créateurs à suivre', () => GoRouter.of(context).push('/createurs-a-suivre'), dark: false)),
      ]);
}

/// « Créateurs à suivre » : suggestions réelles (même département ou établissement, abonnements et communautés en commun, activité). Aucun profil inventé.
class SuggestedCreatorsScreen extends ConsumerStatefulWidget {
  const SuggestedCreatorsScreen({super.key});

  @override
  ConsumerState<SuggestedCreatorsScreen> createState() => _SuggestedCreatorsScreenState();
}

class _SuggestedCreatorsScreenState extends ConsumerState<SuggestedCreatorsScreen> with _ListState<SuggestedCreatorsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(loadFirst);
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Future<void> loadMore() async {}

  @override
  Future<void> loadFirst({bool refresh = false}) async {
    final g = ++gen;
    setState(() {
      loading = !refresh || items.isEmpty;
      error = null;
    });
    final r = await marcheCall('creators_suggested', {'p_limit': 30});
    if (!mounted || g != gen) return;
    if (r.error != null || r.data is! List) {
      setState(() {
        loading = false;
        error = r.error != null ? followListErrorText(r.error) : 'Réponse illisible du serveur. Réessayez dans un instant.';
      });
      return;
    }
    setState(() {
      loading = false;
      items
        ..clear()
        ..addAll([for (final x in r.data as List) if (x is Map) FollowEntry.fromJson(x)]);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider.select((a) => a.current?.serverId ?? ''), (_, _) => loadFirst(refresh: true));
    return MarchePage(
      title: 'Créateurs à suivre',
      child: RefreshIndicator(
        onRefresh: () => loadFirst(refresh: true),
        child: ListView(controller: scroll, physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
          if (loading) ...[const SizedBox(height: 120), const Center(child: CircularProgressIndicator())]
          else if (error != null) ...[const SizedBox(height: 60), mNote(error!), Center(child: mButton('Réessayer', loadFirst, dark: false))]
          else if (items.isEmpty) ...[const SizedBox(height: 60), Container(key: const Key('suggest-empty'), child: mNote('Aucune suggestion pour le moment.'))]
          else
            for (final e in items)
              FollowRow(
                key: ValueKey(e.id),
                entry: e,
                info: [suggestionReasonText(e), if (e.followers > 0) '${e.followers} abonné${e.followers > 1 ? 's' : ''}'].join(' · '),
                busy: busy.contains(e.id),
                onToggle: () => toggle(ref, e),
              ),
        ]),
      ),
    );
  }
}
