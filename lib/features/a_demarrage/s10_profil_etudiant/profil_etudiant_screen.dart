import '../../common/common.dart';

/// 10 · Profil étudiant (vitrine personnelle).
class ProfilEtudiantScreen extends ConsumerWidget {
  const ProfilEtudiantScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionADataProvider);
    final s = d.student;
    final links = ref.watch(nouveauxDataProvider).socialLinks.where((l) => l.enabled).take(4).toList();
    const brand = {
      'LinkedIn': Color(0xFF0A66C2),
      'X': AppColors.ink,
      'Instagram': Color(0xFFD62976),
      'GitHub': Color(0xFF24292F),
    };
    return AppScaffold(
      tab: NavTab.profile,
      padding: EdgeInsets.zero,
      bottomBar: Row(
        children: [
          Expanded(child: PrimaryButton(label: 'Modifier mon profil', onPressed: () => context.openScreen('58'))),
          const SizedBox(width: 12),
          Expanded(
            child: PrimaryButton(label: 'Partager', variant: ButtonVariant.secondary, onPressed: () => context.openScreen('212')),
          ),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              RoundIconButton(icon: AppIcons.arrowLeft, label: 'Retour', bordered: false, elevated: true, onTap: () => ScreenHeader.back(context)),
              Expanded(child: Text('Profil étudiant', textAlign: TextAlign.center, style: AppText.h3)),
              RoundIconButton(icon: AppIcons.ellipsis, label: 'Plus d’options', bordered: false, elevated: true, onTap: () => context.openScreen('148-1')),
            ],
          ),
        ),
        SizedBox(
          height: 290,
          child: Stack(
            children: [
              Positioned.fill(
                bottom: 50,
                child: Row(
                  children: [
                    for (final (i, img) in d.studentGallery.indexed)
                      Expanded(
                        flex: i == 1 ? 125 : 115,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(26),
                            child: Image.asset(img, fit: BoxFit.cover, height: double.infinity),
                          ),
                        ),
                      ),
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
                    gradient: LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFB57CF5)]),
                  ),
                  child: const CircleAvatar(
                    backgroundColor: Colors.white,
                    backgroundImage: AssetImage(Photos.avatarCreator),
                  ),
                ),
              ),
            ],
          ),
        ),
        gap12,
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(s.name, style: AppText.display.copyWith(fontWeight: FontWeight.w500, fontSize: 28)),
            const SizedBox(width: 8),
            const AppIcon(AppIcons.badgeCheck, size: 22, color: Color(0xFF3B82F6), semanticLabel: 'Profil vérifié'),
          ],
        ),
        const SizedBox(height: 4),
        Text(s.school, textAlign: TextAlign.center, style: AppText.secondary),
        Text(s.tags, textAlign: TextAlign.center, style: AppText.secondary),
        gap8,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Text(s.bio, textAlign: TextAlign.center, style: AppText.secondary),
        ),
        gap12,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              for (final (i, c) in s.counters.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 32,
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(color: Colors.white.withValues(alpha: .8), shape: const StadiumBorder()),
                    child: Text(c, style: AppText.label.copyWith(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ],
          ),
        ),
        gap12,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Text('Liens', style: AppText.small),
              const SizedBox(width: 16),
              for (final l in links)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Semantics(
                    button: true,
                    label: l.network,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(color: brand[l.network] ?? AppColors.ink, borderRadius: BorderRadius.circular(8)),
                      alignment: Alignment.center,
                      child: Text(l.asset, style: AppText.small.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
              const Spacer(),
              const Pill('Portfolio ↗', dense: true),
              const SizedBox(width: 6),
              RoundIconButton(
                icon: AppIcons.plus,
                label: 'Ajouter un lien',
                size: 30,
                bordered: false,
                background: AppColors.ink,
                foreground: Colors.white,
                onTap: () => context.openScreen('271'),
              ),
            ],
          ),
        ),
        gap8,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: AppCard(
            onTap: () => context.openScreen('74'),
            radius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                Expanded(child: Text(s.passport, textAlign: TextAlign.center, style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w600))),
                const AppIcon(AppIcons.chevronRight, size: 16, color: AppColors.accent),
              ],
            ),
          ),
        ),
        gap12,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              for (final (i, img) in [Photos.coder, Photos.solar, Photos.technician].indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: PhotoTile(image: img, aspectRatio: 110 / 58, radius: 18, onTap: () => context.openScreen('79'))),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
