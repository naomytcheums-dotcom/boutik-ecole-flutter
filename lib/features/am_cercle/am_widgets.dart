import '../common/common.dart';

export '../../data/demo/section_am_demo.dart';
export '../common/common.dart';

/// Montant court « 12 500 F » (vignettes, primes).
String fcfaF(int v) => '${fcfa(v, withUnit: false)}${nbsp}F';

/// Icône de la section à partir de son nom dans les données de démonstration.
String amIcon(String name) => switch (name) {
  'image' => AppIcons.image,
  'video' => AppIcons.video,
  'radio' => AppIcons.radio,
  'shoppingBag' => AppIcons.shoppingBag,
  'pencil' => AppIcons.pencil,
  'messageCircle' => AppIcons.messageCircle,
  'eye' => AppIcons.eye,
  'userPlus' => AppIcons.userPlus,
  'zap' => AppIcons.zap,
  'flame' => AppIcons.flame,
  _ => AppIcons.circleDot,
};

const amViolet = Color(0xFF6A4BF0);
const amSoftGrey = Color(0xFFF4F2F7);
const amLive = Color(0xFFE11D48);

/// Dégradé encre → violet des cartes mises en avant (240, 242, 253).
const amHeroGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF1F1A40), Color(0xFF3A2C8E), Color(0xFF4F3BC4)],
  stops: [0, .55, 1],
);

/// Bouton rond blanc surélevé des en-têtes.
class AmHeaderButton extends StatelessWidget {
  const AmHeaderButton(this.icon, {super.key, required this.label, this.onTap, this.badge = false});

  final String icon;
  final String label;
  final VoidCallback? onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) =>
      RoundIconButton(icon: icon, label: label, bordered: false, elevated: true, badge: badge, onTap: onTap);
}

/// En-tête des écrans racines (Cercle, Découvrir, Activité) : logo, grand titre, actions.
class AmRootHeader extends StatelessWidget {
  const AmRootHeader(this.title, {super.key, this.actions = const []});

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 6, 18, 6),
    child: Row(
      children: [
        const BrandMark(size: 30),
        const SizedBox(width: 2),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: AppText.h1.copyWith(fontSize: 26, fontWeight: FontWeight.w700)),
          ),
        ),
        ...actions,
      ],
    ),
  );
}

/// Carte blanche arrondie sans bordure.
class AmCard extends StatelessWidget {
  const AmCard({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.radius = 28, this.color});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? AppColors.card,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [BoxShadow(color: Color(0x0F2A1B5C), blurRadius: 18, offset: Offset(0, 6))],
    ),
    child: child,
  );
}

/// Carte dégradée encre → violet.
class AmHeroCard extends StatelessWidget {
  const AmHeroCard({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.height});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    clipBehavior: Clip.antiAlias,
    padding: padding,
    decoration: BoxDecoration(gradient: amHeroGradient, borderRadius: BorderRadius.circular(28)),
    child: DefaultTextStyle.merge(
      style: const TextStyle(color: Colors.white),
      child: child,
    ),
  );
}

/// Petite pastille d'action (violet clair, noire, verte…), zone tactile de 44 px si cliquable.
class AmChip extends StatelessWidget {
  const AmChip(this.label, {super.key, this.onTap, this.dark = false, this.tone, this.height = 30, this.fontSize = 12});

  final String label;
  final VoidCallback? onTap;
  final bool dark;
  final Tone? tone;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = dark
        ? (AppColors.ink, Colors.white)
        : switch (tone) {
            Tone.success => (AppColors.successSoft, AppColors.success),
            Tone.warning => (AppColors.warningSoft, AppColors.warning),
            Tone.neutral => (Colors.white, AppColors.ink),
            _ => (AppColors.accentSoft, AppColors.accent),
          };
    final chip = Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: ShapeDecoration(color: bg, shape: const StadiumBorder()),
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          maxLines: 1,
          style: AppText.label.copyWith(color: fg, fontSize: fontSize, fontWeight: FontWeight.w600),
        ),
      ),
    );
    if (onTap == null) return chip;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTouch),
          child: Center(widthFactor: 1, child: chip),
        ),
      ),
    );
  }
}

/// Photo arrondie (asset), avec contenu superposé facultatif.
class AmPhoto extends StatelessWidget {
  const AmPhoto(this.image, {super.key, this.radius = 24, this.width, this.height, this.children = const []});

  final String image;
  final double radius;
  final double? width;
  final double? height;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(image, fit: BoxFit.cover),
          ...children,
        ],
      ),
    ),
  );
}

/// Pastille sombre translucide (compteurs de vues sur les photos).
class AmDarkTag extends StatelessWidget {
  const AmDarkTag(this.label, {super.key, this.color = const Color(0xB3333238)});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: ShapeDecoration(color: color, shape: const StadiumBorder()),
    child: Text(
      label,
      style: AppText.small.copyWith(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );
}

/// Bouton lecture circulaire translucide.
class AmPlayButton extends StatelessWidget {
  const AmPlayButton({super.key, this.size = 40, this.onTap});

  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Lire la vidéo',
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: size < 44 ? 44 : size,
        height: size < 44 ? 44 : size,
        alignment: Alignment.center,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: Color(0x66FFFFFF), shape: BoxShape.circle),
          child: Padding(
            padding: EdgeInsets.only(left: size * 0.06),
            child: AppIcon(AppIcons.play, size: size * 0.42, color: Colors.white),
          ),
        ),
      ),
    ),
  );
}

/// Barre de progression violette arrondie.
class AmProgress extends StatelessWidget {
  const AmProgress(this.value, {super.key, this.height = 8});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height),
    child: SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Color(0xFFEAE6F4))),
          FractionallySizedBox(
            widthFactor: value.clamp(0.02, 1.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height),
                gradient: const LinearGradient(colors: [Color(0xFF7B61FF), amViolet]),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Logo de réseau social (image arrondie).
class AmNetworkLogo extends StatelessWidget {
  const AmNetworkLogo(this.image, {super.key, this.size = 32, this.radius = 8, this.label});

  final String image;
  final double size;
  final double radius;
  final String? label;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: label,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(image, width: size, height: size, fit: BoxFit.cover),
    ),
  );
}
