import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/paths.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_card.dart';
import 'app_icon.dart';
import 'app_scaffold.dart';
import 'primary_button.dart';

class WebNavItem {
  const WebNavItem(this.label, this.icon, {this.target, this.section});

  final String label;
  final String icon;
  final String? target;
  final String? section;
}

/// Gabarit des tableaux de bord web (1280) : barre haute, barre latérale 240 px, contenu #F7F6F4.
/// Sous 900 px de large, la barre latérale passe dans un tiroir.
class WebShell extends StatelessWidget {
  const WebShell({
    super.key,
    required this.title,
    required this.navItems,
    required this.selected,
    required this.children,
    this.subtitle,
    this.headerActions = const [],
    this.topAction,
    this.onNavigate,
    this.accountName = 'Compte',
    this.accountSubtitle = 'Boutik-École',
    this.searchHint = 'Rechercher données, rapports, produits…',
    this.defaultActions = true,
  });

  final bool defaultActions;

  final String title;
  final String? subtitle;
  final List<WebNavItem> navItems;
  final int selected;
  final List<Widget> children;
  final List<Widget> headerActions;
  final Widget? topAction;
  final ValueChanged<WebNavItem>? onNavigate;
  final String accountName;
  final String accountSubtitle;
  final String searchHint;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.light(web: true),
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 900;
          final sidebar = _Sidebar(
            items: navItems,
            selected: selected,
            onNavigate: onNavigate,
            accountName: accountName,
            accountSubtitle: accountSubtitle,
          );
          return Scaffold(
            backgroundColor: AppColors.webBackground,
            drawer: wide
                ? null
                : Drawer(
                    backgroundColor: AppColors.webSidebar,
                    child: SafeArea(child: sidebar),
                  ),
            body: SafeArea(
              child: Column(
                children: [
                  _TopBar(wide: wide, searchHint: searchHint, action: topAction ?? const _DefaultTopAction()),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (wide)
                          SizedBox(
                            width: AppSizes.sidebarWidth,
                            child: ColoredBox(color: AppColors.webSidebar, child: sidebar),
                          ),
                        Expanded(
                          child: ListView(
                            padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 24, wide ? 28 : 16, 32),
                            children: [
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                runSpacing: 12,
                                spacing: 16,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Semantics(
                                        header: true,
                                        child: Text(title, style: AppText.h1.copyWith(fontWeight: FontWeight.w600)),
                                      ),
                                      if (subtitle != null) ...[
                                        const SizedBox(height: 6),
                                        Text(subtitle!, style: AppText.secondary),
                                      ],
                                    ],
                                  ),
                                  if (headerActions.isNotEmpty || defaultActions)
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 8,
                                      children: [
                                        ...headerActions,
                                        if (defaultActions) ...[
                                          const WebChipButton('Actualiser', 'assets/icons/refresh-cw.svg'),
                                          const WebChipButton(
                                            'Personnaliser la vue',
                                            'assets/icons/sliders-horizontal.svg',
                                          ),
                                        ],
                                      ],
                                    ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              ...children,
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.wide, required this.searchHint, this.action});

  final bool wide;
  final String searchHint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          if (!wide)
            Builder(
              builder: (context) => RoundIconButton(
                icon: 'assets/icons/list.svg',
                label: 'Menu',
                bordered: false,
                onTap: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          const BrandMark(size: 30, withName: true, web: true),
          if (wide) ...[
            const SizedBox(width: 90),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: ShapeDecoration(
                    color: AppColors.webBackground,
                    shape: const StadiumBorder(side: BorderSide(color: AppColors.cardBorder)),
                  ),
                  child: Row(
                    children: [
                      const AppIcon('assets/icons/search.svg', size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        // Zone tactile de 44 px qui déborde de 1 px de la pastille, sans changer le rendu.
                        child: OverflowBox(
                          minHeight: 44,
                          maxHeight: 44,
                          child: TextField(
                            style: AppText.secondary.copyWith(color: AppColors.ink),
                            decoration: InputDecoration(
                              hintText: searchHint,
                              hintStyle: AppText.secondary,
                              filled: false,
                              isDense: true,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 13.5),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else
            const Spacer(),
          if (wide) const Spacer(),
          ?action,
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.items,
    required this.selected,
    required this.onNavigate,
    required this.accountName,
    required this.accountSubtitle,
  });

  final List<WebNavItem> items;
  final int selected;
  final ValueChanged<WebNavItem>? onNavigate;
  final String accountName;
  final String accountSubtitle;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    String? lastSection;
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      final section = it.section ?? (i == 0 ? 'Principal' : null);
      if (section != null && section != lastSection) {
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
            child: Text(section, style: AppText.small),
          ),
        );
        lastSection = section;
      }
      final active = i == selected;
      rows.add(
        Semantics(
          button: true,
          selected: active,
          child: Material(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                if (onNavigate != null) {
                  onNavigate!(it);
                } else if (it.target != null) {
                  context.go(screenPath(it.target!));
                }
              },
              child: SizedBox(
                height: 46,
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    AppIcon(it.icon, size: 18),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        it.label,
                        style: AppText.secondary.copyWith(
                          color: AppColors.ink,
                          fontSize: 15,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      rows.add(const SizedBox(height: 4));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.only(top: 6), children: rows),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: AppCard(
              padding: const EdgeInsets.all(12),
              borderColor: null,
              radius: 14,
              child: Row(
                children: [
                  Avatar(initials: accountName.substring(0, 1), size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(accountName, style: AppText.label, overflow: TextOverflow.ellipsis),
                        Text(
                          accountSubtitle,
                          style: AppText.small.copyWith(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton secondaire arrondi des en-têtes web (« Actualiser »…).
class WebChipButton extends StatelessWidget {
  const WebChipButton(this.label, this.icon, {super.key, this.onTap});

  final String label;
  final String icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const StadiumBorder(side: BorderSide(color: AppColors.cardBorder)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap ?? () {},
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(icon, size: 16),
              const SizedBox(width: 10),
              Text(
                label,
                style: AppText.secondary.copyWith(color: AppColors.ink, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DefaultTopAction extends StatelessWidget {
  const _DefaultTopAction();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (MediaQuery.sizeOf(context).width >= 900) ...[
          SizedBox(
            width: 80,
            height: 36,
            child: Stack(
              children: [
                for (var i = 0; i < 3; i++)
                  Positioned(
                    left: i * 16.0,
                    child: Avatar(
                      image: 'assets/images/${['avatar_woman', 'coder', 'student_hijab'][i]}.jpg',
                      size: 34,
                      ring: true,
                    ),
                  ),
                Positioned(left: 56, top: 9, child: Text('+3', style: AppText.small)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Color(0xFF8E6CF2), AppColors.accent]),
            ),
          ),
          const SizedBox(width: 24),
        ],
        PrimaryButton(
          label: 'Exporter',
          trailingIcon: 'assets/icons/external-link.svg',
          expand: false,
          height: 46,
          onPressed: () =>
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Export préparé (données de démonstration).'))),
        ),
      ],
    );
  }
}

/// Tableau de données web (en-tête gris, lignes séparées).
class WebTable extends StatelessWidget {
  const WebTable({super.key, required this.columns, required this.rows, this.title, this.flex});

  final String? title;
  final List<String> columns;
  final List<List<Widget>> rows;
  final List<int>? flex;

  @override
  Widget build(BuildContext context) {
    Widget row(List<Widget> cells, {bool header = false}) => Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: header
          ? BoxDecoration(color: AppColors.webBackground, borderRadius: BorderRadius.circular(10))
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
            ),
      child: Row(
        children: [for (var i = 0; i < cells.length; i++) Expanded(flex: flex?[i] ?? 1, child: cells[i])],
      ),
    );
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 14),
              child: Text(title!, style: AppText.h3.copyWith(fontWeight: FontWeight.w600)),
            ),
          LayoutBuilder(
            builder: (context, c) {
              final table = Column(
                children: [
                  row([for (final h in columns) Text(h, style: AppText.small)], header: true),
                  for (final r in rows) row(r),
                ],
              );
              final minWidth = columns.length * 130.0;
              if (c.maxWidth >= minWidth) return table;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(width: minWidth, child: table),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Cellule texte de tableau web.
class Cell extends StatelessWidget {
  const Cell(this.text, {super.key, this.strong = false, this.color});

  final String text;
  final bool strong;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: (strong ? AppText.bodyStrong : AppText.body.copyWith(fontWeight: FontWeight.w400)).copyWith(color: color),
    overflow: TextOverflow.ellipsis,
    maxLines: 2,
  );
}

/// Grille responsive pour tableaux de bord : n colonnes sur grand écran, 1 sur petit.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.columns = 4,
    this.spacing = 16,
    this.minItemWidth = 220,
  });

  final List<Widget> children;
  final int columns;
  final double spacing;
  final double minItemWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        var n = columns;
        while (n > 1 && (c.maxWidth - spacing * (n - 1)) / n < minItemWidth) {
          n--;
        }
        final w = (c.maxWidth - spacing * (n - 1)) / n;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final ch in children) SizedBox(width: w, child: ch)],
        );
      },
    );
  }
}
