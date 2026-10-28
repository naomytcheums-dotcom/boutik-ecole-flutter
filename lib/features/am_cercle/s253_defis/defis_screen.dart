import '../am_widgets.dart';

/// 253 · Défis et récompenses : série quotidienne, récompense du jour, défis, badges.
/// 253b = même écran après « Récupérer » (série de 6 jours, récompense récupérée).
class DefisScreen extends ConsumerStatefulWidget {
  const DefisScreen({super.key, this.claimed = false});

  final bool claimed;

  @override
  ConsumerState<DefisScreen> createState() => _DefisScreenState();
}

class _DefisScreenState extends ConsumerState<DefisScreen> {
  late bool _claimed = widget.claimed;

  static const _days = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionAMDataProvider);
    final streak = d.streakDays + (_claimed ? 1 : 0);
    final white = AppText.small.copyWith(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w400);
    return AppScaffold(
      tab: NavTab.home,
      header: ScreenHeader(
        title: 'Défis et récompenses',
        subtitle: 'Reviens chaque jour',
        actions: [AmHeaderButton(AppIcons.trophy, label: 'Classement', onTap: () {})],
      ),
      children: [
        AmHeroCard(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Série de $streak jours',
                style: AppText.h1.copyWith(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 215,
                child: Text(
                  _claimed
                      ? 'Bravo ! Demain : ${streak + 1} jours et +1 boost 24 h'
                      : 'Reviens demain pour passer à ${streak + 1} jours : +1 boost 24 h',
                  style: white,
                ),
              ),
              const SizedBox(height: 22),
              Semantics(
                label: '$streak jours sur 7 validés cette semaine',
                excludeSemantics: true,
                child: Row(
                  children: [
                    for (var i = 0; i < _days.length; i++) ...[
                      if (i > 0) const SizedBox(width: 13),
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < streak ? Colors.white : const Color(0x33FFFFFF),
                        ),
                        child: i < streak
                            ? const AppIcon(AppIcons.check, size: 15)
                            : Text(_days[i], style: white.copyWith(fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        gap16,
        AmCard(
          padding: const EdgeInsets.fromLTRB(16, 18, 14, 18),
          child: Row(
            children: [
              AmPhoto(d.rewardImage, width: 56, height: 56, radius: 12),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Récompense du jour', style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('Un boost gratuit de 24 h sur ton prochain post', style: AppText.small.copyWith(fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _claimed
                  ? const AmChip('Récupérée ✓', tone: Tone.success, height: 26, fontSize: 12)
                  : AmChip(
                      'Récupérer',
                      dark: true,
                      height: 26,
                      fontSize: 12,
                      onTap: () => setState(() => _claimed = true),
                    ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text('Défis de la semaine', style: AppText.h3.copyWith(fontWeight: FontWeight.w600)),
              ),
            ),
            const AmChip('Se termine dans 3 j', height: 26, fontSize: 11),
          ],
        ),
        gap12,
        for (final (i, c) in d.challenges.indexed) ...[
          _ChallengeCard(c, done: _claimed && i == 0 ? c.total : c.done),
          gap8,
        ],
        gap12,
        Semantics(
          header: true,
          child: Text('Mes badges', style: AppText.h3.copyWith(fontWeight: FontWeight.w600)),
        ),
        gap8,
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (final b in d.badges)
              Semantics(
                label: 'Badge ${b.$1}${b.$2 ? '' : ', verrouillé'}',
                excludeSemantics: true,
                child: Column(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: !b.$2 ? const Color(0xFFE6E2EE) : (b.$3 ? const Color(0xFFF43F6B) : AppColors.ink),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: AppIcon(
                        b.$2 ? AppIcons.starFilled : AppIcons.lock,
                        size: 24,
                        color: b.$2 ? Colors.white : AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      b.$1,
                      style: AppText.small.copyWith(
                        color: b.$2 ? AppColors.ink : AppColors.textSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard(this.c, {required this.done});

  final AmChallenge c;
  final int done;

  @override
  Widget build(BuildContext context) => AmCard(
    radius: 24,
    padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: Color(0xFFEFEBFA), shape: BoxShape.circle),
          child: AppIcon(amIcon(c.icon), size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.title, style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(right: 24),
                child: Semantics(
                  label: 'Progression',
                  value: '$done sur ${c.total}',
                  child: AmProgress(done / c.total, height: 6),
                ),
              ),
              const SizedBox(height: 4),
              Text('$done / ${c.total}', style: AppText.small.copyWith(fontSize: 10.5)),
            ],
          ),
        ),
        AmChip('+ ${c.points} pts', tone: Tone.warning, height: 26, fontSize: 11),
      ],
    ),
  );
}
