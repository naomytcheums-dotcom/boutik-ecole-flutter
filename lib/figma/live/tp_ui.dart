import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../gen.dart' show gToast;
import 'backend.dart';
import 'profile_data.dart' show mimeFromName, sizeLabel;

/// Éléments d'interface communs aux pages « réelles » (talents, portfolio, projets, services) : fond de page, champs vides (jamais
/// d'exemple prérempli), sélecteurs extensibles, pastilles de choix et sélection de fichiers contrôlée.

const tpInk = Color(0xFF111015);
const tpGrey = Color(0xFF57545F);
const tpViolet = Color(0xFF5A3FE0);
const tpLine = Color(0xFFE4E0EC);
const tpRed = Color(0xFFC0261B);
const tpGreen = Color(0xFF0F7A52);

TextStyle tpSt(double size, {FontWeight w = FontWeight.w500, Color c = tpInk, double? h}) =>
    TextStyle(inherit: false, fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c, height: h, textBaseline: TextBaseline.alphabetic);

const tpBackground = BoxDecoration(
  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, .5, 1]),
);

/// Page plein écran : fond du site, flèche retour fonctionnelle, titre, contenu défilant et barre d'action fixe optionnelle.
class TpPage extends StatelessWidget {
  const TpPage({super.key, required this.title, required this.children, this.bottom, this.actions = const [], this.subtitle});
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? bottom;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4EFE6),
      resizeToAvoidBottomInset: true,
      body: DecoratedBox(
        decoration: tpBackground,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                  child: Row(children: [
                    TpRound(icon: Icons.arrow_back_ios_new_rounded, label: 'Retour', onTap: () => Navigator.of(context).maybePop()),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: tpSt(20, w: FontWeight.w700)),
                        if (subtitle != null) Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: tpSt(12, c: tpGrey)),
                      ]),
                    ),
                    ...actions,
                  ]),
                ),
                Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(20, 10, 20, 28), keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, children: children)),
                if (bottom != null) Padding(padding: const EdgeInsets.fromLTRB(20, 6, 20, 14), child: bottom),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton rond (retour, action) sur le fond de page.
class TpRound extends StatelessWidget {
  const TpRound({super.key, required this.icon, required this.onTap, this.label = ''});
  final IconData icon;
  final VoidCallback onTap;
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: const Color(0x8CFFFFFF), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
            child: Icon(icon, size: 18, color: tpInk),
          ),
        ),
      );
}

class TpButton extends StatelessWidget {
  const TpButton(this.label, this.onTap, {super.key, this.dark = true, this.busy = false, this.icon, this.compact = false, this.danger = false});
  final String label;
  final VoidCallback? onTap;
  final bool dark, busy, compact, danger;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final fg = danger ? tpRed : (dark ? Colors.white : tpInk);
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: busy ? null : onTap,
        child: Opacity(
          opacity: onTap == null ? .5 : 1,
          child: Container(
            height: compact ? 40 : 52,
            padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 22),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: danger ? Colors.white : (dark ? tpInk : const Color(0xB3FFFFFF)),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: danger ? tpRed : (dark ? tpInk : Colors.white), width: 1.5),
            ),
            child: busy
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
                : Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 8)],
                    Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tpSt(compact ? 13 : 15, w: FontWeight.w600, c: fg))),
                  ]),
          ),
        ),
      ),
    );
  }
}

Widget tpSection(String t, {String? hint}) => Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t, style: tpSt(15, w: FontWeight.w700)),
        if (hint != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(hint, style: tpSt(12, c: tpGrey, h: 1.4))),
      ]),
    );

Widget tpNote(String t, {Color c = tpGrey}) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(t, style: tpSt(12.5, c: c, h: 1.5)));

/// État vide avec action (jamais un lien mort).
class TpEmpty extends StatelessWidget {
  const TpEmpty({super.key, required this.title, required this.text, this.action, this.onAction, this.icon = Icons.folder_open_rounded});
  final String title, text;
  final String? action;
  final VoidCallback? onAction;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 8),
        child: Column(children: [
          Icon(icon, size: 40, color: tpViolet),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: tpSt(16, w: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(text, textAlign: TextAlign.center, style: tpSt(13, c: tpGrey, h: 1.5)),
          if (action != null && onAction != null) ...[const SizedBox(height: 18), TpButton(action!, onAction, icon: Icons.add_rounded)],
        ]),
      );
}

/// Carte blanche translucide.
class TpCard extends StatelessWidget {
  const TpCard({super.key, required this.child, this.onTap, this.margin = const EdgeInsets.only(bottom: 12)});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets margin;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: margin,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xCCFFFFFF), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white, width: 1.5)),
          child: child,
        ),
      );
}

InputDecoration _dec() => InputDecoration(
      isDense: true,
      filled: true,
      fillColor: const Color(0xCCFFFFFF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: tpLine)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: tpLine)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: tpViolet, width: 1.5)),
    );

/// Champ avec libellé au-dessus et AUCUN texte d'exemple.
class TpField extends StatelessWidget {
  const TpField(this.label, this.c, {super.key, this.lines = 1, this.keyboard, this.maxLength, this.required = false, this.formatters, this.onChanged});
  final String label;
  final TextEditingController c;
  final int lines;
  final TextInputType? keyboard;
  final int? maxLength;
  final bool required;
  final List<TextInputFormatter>? formatters;
  final ValueChanged<String>? onChanged;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(required ? '$label *' : label, style: tpSt(12.5, w: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: c,
            minLines: lines,
            maxLines: lines == 1 ? 1 : lines + 3,
            keyboardType: keyboard ?? (lines > 1 ? TextInputType.multiline : TextInputType.text),
            maxLength: maxLength,
            inputFormatters: formatters,
            onChanged: onChanged,
            style: tpSt(14, w: FontWeight.w500),
            decoration: _dec().copyWith(counterText: ''),
          ),
        ]),
      );
}

/// Champ à choix (fenêtre de sélection avec recherche et saisie libre pour étendre la liste).
class TpSelect extends StatelessWidget {
  const TpSelect(this.label, this.value, this.options, this.onChanged, {super.key, this.required = false, this.allowCustom = true, this.customLabel = 'Autre (saisir)', this.enabled = true, this.emptyHint});
  final String label, value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final bool required, allowCustom, enabled;
  final String customLabel;
  final String? emptyHint;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(required ? '$label *' : label, style: tpSt(12.5, w: FontWeight.w600)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: !enabled
                ? () {
                    if (emptyHint != null) gToast(context, emptyHint!);
                  }
                : () async {
                    final v = await tpPick(context, label, options, allowCustom: allowCustom, customLabel: customLabel, current: value);
                    if (v != null) onChanged(v);
                  },
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: enabled ? const Color(0xCCFFFFFF) : const Color(0x66FFFFFF), borderRadius: BorderRadius.circular(16), border: Border.all(color: tpLine)),
              child: Row(children: [
                Expanded(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: tpSt(14))),
                const Icon(Icons.keyboard_arrow_down_rounded, color: tpGrey),
              ]),
            ),
          ),
        ]),
      );
}

/// Fenêtre de sélection : recherche, liste, et « Autre » pour saisir une valeur absente de la liste.
Future<String?> tpPick(BuildContext context, String title, List<String> options, {bool allowCustom = true, String customLabel = 'Autre (saisir)', String current = ''}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => _PickSheet(title: title, options: options, allowCustom: allowCustom, customLabel: customLabel, current: current),
  );
}

class _PickSheet extends StatefulWidget {
  const _PickSheet({required this.title, required this.options, required this.allowCustom, required this.customLabel, required this.current});
  final String title, customLabel, current;
  final List<String> options;
  final bool allowCustom;
  @override
  State<_PickSheet> createState() => _PickSheetState();
}

class _PickSheetState extends State<_PickSheet> {
  final q = TextEditingController();
  bool custom = false;
  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = q.text.trim().toLowerCase();
    final shown = [for (final o in widget.options) if (f.isEmpty || o.toLowerCase().contains(f)) o];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .8),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 8), child: Text(widget.title, style: tpSt(18, w: FontWeight.w700))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: q,
                autofocus: custom,
                onChanged: (_) => setState(() {}),
                onSubmitted: (v) {
                  if (custom && v.trim().length >= 2) Navigator.of(context).pop(v.trim());
                },
                style: tpSt(14),
                decoration: _dec().copyWith(prefixIcon: Icon(custom ? Icons.edit_outlined : Icons.search, size: 20, color: tpGrey), labelText: custom ? 'Votre saisie' : 'Rechercher'),
              ),
            ),
            if (custom)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: TpButton('Utiliser « ${q.text.trim()} »', q.text.trim().length >= 2 ? () => Navigator.of(context).pop(q.text.trim()) : null),
              )
            else
              Flexible(
                child: ListView(shrinkWrap: true, children: [
                  for (final o in shown)
                    ListTile(
                      dense: true,
                      title: Text(o, style: tpSt(14.5, w: o == widget.current ? FontWeight.w700 : FontWeight.w500)),
                      trailing: o == widget.current ? const Icon(Icons.check, color: tpViolet) : null,
                      onTap: () => Navigator.of(context).pop(o),
                    ),
                  if (shown.isEmpty && !widget.allowCustom) Padding(padding: const EdgeInsets.all(20), child: Text('Aucun résultat.', style: tpSt(13, c: tpGrey))),
                  if (widget.allowCustom)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.add_circle_outline, color: tpViolet),
                      title: Text(widget.customLabel, style: tpSt(14.5, w: FontWeight.w700, c: tpViolet)),
                      onTap: () => setState(() {
                        custom = true;
                        q.clear();
                      }),
                    ),
                ]),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Pastilles à choix unique.
class TpChoice extends StatelessWidget {
  const TpChoice(this.label, this.options, this.value, this.onChanged, {super.key, this.required = false});
  final String label;
  final Map<String, String> options; // clé → libellé
  final String value;
  final ValueChanged<String> onChanged;
  final bool required;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(required ? '$label *' : label, style: tpSt(12.5, w: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in options.entries)
              GestureDetector(
                onTap: () => onChanged(e.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: e.key == value ? tpInk : const Color(0xCCFFFFFF),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: e.key == value ? tpInk : tpLine),
                  ),
                  child: Text(e.value, style: tpSt(13, w: FontWeight.w600, c: e.key == value ? Colors.white : tpInk)),
                ),
              ),
          ]),
        ]),
      );
}

/// Fichier choisi par la personne (octets lus, type vérifié).
class PickedFile {
  PickedFile(this.name, this.bytes, this.mime);
  final String name;
  final Uint8List bytes;
  final String mime;
  String get safeName => name.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
}

const _extMime = {
  'pdf': 'application/pdf', 'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'webp': 'image/webp',
  'mp4': 'video/mp4', 'webm': 'video/webm', 'mov': 'video/quicktime',
};

String? mediaMime(String name) => _extMime[name.toLowerCase().split('.').last] ?? mimeFromName(name);

/// Ouvre le sélecteur de fichiers puis contrôle le type et la taille. [images]/[videos]/[pdf] décident des formats acceptés.
Future<PickedFile?> tpPickFile(BuildContext context, {bool images = true, bool videos = false, bool pdf = false, int maxMb = 10}) async {
  final exts = [if (images) ...['jpg', 'jpeg', 'png', 'webp'], if (videos) ...['mp4', 'webm', 'mov'], if (pdf) 'pdf'];
  try {
    final r = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: exts);
    if (r.isEmpty) return null;
    final name = r.first.name;
    final bytes = await r.first.readAsBytes();
    final mime = mediaMime(name);
    if (!context.mounted) return null;
    if (mime == null || !exts.contains(name.toLowerCase().split('.').last)) {
      gToast(context, 'Format refusé. Formats acceptés : ${exts.map((e) => e.toUpperCase()).join(', ')}.');
      return null;
    }
    if (bytes.isEmpty) {
      gToast(context, 'Le fichier est vide.');
      return null;
    }
    if (bytes.length > maxMb * 1024 * 1024) {
      gToast(context, 'Fichier trop lourd (${sizeLabel(bytes.length)}) : $maxMb Mo au maximum.');
      return null;
    }
    return PickedFile(name, bytes, mime);
  } catch (_) {
    if (context.mounted) gToast(context, 'Impossible d’ouvrir le sélecteur de fichiers. Autorisez l’accès aux fichiers dans les réglages.');
    return null;
  }
}

/// Envoie le fichier dans [bucket] sous « utilisateur/dossier/horodatage-nom » ; renvoie le chemin, ou null (message affiché).
Future<String?> tpUpload(BuildContext context, String bucket, String folder, PickedFile f) async {
  final uid = Backend.userId;
  if (uid == null) {
    gToast(context, 'Connexion requise.');
    return null;
  }
  final path = '$uid/$folder/${DateTime.now().microsecondsSinceEpoch}-${f.safeName}';
  final err = await Backend.uploadFile(bucket, path, f.bytes, f.mime);
  if (err != null) {
    if (context.mounted) gToast(context, err);
    return null;
  }
  return path;
}

Future<void> tpOpenUrl(BuildContext context, String url) async {
  var u = url.trim();
  if (u.isEmpty) return;
  if (!u.startsWith('http://') && !u.startsWith('https://')) u = 'https://$u';
  final ok = await launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) gToast(context, 'Impossible d’ouvrir ce lien.');
}

bool tpValidUrl(String s) {
  final u = Uri.tryParse(s.trim());
  return u != null && (u.scheme == 'http' || u.scheme == 'https') && u.host.contains('.');
}

Future<bool> tpConfirm(BuildContext context, String title, String text, {String yes = 'Supprimer'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text(title, style: tpSt(17, w: FontWeight.w700)),
      content: Text(text, style: tpSt(14, c: tpGrey, h: 1.45)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: Text('Annuler', style: tpSt(14, w: FontWeight.w600, c: tpGrey))),
        TextButton(onPressed: () => Navigator.pop(d, true), child: Text(yes, style: tpSt(14, w: FontWeight.w700, c: tpRed))),
      ],
    ),
  );
  return r == true;
}

String tpDate(Object? iso) {
  final d = DateTime.tryParse('$iso')?.toLocal();
  if (d == null) return '';
  const m = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}
