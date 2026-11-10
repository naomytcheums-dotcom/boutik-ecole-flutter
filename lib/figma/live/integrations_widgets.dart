import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';


/// Éléments visuels communs du hub d'intégrations (cohérents avec le reste de l'application : encre #111015, accent #5A3FE0, cartes blanches pleines).
const kInk = Color(0xFF111015);
const kMuted = Color(0xFF57545F);
const kLine = Color(0xFFEEECE8);
const kAccent = Color(0xFF5A3FE0);
const kOk = Color(0xFF0F7A52);
const kWarn = Color(0xFF93370D);
const kBad = Color(0xFFB42318);

TextStyle intText(double size, {FontWeight weight = FontWeight.w500, Color color = kInk, double? height}) =>
    TextStyle(inherit: false, fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: weight, color: color, height: height, textBaseline: TextBaseline.alphabetic);

/// Fond commun : dégradé de l'application jusqu'aux bords, contenu centré (jamais de cadre de téléphone).
class IntBackground extends StatelessWidget {
  const IntBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]),
        ),
        child: child,
      );
}

/// Page défilante : en-tête (retour, titre, sous-titre) puis contenu.
class IntPage extends StatelessWidget {
  const IntPage({super.key, required this.title, this.subtitle, required this.children, this.bottom, this.onBack, this.trailing});
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? bottom;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: IntBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(children: [
                    Semantics(
                      button: true,
                      label: 'Retour',
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onBack ?? () => Navigator.of(context).maybePop(),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: kLine)),
                          child: const Icon(Icons.arrow_back, size: 18, color: kInk),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title, style: intText(18, weight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
                        if (subtitle != null) Text(subtitle!, style: intText(12, color: kMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                    ?trailing,
                  ]),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    children: children,
                  ),
                ),
                if (bottom != null) Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), child: bottom),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class IntCard extends StatelessWidget {
  const IntCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(14), this.margin = const EdgeInsets.only(bottom: 10), this.semantics});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding, margin;
  final String? semantics;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: kLine)),
      child: child,
    );
    return Padding(
      padding: margin,
      child: onTap == null
          ? body
          : Semantics(
              button: true,
              label: semantics,
              child: InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap, child: body),
            ),
    );
  }
}

/// Étiquette d'état (couleur + texte : l'état n'est jamais porté par la couleur seule).
class IntPill extends StatelessWidget {
  const IntPill(this.text, {super.key, this.color = kMuted});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: intText(11, weight: FontWeight.w700, color: color)),
      );
}

class IntButton extends StatelessWidget {
  const IntButton(this.label, {super.key, required this.onTap, this.filled = true, this.danger = false, this.busy = false, this.icon});
  final String label;
  final VoidCallback? onTap;
  final bool filled, danger, busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = danger ? kBad : (filled ? Colors.white : kInk);
    final enabled = onTap != null && !busy;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: enabled ? onTap : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: filled ? (enabled ? (danger ? kBad : kInk) : const Color(0xFFB9B6C0)) : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
            border: filled ? null : Border.all(color: danger ? kBad : (enabled ? kAccent : kLine), width: 1.5),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
            if (busy)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            else if (icon != null)
              Icon(icon, size: 18, color: filled ? Colors.white : color),
            if (busy || icon != null) const SizedBox(width: 8),
            Flexible(child: Text(label, textAlign: TextAlign.center, style: intText(14, weight: FontWeight.w700, color: filled ? Colors.white : (danger ? kBad : kAccent)))),
          ]),
        ),
      ),
    );
  }
}

class IntField extends StatelessWidget {
  const IntField({super.key, required this.controller, required this.label, this.hint, this.keyboard, this.maxLines = 1, this.onChanged, this.maxLength});
  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboard;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final int? maxLength;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          keyboardType: keyboard,
          maxLines: maxLines,
          maxLength: maxLength,
          onChanged: onChanged,
          style: intText(14),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            counterText: '',
            labelStyle: intText(13, color: kMuted),
            hintStyle: intText(13, color: const Color(0xFF77747F)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kLine)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kLine)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kAccent, width: 1.5)),
          ),
        ),
      );
}

class IntSectionTitle extends StatelessWidget {
  const IntSectionTitle(this.text, {super.key, this.hint});
  final String text;
  final String? hint;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(text, style: intText(14, weight: FontWeight.w700)),
          if (hint != null) Text(hint!, style: intText(11.5, color: kMuted)),
        ]),
      );
}

// ---------------------------------------------------------------- logos

typedef _Brand = ({Color color, FaIconData? icon, String mono});

final _brands = <String, _Brand>{
  'facebook': (color: const Color(0xFF1877F2), icon: FontAwesomeIcons.facebook, mono: 'f'),
  'instagram': (color: const Color(0xFFD62976), icon: FontAwesomeIcons.instagram, mono: 'IG'),
  'linkedin': (color: const Color(0xFF0A66C2), icon: FontAwesomeIcons.linkedin, mono: 'in'),
  'tiktok': (color: const Color(0xFF111015), icon: FontAwesomeIcons.tiktok, mono: 'TT'),
  'youtube': (color: const Color(0xFFFF0000), icon: FontAwesomeIcons.youtube, mono: 'YT'),
  'behance': (color: const Color(0xFF1769FF), icon: FontAwesomeIcons.behance, mono: 'Bē'),
  'google_drive': (color: const Color(0xFF1FA463), icon: FontAwesomeIcons.googleDrive, mono: 'D'),
  'google_docs': (color: const Color(0xFF4285F4), icon: FontAwesomeIcons.fileLines, mono: 'Dc'),
  'google_sheets': (color: const Color(0xFF0F9D58), icon: FontAwesomeIcons.tableCells, mono: 'Sh'),
  'gmail': (color: const Color(0xFFEA4335), icon: FontAwesomeIcons.envelope, mono: 'M'),
  'google_calendar': (color: const Color(0xFF4285F4), icon: FontAwesomeIcons.calendarDays, mono: 'Ag'),
  'onedrive': (color: const Color(0xFF0078D4), icon: FontAwesomeIcons.cloud, mono: 'OD'),
  'dropbox': (color: const Color(0xFF0061FF), icon: FontAwesomeIcons.dropbox, mono: 'Db'),
  'slack': (color: const Color(0xFF4A154B), icon: FontAwesomeIcons.slack, mono: 'S'),
  'discord': (color: const Color(0xFF5865F2), icon: FontAwesomeIcons.discord, mono: 'Dc'),
  'github': (color: const Color(0xFF24292F), icon: FontAwesomeIcons.github, mono: 'GH'),
  'notion': (color: const Color(0xFF111015), icon: FontAwesomeIcons.notion, mono: 'N'),
  'trello': (color: const Color(0xFF0079BF), icon: FontAwesomeIcons.trello, mono: 'T'),
  'teams': (color: const Color(0xFF6264A7), icon: FontAwesomeIcons.microsoft, mono: 'Tm'),
  'mtn_momo': (color: const Color(0xFFFFCB05), icon: null, mono: 'MTN'),
  'orange_money': (color: const Color(0xFFFF7900), icon: null, mono: 'OM'),
};

/// Logo de marque : glyphe officiel Font Awesome (Brands) sur la couleur de la marque ; MTN et Orange en monogramme aux couleurs de l'opérateur.
class IntLogo extends StatelessWidget {
  const IntLogo(this.providerId, {super.key, this.size = 44});
  final String providerId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final b = _brands[providerId] ?? (color: kInk, icon: null, mono: providerId.isEmpty ? '?' : providerId[0].toUpperCase());
    final dark = b.color.computeLuminance() > 0.5;
    final fg = dark ? kInk : Colors.white;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: b.color, borderRadius: BorderRadius.circular(size * 0.26)),
        alignment: Alignment.center,
        child: b.icon != null ? FaIcon(b.icon!, size: size * 0.5, color: fg) : Text(b.mono, style: intText(size * 0.30, weight: FontWeight.w800, color: fg)),
      ),
    );
  }
}
