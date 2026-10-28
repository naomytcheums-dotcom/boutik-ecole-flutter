import '../aa_widgets.dart';

/// 208 · Fiche article sur la borne : galerie, note, vendeur, « Sur mon téléphone » / « Commander ».
class FicheBorneScreen extends ConsumerStatefulWidget {
  const FicheBorneScreen({super.key});

  @override
  ConsumerState<FicheBorneScreen> createState() => _FicheBorneScreenState();
}

class _FicheBorneScreenState extends ConsumerState<FicheBorneScreen> {
  int _photo = 0;

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(kioskProductProvider);
    final photo = _photo < p.gallery.length ? _photo : 0;
    return AAPage(
      navIndex: 1,
      builder: (context, l, lang) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(KioskScaffold.padding, 36, KioskScaffold.padding, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 440,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: Image.asset(p.gallery[photo], fit: BoxFit.cover),
                  ),
                  if (p.boosted) Positioned(left: 24, top: 24, child: KioskBoostBadge(l.kioskBoosted, large: true)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                for (var i = 0; i < p.gallery.length; i++) ...[
                  if (i > 0) const SizedBox(width: 16),
                  Semantics(
                    button: true,
                    selected: i == photo,
                    label: 'Photo ${i + 1}',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: () => setState(() => _photo = i),
                      child: Container(
                        width: 96,
                        height: 96,
                        padding: EdgeInsets.all(i == photo ? 4 : 0),
                        decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(24)),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(i == photo ? 20 : 24),
                          child: Image.asset(p.gallery[i], fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.fromLTRB(32, 30, 32, 24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(40)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(p.name, style: AppText.display.copyWith(fontSize: 38, fontWeight: FontWeight.w600)),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Padding(padding: EdgeInsets.only(bottom: 4), child: KioskStars(size: 24, gap: 4)),
                      const SizedBox(width: 24),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          l.kioskReviews(p.rating, p.reviews),
                          style: AppText.body.copyWith(fontSize: 19, color: AppColors.textSecondary),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        fcfaLocalized(p.price, lang),
                        style: AppText.display.copyWith(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Container(
                    height: 90,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: const Color(0xFFF3F1FA), borderRadius: BorderRadius.circular(30)),
                    child: Row(
                      children: [
                        ClipOval(child: Image.asset(p.sellerAvatar, width: 68, height: 68, fit: BoxFit.cover)),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.seller, style: AppText.body.copyWith(fontSize: 22, fontWeight: FontWeight.w500)),
                              Text(
                                l.kioskVerified(p.sellerField),
                                style: AppText.small.copyWith(fontSize: 16, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _KioskButton(
                          label: l.kioskOnPhone,
                          icon: AppIcons.smartphone,
                          dark: true,
                          onTap: () => context.openScreen('209'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 188,
                        child: _KioskButton(label: l.kioskOrder, onTap: () => context.openScreen('209')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KioskButton extends StatelessWidget {
  const _KioskButton({required this.label, required this.onTap, this.icon, this.dark = false});

  final String label;
  final String? icon;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : AppColors.accent;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: dark ? AppColors.ink : const Color(0xFFEDEAFB),
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: SizedBox(
            height: 82,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[AppIcon(icon!, size: 26, color: fg), const SizedBox(width: 22)],
                Text(
                  label,
                  style: AppText.button.copyWith(fontSize: 22.5, color: fg, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
