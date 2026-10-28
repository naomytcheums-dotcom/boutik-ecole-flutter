import 'package:flutter/services.dart';

import '../am_widgets.dart';

/// 240 · Parrainer et gagner : lien d'invitation, partage, niveaux de parrainage.
class ParrainerScreen extends ConsumerWidget {
  const ParrainerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionAMDataProvider);
    return AppScaffold(
      tab: NavTab.home,
      header: ScreenHeader(
        title: 'Parrainer et gagner',
        subtitle: 'Invite, partage, gagne',
        actions: [AmHeaderButton(AppIcons.share, label: 'Partager', onTap: () => context.openScreen('242'))],
      ),
      children: [
        _Hero(gains: d.referralGains),
        gap16,
        AmCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ton lien d’invitation', style: AppText.secondary),
              gap8,
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.centerLeft,
                      decoration: ShapeDecoration(color: amSoftGrey, shape: const StadiumBorder()),
                      child: Text(d.inviteLink, style: AppText.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: 'Copier le lien',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: 'https://${d.inviteLink}'));
                        context.toast('Lien copié');
                      },
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: const ShapeDecoration(color: AppColors.ink, shape: StadiumBorder()),
                        child: Row(
                          children: [
                            const AppIcon(AppIcons.copy, size: 15, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              'Copier',
                              style: AppText.label.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text('Partager via', style: AppText.h3.copyWith(fontWeight: FontWeight.w600)),
        ),
        gap8,
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final c in d.shareChannels)
              _ShareTarget(
                label: c.$1,
                icon: AmNetworkLogo(c.$2, size: 47, radius: 12),
                onTap: c.$1 == 'WhatsApp' ? () => context.openScreen('241') : () => context.toast('Partage ${c.$1}'),
              ),
            _ShareTarget(
              label: 'SMS',
              icon: const _RoundIcon(AppIcons.messageSquare, Color(0xFFE5DEF5)),
              onTap: () => context.openScreen('241'),
            ),
            _ShareTarget(
              label: 'Contacts',
              icon: const _RoundIcon(AppIcons.users, Color(0xFFF6DCD0)),
              onTap: () => context.openScreen('241'),
            ),
          ],
        ),
        gap16,
        AmCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Niveau ${d.level}', style: AppText.h3.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  AmChip('${d.referralsCount} filleuls', fontSize: 12),
                ],
              ),
              const SizedBox(height: 4),
              Text(d.nextLevelHint, style: AppText.small),
              gap12,
              AmProgress(d.levelProgress, height: 9),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (var i = 0; i < d.tiers.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: _Tier(d.tiers[i], current: d.tiers[i].$1 == d.level)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.gains});

  final int gains;

  @override
  Widget build(BuildContext context) => AmHeroCard(
    height: 190,
    padding: EdgeInsets.zero,
    child: Stack(
      children: [
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: Image.asset('assets/images/am_avion.png', width: 151, fit: BoxFit.fill, excludeFromSemantics: true),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 190,
                child: Text(
                  'Invite, partage, gagne.',
                  style: AppText.h1.copyWith(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w700),
                ),
              ),
              gap12,
              SizedBox(
                width: 150,
                child: Text(
                  'Chaque ami inscrit te rapporte des FCFA.',
                  style: AppText.secondary.copyWith(color: Colors.white, fontSize: 12.5),
                ),
              ),
              const Spacer(),
              Semantics(
                button: true,
                child: GestureDetector(
                  onTap: () => context.openScreen('243'),
                  child: Container(
                    height: 32,
                    width: 170,
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(color: const Color(0x33FFFFFF), shape: const StadiumBorder()),
                    child: Text(
                      'Mes gains · ${fcfa(gains)}',
                      style: AppText.label.copyWith(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ShareTarget extends StatelessWidget {
  const _ShareTarget({required this.label, required this.icon, this.onTap});

  final String label;
  final Widget icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Partager via $label',
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        children: [
          icon,
          const SizedBox(height: 7),
          Text(label, style: AppText.small.copyWith(color: AppColors.ink, fontSize: 10.5)),
        ],
      ),
    ),
  );
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon(this.icon, this.color);

  final String icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 47,
    height: 47,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: AppIcon(icon, size: 20),
  );
}

class _Tier extends StatelessWidget {
  const _Tier(this.tier, {required this.current});

  final (String, String, String, String) tier;
  final bool current;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    decoration: BoxDecoration(
      color: current ? const Color(0xFFEFEBFD) : const Color(0xFFF7F6F9),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        Text(tier.$1, style: AppText.bodyStrong.copyWith(fontSize: 13.5, color: current ? amViolet : AppColors.ink)),
        const SizedBox(height: 2),
        Text(tier.$2, style: AppText.small.copyWith(fontSize: 10)),
        const SizedBox(height: 6),
        Text(tier.$3, style: AppText.label.copyWith(fontSize: 11.5, fontWeight: FontWeight.w800)),
        Text(tier.$4, style: AppText.small.copyWith(fontSize: 10)),
      ],
    ),
  );
}
