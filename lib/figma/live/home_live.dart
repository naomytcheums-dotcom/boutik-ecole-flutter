import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:video_player/video_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../nav.dart';
import 'backend.dart';
import 'seller.dart' show allProductsProvider;
import 'store.dart';
import 'talents.dart' show visibleTalentsProvider;

/// Accueil (03), connecté au serveur : produits publiés et talents réels. Aucun produit ni profil de maquette n'est affiché ;
/// sans donnée, un état vide explicite prend la place. Hors connexion au serveur, la maquette reste affichée comme démonstration.

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

class LiveTalent {
  const LiveTalent({required this.id, required this.name, required this.department, required this.skills, required this.avatarUrl, required this.certified, this.coverUrl = '', this.coverVideo = false});
  final String id, name, department, skills, avatarUrl, coverUrl;
  final bool coverVideo;
  final bool certified;

  static LiveTalent fromRow(Map x) => LiveTalent(
        id: '${x['id']}',
        name: '${x['name']}',
        department: '${x['department'] ?? ''}',
        skills: '${x['skills'] ?? ''}',
        avatarUrl: '${x['avatar_url'] ?? ''}',
        certified: x['certified'] == true,
        coverUrl: (x['cover_path'] ?? '').toString().isEmpty ? '' : Backend.postMediaUrl('${x['cover_path']}'),
        coverVideo: x['cover_kind'] == 'video',
      );

  String get initials {
    final p = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (p.isEmpty) return '?';
    return (p.first[0] + (p.length > 1 ? p.last[0] : '')).toUpperCase();
  }
}

/// `null` : lecture en cours, visiteur ou serveur absent ; liste vide : aucun talent à présenter.
class TalentsNotifier extends Notifier<List<LiveTalent>?> {
  bool error = false;

  @override
  List<LiveTalent>? build() {
    if (!Backend.ready) return null;
    Future.microtask(refresh);
    return null;
  }

  Future<void> refresh() async {
    final r = await Backend.rpc('talents_list', {'p_query': '', 'p_limit': 12});
    if (!ref.mounted) return;
    error = r.error != null || r.data is! List;
    state = error ? const [] : [for (final x in r.data as List) LiveTalent.fromRow(x as Map)];
  }
}

final liveTalentsProvider = NotifierProvider<TalentsNotifier, List<LiveTalent>?>(TalentsNotifier.new);

/// « Talents à découvrir » : cartes défilantes horizontalement, avec chargement, état vide et invitation à se connecter.
class HomeTalents extends ConsumerWidget {
  const HomeTalents({super.key, this.width = 368, this.height = 200});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget note(String t, {String? action, VoidCallback? onTap}) => Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(t, textAlign: TextAlign.center, style: _st(12.5, c: _grey).copyWith(height: 1.5)),
            if (action != null) ...[
              const SizedBox(height: 12),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10), decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(20)), child: Text(action, style: _st(12.5, w: FontWeight.w600, c: Colors.white))),
              ),
            ],
          ]),
        );
    final list = ref.watch(liveTalentsProvider);
    if (list == null) return note('Chargement des talents…');
    final failed = ref.read(liveTalentsProvider.notifier).error;
    if (list.isEmpty && failed) return note('Les talents ne peuvent pas être chargés pour le moment.');
    // aucun profil réel : état vide explicite (jamais de profil d'exemple en mode connecté)
    if (list.isEmpty) return note('Aucun talent à présenter pour le moment.\nLes étudiants qui complètent leur profil apparaissent ici.');
    final items = list;
    return SizedBox(
      width: width,
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final t = items[i];
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => gOpen(context, '70'),
            child: _TalentStory(t: t),
          );
        },
      ),
    );
  }
}

/// Carte « story » d'un talent : fond plein cadre (photo du profil, à défaut un dégradé doux), coins arrondis, rond de profil
/// cerclé en bas, puis le nom et le domaine en blanc. Format vertical, comme les stories des réseaux sociaux.
class _TalentStory extends StatelessWidget {
  const _TalentStory({required this.t});
  final LiveTalent t;

  @override
  Widget build(BuildContext context) {
    const ring = LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFFFFB400), Color(0xFFFF2D87), Color(0xFFB026FF)]);
    final hasPhoto = t.avatarUrl.isNotEmpty;
    return SizedBox(
      width: 172,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(fit: StackFit.expand, children: [
          if (t.coverUrl.isNotEmpty && t.coverVideo)
            _CoverVideo(url: t.coverUrl)
          else if (t.coverUrl.isNotEmpty || hasPhoto)
            Image.network(t.coverUrl.isNotEmpty ? t.coverUrl : t.avatarUrl, fit: BoxFit.cover, alignment: Alignment.topCenter, errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFD9D2E6)))
          else
            const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFEDE3F6), Color(0xFFD9C9EC)]))),
          const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0x00000000), Color(0xCC000000)], stops: [0, .5, 1]))),
          Positioned(
            left: 8,
            right: 8,
            bottom: 16,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 56,
                height: 56,
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: ring),
                child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white), child: _Avatar(t, size: 46)),
              ),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Flexible(child: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: _st(13, w: FontWeight.w700, c: Colors.white))),
                if (t.certified) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified, size: 14, color: Color(0xFF4DA3FF))),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Vidéo de couverture : lecture automatique, sans son, en boucle, derrière le nom de la personne.
class _CoverVideo extends StatefulWidget {
  const _CoverVideo({required this.url});
  final String url;
  @override
  State<_CoverVideo> createState() => _CoverVideoState();
}

class _CoverVideoState extends State<_CoverVideo> {
  VideoPlayerController? _c;

  @override
  void initState() {
    super.initState();
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
    if (c == null || !c.value.isInitialized) return const ColoredBox(color: Color(0xFFD9D2E6));
    return FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c)));
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.t, {this.size = 44});
  final LiveTalent t;
  final double size;

  @override
  Widget build(BuildContext context) {
    Widget initials() => Container(width: size, height: size, alignment: Alignment.center, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFEDE9F6)), child: Text(t.initials, style: _st(size * .34, w: FontWeight.w700, c: const Color(0xFF4A4854))));
    if (t.avatarUrl.isEmpty) return initials();
    return ClipOval(child: Image.network(t.avatarUrl, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, _, _) => initials()));
  }
}

/// Deux produits publiés (les plus récents du catalogue), ou un état vide ; la photo vient de l'annonce, sinon un visuel neutre.
class HomeProducts extends ConsumerWidget {
  const HomeProducts({super.key, this.width = 368, this.height = 229});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(allProductsProvider).take(2).toList();
    if (list.isEmpty) {
      return Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text('Aucun produit publié pour le moment.\nLes créations des étudiants apparaîtront ici dès leur publication.', textAlign: TextAlign.center, style: _st(12.5, c: _grey).copyWith(height: 1.5)),
      );
    }
    return Row(children: [
      for (var i = 0; i < list.length; i++) ...[
        if (i > 0) const SizedBox(width: 14),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              ref.read(selectedProductProvider.notifier).select(list[i].title);
              gOpen(context, '05');
            },
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                height: 163,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: list[i].image == 'placeholder' || list[i].image.isEmpty ? Image.asset(neutralProductImage, fit: BoxFit.cover) : (list[i].image.startsWith('http') ? Image.network(list[i].image, fit: BoxFit.cover, errorBuilder: (_, _, _) => Image.asset(neutralProductImage, fit: BoxFit.cover)) : Image.asset(list[i].image, fit: BoxFit.cover)),
                ),
              ),
              const SizedBox(height: 8),
              Text(list[i].title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(11.5, w: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(fcfa(list[i].price), style: _st(10.5, w: FontWeight.w600)),
              const SizedBox(height: 3),
              Text(list[i].seller, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(9.5, c: _grey)),
            ]),
          ),
        ),
      ],
    ]);
  }
}

/// Photo d'un talent de la liste (écran 70) : photo du profil réel, sinon initiales ; la maquette (démonstration) garde ses visuels.
class TalentAvatar extends ConsumerWidget {
  const TalentAvatar({super.key, required this.index});
  final int index;

  static const _demo = ['d902a4aabb7fd7d1d301a3bebd0f8ff54ecefb47', 'ebf23a969ca7b1083d1dcab994c4899c0b4db38b'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(liveTalentsProvider) ?? const <LiveTalent>[];
    if (!Backend.ready) return ClipOval(child: Image.asset('assets/figma/img/${_demo[index % 2]}.png', fit: BoxFit.cover));
    // les lignes suivent la liste filtrée ; on retrouve la personne par son rang parmi les talents visibles
    final shown = ref.watch(visibleTalentsProvider);
    if (index >= shown.length) return const SizedBox.shrink();
    final t = list.where((e) => e.name == shown[index].name).toList();
    return _Avatar(t.isEmpty ? LiveTalent(id: '', name: shown[index].name, department: '', skills: '', avatarUrl: shown[index].avatarUrl, certified: false) : t.first, size: 50);
  }
}

/// Membres de la communauté (écran 103) : les vrais profils étudiants, avec ouverture de leur profil public.
/// Chargement, état vide et erreur ; aucun nom de maquette hors démonstration.
class CommunityMembers extends ConsumerWidget {
  const CommunityMembers({super.key, this.width = 342, this.height = 190});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(liveTalentsProvider);
    final failed = ref.read(liveTalentsProvider.notifier).error;
    Widget note(String t) => Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(t, textAlign: TextAlign.center, style: _st(12.5, c: _grey).copyWith(height: 1.5)),
        );
    if (list == null) return note('Chargement des membres…');
    if (list.isEmpty) return note(failed ? 'Les membres ne peuvent pas être chargés pour le moment.' : 'Aucun membre à présenter pour le moment.\nLes étudiants qui renseignent leurs compétences apparaissent ici.');
    return SizedBox(
      width: width,
      height: height,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: list.length,
        separatorBuilder: (_, _) => const Divider(height: 16, thickness: 1, color: Color(0xFFF2EFF6)),
        itemBuilder: (_, i) {
          final t = list[i];
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => gOpenProfile(context, t.id),
            child: Row(children: [
              _Avatar(t, size: 50),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(13.5, w: FontWeight.w600))),
                    if (t.certified) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified, size: 14, color: Color(0xFF2F6BFF))),
                  ]),
                  const SizedBox(height: 2),
                  Text([if (t.department.isNotEmpty) t.department, t.skills].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(11.5, c: _grey)),
                ]),
              ),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFEFEBFA), borderRadius: BorderRadius.circular(11)), child: Text('Voir le profil', style: _st(11, w: FontWeight.w600, c: const Color(0xFF5A3FE0)))),
            ]),
          );
        },
      ),
    );
  }
}
