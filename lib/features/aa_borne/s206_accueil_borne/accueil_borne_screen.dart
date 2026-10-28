import '../aa_widgets.dart';

/// 206 · Accueil de la borne : visuel, accroche, « Touchez pour commencer », état de la borne.
class AccueilBorneScreen extends ConsumerWidget {
  const AccueilBorneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(appSettingsProvider).offline;
    return AAPage(
      builder: (context, l, lang) => Column(
        children: [
          const SizedBox(height: 76),
          ExcludeSemantics(child: Image.asset('assets/images/ai_kela_noeud.png', width: 500, height: 500)),
          const SizedBox(height: 40),
          Semantics(
            header: true,
            child: Text(
              l.kioskHeroTitle,
              textAlign: TextAlign.center,
              style: AppText.display.copyWith(fontSize: 40, fontWeight: FontWeight.w600, height: 1.3),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l.kioskHeroSubtitle,
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(fontSize: 20, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 70),
          _StartButton(label: l.kioskStart, onTap: () => context.openScreen('207')),
          const Spacer(),
          if (!offline) _StatusPill(l.kioskReady),
          const SizedBox(height: 62),
        ],
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(56)),
          boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 28, offset: Offset(0, 6))],
        ),
        child: Material(
          color: AppColors.ink,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 500,
              height: 110,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: AppText.button.copyWith(fontSize: 27, color: Colors.white)),
                  const SizedBox(width: 14),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: const AppIcon(AppIcons.arrowRight, size: 26, color: AppColors.ink),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(color: const Color(0xFFDCE6D6), borderRadius: BorderRadius.circular(22)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            // Vert assombri : contraste ≥ 4,5:1 sur le fond vert pâle.
            Text(label, style: AppText.body.copyWith(fontSize: 16, color: const Color(0xFF0B6644))),
          ],
        ),
      ),
    );
  }
}
