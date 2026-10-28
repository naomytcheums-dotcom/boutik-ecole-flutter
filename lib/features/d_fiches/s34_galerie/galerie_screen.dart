import '../../common/common.dart';
import '../d_widgets.dart';

/// 34 · Galerie du produit : grande photo, vignettes, grille de photos et vidéo.
class GalerieScreen extends ConsumerStatefulWidget {
  const GalerieScreen({super.key});

  @override
  ConsumerState<GalerieScreen> createState() => _GalerieScreenState();
}

class _GalerieScreenState extends ConsumerState<GalerieScreen> {
  String? _main;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionDDataProvider);
    final main = _main ?? d.galleryHero;
    return DScaffold(
      title: 'Galerie',
      headerActions: [
        DHeaderAction(
          AppIcons.share,
          label: 'Partager la galerie',
          onTap: () => context.toast('Lien de la galerie copié.'),
        ),
      ],
      children: [
        const SizedBox(height: 2),
        DPhoto(main, height: 250, label: 'Photo principale de ${d.productTitle}'),
        const SizedBox(height: 14),
        SizedBox(
          height: 70,
          child: Row(
            children: [
              for (final (i, (p, x)) in d.galleryStrip.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: p == main,
                    label: 'Afficher la photo ${i + 1}',
                    child: GestureDetector(
                      onTap: () => setState(() => _main = p == main ? d.galleryHero : p),
                      child: DPhoto(p, radius: 16, height: 70, alignment: Alignment(x, 0)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 2),
        DSectionTitle(
          'Photos (${d.galleryPhotoCount})',
          trailing: DLink('Tout voir', onTap: () => context.toast('${d.galleryPhotoCount} photos')),
        ),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          mainAxisSpacing: 14,
          crossAxisSpacing: 9,
          childAspectRatio: 108 / 92,
          children: [
            for (final (i, (p, x)) in d.galleryPhotos.indexed)
              Semantics(
                button: true,
                label: 'Photo ${i + 1}',
                child: GestureDetector(
                  onTap: () => setState(() => _main = p),
                  child: DPhoto(p, radius: 18, alignment: Alignment(x, 0)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        const DSectionTitle('Vidéo de présentation'),
        const SizedBox(height: 18),
        _VideoCard(cover: d.videoCover, title: d.videoTitle, meta: d.videoMeta),
      ],
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.cover, required this.title, required this.meta});

  final String cover;
  final String title;
  final String meta;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Lire la vidéo $title, $meta',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => context.toast('Lecture de la vidéo…'),
        child: SizedBox(
          height: 150,
          child: Stack(
            fit: StackFit.expand,
            children: [
              DPhoto(cover),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0x40000000)],
                    stops: [.35, 1],
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.h3.copyWith(fontSize: 17.5, color: Colors.white)),
                    const SizedBox(height: 5),
                    Text(meta, style: DTxt.meta.copyWith(color: const Color(0xE6FFFFFF), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
