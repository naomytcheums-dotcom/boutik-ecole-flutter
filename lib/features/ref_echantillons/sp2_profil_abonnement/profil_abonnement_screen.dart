import '../../../data/demo/section_ref_demo.dart';
import '../../common/common.dart';
import '../ref_widgets.dart';

/// P2 · Profil talent côté visiteur : stories, note, abonnement et réseaux connectés.
class ProfilAbonnementScreen extends ConsumerStatefulWidget {
  const ProfilAbonnementScreen({super.key});

  @override
  ConsumerState<ProfilAbonnementScreen> createState() => _ProfilAbonnementScreenState();
}

class _ProfilAbonnementScreenState extends ConsumerState<ProfilAbonnementScreen> {
  bool _subscribed = false;
  bool _favorite = false;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionREFDataProvider);
    final followers = d.followers + (_subscribed ? 1 : 0);
    return AppScaffold(
      tab: NavTab.profile,
      padding: EdgeInsets.zero,
      background: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0, 0.3, 0.52],
        colors: [Color(0xFFFDE8C2), Color(0xFFFEF2DF), Colors.white],
      ),
      children: [
        SizedBox(
          height: 466,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              for (var i = 0; i < 3; i++)
                Positioned(
                  left: const [18.0, 140.0, 272.0][i],
                  width: const [114.0, 124.0, 128.0][i],
                  top: 56,
                  height: 330,
                  child: _StoryColumn(image: d.stories[i], duration: d.storyDurations[i]),
                ),
              for (var i = 0; i < 3; i++)
                Positioned(
                  top: 104,
                  left: const [28.0, 176.0, 326.0][i],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFF6E665D), borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      d.storyDurations[i],
                      style: AppText.small.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              Positioned(
                top: 374,
                child: Semantics(
                  button: true,
                  label: 'Voir le direct',
                  child: GestureDetector(
                    onTap: () => context.openScreen('L1'),
                    child: RefLiveAvatar(photo: d.talentPhoto, size: 88),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        RefProfileIdentity(name: d.talentName, tags: d.talentTags, nameSize: 20),
        const SizedBox(height: 10),
        Center(
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Color(0x0C000000), blurRadius: 16, offset: Offset(0, 2))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const RefStars(size: 16),
                const SizedBox(width: 8),
                Text(d.rating, style: AppText.bodyStrong.copyWith(fontSize: 15)),
                const SizedBox(width: 6),
                Text('· ${d.reviewCount} avis · Recommandée', style: AppText.small.copyWith(fontSize: 11.5)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        RefStatPills([
          '${fcfa(followers, withUnit: false)} Abonnés',
          '${d.following} Suivis',
          '${d.missions} Missions',
        ]),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: Row(
            children: [
              Expanded(
                flex: 150,
                child: _ActionPill(
                  key: const Key('ref-subscribe'),
                  label: _subscribed ? 'Abonné(e)' : 'S’abonner',
                  icon: _subscribed ? AppIcons.userCheck : AppIcons.userPlus,
                  dark: !_subscribed,
                  onTap: () => setState(() => _subscribed = !_subscribed),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 84,
                child: _ActionPill(label: 'Écrire', onTap: () => context.openScreen('A3')),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 70,
                child: _ActionPill(
                  icon: _favorite ? AppIcons.heartFilled : AppIcons.heart,
                  semanticLabel: _favorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
                  iconColor: _favorite ? refLive : AppColors.ink,
                  onTap: () => setState(() => _favorite = !_favorite),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 34, right: 34),
          child: Row(
            children: [
              Expanded(child: Text('Réseaux connectés', style: AppText.small.copyWith(fontSize: 11))),
              Semantics(
                button: true,
                child: InkWell(
                  onTap: () => context.openScreen('P3'),
                  child: SizedBox(
                    height: 32,
                    child: Center(
                      widthFactor: 1,
                      child: Text(
                        'Voir tout',
                        style: AppText.small.copyWith(
                          color: AppColors.accent,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 43),
          child: Row(
            children: [
              for (final (name, logo) in d.networks)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Semantics(
                    label: name,
                    child: RefToolLogo(image: logo, size: 30, radius: 7),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StoryColumn extends StatelessWidget {
  const _StoryColumn({required this.image, required this.duration});

  final String image;
  final String duration;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Story de $duration',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: 0.07,
              child: Image.asset(image, fit: BoxFit.cover, alignment: Alignment.topCenter, excludeFromSemantics: true),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.4, 1],
                  colors: [Color(0x00FEF2DF), Color(0xFFFEF6EA)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    super.key,
    this.label,
    this.icon,
    this.dark = false,
    this.onTap,
    this.semanticLabel,
    this.iconColor,
  });

  final String? label;
  final String? icon;
  final bool dark;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : AppColors.ink;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: dark ? AppColors.ink : const Color(0xFFF2F1EF),
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: SizedBox(
            height: 46,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) AppIcon(icon!, size: 20, color: iconColor ?? fg),
                if (icon != null && label != null) const SizedBox(width: 14),
                if (label != null)
                  Text(
                    label!,
                    style: AppText.body.copyWith(fontSize: 15, fontWeight: FontWeight.w500, color: fg),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
