import '../v_widgets.dart';

/// 179 · Guide d'utilisation.
class GuideScreen extends ConsumerStatefulWidget {
  const GuideScreen({super.key});

  @override
  ConsumerState<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends ConsumerState<GuideScreen> {
  int _tab = 0;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionVDataProvider);
    final q = _query.trim().toLowerCase();
    final items = d.guides.where((g) {
      final inTab = _tab == 0 || g.$4 == d.guideTabs[_tab];
      return inTab && (q.isEmpty || g.$2.toLowerCase().contains(q));
    }).toList();
    return CPage(
      title: 'Guide d’utilisation',
      tab: NavTab.home,
      children: [
        SearchField(hint: 'Rechercher dans le guide', showFilter: false, onChanged: (v) => setState(() => _query = v)),
        gap12,
        GTabs(labels: d.guideTabs, selected: _tab, onSelected: (i) => setState(() => _tab = i)),
        gap12,
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Aucun guide ne correspond à votre recherche.',
              textAlign: TextAlign.center,
              style: AppText.secondary,
            ),
          )
        else
          QCard(
            children: [
              for (final g in items)
                QRow(
                  icon: g.$1,
                  title: g.$2,
                  subtitle: g.$3,
                  trailing: g.$5 ? const GBadge('Vidéo', Tone.accent) : const AppIcon(AppIcons.chevronRight, size: 18),
                  onTap: () => g.$6.isEmpty ? context.toast('Lecture de la vidéo…') : context.openScreen(g.$6),
                ),
            ],
          ),
        gap16,
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Container(
            height: 140,
            color: const Color(0xFF1B3A6B),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 8, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Besoin d’un coup de main ?',
                          style: AppText.bodyStrong.copyWith(color: Colors.white, fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        Text('Visite guidée de l’application.', style: AppText.small.copyWith(color: Colors.white)),
                        const Spacer(),
                        Semantics(
                          button: true,
                          child: GestureDetector(
                            onTap: () => context.openScreen('01'),
                            child: Container(
                              height: 30,
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              alignment: Alignment.center,
                              decoration: const ShapeDecoration(color: AppColors.ink, shape: StadiumBorder()),
                              child: Text('Lancer la visite', style: AppText.label.copyWith(color: Colors.white)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 150, height: 140, child: Image.asset(d.guideImage, fit: BoxFit.cover)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
