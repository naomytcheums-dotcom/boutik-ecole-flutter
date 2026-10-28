import '../../common/common.dart';

/// 277 · Supervision des bornes (vue administrateur).
class SupervisionBornesScreen extends ConsumerWidget {
  const SupervisionBornesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kiosks = ref.watch(nouveauxDataProvider).kiosks;
    return DetailScreen(
      title: 'Supervision des bornes',
      subtitle: 'Vue administrateur · ${kiosks.length} bornes',
      action: 'Voir les journaux d’incidents',
      onAction: () => context.openScreen('147-1'),
      children: [
        const HeroMessage(icon: AppIcons.activity, iconSize: 56),
        gap16,
        for (final k in kiosks) ...[
          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusDot(switch (k.tone) {
                      Tone.success => const Color(0xFF22B573),
                      Tone.error => const Color(0xFFE5392D),
                      _ => const Color(0xFFF59E2E),
                    }),
                    const SizedBox(width: 10),
                    Expanded(child: Text(k.title, style: AppText.bodyStrong)),
                    Text(k.status, style: AppText.label.copyWith(color: toneToColor(k.tone))),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Text(k.detail, style: AppText.small),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final (i, a) in ['Redémarrer', 'Journal', 'Activer le secours'].indexed) ...[
                        if (i > 0) Text(' · ', style: AppText.small),
                        TextLink(a, onTap: () => context.toast('$a : ${k.title}')),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          gap12,
        ],
      ],
    );
  }
}
