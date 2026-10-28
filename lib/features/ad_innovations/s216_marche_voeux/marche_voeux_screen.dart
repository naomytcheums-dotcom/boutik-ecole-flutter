import '../ad_widgets.dart';

/// 216 · Marché des vœux.
class MarcheVoeuxScreen extends ConsumerStatefulWidget {
  const MarcheVoeuxScreen({super.key});

  @override
  ConsumerState<MarcheVoeuxScreen> createState() => _MarcheVoeuxScreenState();
}

class _MarcheVoeuxScreenState extends ConsumerState<MarcheVoeuxScreen> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionADDataProvider);
    final items = d.wishes.where((w) {
      return switch (_filter) {
        1 => w.count / w.target >= .75,
        2 => w.tag == 'nouveau',
        3 => d.myPreorders.contains(w.title),
        _ => true,
      };
    }).toList();
    return AdPage(
      showNav: true,
      header: AdRootHeader(
        'Marché des vœux',
        action: adHeaderIcon(context, AppIcons.search, 'Rechercher un vœu', () => context.openScreen('21')),
      ),
      children: [
        AdNote(d.wishIntro, icon: AppIcons.sparkleFilled, padding: const EdgeInsets.fromLTRB(12, 14, 16, 14)),
        const SizedBox(height: 10),
        AdPills(
          labels: d.wishFilters,
          selected: _filter,
          onSelected: (i) => setState(() => _filter = i),
          unselectedColor: adLavender,
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Aucun vœu pour ce filtre.', textAlign: TextAlign.center, style: AppText.secondary),
          ),
        for (final w in items) ...[_WishCard(w), const SizedBox(height: 14)],
      ],
    );
  }
}

class _WishCard extends StatelessWidget {
  const _WishCard(this.w);

  final AdWish w;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${w.title}, ${w.count} sur ${w.target} précommandes, ${fcfa(w.price)}',
      child: GestureDetector(
        onTap: () => context.openScreen('217'),
        child: AdCard(
          padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
          child: Row(
            children: [
              AdThumb(w.image, size: 112, height: 118, radius: 14, alignment: const Alignment(-.5, 0)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      w.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyStrong.copyWith(fontSize: 15),
                    ),
                    Text(
                      'par ${w.author}',
                      style: AppText.small.copyWith(fontSize: 12, color: const Color(0xFF5E5B66)),
                    ),
                    const SizedBox(height: 9),
                    AdProgress(value: w.count / w.target),
                    const SizedBox(height: 5),
                    Text(
                      '${w.count} / ${w.target} précommandes',
                      style: AppText.small.copyWith(fontSize: 12, color: AppColors.ink),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            fcfa(w.price),
                            style: AppText.bodyStrong.copyWith(
                              fontSize: 15,
                              color: adAmber,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        AdChipButton(
                          'Précommander',
                          fontSize: 10.5,
                          padding: 6,
                          onTap: () => context.openScreen('217'),
                        ),
                      ],
                    ),
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
