import '../t_widgets.dart';

/// 161 · Fiche d’un hackathon.
class HackathonScreen extends ConsumerStatefulWidget {
  const HackathonScreen({super.key});

  @override
  ConsumerState<HackathonScreen> createState() => _HackathonScreenState();
}

class _HackathonScreenState extends ConsumerState<HackathonScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionTDataProvider);
    return GPage(
      title: 'Hackathon',
      trailing: HeaderIcon(AppIcons.share, label: 'Partager', onTap: () => context.openScreen('212')),
      actions: [
        GOutlineButton('Partager', onPressed: () => context.openScreen('212')),
        PrimaryButton(label: 'S’inscrire', height: 54, onPressed: () => context.openScreen('162')),
      ],
      children: [
        IHeroBanner(image: d.challenge.$3, title: d.challenge.$1, subtitle: d.challenge.$2, height: 176),
        gap12,
        ICounters(d.challengeCounters),
        gap8,
        Row(
          children: [
            for (final (i, t) in d.challengeTabs.indexed)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == _tab,
                  child: InkWell(
                    onTap: () => setState(() => _tab = i),
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: i == _tab ? AppColors.accent : Colors.transparent, width: 2),
                        ),
                      ),
                      child: Text(
                        t,
                        style: AppText.small.copyWith(
                          fontSize: 11.5,
                          color: i == _tab ? AppColors.ink : AppColors.textSecondary,
                          fontWeight: i == _tab ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        gap12,
        Text(d.challengeAbout, style: AppText.small.copyWith(fontSize: 12.5, height: 1.5)),
        const GSectionTitle('Calendrier'),
        IMilestones([for (final c in d.calendar) IMilestone(c.$1, c.$2, c.$3)]),
      ],
    );
  }
}
