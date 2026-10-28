import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/paths.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';
import 'glass_nav_bar.dart';

/// Gabarit des écrans mobiles : fond dégradé, contenu défilant, menu bas en verre.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.children,
    this.header,
    this.showNav = true,
    this.tab,
    this.bottomBar,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
    this.background = AppColors.backgroundGradient,
    this.scrollable = true,
    this.semanticLabel,
    this.bottomBarHeight = 84,
  });

  final double bottomBarHeight;

  final List<Widget> children;
  final Widget? header;
  final bool showNav;
  final NavTab? tab;
  final Widget? bottomBar;
  final EdgeInsets padding;
  final Gradient? background;
  final bool scrollable;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final bottomInset = (showNav ? GlassNavBar.height + 28 : 0) + (bottomBar != null ? bottomBarHeight : 0) + 24.0;
    final content = scrollable
        ? ListView(
            padding: padding.add(EdgeInsets.only(top: 8, bottom: bottomInset)),
            children: children,
          )
        : Padding(
            padding: padding.add(EdgeInsets.only(bottom: bottomInset - 24)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          );
    return Scaffold(
      backgroundColor: AppColors.bgTop,
      body: Semantics(
        label: semanticLabel,
        explicitChildNodes: true,
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: background, color: background == null ? AppColors.bgTop : null),
          child: Stack(
            children: [
              if (background == AppColors.backgroundGradient) const Positioned.fill(child: AppBackgroundGlow()),
              SafeArea(
            bottom: false,
            minimum: const EdgeInsets.only(top: 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        ?header,
                        Expanded(child: content),
                      ],
                    ),
                    if (bottomBar != null || showNav)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: SafeArea(
                          top: false,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (bottomBar != null)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                                  child: bottomBar,
                                ),
                              if (showNav) GlassNavBar(current: tab),
                            ],
                          ),
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
      ),
    );
  }
}

/// Halos colorés du fond (violet à droite, pêche en bas à gauche) superposés au dégradé.
class AppBackgroundGlow extends StatelessWidget {
  const AppBackgroundGlow({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(1.1, -0.35),
                radius: 0.9,
                colors: [Color(0xB3D8C6F2), Color(0x00D8C6F2)],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-1.0, 1.0),
                radius: 1.0,
                colors: [Color(0xCCF8D3B4), Color(0x00F8D3B4)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// En-tête « flèche + titre gras à gauche » des écrans du parcours d'achat (04, 06–09).
class TitleHeader extends StatelessWidget {
  const TitleHeader(this.title, {super.key, this.trailing, this.showBack = true});

  final String title;
  final Widget? trailing;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
      child: Row(
        children: [
          if (showBack)
            RoundIconButton(
              icon: 'assets/icons/arrow-left.svg',
              label: 'Retour',
              bordered: false,
              background: Colors.transparent,
              onTap: () => ScreenHeader.back(context),
            )
          else
            const SizedBox(width: 12),
          const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: AppText.h1.copyWith(fontSize: 24, fontWeight: FontWeight.w700)),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// En-tête d'écran secondaire : bouton retour, titre, actions.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.showBack = true,
    this.large = false,
    this.onBack,
    this.close = false,
  });

  /// Bouton « fermer » (croix) au lieu de « retour », sans logo (écrans de composition).
  final bool close;

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBack;
  final bool large;
  final VoidCallback? onBack;

  static void back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(screenPath(NavTargets.home));
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleWidget = Column(
      crossAxisAlignment: large ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: large ? AppText.h1 : AppText.h2.copyWith(fontSize: 18, fontWeight: FontWeight.w500),
          textAlign: large ? TextAlign.start : TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: AppText.secondary, textAlign: large ? TextAlign.start : TextAlign.center),
        ],
      ],
    );
    final back = showBack
        ? RoundIconButton(
            icon: close ? 'assets/icons/x.svg' : 'assets/icons/arrow-left.svg',
            label: close ? 'Fermer' : 'Retour',
            bordered: false,
            elevated: true,
            onTap: onBack ?? () => ScreenHeader.back(context),
          )
        : null;
    if (large) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (back != null || actions.isNotEmpty)
              Row(children: [?back, const Spacer(), ...actions]),
            const SizedBox(height: 10),
            titleWidget,
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!close) const Padding(padding: EdgeInsets.only(left: 6), child: BrandMark(size: 22)),
          Row(
            children: [
              SizedBox(width: 48, child: back),
              Expanded(child: Semantics(header: true, child: titleWidget)),
              SizedBox(
                width: actions.isEmpty ? 48 : null,
                child: Row(mainAxisSize: MainAxisSize.min, children: actions),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Logo Boutik-École (lettres « BE » encre + accent soleil).
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40, this.withName = false, this.web = false});

  final double size;
  final bool withName;
  final bool web;

  @override
  Widget build(BuildContext context) {
    final mark = Semantics(
      label: 'Boutik-École',
      child: SizedBox(
        width: size * 1.25,
        height: size,
        child: Stack(
          children: [
            Text(
              'B',
              style: TextStyle(
                fontFamily: AppFonts.mobile,
                fontSize: size * 0.95,
                height: 1,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF14284B),
                letterSpacing: -2,
              ),
            ),
            Positioned(
              left: size * 0.52,
              child: Text(
                'E',
                style: TextStyle(
                  fontFamily: AppFonts.mobile,
                  fontSize: size * 0.95,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFF2B33D),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (!withName) return mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 8),
        Text(
          'Boutik-École',
          style: (web ? AppText.web(AppText.h2) : AppText.h2).copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// Petit bouton icône utilisé dans les en-têtes.
class HeaderIcon extends StatelessWidget {
  const HeaderIcon(this.icon, {super.key, required this.label, this.onTap, this.badge = false});

  final String icon;
  final String label;
  final VoidCallback? onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) => RoundIconButton(
    icon: icon,
    label: label,
    onTap: onTap,
    bordered: false,
    background: Colors.transparent,
    badge: badge,
  );
}

/// Bloc de texte d'introduction (titre + sous-titre) en haut d'écran.
class PageIntro extends StatelessWidget {
  const PageIntro(this.title, {super.key, this.subtitle, this.display = false});

  final String title;
  final String? subtitle;
  final bool display;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(title, style: display ? AppText.display : AppText.h1)),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: AppText.body.copyWith(color: AppColors.textSecondary)),
        ],
      ],
    );
  }
}

/// Icône carrée arrondie (catégories de l'accueil).
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final String icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Container(
              width: 56,
              height: 46,
              decoration: BoxDecoration(
                color: selected ? AppColors.ink : AppColors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: selected ? AppColors.ink : AppColors.cardBorder),
              ),
              alignment: Alignment.center,
              child: AppIcon(icon, size: 22, color: selected ? Colors.white : AppColors.ink),
            ),
            const SizedBox(height: 8),
            Text(label, style: AppText.small.copyWith(color: AppColors.ink)),
          ],
        ),
      ),
    );
  }
}
