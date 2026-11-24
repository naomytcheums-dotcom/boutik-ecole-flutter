import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../i18n.dart' show I18n, Text;

/// Bouton « Traduire » d'un message de conversation (CDC 11). La traduction passe par la fonction Edge `translate` : elle vérifie que la personne
/// appartient à la conversation et n'appelle un fournisseur que s'il est configuré ET actif. Sinon : « non configuré », jamais un texte simulé.
enum TranslateStatus { idle, loading, translated, notConfigured, error }

class TranslateOutcome {
  const TranslateOutcome(this.status, {this.text, this.message});
  final TranslateStatus status;
  final String? text, message;
}

const translateNotConfigured = 'La traduction n’est pas configurée pour le moment.';

/// Identifiant serveur d'un message traduisible : texte reçu (pas le sien), déjà enregistré ; sinon null.
int? translatableMessageId({required String id, required String kind, required bool mine, required String status}) {
  if (mine || status != 'ok' || kind != 'text') return null;
  final n = int.tryParse(id);
  return n != null && n > 0 ? n : null;
}

Future<TranslateOutcome> translateMessage(int messageId, String target) async {
  try {
    final r = await Supabase.instance.client.functions.invoke('translate', body: {'message_id': messageId, 'target_lang': target}).timeout(const Duration(seconds: 25));
    final d = r.data;
    final text = d is Map && d['status'] == 'translated' && d['text'] is String ? (d['text'] as String).trim() : '';
    if (text.isEmpty) return const TranslateOutcome(TranslateStatus.error, message: 'La traduction n’a pas pu être obtenue. Réessayez.');
    return TranslateOutcome(TranslateStatus.translated, text: text);
  } on FunctionException catch (e) {
    final d = e.details;
    final code = d is Map ? d['code'] : null;
    final server = d is Map && d['message'] is String ? d['message'] as String : '';
    if (e.status == 503 || code == 'not_configured') return const TranslateOutcome(TranslateStatus.notConfigured, message: translateNotConfigured);
    if (e.status == 401) return const TranslateOutcome(TranslateStatus.error, message: 'Votre session a expiré. Reconnectez-vous pour traduire.');
    return TranslateOutcome(TranslateStatus.error, message: server.isNotEmpty ? server : 'Le service de traduction est momentanément indisponible. Réessayez.');
  } on TimeoutException {
    return const TranslateOutcome(TranslateStatus.error, message: 'La traduction prend trop de temps. Réessayez.');
  } catch (_) {
    return const TranslateOutcome(TranslateStatus.error, message: 'Vérifiez votre connexion puis réessayez.');
  }
}

class TranslateMessageButton extends StatefulWidget {
  const TranslateMessageButton({super.key, required this.messageId, this.alignEnd = false});
  final int messageId;
  final bool alignEnd;
  @override
  State<TranslateMessageButton> createState() => _TranslateMessageButtonState();
}

class _TranslateMessageButtonState extends State<TranslateMessageButton> {
  TranslateStatus _status = TranslateStatus.idle;
  String? _text, _message;
  bool _shown = false;

  static TextStyle _st(double s, Color c, {FontWeight w = FontWeight.w500}) => TextStyle(inherit: false, fontFamily: 'PlusJakartaSans', fontSize: s, fontWeight: w, color: c, height: 1.4, textBaseline: TextBaseline.alphabetic);

  Future<void> _run() async {
    if (_status == TranslateStatus.loading) return;
    setState(() => _status = TranslateStatus.loading);
    final o = await translateMessage(widget.messageId, I18n.lang);
    if (!mounted) return;
    setState(() {
      _status = o.status;
      _text = o.text ?? _text;
      _message = o.message;
      _shown = o.status == TranslateStatus.translated;
    });
  }

  Widget _link(String label, VoidCallback? onTap, {Color color = const Color(0xFF5A3FE0)}) => Semantics(
        button: onTap != null,
        label: label,
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(label, style: _st(10.5, color, w: FontWeight.w600)))),
      );

  @override
  Widget build(BuildContext context) {
    final Widget child;
    switch (_status) {
      case TranslateStatus.idle:
        child = _link('Traduire', _run);
      case TranslateStatus.loading:
        child = Text('Traduction en cours…', style: _st(10.5, const Color(0xFF57545F)));
      case TranslateStatus.notConfigured:
        child = _link('${_message ?? translateNotConfigured} Réessayer', _run, color: const Color(0xFF7A4B00));
      case TranslateStatus.error:
        child = _link('${_message ?? 'Échec de la traduction.'} Réessayer', _run, color: const Color(0xFFD64545));
      case TranslateStatus.translated:
        child = _shown
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Container(
                  constraints: const BoxConstraints(maxWidth: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFFF1ECFF), borderRadius: BorderRadius.circular(14)),
                  child: SelectableText(_text ?? '', style: _st(12, const Color(0xFF111015), w: FontWeight.w500)),
                ),
                _link('Masquer la traduction', () => setState(() => _shown = false)),
              ])
            : _link('Voir la traduction', () => setState(() => _shown = true));
    }
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Align(alignment: widget.alignEnd ? Alignment.centerRight : Alignment.centerLeft, child: child),
    );
  }
}
