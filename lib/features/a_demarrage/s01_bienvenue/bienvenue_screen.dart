import '../../common/common.dart';

/// 01 et 02 · Bienvenue (les deux maquettes sont identiques, cf. docs/QUESTIONS.md).
class BienvenueScreen extends ConsumerWidget {
  const BienvenueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionADataProvider);
    return AppScaffold(
      showNav: false,
      children: [
        gap16,
        SizedBox(
          height: 262,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 196,
                child: _LabeledPhoto(image: Photos.portraitWoman, label: 'Talents', onTap: () => context.openScreen('72')),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 134,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _LabeledPhoto(image: Photos.coder, label: 'Services', onTap: () => context.openScreen('34'))),
                    const SizedBox(height: 12),
                    Expanded(child: _LabeledPhoto(image: Photos.foodSpread, onTap: () => context.openScreen('32'))),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 92),
        Text(
          'BIENVENUE SUR',
          textAlign: TextAlign.center,
          style: AppText.small.copyWith(letterSpacing: 2.4, fontWeight: FontWeight.w500),
        ),
        gap12,
        const Center(child: BrandMark(size: 34)),
        gap12,
        Semantics(
          header: true,
          child: Text(d.onboardingTitle, textAlign: TextAlign.center, style: AppText.display.copyWith(fontSize: 25)),
        ),
        gap12,
        Text(d.onboardingText, textAlign: TextAlign.center, style: AppText.body.copyWith(color: AppColors.textSecondary)),
        gap24,
        const _Dots(count: 3, current: 0),
        gap24,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: PrimaryButton(
            label: 'Commencer',
            trailingIcon: AppIcons.arrowRight,
            onPressed: () => context.goScreen(NavTargets.home),
          ),
        ),
        Center(child: TextLink('Se connecter', color: AppColors.ink, onTap: () => context.openScreen('11'))),
      ],
    );
  }
}

/// Photo arrondie avec pastille blanche posée en bas à gauche (comme la maquette 01).
class _LabeledPhoto extends StatelessWidget {
  const _LabeledPhoto({required this.image, this.label, this.onTap});

  final String image;
  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label ?? 'Produits',
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(image, fit: BoxFit.cover),
              if (label != null)
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    decoration: ShapeDecoration(color: Colors.white, shape: const StadiumBorder()),
                    child: Text(label!, style: AppText.label),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Page ${current + 1} sur $count',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            Container(
              width: i == current ? 16 : 14,
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: i == current ? AppColors.ink : const Color(0xFFE4E0EA),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}
