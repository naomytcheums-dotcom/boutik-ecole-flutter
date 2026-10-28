import '../ad_widgets.dart';

/// 220 · Duel de talents (vote entre deux projets, classement de la semaine).
class DuelTalentsScreen extends ConsumerStatefulWidget {
  const DuelTalentsScreen({super.key});

  @override
  ConsumerState<DuelTalentsScreen> createState() => _DuelTalentsScreenState();
}

class _DuelTalentsScreenState extends ConsumerState<DuelTalentsScreen> {
  int? _vote;

  static const _orange = Color(0xFFE5732A);

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionADDataProvider);
    final votes = [for (final (i, p) in d.duelists.indexed) p.$5 + (_vote == i ? 1 : 0)];
    final total = votes[0] + votes[1];
    final pct = [(votes[0] * 100 / total).round(), 100 - (votes[0] * 100 / total).round()];
    return AdPage(
      showNav: true,
      header: const AdCenterHeader('Duel de talents'),
      children: [
        Center(
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const ShapeDecoration(color: AppColors.ink, shape: StadiumBorder()),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppIcon(AppIcons.clock, size: 15, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  d.duelRemaining,
                  style: AppText.label.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, c) => SizedBox(
            height: 250,
            child: OverflowBox(
              maxWidth: c.maxWidth + 17,
              minWidth: c.maxWidth + 17,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(child: _photo(d.duelists[0].$4, d.duelists[0].$1)),
                      const SizedBox(width: 15),
                      Expanded(child: _photo(d.duelists[1].$4, d.duelists[1].$1, Alignment.centerLeft)),
                    ],
                  ),
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.ink,
                      border: Border.all(color: Colors.white, width: 2.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'VS',
                      style: AppText.label.copyWith(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (final (i, p) in d.duelists.indexed) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: AdCard(
                  radius: 22,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AdAvatar(p.$3, size: 32),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.$1,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.label.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  p.$2,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.small.copyWith(fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              '${pct[i]} %',
                              style: AppText.h2.copyWith(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                                color: i == 0 ? AppColors.accent : _orange,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '${fcfa(votes[i], withUnit: false)} votes',
                              style: AppText.small.copyWith(fontSize: 11, color: const Color(0xFF4A4752)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Semantics(
          label: 'Répartition des votes : ${pct[0]} % contre ${pct[1]} %',
          excludeSemantics: true,
          child: SizedBox(
            height: 14,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: pct[0],
                  child: const DecoratedBox(
                    decoration: ShapeDecoration(color: AppColors.ink, shape: StadiumBorder()),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  flex: pct[1],
                  child: const DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: StadiumBorder(),
                      gradient: LinearGradient(colors: [Color(0xFFFFB46B), Color(0xFFFF7C1D)]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            for (final (i, p) in d.duelists.indexed) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: _VoteButton(
                  label: _vote == i ? 'Vote enregistré' : p.$6,
                  dark: i == 0,
                  onTap: _vote != null
                      ? null
                      : () {
                          setState(() => _vote = i);
                          context.toast('Merci ! Votre vote pour « ${p.$1} » est enregistré.');
                        },
                ),
              ),
            ],
          ],
        ),
        const AdSectionTitle('Classement de la semaine', top: 22, bottom: 8),
        Row(
          children: [
            for (final (i, r) in d.weeklyRanking.indexed) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Semantics(
                  label: '${i + 1}e : ${r.$1}, ${r.$3}',
                  excludeSemantics: true,
                  child: AdCard(
                    radius: 20,
                    padding: const EdgeInsets.fromLTRB(10, 6, 12, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AdAvatar(r.$2, size: 30),
                            const Spacer(),
                            Text(
                              '${i + 1}',
                              style: AppText.bodyStrong.copyWith(
                                color: AppColors.accent,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(r.$1, style: AppText.label.copyWith(fontSize: 12)),
                        Text(r.$3, style: AppText.small.copyWith(fontSize: 11, height: 1.1)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _photo(String image, String label, [Alignment alignment = Alignment.center]) => Semantics(
    image: true,
    label: label,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: Image.asset(image, height: 250, fit: BoxFit.cover, alignment: alignment, excludeFromSemantics: true),
    ),
  );
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({required this.label, required this.dark, required this.onTap});

  final String label;
  final bool dark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    child: Material(
      color: dark ? AppColors.ink : Colors.white,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Center(
            child: Text(
              label,
              style: AppText.label.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: dark ? Colors.white : AppColors.ink,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
