export '../../core/state/app_settings.dart';
export '../../data/demo/section_q_demo.dart';
export '../i_projets/i_widgets.dart';

import '../i_projets/i_widgets.dart';

/// Carte blanche de lignes séparées (paramètres).
class QCard extends StatelessWidget {
  const QCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => GListCard(padding: const EdgeInsets.fromLTRB(12, 2, 12, 2), children: children);
}

/// Ligne de paramètre : pictogramme cerclé, libellé, élément à droite.
class QRow extends StatelessWidget {
  const QRow({super.key, required this.icon, required this.title, this.subtitle, this.trailing, this.onTap});

  final String icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: const Color(0xFFF2F0F5), borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: AppIcon(icon, size: 17),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.body.copyWith(fontSize: 13.5)),
                    if (subtitle != null) Text(subtitle!, style: AppText.small.copyWith(fontSize: 11)),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton bordé rouge (déconnexion).
class QDangerButton extends StatelessWidget {
  const QDangerButton(this.label, {super.key, required this.onTap, this.icon});

  final String label;
  final String? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        color: Colors.white.withValues(alpha: .6),
        shape: const StadiumBorder(side: BorderSide(color: AppColors.error, width: 1.2)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: SizedBox(
            height: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[AppIcon(icon!, size: 18, color: AppColors.error), const SizedBox(width: 10)],
                Text(label, style: AppText.body.copyWith(color: AppColors.error, fontSize: 14.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// État système plein écran : illustration chrome, titre, texte, actions (150-2, 150-3, 150-4).
class QStateView extends StatelessWidget {
  const QStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
    required this.onAction,
    this.secondary,
    this.onSecondary,
  });

  final String icon;
  final String title;
  final String message;
  final String action;
  final VoidCallback onAction;
  final String? secondary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Column(
        children: [
          ChromeIcon(icon, size: 80),
          gap16,
          Semantics(
            header: true,
            child: Text(title, textAlign: TextAlign.center, style: AppText.h2.copyWith(fontWeight: FontWeight.w700)),
          ),
          gap8,
          Text(message, textAlign: TextAlign.center, style: AppText.small.copyWith(fontSize: 12.5)),
          gap24,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: PrimaryButton(label: action, height: 48, onPressed: onAction),
          ),
          if (secondary != null) ...[
            gap16,
            Material(
              color: Colors.white,
              shape: const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: onSecondary,
                child: SizedBox(
                  height: 46,
                  width: double.infinity,
                  child: Center(child: Text(secondary!, style: AppText.body.copyWith(fontSize: 14))),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Titre d'écran sans retour (états système).
class QTitle extends StatelessWidget {
  const QTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Container(
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.fromLTRB(24, 30, 24, 8),
    child: Semantics(
      header: true,
      child: Text(title, style: AppText.h1.copyWith(fontSize: 24, fontWeight: FontWeight.w600)),
    ),
  );
}
