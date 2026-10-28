import '../i_projets/i_widgets.dart';

export '../../data/demo/section_k_demo.dart';
export '../i_projets/i_widgets.dart';

/// Bandeau sombre « texte à gauche, photo à droite » avec bouton blanc (100, 103).
class KPromoBanner extends StatelessWidget {
  const KPromoBanner({
    super.key,
    required this.title,
    required this.text,
    required this.button,
    required this.image,
    required this.onTap,
  });

  final String title;
  final String text;
  final String button;
  final String image;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 132,
        color: const Color(0xFF14284B),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.h3.copyWith(color: Colors.white, height: 1.2)),
                    const Spacer(),
                    Text(text, style: AppText.small.copyWith(fontSize: 11, color: Colors.white)),
                    const SizedBox(height: 6),
                    Semantics(
                      button: true,
                      child: GestureDetector(
                        onTap: onTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                          decoration: const ShapeDecoration(color: AppColors.ink, shape: StadiumBorder()),
                          child: Text(button, style: AppText.label.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 144, height: 132, child: Image.asset(image, fit: BoxFit.cover)),
          ],
        ),
      ),
    );
  }
}

/// Pastille d'action compacte cliquable (« Se connecter », « Réserver »…).
class KBadgeButton extends StatelessWidget {
  const KBadgeButton(this.label, this.tone, {super.key, required this.onTap});

  final String label;
  final Tone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      onTap: onTap,
      child: SizedBox(height: 44, child: Center(child: GBadge(label, tone))),
    ),
  );
}
