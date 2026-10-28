import '../k_widgets.dart';

/// 101 · Événement (fiche et programme).
class EvenementScreen extends ConsumerStatefulWidget {
  const EvenementScreen({super.key});

  @override
  ConsumerState<EvenementScreen> createState() => _EvenementScreenState();
}

class _EvenementScreenState extends ConsumerState<EvenementScreen> {
  bool _registered = false;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionKDataProvider);
    final seats = d.seatsLeft - (_registered ? 1 : 0);
    return GPage(
      title: 'Événement',
      trailing: HeaderIcon(AppIcons.share, label: 'Partager', onTap: () => context.openScreen('212')),
      actions: [
        PrimaryButton(
          label: _registered ? 'Inscription confirmée' : 'S’inscrire',
          height: 54,
          onPressed: _registered ? null : () => setState(() => _registered = true),
        ),
      ],
      children: [
        IHeroBanner(image: d.eventImage, title: d.eventTitle, subtitle: d.eventDetail, height: 190),
        gap16,
        GKpiGrid([
          GKpi('Date', d.eventDate, AppIcons.calendar),
          GKpi('Places restantes', '$seats / ${d.seatsTotal}', AppIcons.users),
        ], valueSize: 20),
        gap16,
        Text(d.eventPitch, style: AppText.body.copyWith(fontSize: 13.5, color: const Color(0xFF4A4752), height: 1.5)),
        const GSectionTitle('Programme'),
        IMilestones([for (final p in d.programme) IMilestone(p.$1, p.$2, p.$3)]),
      ],
    );
  }
}
