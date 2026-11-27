import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../gen.dart';
import '../i18n.dart' show Text;
import 'auth.dart';
import 'backend.dart';
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';
import 'reels.dart';
import 'social_posts.dart' show PostComment, postCommentsProvider;
import 'social_profile.dart' show publicProfileProvider;

/// H13 · réseau social : rubriques du profil créateur (lives, publications, projets, produits, reposts, clips) avec épinglage (3 au plus par rubrique),
/// visites agrégées (jamais d'identité), modification d'une publication ou d'un commentaire par son auteur.
/// Tout vient du serveur (migrations 20261128050000 à 050500) ; aucune donnée d'exemple : une rubrique vide le dit, une panne n'affiche jamais « 0 ».

const creatorTabs = ['publications', 'lives', 'projets', 'produits', 'reposts', 'clips'];

const _tabLabels = {
  'publications': 'Publications',
  'lives': 'Lives',
  'projets': 'Projets',
  'produits': 'Produits',
  'reposts': 'Reposts',
  'clips': 'Clips',
};

const _tabEmpty = {
  'publications': 'Aucune publication pour le moment.',
  'lives': 'Aucun live public pour le moment.',
  'projets': 'Aucun projet public pour le moment.',
  'produits': 'Aucun produit en vente pour le moment.',
  'reposts': 'Aucune republication pour le moment.',
  'clips': 'Aucun clip disponible pour le moment.',
};

/// Message lisible d'une réponse serveur en erreur (hors connexion, fonction non installée, refus).
String creatorErrorText(Object? e) {
  if (e == 'offline') return 'Cette page est disponible une fois l’application connectée au serveur.';
  if (e == 'missing') return 'Les rubriques du profil ne sont pas encore installées sur le serveur.';
  return Backend.userMessage('$e');
}

/// Nombre d'éléments visibles par rubrique ; `null` : profil introuvable, privé ou indisponible pour cette personne.
final creatorTabsProvider = FutureProvider.autoDispose.family<Map<String, int>?, String>((ref, userId) async {
  final r = await marcheCall('creator_profile_tabs', {'p_user': userId});
  if (r.error != null) throw Exception(creatorErrorText(r.error));
  if (r.data is! Map) return null;
  final tabs = (r.data as Map)['tabs'];
  if (tabs is! Map) return null;
  return {for (final k in creatorTabs) k: mInt(tabs[k])};
}, retry: (_, _) => null);

/// Visites du profil des `days` derniers jours : compteurs agrégés, réservés au propriétaire.
final creatorVisitsProvider = FutureProvider.autoDispose.family<int, int>((ref, days) async {
  final r = await marcheCall('creator_visit_stats', {'p_days': days});
  if (r.error != null) throw Exception(creatorErrorText(r.error));
  if (r.data is! Map) throw Exception('Réponse illisible du serveur. Réessayez dans un instant.');
  return mInt((r.data as Map)['visits']);
}, retry: (_, _) => null);

class CreatorItem {
  const CreatorItem({required this.id, required this.title, required this.subtitle, required this.at, required this.pinned});
  final String id, title, subtitle;
  final DateTime? at;
  final bool pinned;

  static CreatorItem fromJson(Map x) => CreatorItem(
        id: '${x['id']}',
        title: '${x['title'] ?? ''}',
        subtitle: '${x['subtitle'] ?? ''}',
        at: DateTime.tryParse('${x['at'] ?? ''}')?.toLocal(),
        pinned: x['pinned'] == true,
      );
}

/// Profil créateur : rubriques, épinglage et, pour le propriétaire, visites. `userId` vide ou « moi » : son propre profil.
class CreatorProfileScreen extends ConsumerStatefulWidget {
  const CreatorProfileScreen({super.key, required this.userId});
  final String userId;

  @override
  ConsumerState<CreatorProfileScreen> createState() => _CreatorProfileScreenState();
}

class _CreatorProfileScreenState extends ConsumerState<CreatorProfileScreen> {
  String tab = creatorTabs.first;
  bool _visitSent = false;

  String get _me => ref.read(authProvider).current?.serverId ?? '';
  String get _id => (widget.userId.isEmpty || widget.userId == 'moi') ? _me : widget.userId;

  void _recordVisit() {
    if (_visitSent || !Backend.ready) return;
    final id = _id;
    if (id.isEmpty || id == _me || _me.isEmpty) return;
    _visitSent = true;
    // la visite est un compteur agrégé : une réponse en échec ne change rien pour la personne qui consulte
    Backend.rpc('profile_visit_record', {'p_user': id});
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
    final id = _id;
    if (id.isEmpty) {
      return MarchePage(
        title: 'Profil du créateur',
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          mNote('Connectez-vous pour voir votre profil.'),
          mButton('Se connecter', () => requireLogin(context, ref, 'voir votre profil')),
        ]),
      );
    }
    final own = id == me;
    final tabs = ref.watch(creatorTabsProvider(id));
    final name = ref.watch(publicProfileProvider(id)).asData?.value.name ?? '';
    final prof = ref.watch(publicProfileProvider(id)).asData?.value;
    return MarchePage(
      title: own ? 'Mon profil créateur' : (name.isEmpty ? 'Profil du créateur' : name),
      child: tabs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          mNote('$e'.replaceFirst('Exception: ', '')),
          mButton('Réessayer', () => ref.invalidate(creatorTabsProvider(id)), dark: false),
        ]),
        data: (counts) {
          if (counts == null) return mNote('Ce profil est introuvable ou n’est pas visible.');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _recordVisit();
          });
          return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
            if (own) _visits(),
            if (prof != null) _counters(id, prof.followersCount, prof.followingCount),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final t in creatorTabs)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: Key('creator-tab-$t'),
                      label: Row(mainAxisSize: MainAxisSize.min, children: [Text(_tabLabels[t] ?? t), Text(' (${counts[t]})')]),
                      selected: tab == t,
                      onSelected: (_) => setState(() => tab = t),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
            CreatorTabList(key: ValueKey('$id-$tab'), userId: id, tab: tab, own: own),
          ]);
        },
      ),
    );
  }

  Widget _counters(String id, int followers, int following) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(children: [
          Expanded(
            child: TextButton(
              key: const Key('creator-followers'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => GoRouter.of(context).push('/abonnes/$id'),
              child: Text('$followers ${followers > 1 ? 'abonnés' : 'abonné'}', style: mst(14, w: FontWeight.w700, c: kViolet)),
            ),
          ),
          Expanded(
            child: TextButton(
              key: const Key('creator-following'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => GoRouter.of(context).push('/abonnements/$id'),
              child: Text('$following ${following > 1 ? 'abonnements' : 'abonnement'}', style: mst(14, w: FontWeight.w700, c: kViolet)),
            ),
          ),
        ]),
      );

  Widget _visits() => Container(
        key: const Key('creator-visits'),
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: kLine)),
        child: ref.watch(creatorVisitsProvider(30)).when(
              loading: () => Text('Chargement des visites…', style: mst(13, c: kGrey)),
              error: (e, _) => Row(children: [
                Expanded(child: Text('Les visites du profil ne peuvent pas être chargées pour le moment.', style: mst(13, c: kGrey))),
                TextButton(onPressed: () => ref.invalidate(creatorVisitsProvider(30)), child: Text('Réessayer', style: mst(13, w: FontWeight.w700))),
              ]),
              data: (n) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Visites du profil · 30 jours : $n', style: mst(14, w: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Compteur par jour : une visite par personne connectée, jamais son identité.', style: mst(12, c: kGrey)),
              ]),
            ),
      );
}

/// Éléments d'une rubrique : épinglés d'abord, puis pages successives par curseur ; état vide et erreur distincts.
class CreatorTabList extends StatefulWidget {
  const CreatorTabList({super.key, required this.userId, required this.tab, required this.own});
  final String userId, tab;
  final bool own;

  @override
  State<CreatorTabList> createState() => _CreatorTabListState();
}

class _CreatorTabListState extends State<CreatorTabList> {
  final List<CreatorItem> items = [];
  Map<String, dynamic>? next;
  bool loading = true, loadingMore = false, pinBusy = false;
  String? error, moreError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    final r = await marcheCall('creator_tab_items', {'p_user': widget.userId, 'p_tab': widget.tab, 'p_limit': 20});
    if (!mounted) return;
    if (r.error != null) {
      setState(() {
        loading = false;
        error = creatorErrorText(r.error);
      });
      return;
    }
    final d = r.data;
    if (d is! Map) {
      setState(() {
        loading = false;
        error = 'Ce profil est introuvable ou n’est pas visible.';
      });
      return;
    }
    setState(() {
      items
        ..clear()
        ..addAll([for (final x in (d['items'] as List? ?? const [])) CreatorItem.fromJson(x as Map)]);
      next = d['next'] is Map ? Map<String, dynamic>.from(d['next'] as Map) : null;
      loading = false;
    });
  }

  Future<void> _more() async {
    final n = next;
    if (n == null || loadingMore) return;
    setState(() {
      loadingMore = true;
      moreError = null;
    });
    final r = await marcheCall('creator_tab_items', {'p_user': widget.userId, 'p_tab': widget.tab, 'p_limit': 20, 'p_before_at': n['before_at'], 'p_before_id': n['before_id']});
    if (!mounted) return;
    if (r.error != null || r.data is! Map) {
      setState(() {
        loadingMore = false;
        moreError = creatorErrorText(r.error ?? 'illisible');
      });
      return;
    }
    final d = r.data as Map;
    final known = {for (final x in items) x.id};
    setState(() {
      items.addAll([for (final x in (d['items'] as List? ?? const [])) CreatorItem.fromJson(x as Map)].where((x) => !known.contains(x.id)));
      next = d['next'] is Map ? Map<String, dynamic>.from(d['next'] as Map) : null;
      loadingMore = false;
    });
  }

  Future<void> _pin(CreatorItem it) async {
    if (pinBusy) return;
    setState(() => pinBusy = true);
    final r = await marcheCall('creator_pin_set', {'p_tab': widget.tab, 'p_item': it.id, 'p_pin': !it.pinned});
    if (!mounted) return;
    setState(() => pinBusy = false);
    if (r.error != null) return gToast(context, creatorErrorText(r.error));
    gToast(context, it.pinned ? 'Élément désépinglé.' : 'Élément épinglé en tête de la rubrique.');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
    if (error != null) {
      return Column(children: [mNote(error!), mButton('Réessayer', _load, dark: false)]);
    }
    if (items.isEmpty) return mNote(_tabEmpty[widget.tab] ?? 'Rien à afficher pour le moment.');
    final pinned = items.where((x) => x.pinned).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (widget.own) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Épinglés : $pinned sur 3 au plus dans cette rubrique.', style: mst(12, c: kGrey))),
      for (final it in items) _tile(it),
      if (moreError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(moreError!, style: mst(12.5, c: kRed))),
      if (next != null) Padding(padding: const EdgeInsets.only(top: 8), child: mButton('Voir plus', loadingMore ? null : _more, dark: false, busy: loadingMore)),
    ]);
  }

  Widget _tile(CreatorItem it) => Container(
        key: Key('creator-item-${it.id}'),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: kLine)),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (it.pinned) Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('Épinglé', style: mst(11, w: FontWeight.w700, c: kViolet))),
              Text(it.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: mst(14, w: FontWeight.w700)),
              if (it.subtitle.isNotEmpty) Text(it.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: mst(12, c: kGrey)),
              if (it.at != null) Text(_date(it.at!), style: mst(11.5, c: kGrey)),
            ]),
          ),
          if (widget.own)
            IconButton(
              key: Key('creator-pin-${it.id}'),
              tooltip: it.pinned ? 'Désépingler' : 'Épingler',
              onPressed: pinBusy ? null : () => _pin(it),
              icon: Icon(it.pinned ? Icons.push_pin : Icons.push_pin_outlined, color: it.pinned ? kViolet : kGrey),
            ),
        ]),
      );

  String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// Champ de saisie d'une modification : texte prérempli, longueur maximale, lien facultatif (publication seulement).
Future<({String text, String link})?> _askEdit(BuildContext context, {required String title, required String initial, required int max, String? link}) {
  final c = TextEditingController(text: initial);
  final l = TextEditingController(text: link ?? '');
  String? error;
  return gDialog<({String text, String link})>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(title, style: mst(16, w: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(key: const Key('edit-text'), controller: c, autofocus: true, minLines: 2, maxLines: 6, maxLength: max, textCapitalization: TextCapitalization.sentences),
            if (link != null) TextField(key: const Key('edit-link'), controller: l, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Lien (facultatif)')),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(error!, style: mst(12.5, c: kRed))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Annuler', style: mst(13.5, w: FontWeight.w700))),
          TextButton(
            key: const Key('edit-save'),
            onPressed: () {
              final t = c.text.trim(), k = l.text.trim();
              if (t.length > max) return set(() => error = 'Texte trop long : $max caractères au plus.');
              if (k.isNotEmpty && !RegExp(r'^https?://\S+$').hasMatch(k)) return set(() => error = 'Lien invalide : il doit commencer par http:// ou https://');
              Navigator.of(ctx).pop((text: t, link: k));
            },
            child: Text('Enregistrer', style: mst(13.5, w: FontWeight.w700)),
          ),
        ],
      ),
    ),
  );
}

/// L'auteur modifie sa publication : un compte non certifié repasse en validation (le serveur le dit), le texte trop long est refusé et non tronqué.
Future<void> editMyPost(BuildContext context, WidgetRef ref, Reel r) async {
  final edit = await _askEdit(context, title: 'Modifier ma publication', initial: r.caption, max: r.hasMedia ? 300 : 2000, link: r.linkUrl);
  if (edit == null || !context.mounted) return;
  final res = await Backend.rpc('edit_my_post', {'p_post': r.id, 'p_caption': edit.text, 'p_link': edit.link.isEmpty ? null : edit.link});
  if (!context.mounted) return;
  if (res.error != null) return gAlert(context, 'Modification impossible', Backend.userMessage(res.error!));
  final st = res.data is Map ? '${(res.data as Map)['status']}' : '';
  await ref.read(reelsProvider.notifier).refresh();
  if (context.mounted) gToast(context, st == 'pending' ? 'Publication modifiée : visible après nouvelle validation.' : 'Publication modifiée.');
}

/// L'auteur modifie son commentaire (500 caractères au plus).
Future<void> editPostComment(BuildContext context, WidgetRef ref, String postId, PostComment c) async {
  final edit = await _askEdit(context, title: 'Modifier mon commentaire', initial: c.body, max: 500);
  if (edit == null || !context.mounted) return;
  final res = await Backend.rpc('edit_post_comment', {'p_comment': c.id, 'p_body': edit.text});
  if (!context.mounted) return;
  if (res.error != null) return gToast(context, Backend.userMessage(res.error!));
  ref.invalidate(postCommentsProvider(postId));
  gToast(context, 'Commentaire modifié.');
}
