import '../k_widgets.dart';

/// 100 · Événements (agenda de la semaine).
class EvenementsScreen extends ConsumerStatefulWidget {
  const EvenementsScreen({super.key});

  @override
  ConsumerState<EvenementsScreen> createState() => _EvenementsScreenState();
}

class _EvenementsScreenState extends ConsumerState<EvenementsScreen> {
  late int _day = ref.read(sectionKDataProvider).today;
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionKDataProvider);
    final items = _filter == 0 ? d.events : d.events.where((e) => e.target == d.eventFilters[_filter]).toList();
    return CPage(
      title: 'Événements',
      trailing: cIcon(context, AppIcons.search, 'Rechercher', '21'),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final (i, w) in d.week.indexed)
              Semantics(
                button: true,
                selected: i == _day,
                label: '${w.$1} ${w.$2}',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => setState(() => _day = i),
                  child: Container(
                    width: 42,
                    height: 56,
                    decoration: BoxDecoration(
                      color: i == _day ? AppColors.ink : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(w.$1, style: AppText.small.copyWith(color: i == _day ? Colors.white : AppColors.ink, fontSize: 11)),
                        Text(
                          '${w.$2}',
                          style: AppText.h3.copyWith(color: i == _day ? Colors.white : AppColors.ink, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        gap8,
        GTabs(labels: d.eventFilters, selected: _filter, onSelected: (i) => setState(() => _filter = i)),
        const GSectionTitle('Cette semaine'),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Aucun événement.', textAlign: TextAlign.center, style: AppText.secondary),
          )
        else
          GListCard(
            children: [
              for (final (i, e) in items.indexed)
                IIconRow(
                  icon: e.icon,
                  title: e.title,
                  subtitle: e.detail,
                  trailing: GBadge(e.badge, e.tone),
                  onTap: () => context.openScreen(i == 0 ? '101' : '160'),
                ),
            ],
          ),
        gap16,
        KPromoBanner(
          title: 'Salon des créations étudiantes',
          text: 'Réservez votre stand avant le 10 nov.',
          button: 'Réserver',
          image: d.salonImage,
          onTap: () => context.toast('Demande de stand envoyée.'),
        ),
      ],
    );
  }
}
