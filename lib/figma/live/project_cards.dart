import '../gdata.dart' show GData, gNetImage;
import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import 'auth.dart';
import 'backend.dart';
import 'console.dart';
import 'entreprise.dart' show dateCourte, projectStatus;
import 'project_pages.dart' show projectProgress;
import 'store.dart' show StrV, fcfa, normText;
import 'talents.dart' show projectTabProvider;

/// Catalogue des projets et innovations (écran 78) : une carte par projet réel, avec ses visuels (photos qui défilent, vidéo lue
/// automatiquement et sans son), son domaine, son état et une fiche détaillée. Rien n'est inventé : sans projet validé, un état vide.

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink, double? h}) =>
    TextStyle(inherit: false, fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c, height: h, textBaseline: TextBaseline.alphabetic);

/// Catalogue de projets validés : lecture de la table pour un compte connecté ; pour un visiteur (ou si la table est refusée),
/// fonction publique `public_projects` (projets validés et publics, sans e-mail ni téléphone de contact).
class PublicProjectRows extends RpcRows {
  PublicProjectRows({this.kind}) : super('public_projects', {if (kind != null) 'p_kind': kind, 'p_limit': 100}, true);
  final String? kind;

  @override
  List<Map<String, dynamic>>? build() {
    if (!Backend.ready) return null;
    ref.watch(authProvider.select((a) => a.current?.email));
    Future.microtask(refresh);
    return null;
  }

  @override
  Future<void> refresh() async {
    if (Backend.userId != null) {
      final r = await Backend.rows('projects', 'id,kind,title,summary,department,details,media,status,created_at',
          eq: {'status': 'approved', if (kind != null) 'kind': kind!}, order: 'created_at');
      if (!ref.mounted) return;
      if (r.error == null) {
        error = false;
        state = r.rows;
        return;
      }
    }
    await super.refresh();
  }
}

/// Seuls les projets validés sont listés (le propriétaire et le département verraient sinon aussi les brouillons).
final projectsFeedProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(PublicProjectRows.new);

Map<String, dynamic> _detailsOf(Map<String, dynamic> p) => p['details'] is Map ? Map<String, dynamic>.from(p['details'] as Map) : <String, dynamic>{};

int _fundingOf(Map<String, dynamic> p) => int.tryParse('${_detailsOf(p)['funding_xaf'] ?? ''}'.replaceAll(RegExp(r'\s'), '')) ?? 0;

/// Pastilles du catalogue : 0 Tous, 1 Prototypes, 2 Recherche, 3 Financement.
bool _inTab(Map<String, dynamic> p, int tab) {
  final progress = '${_detailsOf(p)['progress'] ?? ''}';
  return switch (tab) {
    1 => const ['prototype', 'tests', 'lance'].contains(progress),
    2 => const ['idee', 'conception'].contains(progress),
    3 => _fundingOf(p) > 0,
    _ => true,
  };
}

class _Media {
  const _Media(this.url, this.video);
  final String url;
  final bool video;
}

List<_Media> _mediaOf(Map<String, dynamic> r) {
  final out = <_Media>[];
  final raw = r['media'];
  if (raw is List) {
    for (final m in raw) {
      if (m is! Map) continue;
      final path = '${m['path'] ?? ''}';
      if (path.isEmpty) continue;
      final url = Backend.publicUrl('project-media', path);
      if (url.isNotEmpty) out.add(_Media(url, '${m['type']}' == 'video'));
    }
  }
  // la vidéo en premier plan si elle existe : elle se lance toute seule derrière le titre
  out.sort((a, b) => (a.video == b.video) ? 0 : (a.video ? -1 : 1));
  return out;
}

class ProjectCards extends ConsumerStatefulWidget {
  const ProjectCards({super.key, this.width = 342, this.height = 540});
  final double width, height;

  @override
  ConsumerState<ProjectCards> createState() => _ProjectCardsState();
}

class _ProjectCardsState extends ConsumerState<ProjectCards> {
  @override
  void initState() {
    super.initState();
    // le catalogue est mis en cache par le fournisseur : à chaque ouverture de l'écran on le relit
    if (ref.exists(projectsFeedProvider)) Future.microtask(() => ref.invalidate(projectsFeedProvider));
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.width, height = widget.height;
    Widget note(String t) => Container(
          width: width,
          height: 190,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(t, textAlign: TextAlign.center, style: _st(13, c: _grey, h: 1.5)),
        );
    final all = ref.watch(projectsFeedProvider);
    final tab = ref.watch(projectTabProvider);
    if (all == null) return note('Chargement…');
    if (ref.read(projectsFeedProvider.notifier).error) return note('Les projets ne peuvent pas être chargés pour le moment.');
    if (all.isEmpty) return note('Aucun projet validé pour le moment.\nLes projets des étudiants apparaissent ici après validation.');
    final rows = [for (final p in all) if (_inTab(p, tab)) p];
    if (rows.isEmpty) return note('Aucun projet validé dans cette catégorie pour le moment.');
    return SizedBox(
      width: width,
      height: height,
      child: RefreshIndicator(
        onRefresh: () => ref.read(projectsFeedProvider.notifier).refresh(),
        child: ListView.separated(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const SizedBox(height: 18),
          itemBuilder: (_, i) => _Card(p: rows[i], width: width),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.p, required this.width});
  final Map<String, dynamic> p;
  final double width;

  @override
  Widget build(BuildContext context) {
    final media = _mediaOf(p);
    final dept = '${p['department'] ?? ''}';
    final kind = '${p['kind']}' == 'innovation' ? 'Innovation' : 'Projet';
    return Semantics(
      button: true,
      label: '${p['title']}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showProjectSheet(context, p),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(width: width, height: width * 0.62, child: media.isEmpty ? const _NoMedia() : ProjectMediaView(media: media, interactive: false)),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Text('${p['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: _st(15, w: FontWeight.w700))),
            const SizedBox(width: 8),
            _Chip(projectStatus(p['status'])),
          ]),
          const SizedBox(height: 3),
          Text([kind, if (dept.isNotEmpty) dept].join(' · '), style: _st(11.5, c: _grey)),
          if ('${p['summary'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${p['summary']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: _st(12, c: _grey, h: 1.4))),
        ]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: const Color(0xFFEEE9FF), borderRadius: BorderRadius.circular(11)),
        child: Text(label, style: _st(10.5, w: FontWeight.w600, c: const Color(0xFF5A3FE0))),
      );
}

class _NoMedia extends StatelessWidget {
  const _NoMedia();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFEDE3F6), Color(0xFFF7E6D6)])),
        child: Center(child: Icon(Icons.lightbulb_outline_rounded, size: 40, color: Color(0xFF5A3FE0))),
      );
}

/// Visuels d'un projet : la vidéo se lance seule (sans son, en boucle) ; les photos défilent toutes les 3 secondes et se balaient du doigt.
class ProjectMediaView extends StatefulWidget {
  const ProjectMediaView({super.key, required this.media, this.interactive = true});
  final List<_Media> media;
  final bool interactive;
  @override
  State<ProjectMediaView> createState() => _ProjectMediaViewState();
}

class _ProjectMediaViewState extends State<ProjectMediaView> {
  final _page = PageController();
  Timer? _timer;
  int _i = 0;

  @override
  void initState() {
    super.initState();
    if (widget.media.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (!mounted || !_page.hasClients) return;
        // une vidéo en cours de lecture n'est pas interrompue
        if (widget.media[_i].video) return;
        _page.animateToPage((_i + 1) % widget.media.length, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.media;
    return Stack(fit: StackFit.expand, children: [
      PageView.builder(
        controller: _page,
        physics: widget.interactive || m.length > 1 ? const PageScrollPhysics() : const NeverScrollableScrollPhysics(),
        itemCount: m.length,
        onPageChanged: (v) => setState(() => _i = v),
        itemBuilder: (_, k) => m[k].video
            ? _LoopVideo(url: m[k].url)
            : gNetImage(m[k].url, fit: BoxFit.cover, errorBuilder: (_, _, _) => const _NoMedia()),
      ),
      if (m.length > 1)
        Positioned(
          bottom: 8,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var k = 0; k < m.length; k++)
                AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.symmetric(horizontal: 3), width: k == _i ? 16 : 6, height: 6, decoration: BoxDecoration(color: k == _i ? Colors.white : const Color(0x99FFFFFF), borderRadius: BorderRadius.circular(3))),
            ]),
          ),
        ),
    ]);
  }
}

class _LoopVideo extends StatefulWidget {
  const _LoopVideo({required this.url});
  final String url;
  @override
  State<_LoopVideo> createState() => _LoopVideoState();
}

class _LoopVideoState extends State<_LoopVideo> {
  VideoPlayerController? _c;

  @override
  void initState() {
    super.initState();
    if (!GData.blockVideo) _start();
  }

  void _start() {
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url), videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
    _c = c;
    c.initialize().then((_) {
      c.setVolume(0);
      c.setLooping(true);
      c.play();
      if (mounted) setState(() {});
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) return GestureDetector(onTap: () => setState(_start), child: const ColoredBox(color: Color(0xFF18171F), child: Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 40))));
    if (!c.value.isInitialized) return const ColoredBox(color: Color(0xFF18171F));
    return FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c)));
  }
}

/// Registre des innovations (écran 87) : projets de type innovation validés ; la RLS ne laisse voir que les projets publics (ou les siens).
final innovationsRegistryProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => PublicProjectRows(kind: 'innovation'));

/// Texte saisi dans le champ de recherche du registre.
final innovationQueryProvider = NotifierProvider<StrV, String>(StrV.new);

class InnovationRegistry extends ConsumerStatefulWidget {
  const InnovationRegistry({super.key, this.width = 342, this.height = 520});
  final double width, height;

  @override
  ConsumerState<InnovationRegistry> createState() => _InnovationRegistryState();
}

class _InnovationRegistryState extends ConsumerState<InnovationRegistry> {
  @override
  void initState() {
    super.initState();
    if (ref.exists(innovationsRegistryProvider)) Future.microtask(() => ref.invalidate(innovationsRegistryProvider));
  }

  @override
  Widget build(BuildContext context) {
    Widget note(String t) => Container(
          width: widget.width,
          height: 190,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(t, textAlign: TextAlign.center, style: _st(13, c: _grey, h: 1.5)),
        );
    final all = ref.watch(innovationsRegistryProvider);
    final q = normText(ref.watch(innovationQueryProvider).trim());
    if (all == null) return note('Chargement…');
    if (ref.read(innovationsRegistryProvider.notifier).error) return note('Le registre ne peut pas être chargé pour le moment.');
    if (all.isEmpty) return note('Aucune innovation validée pour le moment.');
    final rows = [for (final r in all) if (q.isEmpty || normText('${r['title'] ?? ''} ${r['summary'] ?? ''}').contains(q)) r];
    if (rows.isEmpty) return note('Aucune innovation ne correspond à votre recherche.');
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: RefreshIndicator(
        onRefresh: () => ref.read(innovationsRegistryProvider.notifier).refresh(),
        child: ListView.separated(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const Divider(height: 22, thickness: 1, color: Color(0xFFF2EFF6)),
          itemBuilder: (_, i) {
            final r = rows[i];
            final dept = '${r['department'] ?? ''}'.trim();
            return Semantics(
              button: true,
              label: '${r['title']}',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => showProjectSheet(context, r),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${r['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: _st(13.5, w: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text([if (dept.isNotEmpty) dept, dateCourte(r['created_at'])].join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis, style: _st(11.5, c: _grey)),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  _Chip(projectStatus(r['status'])),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Fiche d'un projet : visuels, description, problème et solution, avancement, équipe et liens.
Future<void> showProjectSheet(BuildContext context, Map<String, dynamic> p) {
  final media = _mediaOf(p);
  final d = p['details'] is Map ? Map<String, dynamic>.from(p['details'] as Map) : <String, dynamic>{};
  String s(String k) => '${d[k] ?? ''}'.trim();
  Widget block(String title, String text) => text.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: _st(13, w: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(text, style: _st(13, c: const Color(0xFF3B3944), h: 1.5)),
          ]),
        );
  Widget link(String label, String url) => url.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 8),
          child: GestureDetector(
            onTap: () => launchUrl(Uri.parse(url.startsWith('http') ? url : 'https://$url'), mode: LaunchMode.externalApplication),
            child: Text(label, style: _st(13, w: FontWeight.w600, c: const Color(0xFF5A3FE0))),
          ),
        );
  final team = d['team'] is List ? [for (final m in d['team'] as List) if (m is Map) '${m['name']}${'${m['role']}'.isEmpty ? '' : ' · ${m['role']}'}'] : <String>[];
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: .86,
      maxChildSize: .95,
      minChildSize: .5,
      expand: false,
      builder: (_, scroll) => Container(
        decoration: const BoxDecoration(color: Color(0xFFF7F2EA), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(20, 14, 20, 32), children: [
          Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: const Color(0xFFD9D4E0), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),
          if (media.isNotEmpty) ClipRRect(borderRadius: BorderRadius.circular(18), child: AspectRatio(aspectRatio: 16 / 10, child: ProjectMediaView(media: media))),
          const SizedBox(height: 14),
          Text('${p['title']}', style: _st(20, w: FontWeight.w800)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 6, children: [
            _Chip(projectStatus(p['status'])),
            if ('${p['department'] ?? ''}'.isNotEmpty) _Chip('${p['department']}'),
            if (s('domain').isNotEmpty) _Chip(s('domain')),
            if (projectProgress[s('progress')] != null) _Chip(projectProgress[s('progress')]!),
          ]),
          block('Description', '${p['summary'] ?? ''}'.trim()),
          block('Problème résolu', s('problem')),
          block('Solution', s('solution')),
          block('Étapes réalisées', s('done_steps')),
          block('Objectifs', s('objectives')),
          if (team.isNotEmpty) block('Équipe', team.join('\n')),
          if (_fundingOf(p) > 0) block('Besoin de financement', fcfa(_fundingOf(p))),
          block('Besoins de soutien', s('support_needs')),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              link('Voir le prototype', s('prototype_url')),
              link('Voir la démonstration', s('demo_url')),
              link('Lire la documentation', s('doc_url')),
              link('Voir la vidéo', s('video_url')),
            ]),
          ),
        ]),
      ),
    ),
  );
}
