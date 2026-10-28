import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_card.dart';
import 'app_icon.dart';
import 'pill.dart';

/// Illustration « chrome » (texture métal) des en-têtes d'écran.
/// Approximation code de l'illustration Figma : icône au trait épais, dégradé métallique, ombre portée.
class ChromeIcon extends StatelessWidget {
  const ChromeIcon(this.asset, {super.key, this.size = 76, this.semanticLabel});

  final String asset;
  final double size;
  final String? semanticLabel;

  static const metal = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFF9A9AA2),
      Color(0xFF1B1B20),
      Color(0xFFE9E9EE),
      Color(0xFF55555E),
      Color(0xFFF6F6F8),
    ],
    stops: [0, .22, .42, .6, .8, 1],
  );

  @override
  Widget build(BuildContext context) {
    final icon = SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
    );
    return Semantics(
      label: semanticLabel,
      image: semanticLabel != null,
      excludeSemantics: true,
      child: SizedBox(
        width: size + 12,
        height: size + 12,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              bottom: 0,
              child: Container(
                width: size * .7,
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 12)],
                ),
              ),
            ),
            ShaderMask(
              shaderCallback: metal.createShader,
              blendMode: BlendMode.srcIn,
              child: icon,
            ),
          ],
        ),
      ),
    );
  }
}

/// En-tête illustré centré : icône chrome, titre, texte explicatif.
class HeroMessage extends StatelessWidget {
  const HeroMessage({super.key, required this.icon, this.title, this.message, this.iconSize = 76});

  final String icon;
  final String? title;
  final String? message;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ChromeIcon(icon, size: iconSize),
        if (title != null) ...[
          const SizedBox(height: 14),
          Semantics(header: true, child: Text(title!, style: AppText.h2.copyWith(fontSize: 21, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
        ],
        if (message != null) ...[
          const SizedBox(height: 8),
          Text(message!, style: AppText.secondary, textAlign: TextAlign.center),
        ],
      ],
    );
  }
}

/// Couple libellé / valeur pour [KeyValueCard].
class KV {
  const KV(this.label, this.value, {this.color, this.strong = false, this.onTap});

  final String label;
  final String value;
  final Color? color;
  final bool strong;
  final VoidCallback? onTap;
}

/// Carte blanche de lignes « libellé … valeur » (récapitulatifs de paiement, reçus…).
class KeyValueCard extends StatelessWidget {
  const KeyValueCard({super.key, required this.rows, this.title, this.footer, this.rowGap = 14});

  final String? title;
  final List<KV> rows;
  final Widget? footer;
  final double rowGap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(title!, style: AppText.h3),
            SizedBox(height: rowGap),
          ],
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) SizedBox(height: rowGap),
            KeyValueRow(rows[i]),
          ],
          if (footer != null) ...[SizedBox(height: rowGap), footer!],
        ],
      ),
    );
  }
}

class KeyValueRow extends StatelessWidget {
  const KeyValueRow(this.kv, {super.key});

  final KV kv;

  @override
  Widget build(BuildContext context) {
    final row = LayoutBuilder(
      builder: (context, c) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(kv.label, style: kv.strong ? AppText.bodyStrong : AppText.secondary),
          ),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: c.maxWidth * .62),
            child: Text(
              kv.value,
              textAlign: TextAlign.end,
              style: AppText.bodyStrong.copyWith(
                fontSize: kv.strong ? 15 : 13,
                color: kv.color,
                fontWeight: kv.strong ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (kv.onTap == null) return Semantics(label: '${kv.label} : ${kv.value}', excludeSemantics: true, child: row);
    return InkWell(onTap: kv.onTap, child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 44), child: Center(child: row)));
  }
}

/// Encadré d'information (cadenas, alerte…) sur fond translucide.
class InfoNote extends StatelessWidget {
  const InfoNote(this.text, {super.key, this.icon = 'assets/icons/lock.svg', this.tone = NoteTone.neutral, this.title});

  final String text;
  final String? title;
  final String icon;
  final NoteTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, border, fg) = switch (tone) {
      NoteTone.neutral => (Colors.white.withValues(alpha: .55), AppColors.cardBorder, AppColors.textSecondary),
      NoteTone.error => (AppColors.errorSoft, const Color(0xFFF5C9C4), AppColors.error),
      NoteTone.warning => (AppColors.warningSoft, const Color(0xFFF1D9AE), AppColors.warning),
      NoteTone.success => (AppColors.successSoft, const Color(0xFFBFE3D1), AppColors.success),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: AppIcon(icon, size: 20, color: tone == NoteTone.neutral ? AppColors.ink : fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) Text(title!, style: AppText.label.copyWith(color: tone == NoteTone.neutral ? AppColors.ink : fg)),
                Text(text, style: AppText.small.copyWith(color: fg)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum NoteTone { neutral, error, warning, success }

enum StepStatus { done, current, upcoming }

class TimelineStep {
  const TimelineStep(this.title, this.detail, this.state);

  final String title;
  final String detail;
  final StepStatus state;
}

/// Frise verticale d'étapes numérotées (suivi de publication, commande…).
class StepTimeline extends StatelessWidget {
  const StepTimeline({super.key, required this.steps});

  final List<TimelineStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 28,
                  child: Column(
                    children: [
                      _dot(i, steps[i].state),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: steps[i].state == StepStatus.done ? AppColors.success : AppColors.cardBorder,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 18, top: 2),
                    child: Semantics(
                      label: '${steps[i].title}, ${steps[i].detail}',
                      excludeSemantics: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            steps[i].title,
                            style: AppText.bodyStrong.copyWith(
                              fontWeight: steps[i].state == StepStatus.upcoming ? FontWeight.w500 : FontWeight.w700,
                              color: steps[i].state == StepStatus.upcoming ? AppColors.textSecondary : AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            steps[i].detail,
                            style: AppText.small.copyWith(
                              fontSize: 12,
                              color: steps[i].state == StepStatus.current ? AppColors.warning : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _dot(int i, StepStatus s) {
    final (bg, child) = switch (s) {
      StepStatus.done => (AppColors.success, const AppIcon('assets/icons/check.svg', size: 14, color: Colors.white)),
      StepStatus.current => (AppColors.ink, Text('${i + 1}', style: AppText.label.copyWith(color: Colors.white, fontSize: 12))),
      StepStatus.upcoming => (const Color(0xFFE6E3EC), Text('${i + 1}', style: AppText.label.copyWith(color: AppColors.textSecondary, fontSize: 12))),
    };
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// Ligne de choix exclusif (moyen de paiement…) avec pastille de sigle.
class ChoiceRow extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
    this.badgeColor = AppColors.warning,
    this.badgeBackground = AppColors.warningSoft,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final String? badge;
  final Color badgeColor;
  final Color badgeBackground;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        radius: 22,
        borderColor: selected ? AppColors.ink : AppColors.cardBorder,
        child: Row(
          children: [
            if (badge != null) ...[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: badgeBackground, borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: Text(badge!, style: AppText.label.copyWith(color: badgeColor, fontSize: 12)),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppText.body),
                  if (subtitle != null) Text(subtitle!, style: AppText.small),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.ink : const Color(0xFFE6E3EC),
              ),
              alignment: Alignment.center,
              child: selected
                  ? Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Case à cocher carrée noire (CGU, « faire confiance à cet appareil »).
class CheckRow extends StatelessWidget {
  const CheckRow({super.key, required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: value,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: value ? AppColors.ink : Colors.white,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: AppColors.ink, width: 1.5),
                ),
                alignment: Alignment.center,
                child: value ? const AppIcon('assets/icons/check.svg', size: 16, color: Colors.white) : null,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: AppText.body)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barre de progression (compétences, quotas).
class ProgressLine extends StatelessWidget {
  const ProgressLine({super.key, required this.value, this.color = AppColors.accent, this.height = 8});

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      value: '${(value * 100).round()} %',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              Container(color: const Color(0xFFE9E6F2)),
              FractionallySizedBox(widthFactor: value.clamp(0, 1), child: Container(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Point coloré d'état.
class StatusDot extends StatelessWidget {
  const StatusDot(this.color, {super.key, this.size = 10});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

/// Teinte associée à un statut métier (texte coloré à droite des cartes).
Color toneColor(BadgeTone t) => switch (t) {
  BadgeTone.success => AppColors.success,
  BadgeTone.warning => AppColors.warning,
  BadgeTone.error => AppColors.error,
  BadgeTone.accent => AppColors.accent,
  BadgeTone.neutral => AppColors.textSecondary,
  BadgeTone.dark => AppColors.ink,
};
