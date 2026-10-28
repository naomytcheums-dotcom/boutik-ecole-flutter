import '../../common/common.dart';

/// 261 · Mon espace client (accueil client).
class EspaceClientScreen extends ConsumerWidget {
  const EspaceClientScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(nouveauxDataProvider);
    const icons = [AppIcons.shoppingCart, AppIcons.fileText, AppIcons.heart];
    return AppScaffold(
      tab: NavTab.home,
      background: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.bgTop, Color(0xFFFBEFD9), Color(0xFFFCE6B8)],
      ),
      children: [
        gap16,
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bonjour ${d.clientName}', style: AppText.secondary),
                  const SizedBox(height: 4),
                  Semantics(header: true, child: Text('Mon espace client', style: AppText.h1.copyWith(fontWeight: FontWeight.w700))),
                ],
              ),
            ),
            const Avatar(image: Photos.avatarWoman, size: 46),
          ],
        ),
        gap16,
        Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF241C4E), Color(0xFF5A3FE0)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${d.clientOrdersInProgress} commandes en cours',
                style: AppText.h1.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 22),
              ),
              const SizedBox(height: 6),
              Text(d.clientSummary, style: AppText.small.copyWith(color: Colors.white.withValues(alpha: .85))),
              gap12,
              Material(
                color: Colors.white.withValues(alpha: .18),
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => context.openScreen('42'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Text('Suivre ma commande', style: AppText.label.copyWith(color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
        gap12,
        Row(
          children: [
            for (var i = 0; i < d.clientCounters.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppIcon(icons[i], size: 18),
                      const SizedBox(height: 8),
                      Text(d.clientCounters[i].value, style: AppText.h2),
                      Text(d.clientCounters[i].label, style: AppText.small),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        gap16,
        SectionHeader('Commandes récentes', action: 'Tout voir', padding: EdgeInsets.zero, onAction: () => context.openScreen('41')),
        for (final o in d.clientOrders) ...[
          _OrderRow(item: o, onTap: () => context.openScreen('42')),
          gap8,
        ],
        gap8,
        Text('Mes devis et collaborations', style: AppText.h2),
        gap8,
        _OrderRow(item: d.clientCollab, onTap: () => context.openScreen('285'), round: true),
        gap12,
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              const AppIcon(AppIcons.star, size: 20, color: Color(0xFFE0A21B)),
              const SizedBox(width: 12),
              Expanded(child: Text('Donner un avis sur votre dernière commande', style: AppText.body)),
              PrimaryButton(label: 'Noter', expand: false, height: 36, onPressed: () => context.openScreen('47')),
            ],
          ),
        ),
      ],
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.item, required this.onTap, this.round = false});

  final StatusItem item;
  final VoidCallback onTap;
  final bool round;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SizedBox(width: 52, child: PhotoTile(image: item.extra, radius: round ? 26 : 14, semanticLabel: item.title)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: AppText.bodyStrong),
                const SizedBox(height: 2),
                Text(item.detail, style: AppText.small),
              ],
            ),
          ),
          StatusBadge(item.status, tone: toneToBadge(item.tone)),
        ],
      ),
    );
  }
}
