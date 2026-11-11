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
import 'entreprise.dart' show TableRows, projectStatus;

/// Catalogue des projets et innovations (écran 78) : une carte par projet réel, avec ses visuels (photos qui défilent, vidéo lue
/// automatiquement et sans son), son domaine, son état et une fiche détaillée. Rien n'est inventé : sans projet validé, un état vide.

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink, double? h}) =>
    TextStyle(inherit: false, fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c, height: h, textBaseline: TextBaseline.alphabetic);

final projectsFeedProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(
    () => TableRows('projects', 'id,kind,title,summary,department,details,media,status,created_at', order: 'created_at'));

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

class ProjectCards extends ConsumerWidget {
  const ProjectCards({super.key, this.width = 342, this.height = 540});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget note(String t) => Container(
          width: width,
          height: 190,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(t, textAlign: TextAlign.center, style: _st(13, c: _grey, h: 1.5)),
        );
    if (ref.watch(authProvider.select((a) => a.current == null))) return note('Connectez-vous pour voir les projets.');
    final all = ref.watch(projectsFeedProvider);
    if (all == null) return note('Chargement…');
    if (ref.read(projectsFeedProvider.notifier).error) return note('Les projets ne peuvent pas être chargés pour le moment.');
    if (all.isEmpty) return note('Aucun projet validé pour le moment.\nLes projets des étudiants apparaissent ici après validation.');
    return SizedBox(
      width: width,
      height: height,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: all.length,
        separatorBuilder: (_, _) => const SizedBox(height: 18),
        itemBuilder: (_, i) => _Card(p: all[i], width: width),
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
          ]),
          block('Description', '${p['summary'] ?? ''}'.trim()),
          block('Problème résolu', s('problem')),
          block('Solution', s('solution')),
          block('Étapes réalisées', s('done_steps')),
          block('Objectifs', s('objectives')),
          if (team.isNotEmpty) block('Équipe', team.join('\n')),
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
