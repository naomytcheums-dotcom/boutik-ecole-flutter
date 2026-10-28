import 'package:flutter/widgets.dart';

/// Palette Boutik-École (COPILOT_PROMPT.md · design system).
abstract final class AppColors {
  static const ink = Color(0xFF111015);
  static const textSecondary = Color(0xFF66636E);
  static const accent = Color(0xFF5A3FE0);
  static const accentSoft = Color(0xFFEDE9FC);
  static const success = Color(0xFF0F7A52);
  static const successSoft = Color(0xFFE3F4EC);
  static const warning = Color(0xFF8F5400);
  static const warningSoft = Color(0xFFFCF0DC);
  static const error = Color(0xFFB42318);
  static const errorSoft = Color(0xFFFDECEA);

  static const card = Color(0xFFFFFFFF);
  static const cardBorder = Color(0xFFEEECE8);
  static const field = Color(0xFFF4F2EF);

  static const bgTop = Color(0xFFF4EFE6);
  static const bgMiddle = Color(0xFFEEE8F3);
  static const bgBottom = Color(0xFFF7E6D6);

  static const webBackground = Color(0xFFF7F6F4);
  static const webSidebar = Color(0xFFF1EFEC);

  static const backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgTop, bgMiddle, bgBottom],
  );

  static const sunGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF6C84E), Color(0xFFFAE29E), Color(0xFFF6C454)],
  );
}

/// Dimensions communes.
abstract final class AppSizes {
  static const minTouch = 44.0;
  static const buttonHeight = 52.0;
  static const radiusCard = 24.0;
  static const radiusField = 16.0;
  static const sidebarWidth = 240.0;
  static const mobileWidth = 390.0;
  static const pagePadding = 20.0;
}
