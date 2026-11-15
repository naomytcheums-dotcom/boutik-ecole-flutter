import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:go_router/go_router.dart';

import '../gen.dart';
import '../nav.dart';

/// Éléments communs des écrans réels du lot L10 (vœux, duels, ateliers, CV, hackathons) : mêmes couleurs et même gabarit que les écrans de la maquette,
/// mais construits sur des données serveur. La maquette reste servie hors connexion (demoContent).

const l10Ink = Color(0xFF111015);
const l10Grey = Color(0xFF57545F);
const l10Violet = Color(0xFF5A3FE0);

TextStyle l10St(double size, {FontWeight w = FontWeight.w500, Color c = l10Ink, double? h}) =>
    TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c, height: h);

Widget l10Note(double width, String text, {double height = 160}) => Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(text, textAlign: TextAlign.center, style: l10St(13, c: l10Grey, h: 1.5)),
    );

Widget l10Btn(String label, VoidCallback? onTap, {bool dark = true, double? width, bool compact = false}) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: Container(
          width: width,
          padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 18, vertical: compact ? 9 : 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: dark ? l10Ink : Colors.white, borderRadius: BorderRadius.circular(compact ? 16 : 24), border: dark ? null : Border.all(color: const Color(0xFFD9D3E6), width: 1.2)),
          child: Text(label, textAlign: TextAlign.center, style: l10St(compact ? 12.5 : 14, w: FontWeight.w700, c: dark ? Colors.white : l10Ink)),
        ),
      ),
    );

Widget l10Card({required Widget child, VoidCallback? onTap, EdgeInsets padding = const EdgeInsets.all(14)}) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFECE8F2))),
        child: child,
      ),
    );

Widget l10Chip(String text, {Color fill = const Color(0xFFEEE9FF), Color ink = l10Violet}) =>
    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(11)), child: Text(text, style: l10St(11, w: FontWeight.w700, c: ink)));

Widget l10Progress(double ratio) => ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(value: ratio.clamp(0.0, 1.0), minHeight: 8, backgroundColor: const Color(0xFFF2EFF6), valueColor: const AlwaysStoppedAnimation(Color(0xFF6A4DFF))),
    );

List<Map<String, dynamic>> l10Rows(Object? data) => data is List ? [for (final x in data) if (x is Map) Map<String, dynamic>.from(x)] : const [];

/// Paramètre de l'adresse de l'écran (`?wish=…`) ; vide hors routeur (tests, aperçus).
String l10Query(BuildContext context, String key) {
  try {
    return GoRouterState.of(context).uri.queryParameters[key]?.trim() ?? '';
  } catch (_) {
    return '';
  }
}

final _uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
bool l10IsUuid(String s) => _uuid.hasMatch(s);

const _mois = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
const _jours = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];

/// « jeu. 19 nov. · 16 h 30 » en heure locale ; vide si la date est absente ou illisible.
String l10When(Object? iso) {
  final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
  if (d == null) return '';
  final mn = d.minute == 0 ? '' : ' ${d.minute.toString().padLeft(2, '0')}';
  return '${_jours[d.weekday - 1]} ${d.day} ${_mois[d.month - 1]} · ${d.hour} h$mn';
}

String l10Day(Object? iso) {
  final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
  return d == null ? '' : '${d.day} ${_mois[d.month - 1]} ${d.year}';
}

/// Gabarit plein écran d'un écran réel : fond, retour, titre, puis le contenu dans la zone sous l'en-tête.
class L10Screen extends StatelessWidget {
  const L10Screen({super.key, required this.title, required this.child, this.top = 118});
  final String title;
  final Widget child;
  final double top;

  @override
  Widget build(BuildContext context) {
    const h = 844.0;
    return GScreen(w: 390, h: h, radius: 34, bg: const LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(-110, 575.84, 300, 300, gBox(color: const Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(31, 71, 22, 22, const SizedBox.expand(), tap: () => gBack(context)),
      gP(21.98, 61.98, 40, 40, const GGlassCircle()),
      gP(32.583, 72.583, 12.417, 18.833, gImg('assets/figma/v/65dc27d13237d5.svg')),
      gP(32.583, 79, 18.833, 6, gImg('assets/figma/v/cfefc4b0da4201.svg')),
      gP(76, 70, 290, 26, gText(title, 21, l10Ink, weight: 700)),
      gP(24, top, 342, h - top - 16, child),
    ]);
  }
}
