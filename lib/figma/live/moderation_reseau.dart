import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gdata.dart' show gNetImage;
import '../gen.dart' show gAlert, gToast;
import '../nav.dart';
import 'backend.dart';
import 'reels.dart' show relativeTime;
import 'social_posts.dart' show InlineVideo, kGrey, kInk, kLine, kLike, sty;
import 'talents.dart' show askText;

/// Modération du réseau social (département, administration, support) : publications à valider, publications signalées, publications masquées,
/// histoires et commentaires signalés. Toutes les décisions passent par des fonctions serveur qui prévenent l'auteur et les personnes qui ont signalé.

List<Map<String, dynamic>> _asList(Object? d) => [for (final x in (d is List ? d : const [])) Map<String, dynamic>.from(x as Map)];

Future<List<Map<String, dynamic>>> _load(String fn, Map<String, dynamic> params) async {
  final r = await Backend.rpc(fn, params);
  if (r.error != null) throw Exception(Backend.userMessage(r.error!));
  return _asList(r.data);
}

final modPostsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, status) => _load('moderation_posts_list', {'p_status': status}));
final modStoriesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => _load('moderation_stories_list', const {}));
final modCommentReportsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => _load('comment_reports_list', const {}));

class SocialModerationScreen extends ConsumerWidget {
  const SocialModerationScreen({super.key});

  String _count(AsyncValue<List<Map<String, dynamic>>> v) => v.hasValue && v.value!.isNotEmpty ? ' (${v.value!.length})' : '';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = [
      'À valider${_count(ref.watch(modPostsProvider('pending')))}',
      'Signalées${_count(ref.watch(modPostsProvider('reported')))}',
      'Masquées',
      'Histoires${_count(ref.watch(modStoriesProvider))}',
      'Commentaires${_count(ref.watch(modCommentReportsProvider))}',
    ];
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F4FA),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF7F4FA),
          foregroundColor: kInk,
          elevation: 0,
          title: Text('Modération du réseau social', style: sty(18, w: FontWeight.w800)),
          bottom: TabBar(isScrollable: true, tabAlignment: TabAlignment.start, labelColor: kInk, indicatorColor: kInk, labelStyle: sty(13.5, w: FontWeight.w700), tabs: [for (final t in tabs) Tab(text: t)]),
        ),
        body: const TabBarView(children: [
          _PostsTab(status: 'pending'),
          _PostsTab(status: 'reported'),
          _PostsTab(status: 'hidden'),
          _StoriesTab(),
          _CommentReportsTab(),
        ]),
      ),
    );
  }
}

void _refreshAll(WidgetRef ref) {
  ref.invalidate(modPostsProvider('pending'));
  ref.invalidate(modPostsProvider('reported'));
  ref.invalidate(modPostsProvider('hidden'));
  ref.invalidate(modStoriesProvider);
  ref.invalidate(modCommentReportsProvider);
}

Future<void> _run(BuildContext context, WidgetRef ref, String fn, Map<String, dynamic> params, String done) async {
  final r = await Backend.rpc(fn, params);
  if (!context.mounted) return;
  if (r.error != null) {
    await gAlert(context, 'Action impossible', Backend.userMessage(r.error!));
    return;
  }
  gToast(context, done);
  _refreshAll(ref);
}

Future<String?> _askReason(BuildContext context, String title, String body) => askText(context, title: title, body: body, hint: 'Motif (3 caractères au moins)', ok: 'Confirmer', min: 3);

Widget _empty(String text) => ListView(children: [Padding(padding: const EdgeInsets.all(40), child: Text(text, textAlign: TextAlign.center, style: sty(14, c: kGrey, h: 1.5)))]);

Widget _error(String msg, VoidCallback retry) => Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(msg.replaceFirst('Exception: ', ''), textAlign: TextAlign.center, style: sty(13.5, c: kGrey, h: 1.5)),
          TextButton(onPressed: retry, child: Text('Réessayer', style: sty(13.5, w: FontWeight.w700))),
        ]),
      ),
    );

BoxDecoration _card() => BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine));

Widget _btn(String label, VoidCallback onTap, {bool dark = true}) => Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: dark ? kInk : Colors.white, borderRadius: BorderRadius.circular(6), border: dark ? null : Border.all(color: kLine)),
          child: Text(label, textAlign: TextAlign.center, style: sty(13.5, w: FontWeight.w700, c: dark ? Colors.white : kInk)),
        ),
      ),
    );

/// Vignette d'un média : l'image s'agrandit au toucher, la vidéo se lit dans une fenêtre.
Widget _thumb(BuildContext context, String path, String kind) {
  final url = Backend.postMediaUrl(path);
  final video = kind == 'video';
  return GestureDetector(
    onTap: () => showDialog<void>(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.75),
            child: video ? InlineVideo(url: url) : InteractiveViewer(child: gNetImage(url, fit: BoxFit.contain, errorBuilder: (_, _, _) => const SizedBox(height: 200, child: Center(child: Icon(Icons.broken_image_outlined, color: Colors.white))))),
          ),
          Positioned(right: 0, top: 0, child: IconButton(onPressed: () => Navigator.of(c).pop(), icon: const Icon(Icons.close, color: Colors.white), tooltip: 'Fermer')),
        ]),
      ),
    ),
    child: Container(
      width: 96,
      height: 96,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(color: const Color(0xFFEEE9F5), borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: video
          ? const Center(child: Icon(Icons.play_circle_outline, size: 36, color: kInk))
          : gNetImage(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Center(child: Icon(Icons.image_not_supported_outlined, color: kGrey))),
    ),
  );
}

String _roleLabel(String r) => switch (r) { 'student' => 'Étudiant', 'client' => 'Client', 'company' => 'Entreprise', 'dept' => 'Département', 'admin' => 'Administration', 'support' => 'Support', _ => 'Membre' };

// ------------------------------------------------------------------ publications

class _PostsTab extends ConsumerWidget {
  const _PostsTab({required this.status});
  final String status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(modPostsProvider(status));
    return data.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _error('$e', () => ref.invalidate(modPostsProvider(status))),
      data: (list) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(modPostsProvider(status)),
        child: list.isEmpty
            ? _empty(switch (status) { 'pending' => 'Aucune publication en attente de validation.', 'reported' => 'Aucune publication signalée.', _ => 'Aucune publication masquée.' })
            : ListView.builder(padding: const EdgeInsets.fromLTRB(14, 12, 14, 80), itemCount: list.length, itemBuilder: (c, i) => _PostCard(item: list[i], status: status)),
      ),
    );
  }
}

class _PostCard extends ConsumerWidget {
  const _PostCard({required this.item, required this.status});
  final Map<String, dynamic> item;
  final String status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = '${item['id']}';
    final media = _asList(item['media']);
    final text = '${item['text'] ?? ''}'.trim();
    final reasons = [for (final r in (item['reasons'] as List? ?? const [])) '$r'];
    final created = DateTime.tryParse('${item['created_at']}')?.toLocal();
    final certified = item['author_certified'] == true;
    final note = '${item['note'] ?? ''}'.trim();
    final tags = [for (final t in (item['tags'] as List? ?? const [])) '#$t'];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: _card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: '${item['author_id']}'.isEmpty ? null : () => gOpenProfile(context, '${item['author_id']}'),
              child: Text('${item['author']} · ${_roleLabel('${item['author_role']}')}${certified ? ' · certifié' : ' · non certifié'}', style: sty(13.5, w: FontWeight.w800)),
            ),
          ),
          if (created != null) Text(relativeTime(created, DateTime.now()), style: sty(11, c: kGrey)),
        ]),
        if (item['community'] == true) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Publication de communauté', style: sty(11.5, c: kGrey))),
        if (item['repost'] == true) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Republication', style: sty(11.5, c: kGrey))),
        if (text.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(text, style: sty(14, h: 1.45))),
        if ('${item['link_url'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Lien : ${item['link_url']}', style: sty(12.5, c: const Color(0xFF2F7DF6)))),
        if (tags.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(tags.join(' '), style: sty(12, c: kGrey))),
        if ('${item['listing'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Annonce liée : ${item['listing']}', style: sty(12, c: kGrey))),
        if (media.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: SizedBox(height: 96, child: ListView(scrollDirection: Axis.horizontal, children: [for (final m in media) _thumb(context, '${m['path']}', '${m['kind']}')])),
          ),
        if (status == 'reported') ...[
          const SizedBox(height: 10),
          Text('${item['reports']} signalement${(item['reports'] as int? ?? 0) > 1 ? 's' : ''}', style: sty(12.5, w: FontWeight.w700, c: kLike)),
          for (final r in reasons.take(5)) Padding(padding: const EdgeInsets.only(top: 2), child: Text('• $r', style: sty(12.5, c: kGrey))),
        ],
        if (status == 'hidden' && note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Motif : $note', style: sty(12.5, c: kLike))),
        const SizedBox(height: 12),
        Row(children: switch (status) {
          'pending' => [
              Expanded(child: _btn('Approuver', () => _run(context, ref, 'moderate_post', {'p_post': id, 'p_publish': true, 'p_note': null}, 'Publication approuvée : l’auteur est prévenu.'))),
              const SizedBox(width: 10),
              Expanded(
                child: _btn('Refuser', () async {
                  final why = await _askReason(context, 'Refuser la publication', 'Le motif est envoyé à l’auteur.');
                  if (why != null && context.mounted) await _run(context, ref, 'moderate_post', {'p_post': id, 'p_publish': false, 'p_note': why}, 'Publication refusée : l’auteur est prévenu.');
                }, dark: false),
              ),
            ],
          'reported' => [
              Expanded(
                child: _btn('Masquer', () async {
                  final why = await _askReason(context, 'Masquer la publication', 'Le motif est envoyé à l’auteur.');
                  if (why != null && context.mounted) await _run(context, ref, 'moderate_post', {'p_post': id, 'p_publish': false, 'p_note': why}, 'Publication masquée : l’auteur et les signaleurs sont prévenus.');
                }),
              ),
              const SizedBox(width: 10),
              Expanded(child: _btn('Garder en ligne', () => _run(context, ref, 'post_reports_dismiss', {'p_post': id}, 'Signalements classés.'), dark: false)),
            ],
          _ => [Expanded(child: _btn('Rétablir', () => _run(context, ref, 'moderate_post', {'p_post': id, 'p_publish': true, 'p_note': null}, 'Publication rétablie : l’auteur est prévenu.')))],
        }),
      ]),
    );
  }
}

// ------------------------------------------------------------------ histoires

class _StoriesTab extends ConsumerWidget {
  const _StoriesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(modStoriesProvider);
    return data.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _error('$e', () => ref.invalidate(modStoriesProvider)),
      data: (list) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(modStoriesProvider),
        child: list.isEmpty
            ? _empty('Aucune histoire active à examiner.')
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 80),
                itemCount: list.length,
                itemBuilder: (c, i) {
                  final s = list[i];
                  final id = '${s['id']}';
                  final reports = (s['reports'] as int?) ?? 0;
                  final hidden = s['status'] == 'hidden';
                  final reasons = [for (final r in (s['reasons'] as List? ?? const [])) '$r'];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: _card(),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text('${s['author']}', style: sty(13.5, w: FontWeight.w800))),
                        if (DateTime.tryParse('${s['created_at']}') != null) Text(relativeTime(DateTime.parse('${s['created_at']}').toLocal(), DateTime.now()), style: sty(11, c: kGrey)),
                      ]),
                      const SizedBox(height: 8),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _thumb(context, '${s['media_path']}', '${s['media_kind']}'),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if ('${s['caption'] ?? ''}'.isNotEmpty) Text('${s['caption']}', style: sty(13.5, h: 1.4)),
                            if (reports > 0) Padding(padding: const EdgeInsets.only(top: 6), child: Text('$reports signalement${reports > 1 ? 's' : ''}', style: sty(12.5, w: FontWeight.w700, c: kLike))),
                            for (final r in reasons.take(4)) Text('• $r', style: sty(12.5, c: kGrey)),
                            if (hidden) Text('Déjà retirée, signalement encore ouvert', style: sty(12, c: kGrey)),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        if (!hidden)
                          Expanded(
                            child: _btn('Retirer', () async {
                              final why = await _askReason(context, 'Retirer l’histoire', 'Le motif est envoyé à l’auteur.');
                              if (why != null && context.mounted) await _run(context, ref, 'moderate_story', {'p_story': id, 'p_hide': true, 'p_note': why}, 'Histoire retirée : l’auteur est prévenu.');
                            }),
                          ),
                        if (!hidden && reports > 0) const SizedBox(width: 10),
                        if (reports > 0) Expanded(child: _btn('Garder', () => _run(context, ref, 'moderate_story', {'p_story': id, 'p_hide': false, 'p_note': null}, 'Signalements classés.'), dark: false)),
                      ]),
                    ]),
                  );
                },
              ),
      ),
    );
  }
}

// ------------------------------------------------------------------ commentaires signalés

class _CommentReportsTab extends ConsumerWidget {
  const _CommentReportsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(modCommentReportsProvider);
    return data.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _error('$e', () => ref.invalidate(modCommentReportsProvider)),
      data: (all) {
        final list = [for (final r in all) if (r['status'] == 'open') r];
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(modCommentReportsProvider),
          child: list.isEmpty
              ? _empty('Aucun commentaire signalé.')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 80),
                  itemCount: list.length,
                  itemBuilder: (c, i) {
                    final r = list[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: _card(),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${r['author']}', style: sty(13.5, w: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Text('${r['body']}', style: sty(14, h: 1.4)),
                        const SizedBox(height: 8),
                        Text('Signalé par ${r['reporter']} : ${r['reason']}', style: sty(12.5, c: kLike)),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: _btn('Masquer', () async {
                              final del = await Backend.rpc('delete_post_comment', {'p_comment': r['comment_id']});
                              if (!context.mounted) return;
                              if (del.error != null) return gAlert(context, 'Action impossible', Backend.userMessage(del.error!));
                              await _run(context, ref, 'comment_report_close', {'p_id': r['id']}, 'Commentaire masqué.');
                            }),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: _btn('Garder', () => _run(context, ref, 'comment_report_close', {'p_id': r['id']}, 'Signalement classé.'), dark: false)),
                        ]),
                      ]),
                    );
                  },
                ),
        );
      },
    );
  }
}
