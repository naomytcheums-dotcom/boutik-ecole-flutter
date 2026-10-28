import '../../k_evenements/k_widgets.dart' show KBadgeButton;
import '../t_widgets.dart';

/// 164 · Espace d’équipe (Team Innov’).
class EspaceEquipeScreen extends ConsumerWidget {
  const EspaceEquipeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionTDataProvider);
    return GPage(
      title: d.teamName,
      actions: [
        GOutlineButton('Discussion d’équipe', onPressed: () => context.openScreen('51')),
        PrimaryButton(label: 'Déposer le projet', height: 54, onPressed: () => context.openScreen('165')),
      ],
      children: [
        Text(d.teamSubtitle, style: AppText.small.copyWith(fontSize: 11.5)),
        gap8,
        GStepper(labels: d.teamSteps, current: 1),
        gap12,
        IProgressCard([for (final p in d.teamProgress) (p.$1, '${p.$2}%', p.$2 / 100, p.$3)]),
        const GSectionTitle('Tâches de l’équipe'),
        IMilestones([for (final t in d.tasks) IMilestone(t.$1, t.$2, t.$3)]),
        const GSectionTitle('Mentor'),
        AppCard(
          padding: const EdgeInsets.all(10),
          child: GThumbRow(
            image: d.mentor.$3,
            title: d.mentor.$1,
            subtitle: d.mentor.$2,
            trailing: KBadgeButton('Message', Tone.accent, onTap: () => context.openScreen('51')),
          ),
        ),
      ],
    );
  }
}
