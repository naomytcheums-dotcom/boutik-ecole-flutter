import 'package:flutter/material.dart' hide Text;

import '../i18n.dart' show Text;

/// Fonds design des publications d'une communauté (comme sur Facebook) : le texte court se pose en gros, centré, sur un fond au choix.
/// Quatre familles : colorés et dégradés, fonds IUT, fonds fun, fonds sobres pour les annonces sérieuses.
class PostStyle {
  const PostStyle(this.key, this.label, this.colors, {this.dark = false});
  final String key, label;
  final List<Color> colors;

  /// Vrai : texte clair sur fond foncé.
  final bool dark;

  Color get ink => dark ? Colors.white : const Color(0xFF111015);
}

const postStyles = [
  PostStyle('sunset', 'Coucher de soleil', [Color(0xFFFF8A3D), Color(0xFFFF4B6E)], dark: true),
  PostStyle('ocean', 'Océan', [Color(0xFF1E4A80), Color(0xFF4F8CFF)], dark: true),
  PostStyle('forest', 'Forêt', [Color(0xFF1F7A52), Color(0xFF8BC34A)], dark: true),
  PostStyle('night', 'Nuit', [Color(0xFF12121A), Color(0xFF3A2F6B)], dark: true),
  PostStyle('candy', 'Bonbon', [Color(0xFFFF8AD8), Color(0xFFFFC38A)]),
  PostStyle('iut', 'IUT', [Color(0xFF0F2E4E), Color(0xFF1E4A80)], dark: true),
  PostStyle('fun', 'Fun', [Color(0xFFFFC72C), Color(0xFFFF8A3D)]),
  PostStyle('paper', 'Papier', [Color(0xFFF4EFE6), Color(0xFFEEE8F3)]),
  PostStyle('sober', 'Sobre', [Color(0xFFE6E1EE), Color(0xFFE6E1EE)]),
];

PostStyle? postStyleOf(Object? key) {
  for (final s in postStyles) {
    if (s.key == '$key') return s;
  }
  return null;
}

/// Texte d'une publication sur son fond design (gros texte centré) ; sans fond, le texte s'affiche normalement.
class StyledPostText extends StatelessWidget {
  const StyledPostText(this.text, {super.key, this.style, this.minHeight = 170});
  final String text;
  final PostStyle? style;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final s = style;
    if (s == null) return Text(text, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, height: 1.5, color: Color(0xFF111015)));
    final size = text.length <= 60 ? 24.0 : (text.length <= 140 ? 19.0 : 16.0);
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.all(22),
      alignment: Alignment.center,
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: s.colors), borderRadius: BorderRadius.circular(8)),
      child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: FontWeight.w800, height: 1.3, color: s.ink)),
    );
  }
}

/// Choix du fond : pastilles de couleur ; la première (aucune) publie sans fond.
class StylePicker extends StatelessWidget {
  const StylePicker({super.key, required this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 48,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          GestureDetector(
            onTap: () => onChanged(null),
            child: Semantics(
              button: true,
              selected: value == null,
              label: 'Sans fond',
              child: Container(width: 40, height: 40, margin: const EdgeInsets.only(right: 8, top: 4), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: value == null ? const Color(0xFF111015) : const Color(0xFFD9D3E6), width: value == null ? 2.5 : 1.5)), child: const Icon(Icons.format_color_reset_outlined, size: 18)),
            ),
          ),
          for (final s in postStyles)
            GestureDetector(
              onTap: () => onChanged(s.key),
              child: Semantics(
                button: true,
                selected: value == s.key,
                label: 'Fond ${s.label}',
                child: Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(right: 8, top: 4),
                  decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: s.colors), border: Border.all(color: value == s.key ? const Color(0xFF111015) : Colors.white, width: value == s.key ? 2.5 : 1.5)),
                ),
              ),
            ),
        ]),
      );
}

/// Sondage d'une communauté : une barre par réponse avec le nombre de votes ; toucher une réponse vote (modifiable).
class PollView extends StatelessWidget {
  const PollView({super.key, required this.question, required this.poll, required this.onVote, this.style});
  final String question;
  final Map<String, dynamic> poll;
  final ValueChanged<int> onVote;
  final PostStyle? style;

  @override
  Widget build(BuildContext context) {
    final options = [for (final o in (poll['options'] as List? ?? const [])) Map<String, dynamic>.from(o as Map)];
    final total = (poll['total'] as num?)?.toInt() ?? 0;
    final mine = (poll['mine'] as num?)?.toInt();
    final s = style;
    final ink = s?.ink ?? const Color(0xFF111015);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: s == null ? null : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: s.colors),
        color: s == null ? const Color(0xFFF7F4FA) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(question, style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 15, fontWeight: FontWeight.w800, height: 1.35, color: ink)),
        const SizedBox(height: 10),
        for (var i = 0; i < options.length; i++)
          Builder(builder: (_) {
            final votes = (options[i]['votes'] as num?)?.toInt() ?? 0;
            final pct = total == 0 ? 0.0 : votes / total;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onVote(i),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                height: 40,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(6), border: Border.all(color: mine == i ? const Color(0xFF111015) : const Color(0xFFE6E1EE), width: mine == i ? 2 : 1)),
                child: Stack(children: [
                  FractionallySizedBox(widthFactor: pct.clamp(0.0, 1.0), child: Container(decoration: BoxDecoration(color: const Color(0xFFDDD5F5), borderRadius: BorderRadius.circular(5)))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(children: [
                      if (mine == i) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.check_circle, size: 16, color: Color(0xFF111015))),
                      Expanded(child: Text('${options[i]['label']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111015)))),
                      Text('$votes', style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF57545F))),
                    ]),
                  ),
                ]),
              ),
            );
          }),
        Text('$total vote${total > 1 ? 's' : ''}${mine == null ? ' · touchez une réponse pour voter' : ''}', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11.5, color: ink.withValues(alpha: 0.8))),
      ]),
    );
  }
}
