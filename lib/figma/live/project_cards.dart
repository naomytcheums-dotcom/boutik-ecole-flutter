import '../gdata.dart' show GData, gNetImage;
import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../gen.dart' show gToast;
import '../nav.dart';
import 'auth.dart';
import 'backend.dart';
import 'console.dart';
import 'entreprise.dart' show dateCourte, projectStatus;
import 'l9_campagnes.dart' show CampaignDetailPage;
import 'project_pages.dart' show projectLicenses, projectProgress;
import 'store.dart' show StrV, fcfa, normText;
import 'talents.dart' show projectTabProvider;
import 'tp_ui.dart';

/// Catalogue des projets et innovations (écran 78) : une carte par projet réel, avec ses visuels (photos qui défilent, vidéo lue
/// automatiquement et sans son), son domaine, son état et une fiche détaillée. Rien n'est inventé : sans projet validé, un état vide.

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink, double? h}) =>
    TextStyle(inherit: false, fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c, height: h, textBaseline: TextBaseline.alphabetic);

/// Catalogue de projets validés : pour TOUS les comptes (visiteur compris), la fonction publique `public_projects` renvoie les projets
/// validés et publics sans e-mail ni téléphone de contact. La table `projects` n'est lue que pour « Mes projets » (filtre propriétaire).
class PublicProjectRows extends RpcRows {
  PublicProjectRows({this.kind}) : super('public_projects', {'p_kind': ?kind, 'p_limit': 100}, true);
  final String? kind;

  @override
  List<Map<String, dynamic>>? build() {
    if (!Backend.ready) return null;
    ref.watch(authProvider.select((a) => a.current?.email));
    Future.microtask(refresh);
    return null;
  }
}

/// Seuls les projets validés sont listés (le propriétaire et le département verraient sinon aussi les brouillons).
final projectsFeedProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(PublicProjectRows.new);

Map<String, dynamic> _detailsOf(Map<String, dynamic> p) => p['details'] is Map ? Map<String, dynamic>.from(p['details'] as Map) : <String, dynamic>{};

int _fundingOf(Map<String, dynamic> p) => int.tryParse('${_detailsOf(p)['funding_xaf'] ?? ''}'.replaceAll(RegExp(r'\s'), '')) ?? 0;

/// Propriété intellectuelle déclarée par le porteur (details.ip) : champs non vides uniquement.
Map<String, String> _ipOf(Map<String, dynamic> p) {
  final raw = _detailsOf(p)['ip'];
  if (raw is! Map) return const {};
  return {for (final e in raw.entries) if ('${e.value}'.trim().isNotEmpty) '${e.key}': '${e.value}'.trim()};
}

String _ipSummary(Map<String, dynamic> p) {
  final ip = _ipOf(p);
  return [
    if (ip['license'] != null) 'Licence : ${projectLicenses[ip['license']] ?? ip['license']}',
    if (ip['filing_number'] != null) 'Dépôt déclaré n° ${ip['filing_number']}',
  ].join(' · ');
}

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
  String _q = '';

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
    final q = normText(_q.trim());
    final rows = [
      for (final p in all)
        if (_inTab(p, tab) && (q.isEmpty || normText('${p['title'] ?? ''} ${p['summary'] ?? ''} ${p['department'] ?? ''} ${_detailsOf(p)['domain'] ?? ''}').contains(q))) p,
    ];
    return SizedBox(
      width: width,
      height: height,
      child: Column(children: [
        SizedBox(
          height: 42,
          child: TextField(
            onChanged: (v) => setState(() => _q = v),
            style: _st(13.5),
            decoration: InputDecoration(
              hintText: 'Rechercher un projet',
              hintStyle: _st(13.5, c: _grey),
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: _grey),
              isDense: true,
              filled: true,
              fillColor: const Color(0xCCFFFFFF),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(21), borderSide: const BorderSide(color: Color(0xFFE4E0EC))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(21), borderSide: const BorderSide(color: Color(0xFFE4E0EC))),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: rows.isEmpty
              ? Align(alignment: Alignment.topCenter, child: note(q.isEmpty ? 'Aucun projet validé dans cette catégorie pour le moment.' : 'Aucun projet ne correspond à votre recherche.'))
              : RefreshIndicator(
                  onRefresh: () => ref.read(projectsFeedProvider.notifier).refresh(),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 18),
                    itemBuilder: (_, i) => _Card(p: rows[i], width: width),
                  ),
                ),
        ),
      ]),
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
            _Chip(projectProgress['${_detailsOf(p)['progress'] ?? ''}'] ?? projectStatus(p['status'])),
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
    final rows = [for (final r in all) if (q.isEmpty || normText('${r['title'] ?? ''} ${r['summary'] ?? ''} ${_ipOf(r)['authors'] ?? ''} ${_ipOf(r)['filing_number'] ?? ''}').contains(q)) r];
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
                      if (_ipSummary(r).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(_ipSummary(r), maxLines: 2, overflow: TextOverflow.ellipsis, style: _st(11, c: const Color(0xFF5A3FE0)))),
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

/// Projet ouvert depuis le catalogue (écran 79 : le dernier choix).
final selectedProjectIdProvider = NotifierProvider<StrV, String>(StrV.new);

/// Ouvre la fiche d'un projet : affichée tout de suite avec la ligne déjà connue, puis relue sur le serveur.
Future<void> showProjectSheet(BuildContext context, Map<String, dynamic> p) => Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => ProjectDetailPage(initial: p)));

/// Fiche d'un projet réel (écran 79) : visuels, description, problème et solution, avancement, équipe, financement,
/// propriété intellectuelle déclarée, liens, et soutien. Les contacts n'y figurent jamais.
class ProjectDetailPage extends ConsumerStatefulWidget {
  const ProjectDetailPage({super.key, this.projectId, this.initial});
  final String? projectId;
  final Map<String, dynamic>? initial;

  @override
  ConsumerState<ProjectDetailPage> createState() => _ProjectDetailState();
}

class _ProjectDetailState extends ConsumerState<ProjectDetailPage> {
  Map<String, dynamic>? p;
  bool loading = true, gone = false, busy = false;

  String? get _id {
    final i = (widget.projectId ?? '${widget.initial?['id'] ?? ''}').trim();
    return i.isEmpty || i == 'null' ? null : i;
  }

  @override
  void initState() {
    super.initState();
    p = widget.initial;
    if (_id == null) {
      loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final r = await Backend.rpc('public_project_get', {'p_id': _id});
    if (!mounted) return;
    setState(() {
      loading = false;
      if (r.error != null) return;
      if (r.data is Map) {
        p = Map<String, dynamic>.from(r.data as Map);
        gone = false;
      } else {
        gone = true;
      }
    });
  }

  Future<void> _support() async {
    final cur = p;
    if (cur == null) return;
    if (!await requireLogin(context, ref, 'soutenir un projet') || !mounted) return;
    setState(() => busy = true);
    final r = await Backend.rpc('project_upvote_toggle', {'p_project': cur['id']});
    if (!mounted) return;
    setState(() => busy = false);
    if (r.error != null) return gToast(context, Backend.userMessage(r.error!));
    final on = r.data == true;
    setState(() => p = {...cur, 'voted': on, 'votes': ((cur['votes'] as num?)?.toInt() ?? 0) + (on ? 1 : -1)});
    gToast(context, on ? 'Merci ! Votre soutien à « ${cur['title']} » est enregistré.' : 'Votre soutien à « ${cur['title']} » est retiré.');
  }

  @override
  Widget build(BuildContext context) {
    final cur = p;
    if (cur == null || gone) {
      return TpPage(title: 'Projet', children: [
        if (loading)
          const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
        else ...[
          TpEmpty(
            title: _id == null ? 'Aucun projet sélectionné' : 'Projet indisponible',
            text: _id == null ? 'Ouvrez un projet depuis le catalogue pour voir sa fiche.' : 'Ce projet n’est plus publié ou n’existe pas.',
            icon: Icons.lightbulb_outline_rounded,
          ),
          TpButton('Voir les projets validés', () => gOpen(context, '78'), icon: Icons.lightbulb_outline_rounded),
        ],
      ]);
    }
    final d = _detailsOf(cur);
    String s(String k) => '${d[k] ?? ''}'.trim();
    final media = _mediaOf(cur);
    final ip = _ipOf(cur);
    final team = cur['team'] is List ? [for (final m in cur['team'] as List) if (m is Map) '${m['name']}${'${m['role']}'.isEmpty ? '' : ' · ${m['role']}'}'] : <String>[];
    final free = d['team'] is List ? [for (final m in d['team'] as List) if (m is Map) '${m['name']}${'${m['role']}'.isEmpty ? '' : ' · ${m['role']}'}'] : <String>[];
    final ipLines = [
      if (ip['authors'] != null) 'Auteurs : ${ip['authors']}',
      if (ip['supervisor'] != null) 'Encadrant : ${ip['supervisor']}',
      if (ip['license'] != null) 'Licence : ${projectLicenses[ip['license']] ?? ip['license']}',
      if (ip['rights_holder'] != null) 'Titulaire des droits : ${ip['rights_holder']}',
      if (ip['restrictions'] != null) 'Restrictions d’usage : ${ip['restrictions']}',
      if (ip['filing_number'] != null) 'N° de dépôt déclaré : ${ip['filing_number']}',
    ];
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
            child: GestureDetector(onTap: () => tpOpenUrl(context, url), child: Text(label, style: _st(13, w: FontWeight.w600, c: const Color(0xFF5A3FE0)))),
          );
    final votes = (cur['votes'] as num?)?.toInt();
    final campaign = cur['campaign_id'] == null ? null : '${cur['campaign_id']}';
    final mine = cur['mine'] == true;
    final canSupport = '${cur['status']}' == 'approved';
    return TpPage(
      title: '${cur['kind']}' == 'innovation' ? 'Innovation' : 'Projet',
      subtitle: '${cur['department'] ?? ''}'.isEmpty ? null : '${cur['department']}',
      bottom: !canSupport
          ? null
          : mine
              ? Text('C’est votre projet : il ne peut pas être soutenu par vous.', textAlign: TextAlign.center, style: _st(12.5, c: _grey))
              : TpButton(cur['voted'] == true ? 'Retirer mon soutien' : 'Soutenir le projet', busy ? null : _support, dark: cur['voted'] != true, busy: busy, icon: cur['voted'] == true ? Icons.favorite_rounded : Icons.favorite_border_rounded),
      children: [
        if (media.isNotEmpty) ClipRRect(borderRadius: BorderRadius.circular(18), child: AspectRatio(aspectRatio: 16 / 10, child: ProjectMediaView(media: media))),
        const SizedBox(height: 14),
        Text('${cur['title']}', style: _st(20, w: FontWeight.w800)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 6, children: [
          _Chip(projectStatus(cur['status'])),
          if (s('domain').isNotEmpty) _Chip(s('domain')),
          if (projectProgress[s('progress')] != null) _Chip(projectProgress[s('progress')]!),
        ]),
        if ('${cur['owner'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Porté par ${cur['owner']}', style: _st(12.5, c: _grey))),
        if (votes != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('$votes soutien${votes > 1 ? 's' : ''}', style: _st(12.5, w: FontWeight.w600, c: const Color(0xFF5A3FE0)))),
        block('Description', '${cur['summary'] ?? ''}'.trim()),
        block('Problème résolu', s('problem')),
        block('Solution', s('solution')),
        block('Étapes réalisées', s('done_steps')),
        block('Objectifs', s('objectives')),
        if (team.isNotEmpty) block('Équipe', team.join('\n')),
        if (free.isNotEmpty) block(team.isEmpty ? 'Équipe' : 'Autres contributeurs', free.join('\n')),
        if (_fundingOf(cur) > 0) block('Besoin de financement', fcfa(_fundingOf(cur))),
        if (campaign != null)
          Padding(padding: const EdgeInsets.only(top: 10), child: TpButton('Voir la campagne de financement', () => Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => CampaignDetailPage(campaignId: campaign))), dark: false, compact: true, icon: Icons.volunteer_activism_outlined)),
        block('Besoins de soutien', s('support_needs')),
        if (ipLines.isNotEmpty) ...[
          block('Propriété intellectuelle', ipLines.join('\n')),
          Padding(padding: const EdgeInsets.only(top: 4), child: Text('Informations déclarées par le porteur du projet ; elles ne remplacent pas un certificat de dépôt.', style: _st(11.5, c: _grey, h: 1.4))),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            link('Voir le prototype', s('prototype_url')),
            link('Voir la démonstration', s('demo_url')),
            link('Lire la documentation', s('doc_url')),
            link('Voir la vidéo', s('video_url')),
          ]),
        ),
      ],
    );
  }
}
