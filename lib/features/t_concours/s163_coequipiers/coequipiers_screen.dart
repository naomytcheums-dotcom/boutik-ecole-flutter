import '../../k_evenements/k_widgets.dart' show KBadgeButton;
import '../t_widgets.dart';

/// 163 · Trouver des coéquipiers.
class CoequipiersScreen extends ConsumerStatefulWidget {
  const CoequipiersScreen({super.key});

  @override
  ConsumerState<CoequipiersScreen> createState() => _CoequipiersScreenState();
}

class _CoequipiersScreenState extends ConsumerState<CoequipiersScreen> {
  int _filter = 0;
  final _invited = <String>{};

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionTDataProvider);
    return CPage(
      title: 'Trouver des coéquipiers',
      tab: NavTab.home,
      showNav: false,
      children: [
        const SearchField(hint: 'Compétence, filière, nom…'),
        gap8,
        GTabs(labels: d.skillFilters, selected: _filter, onSelected: (i) => setState(() => _filter = i)),
        gap8,
        Text('${d.teammatesCount} talents disponibles', style: AppText.bodyStrong),
        gap8,
        GListCard(
          children: [
            for (final t in d.teammates)
              GThumbRow(
                image: t.$3,
                title: t.$1,
                subtitle: t.$2,
                onTap: () => context.openScreen('10'),
                trailing: t.$4 || _invited.contains(t.$1)
                    ? const GBadge('Invité', Tone.neutral)
                    : KBadgeButton('Inviter', Tone.accent, onTap: () => setState(() => _invited.add(t.$1))),
              ),
          ],
        ),
        gap12,
        const GNote(
          'Les invitations sont envoyées par notification, SMS ou WhatsApp selon les préférences du talent.',
          icon: AppIcons.bell,
        ),
      ],
    );
  }
}
