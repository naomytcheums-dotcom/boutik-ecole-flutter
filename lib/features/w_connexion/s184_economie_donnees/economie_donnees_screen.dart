import '../w_widgets.dart';

/// 184 · Économie de données : le mode économie est global (partagé avec 150), les autres réglages sont locaux.
class EconomieDonneesScreen extends ConsumerStatefulWidget {
  const EconomieDonneesScreen({super.key});

  @override
  ConsumerState<EconomieDonneesScreen> createState() => _EconomieDonneesScreenState();
}

class _EconomieDonneesScreenState extends ConsumerState<EconomieDonneesScreen> {
  late final List<bool> _values = [for (final t in ref.read(sectionWDataProvider).dataToggles) t.value];

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionWDataProvider);
    final s = ref.watch(appSettingsProvider);
    return AppScaffold(
      showNav: false,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      header: const CHeader('Économie de données'),
      children: [
        QCard(
          children: [
            WToggleRow(
              title: 'Mode économie de données',
              subtitle: 'Charger moins d’images',
              value: s.lightMode,
              onChanged: ref.read(appSettingsProvider.notifier).setLightMode,
            ),
            for (var i = 0; i < d.dataToggles.length; i++)
              WToggleRow(
                title: d.dataToggles[i].title,
                subtitle: d.dataToggles[i].subtitle,
                value: _values[i],
                onChanged: (v) => setState(() => _values[i] = v),
              ),
          ],
        ),
        gap16,
        KeyValueCard(
          title: 'Consommation',
          rows: [KV('Données utilisées (30 j)', d.dataUsed), KV('Économisées grâce au mode', d.dataSaved)],
        ),
        gap16,
        const WInfoCard(
          icon: AppIcons.leaf,
          text: 'Le mode économie réduit la taille des images et reporte les contenus lourds.',
        ),
      ],
    );
  }
}
