import '../t_widgets.dart';

/// 160 · Hackathons et concours.
class HackathonsScreen extends ConsumerStatefulWidget {
  const HackathonsScreen({super.key});

  @override
  ConsumerState<HackathonsScreen> createState() => _HackathonsScreenState();
}

class _HackathonsScreenState extends ConsumerState<HackathonsScreen> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionTDataProvider);
    final f = d.filters[_filter];
    final items = d.contests.where((c) {
      return switch (_filter) {
        0 => true,
        4 => false,
        _ => c.$6 == f,
      };
    }).toList();
    return CPage(
      title: 'Hackathons et concours',
      tab: NavTab.home,
      trailing: cIcon(context, AppIcons.search, 'Rechercher', '21'),
      children: [
        GTabs(labels: d.filters, selected: _filter, onSelected: (i) => setState(() => _filter = i)),
        gap12,
        IHeroBanner(
          image: d.featured.$3,
          title: d.featured.$1,
          subtitle: d.featured.$2,
          onTap: () => context.openScreen('161'),
        ),
        GSectionTitle('Prochains concours', trailing: TextLink('Voir tout →', onTap: () => setState(() => _filter = 0))),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Aucun concours pour ce filtre.', textAlign: TextAlign.center, style: AppText.secondary),
          )
        else
          QCard(
            children: [
              for (final c in items)
                QRow(
                  icon: c.$1,
                  title: c.$2,
                  subtitle: c.$3,
                  trailing: GBadge(c.$4, c.$5),
                  onTap: () => context.openScreen('161'),
                ),
            ],
          ),
        gap16,
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(colors: [Color(0xFF1B2D5A), Color(0xFF244884)]),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pas encore d’équipe ?', style: AppText.h3.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
              gap16,
              Text(
                'Trouvez des coéquipiers dans l’annuaire des talents.',
                style: AppText.small.copyWith(color: Colors.white, fontSize: 11.5),
              ),
              gap8,
              Semantics(
                button: true,
                child: GestureDetector(
                  onTap: () => context.openScreen('163'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    decoration: const ShapeDecoration(color: AppColors.ink, shape: StadiumBorder()),
                    child: Text('Trouver une équipe', style: AppText.label.copyWith(color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
