import '../h_widgets.dart';

/// 77 · Profil de mentor (vitrine d'un enseignant accompagnateur).
class ProfilMentorScreen extends ConsumerWidget {
  const ProfilMentorScreen({super.key});

  static const _links = [
    ('LinkedIn', 'assets/images/h_logo_linkedin.png'),
    ('X', 'assets/images/h_logo_x.png'),
    ('Facebook', 'assets/images/h_logo_facebook.png'),
    ('GitHub', 'assets/images/h_logo_github.png'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionHDataProvider);
    return AppScaffold(
      padding: EdgeInsets.zero,
      bottomBarHeight: 56,
      bottomBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            Expanded(
              flex: 200,
              child: _PillButton(
                'Demander un accompagnement',
                dark: true,
                onTap: () => context.toast('Demande envoyée à ${d.mentorName}.'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(flex: 134, child: _PillButton('Écrire', onTap: () => context.openScreen('53'))),
          ],
        ),
      ),
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 22),
          child: Align(alignment: Alignment.centerLeft, child: BrandMark(size: 32)),
        ),
        SizedBox(
          height: 316,
          child: Stack(
            children: [
              for (final (i, (left, width)) in const [(18.0, 113.0), (140.0, 124.0), (272.0, 114.0)].indexed)
                Positioned(
                  left: left,
                  width: width,
                  top: 22,
                  height: i == 1 ? 192 : 243,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(d.mentorGallery[i], fit: BoxFit.cover),
                  ),
                ),
              Positioned(
                left: 30,
                right: 10,
                top: 0,
                child: Row(
                  children: [
                    _GlassCircle(AppIcons.arrowLeft, label: 'Retour', onTap: () => ScreenHeader.back(context)),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          'Profil de mentor',
                          textAlign: TextAlign.center,
                          style: AppText.h3.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    _GlassCircle(
                      AppIcons.ellipsisVertical,
                      label: 'Plus d’options',
                      onTap: () => context.toast('Signaler · Partager le profil'),
                    ),
                    const SizedBox(width: 20),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: 112,
                  height: 112,
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFD4D6B), Color(0xFFF9873E), Color(0xFF9976EC)],
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                    child: ClipOval(child: Image.asset(d.mentorAvatar, fit: BoxFit.cover)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(d.mentorName, style: AppText.display.copyWith(fontWeight: FontWeight.w500, fontSize: 28)),
            const SizedBox(width: 6),
            const AppIcon(AppIcons.badgeCheck, size: 20, color: Color(0xFF3B82F6), semanticLabel: 'Profil vérifié'),
          ],
        ),
        const SizedBox(height: 2),
        Text(d.mentorRole, textAlign: TextAlign.center, style: AppText.secondary.copyWith(fontSize: 13)),
        const SizedBox(height: 3),
        Text(d.mentorTags, textAlign: TextAlign.center, style: AppText.secondary.copyWith(fontSize: 13)),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: Text(
            d.mentorBio,
            textAlign: TextAlign.center,
            style: AppText.small.copyWith(fontSize: 12.5, height: 1.4),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: Row(
            children: [
              for (final (i, c) in d.mentorCounters.indexed) ...[
                if (i > 0) const SizedBox(width: 7),
                Expanded(
                  child: Container(
                    height: 29,
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: Colors.white.withValues(alpha: .85),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(c, style: AppText.label.copyWith(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 15),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              SizedBox(width: 68, child: Text('Liens', style: AppText.small.copyWith(fontSize: 12.5))),
              for (final (name, logo) in _links)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Semantics(
                    button: true,
                    label: name,
                    child: Semantics(
                      button: true,
                      label: 'Ouvrir $name',
                      child: GestureDetector(
                        onTap: () => context.toast('Ouvrir $name'),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Image.asset(logo, width: 26, height: 26, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 22),
              Semantics(
                button: true,
                child: Semantics(
                  button: true,
                  label: 'Ouvrir le portfolio',
                  child: GestureDetector(
                    onTap: () => context.toast('Ouvrir le portfolio'),
                    child: Container(
                      height: 26,
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      decoration: const ShapeDecoration(color: Colors.white, shape: StadiumBorder()),
                      alignment: Alignment.center,
                      child: Text(
                        'Portfolio ↗',
                        style: AppText.small.copyWith(fontSize: 12, color: AppColors.ink, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              for (final (i, img) in d.mentorGallery.indexed) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: PhotoTile(
                    image: img,
                    aspectRatio: 110 / 92,
                    radius: 20,
                    onTap: () => context.openScreen('34'),
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

/// Bouton rond gris translucide posé sur la galerie.
class _GlassCircle extends StatelessWidget {
  const _GlassCircle(this.icon, {required this.label, required this.onTap});

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFEEEBEB),
              boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 3))],
            ),
            alignment: Alignment.center,
            child: AppIcon(icon, size: 20),
          ),
        ),
      ),
    ),
  );
}

/// Bouton pilule des actions du bas (noir ou blanc).
class _PillButton extends StatelessWidget {
  const _PillButton(this.label, {required this.onTap, this.dark = false});

  final String label;
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: Material(
      color: dark ? AppColors.ink : Colors.white.withValues(alpha: .85),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              style: AppText.body.copyWith(
                fontSize: dark ? 13.5 : 14,
                fontWeight: FontWeight.w600,
                color: dark ? Colors.white : AppColors.ink,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
