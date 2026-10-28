import '../am_widgets.dart';

/// 247 · Profil créateur : identité, statistiques, réseaux et grille de publications.
class ProfilCreateurScreen extends ConsumerStatefulWidget {
  const ProfilCreateurScreen({super.key});

  @override
  ConsumerState<ProfilCreateurScreen> createState() => _ProfilCreateurScreenState();
}

class _ProfilCreateurScreenState extends ConsumerState<ProfilCreateurScreen> {
  int _tab = 0;
  bool _following = false;

  static const _tabs = [
    (AppIcons.layoutGrid, 'Publications'),
    (AppIcons.video, 'Reels'),
    (AppIcons.shoppingBag, 'Boutique'),
    (AppIcons.star, 'Avis'),
  ];

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionAMDataProvider);
    return AppScaffold(
      tab: NavTab.profile,
      header: ScreenHeader(
        title: d.creatorHandle,
        actions: [AmHeaderButton(AppIcons.ellipsisVertical, label: 'Plus d’options', onTap: () {})],
      ),
      children: [
        gap12,
        Row(
          children: [
            _LiveAvatar(d.creatorAvatar),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          d.creatorName,
                          style: AppText.h2.copyWith(fontSize: 20, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Semantics(
                        label: 'Compte vérifié',
                        child: Container(
                          width: 16,
                          height: 16,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: Color(0xFF2F80ED), shape: BoxShape.circle),
                          child: const AppIcon(AppIcons.check, size: 10, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  Text(d.creatorRole, style: AppText.small.copyWith(fontSize: 11.5)),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 6,
                    children: [
                      AmChip(
                        _following ? 'Abonné' : 'S’abonner',
                        dark: !_following,
                        tone: Tone.neutral,
                        height: 26,
                        onTap: () => setState(() => _following = !_following),
                      ),
                      AmChip('Écrire', tone: Tone.neutral, height: 26, onTap: () => context.openScreen('53')),
                      AmChip('Boutique', height: 26, onTap: () => context.openScreen('248')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        gap12,
        Text(d.creatorBio, style: AppText.secondary.copyWith(fontSize: 12.5)),
        gap12,
        AmCard(
          radius: 24,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              for (final s in d.creatorStats)
                Expanded(
                  child: Column(
                    children: [
                      Text(s.$1, style: AppText.h3.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(s.$2, style: AppText.small.copyWith(fontSize: 11)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        gap12,
        Row(
          children: [
            Text('Mes réseaux', style: AppText.small.copyWith(color: AppColors.ink)),
            const SizedBox(width: 12),
            for (final n in d.creatorNetworks) ...[
              AmNetworkLogo(n.$2, size: 26, radius: 6, label: n.$1),
              const SizedBox(width: 9),
            ],
          ],
        ),
        gap8,
        Row(
          children: [
            for (var i = 0; i < _tabs.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == _tab,
                  label: _tabs[i].$2,
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => i == 2 ? context.openScreen('248') : setState(() => _tab = i),
                    child: SizedBox(
                      height: 44,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AppIcon(_tabs[i].$1, size: 20),
                          const SizedBox(height: 8),
                          Container(
                            width: 28,
                            height: 2.5,
                            decoration: BoxDecoration(
                              color: i == _tab ? amViolet : Colors.transparent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const Divider(height: 1, color: AppColors.cardBorder),
        gap12,
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 112 / 100,
          children: [
            for (final g in (_tab == 1 ? d.creatorGrid.where((g) => g.$2 != null) : d.creatorGrid))
              AmPhoto(
                g.$1,
                radius: 4,
                children: [if (g.$2 != null) Positioned(left: 6, bottom: 6, child: AmDarkTag(g.$2!))],
              ),
          ],
        ),
      ],
    );
  }
}

class _LiveAvatar extends StatelessWidget {
  const _LiveAvatar(this.image);

  final String image;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Photo de profil, en direct',
    child: SizedBox(
      width: 88,
      height: 92,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 88,
            height: 88,
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(color: AppColors.ink, shape: BoxShape.circle),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Avatar(image: image, size: 78),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: BoxDecoration(color: amLive, borderRadius: BorderRadius.circular(8)),
                child: const Text(
                  'LIVE',
                  style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
