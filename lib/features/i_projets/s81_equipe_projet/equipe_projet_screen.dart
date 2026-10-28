import '../i_widgets.dart';

/// 81 · Équipe du projet.
class EquipeProjetScreen extends ConsumerWidget {
  const EquipeProjetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionIDataProvider);
    return AppScaffold(
      showNav: false,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      header: CHeader(
        'Équipe du projet',
        trailing: HeaderIcon(AppIcons.plus, label: 'Inviter un membre', onTap: () => context.toast('Invitation envoyée.')),
      ),
      children: [
        GListCard(
          children: [
            for (final m in d.team)
              GThumbRow(
                image: m.avatar,
                title: m.name,
                subtitle: m.detail,
                trailing: GBadge(m.role!, m.tone),
                onTap: () => context.openScreen('10'),
              ),
          ],
        ),
        const GSectionTitle('Répartition des responsabilités'),
        IProgressCard([for (final r in d.responsibilities) (r.$1, '${r.$2}%', r.$2 / 100, r.$3)]),
        gap16,
        const GNote('Chaque membre peut modifier uniquement les étapes qui lui sont attribuées.', icon: AppIcons.lock),
      ],
    );
  }
}
