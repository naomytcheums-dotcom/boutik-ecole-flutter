import '../c_widgets.dart';

/// 24 · Profil d’un vendeur (boutique étudiante).
class ProfilVendeurScreen extends ConsumerStatefulWidget {
  const ProfilVendeurScreen({super.key});

  @override
  ConsumerState<ProfilVendeurScreen> createState() => _ProfilVendeurScreenState();
}

class _ProfilVendeurScreenState extends ConsumerState<ProfilVendeurScreen> {
  int _tab = 0;
  bool _following = false;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionCDataProvider);
    return AppScaffold(
      tab: NavTab.search,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      header: Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 12, 0),
        child: Row(
          children: [
            HeaderIcon(AppIcons.arrowLeft, label: 'Retour', onTap: () => ScreenHeader.back(context)),
            const Spacer(),
            RoundIconButton(
              icon: AppIcons.share2,
              label: 'Partager',
              bordered: false,
              elevated: true,
              badge: true,
              onTap: () => context.openScreen('212'),
            ),
            const SizedBox(width: 4),
            RoundIconButton(
              icon: AppIcons.ellipsis,
              label: 'Plus d’options',
              bordered: false,
              elevated: true,
              onTap: () => context.openScreen('170'),
            ),
          ],
        ),
      ),
      children: [
        SizedBox(
          height: 200,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                child: Image.asset(d.shopCover, height: 114, width: double.infinity, fit: BoxFit.cover),
              ),
              const Positioned.fill(top: 114, child: DecoratedBox(decoration: BoxDecoration(color: Colors.white))),
              Positioned(
                left: 12,
                top: 74,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: CircleAvatar(radius: 46, backgroundImage: AssetImage(d.shopAvatar)),
                ),
              ),
              Positioned(
                left: 122,
                right: 8,
                top: 128,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(d.shopName, style: AppText.h2.copyWith(fontWeight: FontWeight.w500, fontSize: 21)),
                        ),
                        const SizedBox(width: 6),
                        const AppIcon(AppIcons.badgeCheck, size: 18, semanticLabel: 'Vendeur vérifié'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(d.shopSubtitle, style: AppText.small.copyWith(fontSize: 11, color: AppColors.accent)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: AppCard(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                for (final (i, c) in d.shopCounters.indexed) ...[
                  if (i > 0) Container(width: 1, height: 36, color: AppColors.cardBorder),
                  Expanded(
                    child: Column(
                      children: [
                        Text(c.$1, style: AppText.h2.copyWith(fontWeight: FontWeight.w500)),
                        Text(c.$2, style: AppText.small),
                      ],
                    ),
                  ),
                ],
                PrimaryButton(
                  label: _following ? 'Suivi' : 'Suivre',
                  expand: false,
                  height: 44,
                  onPressed: () => setState(() => _following = !_following),
                ),
              ],
            ),
          ),
        ),
        gap16,
        GTabs(labels: d.shopTabs, selected: _tab, onSelected: (i) => setState(() => _tab = i)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: GSectionTitle(
            'Produits phares',
            trailing: TextLink('Voir tout →', onTap: () => context.openScreen('22')),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: CGrid(d.shopProducts, aspect: 168 / 142),
        ),
      ],
    );
  }
}
