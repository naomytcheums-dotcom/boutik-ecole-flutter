import '../../../data/demo/section_ref_demo.dart';
import '../../common/common.dart';
import '../ref_widgets.dart';

/// A2 · Accueil Kéla : raccourcis vocaux, thèmes et suggestions de talents.
class AccueilKelaScreen extends ConsumerStatefulWidget {
  const AccueilKelaScreen({super.key});

  @override
  ConsumerState<AccueilKelaScreen> createState() => _AccueilKelaScreenState();
}

class _AccueilKelaScreenState extends ConsumerState<AccueilKelaScreen> {
  int _theme = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionREFDataProvider);
    return AppScaffold(
      tab: NavTab.home,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        const SizedBox(height: 4),
        Transform.translate(
          offset: const Offset(-2, 0),
          child: const Align(alignment: Alignment.centerLeft, child: BrandMark(size: 26)),
        ),
        Row(
          children: [
            Avatar(image: d.userAvatar, size: 46),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bonjour ${d.userFirstName}', style: AppText.secondary.copyWith(fontSize: 14)),
                  Semantics(
                    header: true,
                    child: Text(
                      'Que fait-on aujourd’hui ?',
                      style: AppText.h3.copyWith(fontSize: 16.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            RefGlassButton(
              icon: AppIcons.bell,
              label: 'Notifications',
              onTap: () => context.toast('Aucune nouvelle notification'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        SizedBox(
          height: 208,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: _Shortcut(
                        image: 'assets/images/ref_3d_brief.jpg',
                        title: 'Brief express',
                        text: 'Décris ton besoin à voix haute',
                        onTap: () => context.openScreen('A1'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _Shortcut(
                        image: 'assets/images/ref_3d_voix.jpg',
                        title: 'Voix en texte',
                        text: 'Tes notes en transcription',
                        onTap: () => context.openScreen('A3'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RefCard(
                  radius: 26,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.asset('assets/images/ref_3d_kela.jpg', width: 60, height: 60, excludeFromSemantics: true),
                      const SizedBox(height: 18),
                      Text('Parle à Kéla', style: AppText.h2.copyWith(fontSize: 17.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('Essaie dès maintenant', style: AppText.secondary),
                      const Spacer(),
                      PrimaryButton(label: 'Commencer', height: 42, onPressed: () => context.openScreen('A1')),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text('Thèmes', style: AppText.h3.copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            TextLink('Tout voir', color: AppColors.textSecondary, onTap: () => context.openScreen('V1')),
          ],
        ),
        RefPillRow(fontSize: 13, labels: d.themes, selected: _theme, onSelected: (i) => setState(() => _theme = i)),
        const SizedBox(height: 18),
        SizedBox(
          height: 190,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _ThemeCard(
                  image: 'assets/images/ref_3d_besoin.jpg',
                  title: 'Déposer un besoin',
                  text: 'Logo, affiche, vidéo : Kéla t’oriente vers les bons talents.',
                  onTap: () => context.openScreen('191'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ThemeCard(
                  image: 'assets/images/ref_3d_mission.jpg',
                  title: 'Suivre ma mission',
                  text: 'Étapes, preuves et paiement par jalons.',
                  onTap: () => context.openScreen('194'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Semantics(
          button: true,
          child: GestureDetector(
            onTap: () => context.openScreen('P1'),
            child: _MatchCard(d: d),
          ),
        ),
      ],
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.d});

  final SectionREFData d;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 1.2),
      ),
      child: Row(
        children: [
          Avatar(image: d.userAvatar, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${d.matchCount} talents de ${d.matchDepartment} correspondent à ton ${d.matchBrief}.',
                  style: AppText.body.copyWith(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  'Voir les profils',
                  style: AppText.small.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.image, required this.title, required this.text, this.onTap});

  final String image;
  final String title;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return RefCard(
      radius: 26,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 8, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(image, width: 40, height: 46, fit: BoxFit.contain, excludeFromSemantics: true),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  title,
                  style: AppText.bodyStrong.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  softWrap: false,
                ),
              ),
              const _ArrowDot(),
            ],
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(right: 22),
            child: Text(text, style: AppText.small.copyWith(fontSize: 11.5), maxLines: 2),
          ),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.image, required this.title, required this.text, this.onTap});

  final String image;
  final String title;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return RefCard(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(image, width: 52, height: 54, fit: BoxFit.contain, excludeFromSemantics: true),
              const SizedBox(height: 14),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(title, style: AppText.h3.copyWith(fontWeight: FontWeight.w600), maxLines: 1),
              ),
              const Spacer(),
              Text(text, style: AppText.small.copyWith(fontSize: 11.5), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 30),
            ],
          ),
          Positioned(
            left: 0,
            bottom: 0,
            child: RefChipButton('Découvrir', trailing: AppIcons.arrowRight, height: 30, onTap: onTap),
          ),
        ],
      ),
    );
  }
}

class _ArrowDot extends StatelessWidget {
  const _ArrowDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(color: refChip, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: const AppIcon(AppIcons.arrowRight, size: 14),
    );
  }
}
