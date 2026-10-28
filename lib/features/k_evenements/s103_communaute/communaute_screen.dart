import '../k_widgets.dart';

/// 103 · Communauté (anciens, mentors, groupes).
class CommunauteScreen extends ConsumerStatefulWidget {
  const CommunauteScreen({super.key});

  @override
  ConsumerState<CommunauteScreen> createState() => _CommunauteScreenState();
}

class _CommunauteScreenState extends ConsumerState<CommunauteScreen> {
  int _tab = 0;
  final _connected = <String>{};

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionKDataProvider);
    return CPage(
      title: 'Communauté',
      trailing: cIcon(context, AppIcons.search, 'Rechercher', '21'),
      children: [
        GTabs(labels: d.communityTabs, selected: _tab, onSelected: (i) => setState(() => _tab = i)),
        gap8,
        GListCard(
          children: [
            for (final a in d.alumni)
              GThumbRow(
                image: a.$3,
                title: a.$1,
                subtitle: a.$2,
                onTap: () => context.openScreen('72'),
                trailing: a.$4 || _connected.contains(a.$1)
                    ? const GBadge('Connecté', Tone.success)
                    : KBadgeButton('Se connecter', Tone.accent, onTap: () => setState(() => _connected.add(a.$1))),
              ),
          ],
        ),
        gap16,
        KPromoBanner(
          title: 'Rejoignez un groupe',
          text: 'Échangez avec les anciens de votre filière.',
          button: 'Explorer',
          image: d.groupImage,
          onTap: () => setState(() => _tab = 2),
        ),
        const GSectionTitle('Groupes populaires'),
        GListCard(
          children: [
            for (final g in d.groups)
              IIconRow(
                icon: g.icon,
                title: g.title,
                subtitle: g.detail,
                trailing: const AppIcon(AppIcons.chevronRight, size: 18),
                onTap: () => context.openScreen('240'),
              ),
          ],
        ),
      ],
    );
  }
}
