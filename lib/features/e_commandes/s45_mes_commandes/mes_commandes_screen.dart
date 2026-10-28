import '../../common/common.dart';
import '../e_widgets.dart';

/// 45 · Mes commandes : recherche, filtres par statut, liste.
class MesCommandesScreen extends ConsumerStatefulWidget {
  const MesCommandesScreen({super.key});

  @override
  ConsumerState<MesCommandesScreen> createState() => _MesCommandesScreenState();
}

class _MesCommandesScreenState extends ConsumerState<MesCommandesScreen> {
  int _filter = 0;
  String _query = '';
  bool _oldestFirst = false;

  bool _matches(EOrder o) {
    final byStatus = switch (_filter) {
      1 => o.status != EOrderStatus.delivered && o.status != EOrderStatus.cancelled,
      2 => o.status == EOrderStatus.delivered,
      3 => o.status == EOrderStatus.cancelled,
      _ => true,
    };
    final q = _query.trim().toLowerCase().replaceAll('#', '');
    return byStatus && (q.isEmpty || o.ref.toLowerCase().contains(q) || o.date.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionEDataProvider);
    final list = d.orders.where(_matches).toList()
      ..sort((a, b) => _oldestFirst ? a.dateOrder.compareTo(b.dateOrder) : b.dateOrder.compareTo(a.dateOrder));
    final filtered = _filter != 0 || _query.trim().isNotEmpty;
    final count = filtered ? list.length : d.ordersCount;
    return EScaffold(
      title: 'Mes commandes',
      showNav: true,
      children: [
        const SizedBox(height: 2),
        ESearchField(
          hint: 'Rechercher une commande',
          onChanged: (v) => setState(() => _query = v),
          onFilter: () => context.toast('Filtrez par statut avec les pastilles ci-dessous.'),
        ),
        const SizedBox(height: 9),
        SizedBox(
          height: 44,
          child: LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: c.maxWidth),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final (i, f) in d.orderFilters.indexed) ...[
                      if (i > 0) const SizedBox(width: 8),
                      _Chip(label: f, selected: i == _filter, onTap: () => setState(() => _filter = i)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -2.5),
          child: SizedBox(
            height: 44,
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    liveRegion: true,
                    child: Text('$count commande${count > 1 ? 's' : ''}', style: ETxt.section),
                  ),
                ),
                Semantics(
                  button: true,
                  label: _oldestFirst ? 'Trier : plus anciennes d’abord' : 'Trier : plus récentes d’abord',
                  excludeSemantics: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _oldestFirst = !_oldestFirst),
                    child: SizedBox(
                      height: 44,
                      child: Row(
                        children: [
                          Text('Trier', style: ETxt.body.copyWith(fontSize: 11.8, color: AppColors.accent)),
                          const SizedBox(width: 6),
                          const AppIcon(AppIcons.arrowRight, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 3),
        if (list.isEmpty)
          ECard(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            child: Column(
              children: [
                const ETile(AppIcons.package2, size: 48, iconSize: 24),
                gap12,
                Text('Aucune commande trouvée', style: ETxt.cardTitle, textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text('Essayez un autre filtre ou une autre référence.', style: ETxt.body, textAlign: TextAlign.center),
              ],
            ),
          )
        else
          ECard(
            child: Column(
              children: [
                for (final (i, o) in list.indexed) ...[
                  if (i > 0) const EDivider(indent: 98.5, endIndent: 12),
                  Semantics(
                    label: 'Commande ${o.ref}, ${o.date}, ${fcfa(o.amount)}, ${EStatusBadge.labelOf(o.status)}',
                    button: true,
                    excludeSemantics: true,
                    child: ERow(
                      height: i == 0 ? 66 : 65,
                      leading: EThumb(o.image),
                      title: o.ref,
                      titleStyle: ETxt.itemRegular,
                      subtitle: '${o.date} · ${fcfa(o.amount)}',
                      trailing: EStatusBadge(o.status),
                      onTap: () => context.openScreen(o.status == EOrderStatus.cancelled ? '48' : '46'),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Container(
            height: 33,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: ShapeDecoration(color: selected ? AppColors.ink : EColors.soft, shape: const StadiumBorder()),
            child: Text(
              label,
              style: ETxt.body.copyWith(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
