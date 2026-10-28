import '../../common/common.dart';
import '../s262_accueil_b2b/web_blocks.dart';

/// 263 · Médiathèque (images, vidéos, preuves, documents).
class MediathequeScreen extends ConsumerStatefulWidget {
  const MediathequeScreen({super.key});

  @override
  ConsumerState<MediathequeScreen> createState() => _MediathequeScreenState();
}

class _MediathequeScreenState extends ConsumerState<MediathequeScreen> {
  int _filter = 0;
  static const _filters = ['Tout', 'Images', 'Vidéos', 'Documents', 'Preuves'];

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(nouveauxDataProvider);
    final media = switch (_filter) {
      1 => d.media.where((m) => m.kind == 'Image').toList(),
      2 => d.media.where((m) => m.kind == 'Vidéo').toList(),
      0 => d.media,
      _ => <MediaItem>[],
    };
    return WebShell(
      title: 'Médiathèque',
      subtitle: 'Images, vidéos, preuves et documents des productions.',
      navItems: adminNav([
        ('Tableau de bord', AppIcons.layoutGrid, '117'),
        ('Catalogue', AppIcons.fileText, '288'),
        ('Médiathèque', AppIcons.image, '263'),
        ('Étudiants', AppIcons.userCheck, '120'),
      ]),
      selected: 2,
      children: [
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (i, f) in _filters.indexed) Pill(f, selected: i == _filter, onTap: () => setState(() => _filter = i)),
                ],
              ),
            ),
            PrimaryButton(label: 'Téléverser un média', expand: false, height: 46, onPressed: () => context.openScreen('279')),
          ],
        ),
        gap16,
        if (media.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Text('Aucun média dans cette catégorie.', style: AppText.secondary, textAlign: TextAlign.center),
          )
        else
          ResponsiveGrid(
            columns: 4,
            minItemWidth: 180,
            spacing: 16,
            children: [
              for (final m in media)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        PhotoTile(image: m.image, aspectRatio: 185 / 135, radius: 22, semanticLabel: m.name),
                        Positioned(
                          left: 8,
                          top: 8,
                          child: StatusBadge(m.public ? 'Public' : 'Privé', tone: m.public ? BadgeTone.success : BadgeTone.warning),
                        ),
                        Positioned(right: 8, top: 8, child: _WhiteBadge(m.kind)),
                      ],
                    ),
                    gap12,
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(m.name, style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text('Droits : établissement · ${m.public ? 'public' : 'privé'}', style: AppText.small),
                    ),
                    gap24,
                  ],
                ),
            ],
          ),
        gap16,
        Text(d.storage, style: AppText.small),
      ],
    );
  }
}

class _WhiteBadge extends StatelessWidget {
  const _WhiteBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: ShapeDecoration(color: Colors.white, shape: const StadiumBorder()),
    child: Text(label, style: AppText.small.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600)),
  );
}
