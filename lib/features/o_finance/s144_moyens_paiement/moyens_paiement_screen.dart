import '../o_widgets.dart';

/// 144 · Moyens de paiement et règles financières.
class MoyensPaiementScreen extends ConsumerWidget {
  const MoyensPaiementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionODataProvider);
    return OFinanceShell(
      title: 'Moyens de paiement et règles',
      selected: 1,
      children: [
        OpsSplit(
          left: OpsCard(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              children: [
                for (final (i, m) in d.methods.indexed) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.cardBorder),
                  IIconRow(icon: m.$3, title: m.$1, subtitle: m.$2, trailing: OpsBadge(m.$4, tone: opsToneOf(m.$5))),
                ],
              ],
            ),
          ),
          right: OpsKvCard(title: 'Règles financières (modifiables)', rows: d.rules),
        ),
        gap16,
        const OpsInfoNote(
          'Ces règles restent configurables et doivent être confirmées avec l’IUT avant toute mise en production.',
        ),
      ],
    );
  }
}
