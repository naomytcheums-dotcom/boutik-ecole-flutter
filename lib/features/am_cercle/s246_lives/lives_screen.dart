import '../am_widgets.dart';

/// 246 · Lives : direct en cours et prochains lives avec rappel.
class LivesScreen extends ConsumerStatefulWidget {
  const LivesScreen({super.key});

  @override
  ConsumerState<LivesScreen> createState() => _LivesScreenState();
}

class _LivesScreenState extends ConsumerState<LivesScreen> {
  final _reminders = <String>{};

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionAMDataProvider);
    return AppScaffold(
      tab: NavTab.home,
      header: ScreenHeader(
        title: 'Lives',
        subtitle: 'Sans seuil d’abonnés',
        actions: [AmHeaderButton(AppIcons.bell, label: 'Notifications', onTap: () => context.openScreen('254'))],
      ),
      children: [
        Semantics(
          header: true,
          child: Text('En direct maintenant', style: AppText.h3.copyWith(fontWeight: FontWeight.w600)),
        ),
        gap12,
        AmPhoto(
          d.liveNowImage,
          height: 196,
          children: [
            const DecoratedBox(decoration: BoxDecoration(color: Color(0x1F000000))),
            Positioned(
              left: 16,
              top: 10,
              child: Container(
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: const ShapeDecoration(color: amLive, shape: StadiumBorder()),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'EN DIRECT',
                      style: AppText.small.copyWith(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(right: 16, top: 10, child: AmDarkTag(d.liveNowViewers)),
            Center(child: AmPlayButton(size: 48, onTap: () => context.openScreen('245'))),
          ],
        ),
        gap12,
        Row(
          children: [
            Avatar(image: d.liveNowAvatar, size: 40),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.liveNowTitle, style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w600)),
                  Text(d.liveNowAuthor, style: AppText.small.copyWith(fontSize: 11)),
                ],
              ),
            ),
            AmChip('Regarder', dark: true, height: 26, onTap: () => context.openScreen('245')),
          ],
        ),
        const SizedBox(height: 22),
        Semantics(
          header: true,
          child: Text('Prochains lives', style: AppText.h3.copyWith(fontWeight: FontWeight.w600)),
        ),
        gap12,
        for (final l in d.upcomingLives) ...[
          _UpcomingLive(
            live: l,
            reminded: _reminders.contains(l.title),
            onRemind: () => setState(() {
              _reminders.contains(l.title) ? _reminders.remove(l.title) : _reminders.add(l.title);
            }),
          ),
          gap12,
        ],
      ],
    );
  }
}

class _UpcomingLive extends StatelessWidget {
  const _UpcomingLive({required this.live, required this.reminded, required this.onRemind});

  final AmLive live;
  final bool reminded;
  final VoidCallback onRemind;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 80,
    child: Row(
      children: [
        AmCard(
          radius: 20,
          padding: EdgeInsets.zero,
          child: SizedBox(
            width: 64,
            height: 76,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(live.day, style: AppText.small.copyWith(fontSize: 11)),
                Text(live.date, style: AppText.h2.copyWith(fontSize: 22, fontWeight: FontWeight.w800, height: 1.15)),
                Text(live.month, style: AppText.small.copyWith(fontSize: 11)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        AmPhoto(live.image, width: 76, height: 76, radius: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                live.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodyStrong.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(child: Text(live.author, style: AppText.small.copyWith(fontSize: 11))),
                  AmChip(reminded ? 'Rappel activé ✓' : 'Me rappeler', height: 26, fontSize: 11, onTap: onRemind),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
