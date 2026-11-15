import 'package:flutter/material.dart' hide Text;
import '../gen.dart' show gDialog;
import '../i18n.dart' show Text;

/// Éléments communs aux écrans talents, opportunités, mentors et communautés : message centré avec action, confirmation.

const l8Ink = Color(0xFF111015);
const l8Grey = Color(0xFF57545F);
const l8Violet = Color(0xFF5A3FE0);

TextStyle l8St(double size, {FontWeight w = FontWeight.w500, Color c = l8Ink}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

/// Message centré (chargement, vide, erreur), avec un bouton facultatif.
Widget l8Note(double width, String text, {double height = 190, String? action, VoidCallback? onAction}) => Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(text, textAlign: TextAlign.center, style: l8St(12.5, c: l8Grey).copyWith(height: 1.5)),
        if (action != null) ...[
          const SizedBox(height: 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAction,
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: l8Ink, borderRadius: BorderRadius.circular(22)),
              child: Text(action, style: l8St(12.5, w: FontWeight.w600, c: Colors.white)),
            ),
          ),
        ],
      ]),
    );

Widget l8Pill(String label, {Color bg = const Color(0xFFEFEBFA), Color fg = l8Violet, VoidCallback? onTap}) {
  final pill = Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)), child: Text(label, style: l8St(11, w: FontWeight.w600, c: fg)));
  return onTap == null
      ? pill
      : GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 44), child: Center(widthFactor: 1, child: pill)),
        );
}

Future<bool> l8Confirm(BuildContext context, String title, String body, {String keep = 'Annuler', String go = 'Confirmer'}) async {
  final r = await gDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(title, style: l8St(16, w: FontWeight.w700)),
      content: Text(body, style: l8St(13.5, c: l8Grey).copyWith(height: 1.45)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(keep, style: l8St(13.5))),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(go, style: l8St(13.5, w: FontWeight.w700, c: l8Violet))),
      ],
    ),
  );
  return r == true;
}

const l8Months = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

String l8Date(Object? iso) {
  final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
  return d == null ? '' : '${d.day} ${l8Months[d.month - 1]} ${d.year}';
}
