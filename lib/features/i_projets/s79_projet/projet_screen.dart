import '../i_widgets.dart';

/// 79 · Projet (fiche d’un projet innovant).
class ProjetScreen extends ConsumerWidget {
  const ProjetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionIDataProvider);
    return GPage(
      title: 'Projet',
      trailing: HeaderIcon(AppIcons.share, label: 'Partager', onTap: () => context.openScreen('212')),
      actions: [PrimaryButton(label: 'Soutenir le projet', height: 54, onPressed: () => context.openScreen('84b'))],
      children: [
        IHeroBanner(image: d.projectImage, title: d.projectTitle, subtitle: d.projectDepartment, height: 180),
        gap16,
        ICounters(d.projectCounters),
        gap16,
        IProgressCard(d.projectProgress),
        gap24,
        Text(d.projectPitch, style: AppText.body.copyWith(fontSize: 13.5, color: const Color(0xFF4A4752), height: 1.5)),
        const GSectionTitle('Équipe'),
        GListCard(
          children: [
            for (final m in d.projectTeam)
              GThumbRow(
                image: m.avatar,
                title: m.name,
                subtitle: m.detail,
                thumb: 50,
                trailing: const AppIcon(AppIcons.chevronRight, size: 18),
                onTap: () => context.openScreen('81'),
              ),
          ],
        ),
      ],
    );
  }
}
