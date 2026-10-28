import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/paths.dart';
import '../theme/app_colors.dart';
import 'app_icon.dart';

enum NavTab { search, messages, home, kela, profile }

/// Menu bas « verre liquide » : barre translucide floutée, Accueil rond sombre au centre.
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({super.key, this.current});

  final NavTab? current;

  static const height = 66.0;

  void _go(BuildContext context, String id) => context.go(screenPath(id));

  @override
  Widget build(BuildContext context) {
    Widget item(NavTab tab, String icon, String label, String target) {
      final active = current == tab;
      return Expanded(
        child: Semantics(
          button: true,
          selected: active,
          label: label,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _go(context, target),
            child: SizedBox(
              height: height,
              child: Center(
                child: AppIcon(
                  icon,
                  size: 24,
                  color: active ? AppColors.accent : AppColors.ink,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height / 2),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.72),
                  const Color(0xFFE9E4EC).withValues(alpha: 0.62),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.2),
            ),
            child: Row(
              children: [
                item(NavTab.search, 'assets/icons/search.svg', 'Recherche', NavTargets.search),
                item(NavTab.messages, 'assets/icons/message-circle.svg', 'Messages', NavTargets.messages),
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: current == NavTab.home,
                    label: 'Accueil',
                    child: GestureDetector(
                      onTap: () => _go(context, NavTargets.home),
                      child: const Center(child: _HomeOrb()),
                    ),
                  ),
                ),
                item(NavTab.kela, 'assets/icons/mic.svg', 'Kéla, assistant vocal', NavTargets.kela),
                item(NavTab.profile, 'assets/icons/user.svg', 'Profil', NavTargets.profile),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeOrb extends StatelessWidget {
  const _HomeOrb();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      padding: const EdgeInsets.all(2.5),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [
            Color(0xFFFF8A65),
            Color(0xFFF06292),
            Color(0xFF7986CB),
            Color(0xFF64B5F6),
            Color(0xFFFFB74D),
            Color(0xFFFF8A65),
          ],
        ),
        boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [Color(0xFF2A2833), AppColors.ink],
          ),
        ),
        alignment: Alignment.center,
        child: const AppIcon('assets/icons/house.svg', size: 24, color: Colors.white),
      ),
    );
  }
}
