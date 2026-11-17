import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../gen.dart' show gToast;
import '../i18n.dart' show Text;
import 'backend.dart';
import 'entreprise.dart' show invalidateCompanyData;
import 'f4_api.dart';
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';
import 'services.dart' show parseFcfa, quoteAmountError, quoteStatusLabel;

/// Négociation d'un devis : le fil réel du devis (demande, devis, contre-propositions de prix et de délai, messages, décision) et les actions
/// possibles selon le rôle et le statut. Fonctions serveur : quote_thread, quote_message_send (migration 20261118040200), answer_quote,
/// decide_quote, decline_quote, cancel_quote, quote_checkout.

/// Ouvre le fil de négociation du devis [quote] (au moins son `id`, par exemple une ligne de my_quotes).
Future<void> openQuoteNegotiation(BuildContext context, WidgetRef ref, Map<String, dynamic> quote) async {
  final id = '${quote['id'] ?? quote['quote_id'] ?? ''}';
  if (id.isEmpty) return;
  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => QuoteNegotiationScreen(quoteId: id, seed: quote)));
}

String _fcfa(num v) => '${v.toInt().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ')} FCFA';

String _stamp(String iso) {
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  String t(int n) => n.toString().padLeft(2, '0');
  return '${t(d.day)}/${t(d.month)} ${t(d.hour)}:${t(d.minute)}';
}

class QuoteNegotiationScreen extends ConsumerStatefulWidget {
  const QuoteNegotiationScreen({super.key, required this.quoteId, this.seed = const {}});
  final String quoteId;
  final Map<String, dynamic> seed;

  @override
  ConsumerState<QuoteNegotiationScreen> createState() => _NegotiationState();
}

class _NegotiationState extends ConsumerState<QuoteNegotiationScreen> {
  final _input = TextEditingController(), _scroll = ScrollController();
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true, _sending = false, _acting = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
    _poll = Timer.periodic(const Duration(seconds: 25), (_) {
      if (!_sending && !_acting) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final r = await _rpc('quote_thread', {'p_quote': widget.quoteId});
    if (!mounted) return;
    if (r.error != null || r.data is! Map) {
      if (silent && _data != null) return;
      setState(() {
        _loading = false;
        _error = r.error == 'offline' || r.error == 'missing' ? marcheErrorText(r.error) : Backend.userMessage(r.error ?? 'Ce devis est introuvable.');
      });
      return;
    }
    final before = (_data?['messages'] as List?)?.length ?? -1;
    setState(() {
      _data = Map<String, dynamic>.from(r.data as Map);
      _loading = false;
      _error = null;
    });
    if (before != ((_data!['messages'] as List).length)) _toEnd();
  }

  void _toEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });

  Future<({Object? data, String? error})> _rpc(String fn, Map<String, dynamic> params) => ref.read(f4RpcProvider)(fn, params);
  Future<String?> _call(String fn, Map<String, dynamic> params) async => (await _rpc(fn, params)).error;

  Map<String, dynamic> get _quote => Map<String, dynamic>.from((_data?['quote'] as Map?) ?? const {});
  Map<String, dynamic> get _can => Map<String, dynamic>.from((_data?['can'] as Map?) ?? const {});
  String get _role => '${_data?['my_role'] ?? ''}';

  Future<void> _send() async {
    final body = _input.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    final r = await _rpc('quote_message_send', {'p_quote': widget.quoteId, 'p_body': body});
    if (!mounted) return;
    setState(() => _sending = false);
    if (r.error != null) return gToast(context, Backend.userMessage('${r.error}'));
    _input.clear();
    await _load(silent: true);
  }

  /// Exécute une action de décision, puis relit le fil : le message de succès n'apparaît que si le serveur a accepté.
  Future<void> _act(Future<String?> Function() run, String done) async {
    setState(() => _acting = true);
    final err = await run();
    if (!mounted) return;
    setState(() => _acting = false);
    if (err != null) return gToast(context, Backend.userMessage(err));
    invalidateCompanyData(context);
    gToast(context, done);
    await _load(silent: true);
  }

  Future<bool> _confirm(String title, String body, String ok) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Retour')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ok))],
        ),
      ) ==
      true;

  Future<void> _accept() async {
    final q = _quote;
    final amount = (q['quote_amount'] as num?)?.toInt();
    if (!await _confirm('Accepter ce devis ?', 'Montant du devis : ${amount == null ? 'non indiqué' : _fcfa(amount)}${q['quote_delay_days'] == null ? '' : ' · délai ${q['quote_delay_days']} jour(s)'}.\nLe prestataire sera prévenu. Rien n’est payé maintenant.', 'Accepter ce montant') || !mounted) return;
    await _act(() => _call('decide_quote', {'p_id': widget.quoteId, 'p_accept': true, 'p_amount': ?amount}), 'Devis accepté. Le prestataire est prévenu.');
  }

  Future<void> _refuse() async {
    if (!await _confirm('Refuser ce devis ?', 'Le prestataire sera prévenu. Vous pourrez faire une nouvelle demande.', 'Refuser') || !mounted) return;
    await _act(() => _call('decide_quote', {'p_id': widget.quoteId, 'p_accept': false}), 'Devis refusé.');
  }

  Future<void> _cancel() async {
    if (!await _confirm('Annuler la demande ?', 'La demande est close : le prestataire n’a plus à répondre.', 'Annuler la demande') || !mounted) return;
    await _act(() => _call('cancel_quote', {'p_id': widget.quoteId}), 'Demande annulée.');
  }

  Future<void> _checkout() async {
    setState(() => _acting = true);
    final r = await _rpc('quote_checkout', {'p_quote': widget.quoteId});
    if (!mounted) return;
    setState(() => _acting = false);
    if (r.error != null) return gToast(context, Backend.userMessage('${r.error}'));
    final d = r.data is Map ? Map<String, dynamic>.from(r.data as Map) : const <String, dynamic>{};
    gToast(context, d['existing'] == true ? 'La commande ${d['number']} existe déjà : payez-la depuis « Mes commandes ».' : 'Commande ${d['number']} créée au prix du devis. Payez-la depuis « Mes commandes ».');
    await _load(silent: true);
  }

  Future<void> _reject() async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Décliner cette demande ?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Le demandeur est prévenu.'),
          TextField(controller: reason, maxLength: 500, maxLines: 2, decoration: const InputDecoration(labelText: 'Motif (facultatif)')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Retour')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Décliner'))],
      ),
    );
    final why = reason.text.trim();
    if (ok != true || !mounted) return;
    await _act(() => _call('decline_quote', {'p_id': widget.quoteId, 'p_reason': why.isEmpty ? null : why}), 'Demande déclinée : le demandeur est prévenu.');
  }

  Future<void> _revise() async {
    final q = _quote;
    final amount = TextEditingController(text: q['quote_amount']?.toString() ?? ''), days = TextEditingController(text: q['quote_delay_days']?.toString() ?? ''), msg = TextEditingController();
    String? error;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(q['quote_amount'] == null ? 'Votre devis' : 'Votre contre-proposition'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Montant (FCFA)')),
              TextField(controller: days, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Délai (jours)')),
              TextField(controller: msg, maxLines: 3, maxLength: 2000, decoration: const InputDecoration(labelText: 'Message (facultatif)')),
              if (error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(error!, style: mst(12.5, c: kRed))),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler')),
            FilledButton(
              onPressed: () {
                final e = quoteAmountError(amount.text);
                final d = int.tryParse(days.text.trim());
                if (e != null) return set(() => error = e);
                if (d == null || d < 1 || d > 365) return set(() => error = 'Indiquez un délai de 1 à 365 jours.');
                Navigator.pop(ctx, true);
              },
              child: Text('Envoyer'),
            ),
          ],
        ),
      ),
    );
    final a = parseFcfa(amount.text), d = int.tryParse(days.text.trim()), m = msg.text.trim();
    if (go != true || a == null || d == null || !mounted) return;
    await _act(() => _call('answer_quote', {'p_id': widget.quoteId, 'p_amount': a, 'p_delay_days': d, 'p_message': m}), 'Devis envoyé : le demandeur est prévenu.');
  }

  @override
  Widget build(BuildContext context) {
    final seedTitle = '${widget.seed['listing_title'] ?? (widget.seed['listings'] as Map?)?['title'] ?? 'Devis'}';
    return MarchePage(
      title: _data == null ? seedTitle : '${_quote['listing_title'] ?? seedTitle}',
      child: _loading && _data == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _data == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error!, textAlign: TextAlign.center, style: mst(14, c: kGrey).copyWith(height: 1.5)),
                      const SizedBox(height: 14),
                      mButton('Réessayer', _load, dark: false, icon: Icons.refresh_rounded),
                    ]),
                  ),
                )
              : _content(),
    );
  }

  Widget _content() {
    final q = _quote, can = _can;
    final messages = [for (final m in (_data!['messages'] as List? ?? const [])) Map<String, dynamic>.from(m as Map)];
    final status = '${q['status']}';
    final expired = q['expired'] == true;
    final other = _role == 'requester' ? 'Prestataire : ${q['provider_name'] ?? ''}' : (_role == 'provider' ? 'Demandeur : ${q['requester_name'] ?? ''}' : 'Demandeur : ${q['requester_name'] ?? ''} · Prestataire : ${q['provider_name'] ?? ''}');
    final amount = (q['quote_amount'] as num?)?.toInt();
    final until = DateTime.tryParse('${q['valid_until'] ?? ''}')?.toLocal();
    final hasOrder = '${q['order_number'] ?? ''}'.isNotEmpty;
    final actions = <Widget>[
      if (can['accept'] == true) mButton('Accepter ce devis', _acting ? null : _accept, icon: Icons.check_rounded),
      if (can['decline'] == true) mButton('Refuser', _acting ? null : _refuse, dark: false),
      if (can['revise'] == true) mButton(amount == null ? 'Envoyer mon devis' : 'Modifier mon devis', _acting ? null : _revise, icon: Icons.edit_outlined),
      if (can['reject'] == true) mButton('Décliner la demande', _acting ? null : _reject, dark: false),
      if (can['cancel'] == true) mButton('Annuler la demande', _acting ? null : _cancel, dark: false),
      if (_role == 'requester' && status == 'accepted' && !hasOrder) mButton('Commander au prix du devis', _acting ? null : _checkout, icon: Icons.shopping_bag_outlined),
      if (_role == 'requester' && status == 'accepted' && hasOrder) mButton('Voir mes commandes', () => context.push('/s/45'), dark: false),
    ];
    return Column(children: [
      Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: kLine)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(other, maxLines: 2, overflow: TextOverflow.ellipsis, style: mst(12.5, w: FontWeight.w700))),
            const SizedBox(width: 8),
            Text(expired && status == 'quoted' ? quoteStatusLabel('expired') : quoteStatusLabel(status), style: mst(12, w: FontWeight.w700, c: kViolet)),
          ]),
          const SizedBox(height: 4),
          Text('${q['brief'] ?? ''}', maxLines: 3, overflow: TextOverflow.ellipsis, style: mst(12.5, c: kGrey)),
          if (q['budget'] != null) Text('Budget indiqué : ${_fcfa(q['budget'] as num)}', style: mst(12, c: kGrey)),
          if (amount != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Devis : ${_fcfa(amount)} en ${q['quote_delay_days']} jour(s)${status == 'quoted' && until != null && !expired ? ' · valable jusqu’au ${until.day.toString().padLeft(2, '0')}/${until.month.toString().padLeft(2, '0')}/${until.year}' : ''}', style: mst(13.5, w: FontWeight.w800))),
          if (hasOrder) Text('Commande ${q['order_number']}', style: mst(12, w: FontWeight.w700, c: kGreen)),
        ]),
      ),
      if (actions.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Wrap(spacing: 8, runSpacing: 8, children: [for (final a in actions) ConstrainedBox(constraints: const BoxConstraints(minWidth: 140), child: a)]),
        ),
      Expanded(
        child: messages.isEmpty
            ? mNote('Aucun message pour le moment.')
            : ListView.builder(controller: _scroll, padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), itemCount: messages.length, itemBuilder: (_, i) => _Bubble(m: messages[i])),
      ),
      if (can['write'] == true)
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 1000,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(hintText: 'Votre message', counterText: '', filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14), border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: kLine))),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton.filled(tooltip: 'Envoyer', style: IconButton.styleFrom(backgroundColor: kInk), onPressed: _sending ? null : _send, icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded, color: Colors.white, size: 20)),
              ),
            ]),
          ),
        )
      else
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          child: Text(_role == 'staff' ? 'Lecture seule : vous consultez ce fil en tant que gestionnaire.' : 'Cette demande est clôturée : le fil n’accepte plus de message.', textAlign: TextAlign.center, style: mst(12.5, c: kGrey)),
        ),
    ]);
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.m});
  final Map<String, dynamic> m;

  @override
  Widget build(BuildContext context) {
    final event = m['kind'] == 'event', mine = m['mine'] == true;
    final when = _stamp('${m['created_at']}');
    if (event) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFEFEBFA), borderRadius: BorderRadius.circular(8)),
            child: Text('${m['body']}', textAlign: TextAlign.center, style: mst(12.5, w: FontWeight.w600, c: const Color(0xFF3B2AA8)).copyWith(height: 1.4)),
          ),
          if (when.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(when, style: mst(10.5, c: kGrey))),
        ]),
      );
    }
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: mine ? kInk : Colors.white, borderRadius: BorderRadius.circular(14), border: mine ? null : Border.all(color: kLine)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (!mine && '${m['sender_name'] ?? ''}'.isNotEmpty) Text('${m['sender_name']}', style: mst(11, w: FontWeight.w700, c: kViolet)),
            Text('${m['body']}', style: mst(13.5, c: mine ? Colors.white : kInk).copyWith(height: 1.4)),
            Align(alignment: Alignment.centerRight, child: Text(when, style: mst(10, c: mine ? const Color(0xFFCFCBDB) : kGrey))),
          ]),
        ),
      ),
    );
  }
}
