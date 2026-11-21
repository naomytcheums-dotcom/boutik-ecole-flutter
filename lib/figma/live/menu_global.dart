import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/paths.dart';
import 'auth.dart' show authProvider;
import 'kiosk_mode.dart' show KioskTerminal;

/// Menu du bas commun aux écrans écrits à la main (marché, organisation, département, concours, opportunités…).
///
/// Les écrans générés depuis Figma (`/s/<id>`) reconstruisent déjà ce même menu à cinq onglets (Kéla, messages, accueil, réseau social,
/// profil) ; sans cette enveloppe, la personne le voyait disparaître en ouvrant une page écrite à la main. Ici il est identique, au même
/// endroit, avec les mêmes cibles, pour tous les acteurs connectés. Comme sur Facebook, il se masque quand on descend dans une page et
/// réapparaît dès qu'on remonte.
/// Nombre de fenêtres modales ouvertes (boîtes de dialogue, feuilles du bas) : le menu s'efface derrière elles.
final ValueNotifier<int> menuModalCount = ValueNotifier<int>(0);

class MenuModalObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) Future.microtask(() => menuModalCount.value++);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) Future.microtask(() => menuModalCount.value = (menuModalCount.value - 1).clamp(0, 99));
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) Future.microtask(() => menuModalCount.value = (menuModalCount.value - 1).clamp(0, 99));
  }
}

class SharedBottomMenu extends ConsumerStatefulWidget {
  const SharedBottomMenu({super.key, required this.router, required this.child});
  final GoRouter router;
  final Widget child;

  /// Hauteur réservée en bas des pages écrites à la main (menu 64 + marges).
  static const reserve = 84.0;

  /// Les pages `/s/...` ont leur propre menu ; ces routes n'en veulent pas (paiement, partage de CV public, outils internes).
  static bool eligible(String path) {
    if (path == '/' || path.startsWith('/s/') || path.startsWith('/cv/') || path.startsWith('/invitation/')) return false;
    const exclues = {'/paiement', '/catalogue', '/design', '/integrations/api', '/comptes-test'};
    return !exclues.contains(path);
  }

  static const targets = ['231', '52', '03', '244', '10'];

  @override
  ConsumerState<SharedBottomMenu> createState() => _SharedBottomMenuState();
}

class _SharedBottomMenuState extends ConsumerState<SharedBottomMenu> {
  bool _shown = true;
  String _path = '';

  @override
  void initState() {
    super.initState();
    widget.router.routerDelegate.addListener(_onRoute);
    menuModalCount.addListener(_onModal);
    _path = _currentPath();
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_onRoute);
    menuModalCount.removeListener(_onModal);
    super.dispose();
  }

  String _currentPath() {
    try {
      return widget.router.routeInformationProvider.value.uri.path;
    } catch (_) {
      return '';
    }
  }

  void _onModal() {
    if (mounted) setState(() {});
  }

  void _onRoute() {
    final p = _currentPath();
    if (p == _path || !mounted) return;
    setState(() {
      _path = p;
      _shown = true;
    });
  }

  bool _onScroll(ScrollNotification n) {
    if (n is! ScrollUpdateNotification || n.metrics.axis != Axis.vertical) return false;
    final d = n.scrollDelta ?? 0;
    // visible en haut de page, en remontant, et tout en bas (fin de page atteinte) ; masqué en descendant
    final shown = n.metrics.pixels <= 24 || d < -6 || n.metrics.extentAfter <= 2 ? true : (d > 6 ? false : _shown);
    if (shown != _shown) setState(() => _shown = shown);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final loggedIn = ref.watch(authProvider.select((a) => a.current != null));
    final active = loggedIn && SharedBottomMenu.eligible(_path) && mq.size.width < 700 && !KioskTerminal.active && mq.viewInsets.bottom == 0;
    if (!active) return widget.child;
    final padded = MediaQuery(
      data: mq.copyWith(padding: mq.padding + const EdgeInsets.only(bottom: SharedBottomMenu.reserve), viewPadding: mq.viewPadding + const EdgeInsets.only(bottom: SharedBottomMenu.reserve)),
      child: widget.child,
    );
    return Stack(children: [
      Positioned.fill(child: NotificationListener<ScrollNotification>(onNotification: _onScroll, child: padded)),
      Positioned(
        left: 0,
        right: 0,
        bottom: mq.padding.bottom + 10,
        child: IgnorePointer(
          ignoring: !_shown || menuModalCount.value > 0,
          child: AnimatedSlide(
            key: const ValueKey('menu-bas-commun'),
            offset: _shown && menuModalCount.value == 0 ? Offset.zero : const Offset(0, 1.6),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: Center(child: _Pill(onTap: (i) => widget.router.go(screenPath(SharedBottomMenu.targets[i])))),
          ),
        ),
      ),
    ]);
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.onTap});
  final void Function(int index) onTap;

  static const _labels = ['Kéla', 'Messages', 'Accueil', 'Réseau social', 'Profil'];

  Widget _glyph(int k) => switch (k) {
        0 => Image.asset('assets/figma/img/2b51b5d6469cca917952ac344a2ddf9cc1440830.png', width: 30, height: 30, fit: BoxFit.contain),
        1 => const Icon(Icons.chat_bubble_outline, size: 23, color: Color(0xFF111015)),
        2 => const Icon(Icons.home_rounded, size: 25, color: Color(0xFF111015)),
        3 => const Icon(Icons.groups_outlined, size: 25, color: Color(0xFF111015)),
        _ => const Icon(Icons.person_outline, size: 25, color: Color(0xFF111015)),
      };

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 346),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 64,
            margin: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: const Color(0x6BFFFFFF),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: const [BoxShadow(color: Color(0x29403366), offset: Offset(0, 10), blurRadius: 24)],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              for (var k = 0; k < 5; k++)
                Semantics(
                  button: true,
                  label: _labels[k],
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(k),
                    child: SizedBox(width: 50, height: 50, child: Center(child: _glyph(k))),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
