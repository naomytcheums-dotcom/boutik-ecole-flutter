import '../m_widgets.dart';

/// 118 · Établissement et identité visuelle.
class EtablissementScreen extends ConsumerWidget {
  const EtablissementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionMDataProvider);
    return MAdminShell(
      title: 'Établissement et identité visuelle',
      selected: 1,
      children: [
        OpsSplit(
          left: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OpsKvCard(title: 'Informations de l’établissement', rows: d.institutionInfo),
              gap16,
              OpsCard(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  children: [
                    for (final (i, f) in d.brandFiles.indexed) ...[
                      if (i > 0) const Divider(height: 1, color: AppColors.cardBorder),
                      IIconRow(
                        icon: AppIcons.image,
                        title: f.$1,
                        subtitle: f.$2,
                        trailing: OpsBadge('Modifier', tone: OpsTone.info, onTap: () => context.openScreen('279')),
                      ),
                    ],
                  ],
                ),
              ),
              gap16,
              SizedBox(
                width: 300,
                child: OpsBigButton(
                  label: 'Enregistrer les modifications',
                  icon: AppIcons.check,
                  onTap: () => context.toast('Modifications enregistrées.'),
                ),
              ),
            ],
          ),
          right: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OpsKvCard(title: 'Identité visuelle', rows: d.visualIdentity),
              gap16,
              const OpsInfoNote(
                'Ces paramètres s’appliquent à l’espace de l’établissement ; ils restent configurables.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

