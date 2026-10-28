import '../am_widgets.dart';

/// 244 · Cercle : stories, filtres et fil de publications. 244b = même écran, publication aimée.
class CercleScreen extends ConsumerStatefulWidget {
  const CercleScreen({super.key, this.liked = false});

  final bool liked;

  @override
  ConsumerState<CercleScreen> createState() => _CercleScreenState();
}

class _CercleScreenState extends ConsumerState<CercleScreen> {
  late bool _liked = widget.liked;
  int _filter = 0;
  int _page = 0;
  bool _following = false;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionAMDataProvider);
    final p = d.post;
    return AppScaffold(
      tab: NavTab.home,
      padding: EdgeInsets.zero,
      header: AmRootHeader(
        'Cercle',
        actions: [
          AmHeaderButton(AppIcons.plus, label: 'Créer', onTap: () => context.openScreen('249')),
          const SizedBox(width: 4),
          AmHeaderButton(AppIcons.bell, label: 'Activité', badge: true, onTap: () => context.openScreen('254')),
        ],
      ),
      children: [
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: d.stories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (_, i) => _Story(d.stories[i], first: i == 0),
          ),
        ),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              for (var i = 0; i < d.feedFilters.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Pill(d.feedFilters[i], dense: true, selected: i == _filter, onTap: () => setState(() => _filter = i)),
              ],
            ],
          ),
        ),
        gap8,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GestureDetector(
            onDoubleTap: () => setState(() => _liked = true),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                height: 290,
                child: Stack(
                  children: [
                    PageView(
                      onPageChanged: (i) => setState(() => _page = i),
                      children: [
                        for (final img in p.images)
                          Image.asset(img, fit: BoxFit.cover, semanticLabel: 'Photo de la publication'),
                      ],
                    ),
                    Positioned(left: 14, top: 14, child: AmChip(p.category, tone: Tone.neutral, height: 26)),
                    Positioned(right: 14, top: 14, child: AmDarkTag(p.type, color: const Color(0xCC45444B))),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 10,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < p.images.length; i++)
                            Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 2.5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == _page ? Colors.white : const Color(0x99FFFFFF),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Avatar(image: p.avatar, size: 40),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => context.openScreen('247'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(p.author, style: AppText.bodyStrong.copyWith(fontSize: 15)),
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
                          Text(p.meta, style: AppText.small.copyWith(fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                  AmChip(
                    _following ? 'Abonné' : 'S’abonner',
                    dark: !_following,
                    height: 26,
                    fontSize: 12,
                    onTap: () => setState(() => _following = !_following),
                  ),
                ],
              ),
              gap8,
              Text(
                p.text,
                style: AppText.body,
                maxLines: _expanded ? null : 2,
                overflow: _expanded ? null : TextOverflow.ellipsis,
              ),
              if (!_expanded)
                GestureDetector(
                  onTap: () => setState(() => _expanded = true),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('Voir plus', style: AppText.small),
                  ),
                ),
              Row(
                children: [
                  _Action(
                    icon: _liked ? AppIcons.heartFilled : AppIcons.heart,
                    count: '${p.likes + (_liked ? 1 : 0)}',
                    color: _liked ? amLive : AppColors.ink,
                    label: _liked ? 'Je n’aime plus' : 'J’aime',
                    onTap: () => setState(() => _liked = !_liked),
                  ),
                  _Action(
                    icon: AppIcons.messageCircle,
                    count: '${p.comments}',
                    label: 'Commentaires',
                    onTap: () => context.openScreen('252'),
                  ),
                  _Action(
                    icon: AppIcons.share,
                    count: '${p.shares}',
                    label: 'Partager',
                    onTap: () => context.openScreen('240'),
                  ),
                  const Spacer(),
                  AmChip(
                    'Voir l’article · ${fcfaF(p.price)}',
                    height: 26,
                    fontSize: 11.5,
                    onTap: () => context.openScreen('252'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Story extends StatelessWidget {
  const _Story(this.s, {this.first = false});

  final AmStory s;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final ring = switch (s.badge) {
      'LIVE' => const LinearGradient(colors: [Color(0xFFFF8A3D), amLive]),
      'BOOST' => const LinearGradient(colors: [AppColors.ink, AppColors.ink]),
      _ => const LinearGradient(colors: [Color(0xFFDCD6EA), Color(0xFFDCD6EA)]),
    };
    return Semantics(
      button: true,
      label: first ? 'Ajouter une story' : 'Story de ${s.name}${s.badge == 'LIVE' ? ', en direct' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => context.openScreen(first ? '249' : (s.badge == 'LIVE' ? '246' : '245')),
        child: SizedBox(
          width: 58,
          child: Column(
            children: [
              SizedBox(
                width: 58,
                height: 62,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(shape: BoxShape.circle, gradient: ring),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: Avatar(image: s.avatar, size: 48),
                      ),
                    ),
                    if (first)
                      Positioned(
                        right: -2,
                        bottom: 4,
                        child: Container(
                          width: 18,
                          height: 18,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.ink,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const AppIcon(AppIcons.plus, size: 11, color: Colors.white),
                        ),
                      ),
                    if (s.badge != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: s.badge == 'LIVE' ? amLive : AppColors.ink,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              s.badge!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 7.5,
                                fontWeight: FontWeight.w800,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                s.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.small.copyWith(color: AppColors.ink, fontSize: 10.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.count, required this.label, this.onTap, this.color = AppColors.ink});

  final String icon;
  final String count;
  final String label;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$label, $count',
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(icon, size: 22, color: color),
              const SizedBox(width: 6),
              Text(count, style: AppText.body.copyWith(color: color, fontSize: 13)),
            ],
          ),
        ),
      ),
    ),
  );
}
