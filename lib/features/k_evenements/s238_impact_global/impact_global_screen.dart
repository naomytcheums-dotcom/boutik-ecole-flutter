import '../k_widgets.dart';

/// 238 · Impact de Boutik-École (vue publique mobile).
class ImpactGlobalScreen extends ConsumerWidget {
  const ImpactGlobalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionKDataProvider);
    return AppScaffold(
      tab: NavTab.home,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      header: const GRootHeader('Impact de Boutik-École'),
      children: [
        IHeroBanner(
          image: d.globalImage,
          title: 'Ensemble, nous faisons grandir le Cameroun',
          subtitle: 'Données mises à jour en temps réel',
          height: 160,
          onTap: () => context.openScreen('237'),
        ),
        gap16,
        ICounters(d.globalCounters),
        const GSectionTitle('Par région'),
        IProgressCard([for (final r in d.regions) (r.$1, '${r.$2} %', r.$2 / 100, r.$3)]),
        gap16,
        const GNote(
          'Chaque achat et chaque mission financent directement des étudiants et des projets de leur région.',
          icon: AppIcons.leaf,
        ),
      ],
    );
  }
}
