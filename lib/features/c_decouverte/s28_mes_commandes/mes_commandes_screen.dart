import '../c_widgets.dart';

/// 28 · Mes commandes (historique client).
class MesCommandesClientScreen extends ConsumerStatefulWidget {
  const MesCommandesClientScreen({super.key});

  @override
  ConsumerState<MesCommandesClientScreen> createState() => _MesCommandesClientScreenState();
}

class _MesCommandesClientScreenState extends ConsumerState<MesCommandesClientScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionCDataProvider);
    final status = [null, 'en_cours', 'livree', 'annulee'][_tab];
    final items = d.orders.where((o) => status == null || o.status == status).toList();
    return CPage(
      title: 'Mes commandes',
      tab: NavTab.profile,
      children: [
        GTabs(labels: d.orderTabs, selected: _tab, onSelected: (i) => setState(() => _tab = i)),
        gap12,
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text('Aucune commande.', textAlign: TextAlign.center, style: AppText.secondary),
          ),
        for (final o in items) ...[
          AppCard(
            onTap: () => context.openScreen('29'),
            padding: const EdgeInsets.fromLTRB(16, 18, 10, 18),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(o.image, width: 62, height: 62, fit: BoxFit.cover),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o.ref, style: AppText.bodyStrong.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      Text(
                        '${o.date}  •  ${fcfa(o.amount)}',
                        style: AppText.small.copyWith(fontSize: 11.5, color: AppColors.accent),
                      ),
                    ],
                  ),
                ),
                GBadge(cOrderStatus(o.status).$1, cOrderStatus(o.status).$2),
              ],
            ),
          ),
          gap16,
        ],
      ],
    );
  }
}
