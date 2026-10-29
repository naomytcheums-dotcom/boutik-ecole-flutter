import '../../../data/demo/section_ref_demo.dart';
import '../../common/common.dart';
import '../ref_widgets.dart';

/// P1 · Profil talent : stories, identité, statistiques et galerie de réalisations.
class ProfilTalentScreen extends ConsumerWidget {
  const ProfilTalentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionREFDataProvider);
    return AppScaffold(
      tab: NavTab.profile,
      padding: EdgeInsets.zero,
      background: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, Color(0xFFFCFAFA)],
      ),
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 22),
          child: Align(alignment: Alignment.centerLeft, child: BrandMark(size: 26)),
        ),
        const SizedBox(height: 30),
        SizedBox(
          height: 300,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(left: 18, top: 0, width: 114, height: 243, child: _Story(d.stories[0])),
              Positioned(left: 140, top: 0, width: 124, height: 243, child: _Story(d.stories[1], fit: BoxFit.cover)),
              Positioned(left: 272, top: 0, right: -10, height: 243, child: _Story(d.stories[2])),
              Positioned(
                top: 188,
                child: Semantics(
                  button: true,
                  label: 'Voir le direct d’Aminata',
                  child: GestureDetector(
                    onTap: () => context.openScreen('L1'),
                    child: RefLiveAvatar(photo: d.talentPhoto),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        RefProfileIdentity(name: d.talentName, tags: d.talentTags),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Text(
            d.talentBio,
            style: AppText.secondary.copyWith(fontSize: 12.2, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 10),
        RefStatPills([
          '${fcfa(d.followers, withUnit: false)} Abonnés',
          '${d.following} Suivis',
          '${d.missions} Missions',
        ]),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    _FriendStack(d.friendAvatars),
                    const SizedBox(height: 6),
                    Text('Amis qui suivent', style: AppText.small.copyWith(fontSize: 11)),
                  ],
                ),
              ),
              RefChipButton(
                'Avis & réseaux',
                leading: AppIcons.starFilled,
                trailing: AppIcons.arrowRight,
                height: 36,
                color: const Color(0xFFF2F1EF),
                leadingColor: refStar,
                fontSize: 12.5,
                onTap: () => context.openScreen('P3'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(flex: 2, child: _Tile(d.galleryTop[0])),
                  const SizedBox(width: 8),
                  Expanded(child: _Tile(d.galleryTop[1])),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 0; i < d.galleryBottom.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: _Tile(d.galleryBottom[i])),
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

class _Story extends StatelessWidget {
  const _Story(this.image, {this.fit = BoxFit.fitWidth});

  final String image;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.white),
          Image.asset(image, fit: fit, alignment: Alignment.topCenter, excludeFromSemantics: true),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.45, 1],
                colors: [Color(0x00FFFFFF), Color(0xF2FFFFFF)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.image);

  final String image;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Voir la réalisation',
      child: GestureDetector(onTap: () => context.openScreen('V1'), child: RefPhoto(image, height: 112, radius: 20)),
    );
  }
}

class _FriendStack extends StatelessWidget {
  const _FriendStack(this.avatars);

  final List<String> avatars;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26.0 + (avatars.length - 1) * 20,
      height: 26,
      child: Stack(
        children: [
          for (var i = 0; i < avatars.length; i++)
            Positioned(
              left: i * 20.0,
              child: Container(
                width: 26,
                height: 26,
                padding: const EdgeInsets.all(1.5),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: ClipOval(child: Image.asset(avatars[i], fit: BoxFit.cover, excludeFromSemantics: true)),
              ),
            ),
        ],
      ),
    );
  }
}
