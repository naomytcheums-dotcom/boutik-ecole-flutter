import '../../common/common.dart';
import '../../../data/demo/section_n_demo.dart';
import '../n_widgets.dart';

/// 135 · Commissions et règles économiques (règles configurables, à confirmer avec l'IUT).
class CommissionsScreen extends ConsumerWidget {
  const CommissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionNDataProvider);
    return NAdminShell(
      title: 'Commissions et règles économiques',
      selected: 8,
      children: [
        OpsSplit(
          left: OpsKvCard(
            title: 'Règles actuelles (modifiables)',
            rows: [...d.commissionRules, ('Seuil de paiement vendeur', fcfa(d.sellerPayoutThreshold))],
          ),
          right: OpsSettingsCard(
            items: [
              (
                AppIcons.percent,
                'Modifier les commissions',
                'Effet à la prochaine période',
                OpsBadge(
                  'Modifier',
                  tone: OpsTone.info,
                  onTap: () => context.toast('Modification soumise à double validation (démonstration).'),
                ),
              ),
              (
                AppIcons.history,
                'Historique des changements',
                'Dernier : ${d.lastCommissionChange}',
                OpsBadge('Voir', tone: OpsTone.neutral, onTap: () => context.openScreen('137')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        OpsInfoNote(d.commissionNote),
      ],
    );
  }
}
