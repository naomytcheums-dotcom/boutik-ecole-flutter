import '../../data/demo/section_v_demo.dart';
import '../u_confiance/u_widgets.dart';

export '../../data/demo/section_v_demo.dart';
export '../u_confiance/u_widgets.dart';

/// Indicateur de page du carrousel d'accueil.
class VDots extends StatelessWidget {
  const VDots({super.key, required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Page ${index + 1} sur $count',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            Container(
              width: i == index ? 18 : 6,
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: i == index ? AppColors.ink : Colors.white.withValues(alpha: .7),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}

/// Écran d'accueil par rôle (175–178) : bannière, promesse, raccourcis, Passer / Continuer.
class VOnboardingPage extends StatelessWidget {
  const VOnboardingPage(this.data, {super.key});

  final VOnboardingData data;

  @override
  Widget build(BuildContext context) {
    return GPage(
      title: data.welcome,
      showBack: false,
      actions: [
        GOutlineButton('Passer', onPressed: () => context.goScreen('03')),
        PrimaryButton(label: data.primary, height: 54, onPressed: () => context.openScreen(data.primaryTarget)),
      ],
      children: [
        IHeroBanner(image: data.image, title: data.bannerTitle, subtitle: data.bannerSubtitle, height: 210),
        gap16,
        VDots(index: data.dot, count: data.dots),
        gap24,
        Semantics(
          header: true,
          child: Text(data.heading, style: AppText.h2.copyWith(fontSize: 22, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 6),
        Text(data.description, style: AppText.secondary.copyWith(fontSize: 13)),
        gap16,
        QCard(
          children: [
            for (final f in data.features)
              QRow(
                icon: f.$1,
                title: f.$2,
                trailing: const AppIcon(AppIcons.chevronRight, size: 18),
                onTap: () => context.openScreen(f.$3),
              ),
          ],
        ),
      ],
    );
  }
}
