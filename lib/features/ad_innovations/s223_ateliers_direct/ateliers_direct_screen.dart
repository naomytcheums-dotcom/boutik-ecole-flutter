import '../ad_widgets.dart';

/// 223 · Ateliers en direct (direct en cours, ateliers à venir, rappels).
class AteliersDirectScreen extends ConsumerStatefulWidget {
  const AteliersDirectScreen({super.key});

  @override
  ConsumerState<AteliersDirectScreen> createState() => _AteliersDirectScreenState();
}

class _AteliersDirectScreenState extends ConsumerState<AteliersDirectScreen> {
  int _filter = 0;
  final _reminders = <String>{};

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionADDataProvider);
    final items = _filter == 2 ? d.upcomingLives.where((l) => _reminders.contains(l.$1)).toList() : d.upcomingLives;
    return AdPage(
      showNav: true,
      header: AdRootHeader(
        'Ateliers en direct',
        action: adHeaderIcon(context, AppIcons.bell, 'Notifications', () => context.openScreen('50')),
      ),
      children: [
        AdHero(
          image: d.liveNow.$3,
          title: d.liveNow.$1,
          subtitle: d.liveNow.$2,
          titleSize: 18,
          onTap: () => context.openScreen('222'),
        ),
        const SizedBox(height: 10),
        AdPills(
          labels: d.liveFilters,
          selected: _filter,
          onSelected: (i) => setState(() => _filter = i),
          unselectedColor: adLavender,
        ),
        const AdSectionTitle('À venir', top: 8, bottom: 18),
        if (items.isEmpty)
          AdCard(
            child: Text(
              'Aucun rappel pour le moment. Touchez « Rappel » sur un atelier pour être prévenu.',
              textAlign: TextAlign.center,
              style: AppText.secondary,
            ),
          )
        else
          AdCard(
            padding: const EdgeInsets.fromLTRB(12, 0, 14, 0),
            child: Column(
              children: [
                for (final (i, l) in items.indexed) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.only(left: 62),
                      child: Divider(height: 1, color: Color(0xFFEDEBF0)),
                    ),
                  SizedBox(
                    height: 66,
                    child: Row(
                      children: [
                        AdThumb(l.$3, size: 50, radius: 12),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.$1,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.body.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(l.$2, style: AppText.small.copyWith(fontSize: 12)),
                            ],
                          ),
                        ),
                        _ReminderButton(
                          on: _reminders.contains(l.$1),
                          onTap: () => setState(() {
                            if (!_reminders.remove(l.$1)) _reminders.add(l.$1);
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _ReminderButton extends StatelessWidget {
  const _ReminderButton({required this.on, required this.onTap});

  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    toggled: on,
    label: on ? 'Rappel activé' : 'Activer le rappel',
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 44,
        child: Center(child: GBadge(on ? 'Activé' : 'Rappel', on ? Tone.success : Tone.accent)),
      ),
    ),
  );
}
