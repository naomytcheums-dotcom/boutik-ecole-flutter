import 'package:flutter/material.dart' hide Text;

import '../gen.dart' show gDialog;
import '../i18n.dart' show Text;
import 'tp_ui.dart';
import 'top100_admin_common.dart';

/// Formulaire de la console « Classement et talents » : la fenêtre reste ouverte tant que le serveur refuse (le texte du serveur est affiché dans la fenêtre :
/// 2FA requise, motif trop court, mois déjà publié…) et ne se ferme, avec succès, que sur sa confirmation. Rien n'est annoncé réussi si l'écriture échoue.

enum T100Kind { text, multiline, integer, decimal, toggle, choice }

class T100Field {
  const T100Field(this.key, this.label, {this.kind = T100Kind.text, this.initial = '', this.options = const {}, this.required = false, this.maxLength});
  final String key, label, initial;
  final T100Kind kind;
  final Map<String, String> options; // choice : clé → libellé
  final bool required;
  final int? maxLength;
}

/// Ouvre le formulaire ; [submit] reçoit les valeurs (texte ; « true » / « false » pour un interrupteur). Renvoie vrai si le serveur a confirmé.
Future<bool> top100Form(
  BuildContext context, {
  required String title,
  String? body,
  required List<T100Field> fields,
  required String ok,
  required Future<void> Function(Map<String, String> values) submit,
  String? Function(Map<String, String> values)? validate,
  bool danger = false,
}) async {
  final r = await gDialog<bool>(context: context, builder: (ctx) => _FormDialog(title: title, body: body, fields: fields, ok: ok, submit: submit, validate: validate, danger: danger));
  return r == true;
}

class _FormDialog extends StatefulWidget {
  const _FormDialog({required this.title, required this.body, required this.fields, required this.ok, required this.submit, required this.validate, required this.danger});
  final String title, ok;
  final String? body;
  final List<T100Field> fields;
  final Future<void> Function(Map<String, String>) submit;
  final String? Function(Map<String, String>)? validate;
  final bool danger;

  @override
  State<_FormDialog> createState() => _FormDialogState();
}

class _FormDialogState extends State<_FormDialog> {
  late final Map<String, TextEditingController> _c = {for (final f in widget.fields) if (f.kind != T100Kind.toggle && f.kind != T100Kind.choice) f.key: TextEditingController(text: f.initial)};
  late final Map<String, String> _v = {for (final f in widget.fields) if (f.kind == T100Kind.toggle || f.kind == T100Kind.choice) f.key: f.initial.isEmpty && f.kind == T100Kind.choice ? (f.options.keys.firstOrNull ?? '') : f.initial};
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> get _values => {for (final e in _c.entries) e.key: e.value.text.trim(), ..._v};

  Future<void> _go() async {
    final v = _values;
    for (final f in widget.fields) {
      if (f.required && (v[f.key] ?? '').isEmpty) {
        setState(() => _error = 'Renseignez « ${f.label} ».');
        return;
      }
      final s = v[f.key] ?? '';
      if (s.isNotEmpty && f.kind == T100Kind.integer && int.tryParse(s) == null) {
        setState(() => _error = '« ${f.label} » doit être un nombre entier.');
        return;
      }
      if (s.isNotEmpty && f.kind == T100Kind.decimal && double.tryParse(s.replaceAll(',', '.')) == null) {
        setState(() => _error = '« ${f.label} » doit être un nombre.');
        return;
      }
    }
    final problem = widget.validate?.call(v);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.submit(v);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = top100Msg(e);
        });
      }
    }
  }

  Widget _field(T100Field f) {
    switch (f.kind) {
      case T100Kind.toggle:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(f.label, style: tpSt(13, w: FontWeight.w600)),
          value: _v[f.key] == 'true',
          onChanged: _busy ? null : (b) => setState(() => _v[f.key] = '$b'),
        );
      case T100Kind.choice:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(f.required ? '${f.label} *' : f.label, style: tpSt(12.5, w: FontWeight.w600)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: tpLine)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: f.options.containsKey(_v[f.key]) ? _v[f.key] : null,
                  hint: Text('Choisir', style: tpSt(13, c: tpGrey)),
                  items: [for (final e in f.options.entries) DropdownMenuItem(value: e.key, child: Text(e.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: tpSt(13)))],
                  onChanged: _busy ? null : (s) => setState(() => _v[f.key] = s ?? ''),
                ),
              ),
            ),
          ]),
        );
      case T100Kind.text || T100Kind.multiline || T100Kind.integer || T100Kind.decimal:
        return TpField(
          f.label,
          _c[f.key]!,
          required: f.required,
          lines: f.kind == T100Kind.multiline ? 3 : 1,
          maxLength: f.maxLength,
          keyboard: f.kind == T100Kind.integer ? TextInputType.number : (f.kind == T100Kind.decimal ? const TextInputType.numberWithOptions(decimal: true) : null),
        );
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(widget.title, style: tpSt(16, w: FontWeight.w700)),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (widget.body != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(widget.body!, style: tpSt(13, c: tpGrey, h: 1.5))),
              for (final f in widget.fields) _field(f),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_error!, style: tpSt(12.5, c: tpRed, h: 1.45, w: FontWeight.w600))),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: Text('Annuler', style: tpSt(13.5, c: tpGrey))),
          TextButton(
            onPressed: _busy ? null : _go,
            child: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(widget.ok, style: tpSt(13.5, w: FontWeight.w700, c: widget.danger ? tpRed : tpViolet)),
          ),
        ],
      );
}
