import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gAlert, gConfirm, gToast;
import '../i18n.dart' show Text;
import 'access.dart' show roleKey;
import 'auth.dart';
import 'backend.dart';
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';
import 'ranking_h13.dart' show EventAttendanceStudentBlock, showEventAttendanceSheet;

/// Événements officiels : « Mes événements » (inscriptions et reçus de toute personne connectée) et gestion (création, modification,
/// annulation, inscrits, remboursements) pour le responsable de département, la direction, la finance et l'administration.
/// Tout passe par des fonctions serveur (migration 20261117050000) ; le prix est events.price (FCFA), jamais calculé ici.

const _kinds = {'exposition': 'Exposition', 'atelier': 'Atelier', 'conference': 'Conférence', 'salon': 'Salon', 'autre': 'Autre'};
const _mois = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

String _when(Object? iso) {
  final d = (DateTime.tryParse('$iso') ?? DateTime.now()).toLocal();
  return '${d.day} ${_mois[d.month - 1]} ${d.year} · ${d.hour} h${d.minute == 0 ? '' : ' ${d.minute.toString().padLeft(2, '0')}'}';
}

Future<List<Map<String, dynamic>>> _rows(String fn, [Map<String, dynamic> p = const {}]) async {
  final r = await marcheCall(fn, p);
  if (r.error != null) throw MarcheException(r.error);
  return [for (final x in (r.data as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
}

final myEventRegistrationsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  return _rows('my_event_registrations');
}, retry: (_, _) => null);

final managedEventsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  return _rows('events_managed');
}, retry: (_, _) => null);

Widget _card(Widget child) => Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: kLine)),
      child: child,
    );

Widget _chip(String t, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Text(t, style: mst(11.5, w: FontWeight.w700, c: c)),
    );

InputDecoration _deco(String l, {String? hint}) => InputDecoration(labelText: l, hintText: hint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)), filled: true, fillColor: Colors.white);

// ------------------------------------------------------------------ Mes événements

/// Inscriptions de la personne connectée (à venir, passées, annulées par l'organisateur) avec leur reçu et l'état du remboursement.
class MyEventsScreen extends ConsumerWidget {
  const MyEventsScreen({super.key});

  Future<void> _unregister(BuildContext context, WidgetRef ref, Map<String, dynamic> x) async {
    if (!await gConfirm(context, 'Annuler mon inscription ?', 'Votre place sur « ${x['title']} » sera libérée et pourra être prise par quelqu’un d’autre.', yes: 'Annuler mon inscription', no: 'Garder ma place') || !context.mounted) return;
    final r = await marcheCall('event_unregister', {'p_event': x['event']});
    if (!context.mounted) return;
    if (r.error != null) return gAlert(context, 'Annulation impossible', Backend.userMessage('${r.error}'));
    ref.invalidate(myEventRegistrationsProvider);
    gToast(context, 'Inscription annulée');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myEventRegistrationsProvider);
    return MarchePage(
      title: 'Mes événements',
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => mNote('Vos inscriptions ne peuvent pas être chargées pour le moment.'),
        data: (rows) => rows.isEmpty
            ? mNote('Aucune inscription pour le moment.\nVos événements, vos reçus et vos remboursements apparaîtront ici.')
            : RefreshIndicator(
                onRefresh: () async => ref.refresh(myEventRegistrationsProvider.future),
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 90),
                  itemCount: rows.length,
                  itemBuilder: (_, i) {
                    final x = rows[i];
                    final cancelled = x['event_status'] == 'cancelled' || x['status'] == 'cancelled';
                    final future = (DateTime.tryParse('${x['starts_at']}') ?? DateTime.now()).isAfter(DateTime.now());
                    final paid = mInt(x['price']) > 0;
                    final refund = '${x['refund_status'] ?? ''}';
                    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text('${x['title']}', style: mst(15, w: FontWeight.w800))),
                        if (cancelled) _chip('Annulé', kRed) else if (future) _chip('Inscrit(e)', kGreen) else _chip('Terminé', kGrey),
                      ]),
                      const SizedBox(height: 4),
                      Text([_when(x['starts_at']), if ('${x['place']}'.isNotEmpty) '${x['place']}'].join(' · '), style: mst(12.5, c: kGrey)),
                      Text(paid ? 'Tarif : ${mFcfa(x['price'])}' : 'Entrée gratuite', style: mst(12.5, c: kGrey)),
                      if (x['receipt'] != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Reçu ${x['receipt']} · paiement ${x['receipt_reference']}', style: mst(12, w: FontWeight.w600, c: kGreen))),
                      if (cancelled && '${x['cancel_reason'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Motif : ${x['cancel_reason']}', style: mst(12, c: kRed))),
                      if (cancelled && paid && refund == 'to_refund') Padding(padding: const EdgeInsets.only(top: 4), child: Text('Remboursement en cours de traitement par la finance.', style: mst(12, w: FontWeight.w600, c: const Color(0xFF8F5400)))),
                      if (refund == 'refunded') Padding(padding: const EdgeInsets.only(top: 4), child: Text('Remboursé.', style: mst(12, w: FontWeight.w600, c: kGreen))),
                      if (!cancelled) EventAttendanceStudentBlock(eventId: '${x['event']}'),
                      if (!cancelled && future && !paid) Padding(padding: const EdgeInsets.only(top: 10), child: mButton('Annuler mon inscription', () => _unregister(context, ref, x), dark: false)),
                      if (!cancelled && future && paid) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Inscription payée : pour l’annuler et demander un remboursement, contactez la finance depuis la messagerie de paiement.', style: mst(12, c: kGrey))),
                    ]));
                  },
                ),
              ),
      ),
    );
  }
}

// ------------------------------------------------------------------ Gestion des événements

class EventsManageScreen extends ConsumerWidget {
  const EventsManageScreen({super.key});

  Future<void> _form(BuildContext context, WidgetRef ref, [Map<String, dynamic>? e]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
      builder: (c) => _EventForm(event: e),
    );
    if (saved == true) ref.invalidate(managedEventsProvider);
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, Map<String, dynamic> e) async {
    final reason = TextEditingController();
    final n = mInt(e['registered']) + mInt(e['held']);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Annuler « ${e['title']} » ?', style: mst(16, w: FontWeight.w800)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(n == 0 ? 'Personne n’est encore inscrit.' : '$n inscrit(s) seront prévenus. Les paiements reçus seront signalés à la finance pour remboursement.', style: mst(13, c: kGrey)),
          const SizedBox(height: 10),
          TextField(controller: reason, maxLength: 300, maxLines: 2, decoration: _deco('Motif de l’annulation (obligatoire)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Retour', style: mst(14, c: kGrey))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text('Annuler l’événement', style: mst(14, w: FontWeight.w800, c: kRed))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final r = await marcheCall('event_cancel', {'p_id': e['id'], 'p_reason': reason.text});
    if (!context.mounted) return;
    if (r.error != null) return gAlert(context, 'Annulation impossible', Backend.userMessage('${r.error}'));
    ref.invalidate(managedEventsProvider);
    gToast(context, 'Événement annulé : les inscrits sont prévenus.');
  }

  Future<void> _registrants(BuildContext context, WidgetRef ref, Map<String, dynamic> e, bool canRefund) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
      builder: (c) => _Registrants(event: e, canRefund: canRefund, onChanged: () => ref.invalidate(managedEventsProvider)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = roleKey(ref.watch(authProvider).current);
    final canCreate = const {'dept', 'direction', 'admin'}.contains(role);
    final canRefund = const {'finance', 'admin'}.contains(role);
    final async = ref.watch(managedEventsProvider);
    return MarchePage(
      title: 'Événements officiels',
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => mNote('Les événements ne peuvent pas être chargés pour le moment.'),
        data: (rows) => ListView(padding: const EdgeInsets.only(top: 4, bottom: 90), children: [
          if (canCreate) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: mButton('Nouvel événement', () => _form(context, ref), icon: Icons.add)),
          if (rows.isEmpty) mNote('Aucun événement pour le moment.\nCréez la première exposition, le premier atelier ou la première conférence.'),
          for (final e in rows)
            _card(Builder(builder: (_) {
              final cancelled = e['status'] == 'cancelled';
              final future = (DateTime.tryParse('${e['starts_at']}') ?? DateTime.now()).isAfter(DateTime.now());
              final editable = !cancelled && future && canCreate && (e['mine'] == true || const {'direction', 'admin'}.contains(role));
              final free = mInt(e['price']) == 0;
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('${e['title']}', style: mst(15, w: FontWeight.w800))),
                  if (cancelled) _chip('Annulé', kRed) else if (!future) _chip('Terminé', kGrey) else _chip('Publié', kGreen),
                ]),
                const SizedBox(height: 4),
                Text('${_kinds[e['kind']] ?? e['kind']} · ${_when(e['starts_at'])}${'${e['place']}'.isEmpty ? '' : ' · ${e['place']}'}', style: mst(12.5, c: kGrey)),
                Text('${free ? 'Gratuit' : mFcfa(e['price'])} · ${mInt(e['registered'])} inscrit(s)${e['capacity'] == null ? '' : ' sur ${e['capacity']} places'}${mInt(e['held']) > 0 ? ' · ${e['held']} réservation(s) en cours' : ''}', style: mst(12.5, c: kGrey)),
                if (cancelled && '${e['cancel_reason'] ?? ''}'.isNotEmpty) Text('Motif : ${e['cancel_reason']}', style: mst(12, c: kRed)),
                if (mInt(e['to_refund']) > 0) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${e['to_refund']} remboursement(s) à traiter', style: mst(12, w: FontWeight.w700, c: const Color(0xFF8F5400)))),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  mButton('Inscrits', () => _registrants(context, ref, e, canRefund), dark: false),
                  if (!cancelled && canCreate && (e['mine'] == true || const {'direction', 'admin'}.contains(role))) mButton('Pointage', () => showEventAttendanceSheet(context, e), dark: false),
                  if (editable) mButton('Modifier', () => _form(context, ref, e), dark: false),
                  if (editable) mButton('Annuler', () => _cancel(context, ref, e), dark: false),
                ]),
              ]);
            })),
        ]),
      ),
    );
  }
}

class _Registrants extends StatefulWidget {
  const _Registrants({required this.event, required this.canRefund, required this.onChanged});
  final Map<String, dynamic> event;
  final bool canRefund;
  final VoidCallback onChanged;

  @override
  State<_Registrants> createState() => _RegistrantsState();
}

class _RegistrantsState extends State<_Registrants> {
  List<Map<String, dynamic>>? _list;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _rows('event_registrants', {'p_event': widget.event['id']});
      if (mounted) setState(() => _list = r);
    } catch (_) {
      if (mounted) setState(() => _error = 'La liste des inscrits ne peut pas être chargée.');
    }
  }

  Future<void> _refunded(Map<String, dynamic> x) async {
    final r = await marcheCall('event_refund_done', {'p_event': widget.event['id'], 'p_user': x['user_id']});
    if (!mounted) return;
    if (r.error != null) return gAlert(context, 'Impossible', Backend.userMessage('${r.error}'));
    widget.onChanged();
    gToast(context, 'Remboursement enregistré : la personne est prévenue.');
    await _load();
  }

  static const _status = {'confirmed': 'Inscrit(e)', 'pending_payment': 'Paiement en attente', 'cancelled': 'Annulé'};

  @override
  Widget build(BuildContext context) {
    final list = _list;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Inscrits · ${widget.event['title']}', style: mst(17, w: FontWeight.w800)),
            const SizedBox(height: 10),
            if (_error != null) Text(_error!, style: mst(13, c: kRed))
            else if (list == null) const Center(child: CircularProgressIndicator())
            else if (list.isEmpty) Text('Personne n’est encore inscrit.', style: mst(13, c: kGrey))
            else
              Flexible(
                child: ListView(shrinkWrap: true, children: [
                  for (final x in list)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${x['name']}', style: mst(14, w: FontWeight.w700)),
                          Text([_status['${x['status']}'] ?? '${x['status']}', if (x['paid'] == true) 'payé ${mFcfa(x['amount'])}', if (x['refund_status'] == 'to_refund') 'à rembourser', if (x['refund_status'] == 'refunded') 'remboursé'].join(' · '), style: mst(12, c: kGrey)),
                        ])),
                        if (widget.canRefund && x['refund_status'] == 'to_refund') mButton('Remboursé', () => _refunded(x), dark: false),
                      ]),
                    ),
                ]),
              ),
          ]),
        ),
      ),
    );
  }
}

class _EventForm extends StatefulWidget {
  const _EventForm({this.event});
  final Map<String, dynamic>? event;

  @override
  State<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<_EventForm> {
  late final title = TextEditingController(text: '${widget.event?['title'] ?? ''}');
  late final description = TextEditingController(text: '${widget.event?['description'] ?? ''}');
  late final place = TextEditingController(text: '${widget.event?['place'] ?? ''}');
  late final price = TextEditingController(text: widget.event == null ? '0' : '${mInt(widget.event?['price'])}');
  late final capacity = TextEditingController(text: widget.event?['capacity'] == null ? '' : '${widget.event?['capacity']}');
  late String kind = widget.event == null ? 'atelier' : '${widget.event!['kind']}';
  late DateTime? start = widget.event == null ? null : DateTime.tryParse('${widget.event!['starts_at']}')?.toLocal();
  late DateTime? end = widget.event?['ends_at'] == null ? null : DateTime.tryParse('${widget.event!['ends_at']}')?.toLocal();
  bool busy = false;
  String? error;

  Future<DateTime?> _pick(DateTime? initial) async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: initial ?? now.add(const Duration(days: 7)), firstDate: now, lastDate: now.add(const Duration(days: 730)));
    if (d == null || !mounted) return null;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial ?? DateTime(now.year, now.month, now.day, 10)));
    if (t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  String _fmt(DateTime? d) => d == null ? 'Choisir' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} à ${d.hour} h${d.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    final t = title.text.trim();
    if (t.length < 3) return setState(() => error = 'Le titre doit faire au moins 3 caractères.');
    if (start == null) return setState(() => error = 'Choisissez la date et l’heure de début.');
    if (end != null && end!.isBefore(start!)) return setState(() => error = 'La fin ne peut pas précéder le début.');
    final p = int.tryParse(price.text.trim().isEmpty ? '0' : price.text.replaceAll(RegExp(r'\s'), ''));
    if (p == null || p < 0) return setState(() => error = 'Le tarif doit être un nombre de FCFA (0 pour gratuit).');
    final capText = capacity.text.trim();
    final cap = capText.isEmpty ? null : int.tryParse(capText);
    if (capText.isNotEmpty && (cap == null || cap < 1)) return setState(() => error = 'La capacité doit être d’au moins une place (laissez vide pour illimité).');
    setState(() { busy = true; error = null; });
    final params = <String, dynamic>{
      'p_title': t,
      'p_description': description.text.trim(),
      'p_kind': kind,
      'p_starts': start!.toUtc().toIso8601String(),
      'p_ends': end?.toUtc().toIso8601String(),
      'p_place': place.text.trim(),
      'p_price': p,
      'p_capacity': cap,
    };
    final r = widget.event == null ? await marcheCall('event_create', params) : await marcheCall('event_update', {'p_id': widget.event!['id'], ...params});
    if (!mounted) return;
    if (r.error != null) return setState(() { busy = false; error = Backend.userMessage('${r.error}'); });
    gToast(context, widget.event == null ? 'Événement publié.' : (mInt(r.data) > 0 ? 'Événement modifié : ${r.data} inscrit(s) prévenu(s).' : 'Événement modifié.'));
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.event == null ? 'Nouvel événement' : 'Modifier l’événement', style: mst(18, w: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(controller: title, maxLength: 140, decoration: _deco('Titre')),
            Wrap(spacing: 8, children: [
              for (final k in _kinds.entries)
                ChoiceChip(label: Text(k.value), selected: kind == k.key, onSelected: (_) => setState(() => kind = k.key)),
            ]),
            const SizedBox(height: 10),
            TextField(controller: description, maxLines: 3, maxLength: 2000, decoration: _deco('Description (facultatif)')),
            TextField(controller: place, maxLength: 140, decoration: _deco('Lieu (facultatif)')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () async { final d = await _pick(start); if (d != null) setState(() => start = d); }, child: Text('Début : ${_fmt(start)}'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: () async { final d = await _pick(end ?? start); if (d != null) setState(() => end = d); }, child: Text('Fin : ${end == null ? 'facultatif' : _fmt(end)}'))),
            ]),
            const SizedBox(height: 10),
            TextField(controller: price, keyboardType: TextInputType.number, decoration: _deco('Tarif (FCFA, 0 = gratuit)', hint: '0')),
            const SizedBox(height: 10),
            TextField(controller: capacity, keyboardType: TextInputType.number, decoration: _deco('Nombre de places (vide = illimité)')),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error!, style: mst(13, c: kRed))),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: mButton('Annuler', busy ? null : () => Navigator.pop(context, false), dark: false)),
              const SizedBox(width: 10),
              Expanded(child: mButton(widget.event == null ? 'Publier' : 'Enregistrer', busy ? null : _save, busy: busy)),
            ]),
          ]),
        ),
      );
}
