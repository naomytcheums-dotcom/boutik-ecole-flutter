import '../h_widgets.dart';

/// 75 · Opportunités (stages, emplois, défis, missions).
class OpportunitesScreen extends ConsumerStatefulWidget {
  const OpportunitesScreen({super.key});

  @override
  ConsumerState<OpportunitesScreen> createState() => _OpportunitesScreenState();
}

class _OpportunitesScreenState extends ConsumerState<OpportunitesScreen> {
  int _tab = 0;
  final _applied = <String>{};

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionHDataProvider);
    final items = d.offers.where((o) => o.type == d.offerTabs[_tab]).toList();
    final count = _tab == 0 ? d.offersAvailable : items.length;
    return AppScaffold(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      header: HHeader(
        'Opportunités',
        trailing: HHeaderAction(
          AppIcons.funnel,
          label: 'Filtrer',
          onTap: () => context.toast('Filtres : ville, durée, rémunération.'),
        ),
      ),
      children: [
        HChips(labels: d.offerTabs, selected: _tab, onSelected: (i) => setState(() => _tab = i)),
        HCountTitle('$count offre${count > 1 ? 's' : ''} disponible${count > 1 ? 's' : ''}'),
        if (items.isEmpty)
          const HEmpty('Aucune offre pour le moment.')
        else
          HListCard(
            indent: 52,
            children: [
              for (final o in items)
                HRow(
                  leading: const HIconTile(AppIcons.briefcase),
                  title: o.title,
                  subtitle: '${o.company} · ${o.city} · ${o.duration}',
                  trailing: o.applied || _applied.contains(o.title)
                      ? const HBadge('Postulé', HBadgeKind.success)
                      : Semantics(
                          button: true,
                          label: 'Postuler : ${o.title}',
                          excludeSemantics: true,
                          child: GestureDetector(
                            onTap: () => setState(() => _applied.add(o.title)),
                            child: const SizedBox(
                              height: 44,
                              child: Center(child: HBadge('Postuler', HBadgeKind.accent)),
                            ),
                          ),
                        ),
                  onTap: () => context.openScreen('76'),
                ),
            ],
          ),
        gap16,
        _ProfileBanner(image: d.profileBannerImage),
      ],
    );
  }
}

class _ProfileBanner extends StatelessWidget {
  const _ProfileBanner({required this.image});

  final String image;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 132,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(colors: [Color(0xFF0F2E4F), Color(0xFF1B3D66)]),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 8, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text('Profil à compléter', style: AppText.h3.copyWith(color: Colors.white, fontSize: 16)),
                  ),
                  const Spacer(),
                  Text(
                    'Un profil complet reçoit 3× plus de réponses.',
                    style: AppText.small.copyWith(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w400),
                  ),
                  const SizedBox(height: 4),
                  Semantics(
                    button: true,
                    child: GestureDetector(
                      onTap: () => context.openScreen('72'),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 28,
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                        decoration: const ShapeDecoration(color: AppColors.ink, shape: StadiumBorder()),
                        child: Text(
                          'Compléter',
                          style: AppText.small.copyWith(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.asset(image, width: 144, height: 132, fit: BoxFit.cover),
          ),
        ],
      ),
    );
  }
}
