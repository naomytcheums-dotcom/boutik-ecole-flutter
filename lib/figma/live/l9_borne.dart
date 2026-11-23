import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gToast;
import 'access.dart' show roleKey;
import 'auth.dart';
import 'backend.dart';
import 'lot20.dart' show kiosksProvider;
import 'missions.dart' show countdown, kioskSessionProvider;
import 'qr.dart' show QrView, qrPayload;
import 'tp_ui.dart';

String _stamp(DateTime? d) => d == null ? 'À choisir' : '${tpDate(d.toIso8601String())} à ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// QR de transfert de la borne et programmation du mode événement : réservé au support et à l'administration.
class KioskTransferPage extends ConsumerStatefulWidget {
  const KioskTransferPage({super.key});
  @override
  ConsumerState<KioskTransferPage> createState() => _KioskTransferState();
}

class _KioskTransferState extends ConsumerState<KioskTransferPage> {
  String kiosk = '';
  final title = TextEditingController();
  DateTime? start, end;
  bool busy = false;

  /// Bornes réellement enregistrées sur le serveur (identifiant → nom) ; la borne choisie est toujours l'une d'elles.
  Map<String, String> _options(List<Map<String, dynamic>> rows) => {for (final r in rows) '${r['id']}': '${r['name'] ?? r['id']}'};

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime? current) async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: current ?? now, firstDate: now, lastDate: now.add(const Duration(days: 365)));
    if (d == null || !mounted) return null;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(current ?? now));
    if (t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> _schedule(Map<String, String> kiosks) async {
    final s = start, e = end;
    final id = kiosks.containsKey(kiosk) ? kiosk : (kiosks.isEmpty ? '' : kiosks.keys.first);
    if (id.isEmpty) return gToast(context, 'Aucune borne enregistrée : rien à programmer.');
    if (title.text.trim().length < 3) return gToast(context, 'Donnez un nom à l’événement (3 caractères au moins).');
    if (s == null || e == null) return gToast(context, 'Choisissez le début et la fin de l’événement.');
    if (!e.isAfter(s)) return gToast(context, 'La fin doit suivre le début.');
    if (s.isBefore(DateTime.now())) return gToast(context, 'L’événement ne peut pas commencer dans le passé.');
    setState(() => busy = true);
    final r = await Backend.rpc('schedule_kiosk_event', {'p_kiosk': id, 'p_title': title.text.trim(), 'p_starts': s.toUtc().toIso8601String(), 'p_ends': e.toUtc().toIso8601String()});
    if (!mounted) return;
    setState(() => busy = false);
    if (r.error != null) return gToast(context, Backend.userMessage(r.error!));
    gToast(context, 'Événement programmé sur ${kiosks[id]}.');
    setState(() {
      title.clear();
      start = null;
      end = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = ref.watch(authProvider.select((s) => s.current));
    if (a == null) {
      return TpPage(title: 'QR de transfert', children: [
        TpEmpty(title: 'Connexion requise', text: 'Connectez-vous avec un compte du support ou de l’administration.', icon: Icons.lock_outline_rounded, action: 'Se connecter', onAction: () => requireLogin(context, ref, 'programmer un événement de borne')),
      ]);
    }
    if (!const {'support', 'admin'}.contains(roleKey(a))) {
      return TpPage(title: 'QR de transfert', children: [
        const TpEmpty(title: 'Réservé au support et à l’administration', text: 'La programmation des événements de borne est réservée à l’équipe du support et à l’administration. Le code de transfert d’un panier se génère depuis la borne.', icon: Icons.lock_outline_rounded),
      ]);
    }
    final s = ref.watch(kioskSessionProvider);
    final live = s != null && s.server && !s.expired && !s.used;
    final rows = ref.watch(kiosksProvider);
    final kiosks = rows == null ? <String, String>{} : _options(rows);
    final chosen = kiosks.containsKey(kiosk) ? kiosk : (kiosks.isEmpty ? '' : kiosks.keys.first);
    return TpPage(
      title: 'QR de transfert',
      subtitle: 'Borne',
      bottom: TpButton(busy ? 'Programmation…' : 'Programmer l’événement', busy ? null : () => _schedule(kiosks), busy: busy),
      children: [
        Center(child: live ? QrView(data: qrPayload(s.token), size: 160) : Text('Aucun code actif', style: tpSt(13, c: tpGrey))),
        const SizedBox(height: 8),
        Center(child: Text(live ? 'Expire dans ${countdown(ref)}' : 'Le code se génère depuis la fiche d’un produit de la borne.', textAlign: TextAlign.center, style: tpSt(live ? 16 : 12.5, w: live ? FontWeight.w700 : FontWeight.w500, c: live ? tpInk : tpGrey))),
        if (live) tpNote('Code créé par le serveur : aléatoire, valable 5 minutes, à usage unique.'),
        tpSection('Programmer un événement', hint: 'Pendant l’événement, la borne passe en mode événement sur le créneau choisi.'),
        if (kiosks.isEmpty)
          tpNote(rows == null ? 'Chargement des bornes…' : 'Aucune borne enregistrée pour le moment : rien à programmer.')
        else
          TpChoice('Borne', kiosks, chosen, (v) => setState(() => kiosk = v), required: true),
        TpField('Nom de l’événement', title, maxLength: 80, required: true),
        TpButton('Début : ${_stamp(start)}', () async {
          final d = await _pick(start);
          if (d != null) setState(() => start = d);
        }, dark: false, compact: true, icon: Icons.event_outlined),
        const SizedBox(height: 8),
        TpButton('Fin : ${_stamp(end)}', () async {
          final d = await _pick(end ?? start);
          if (d != null) setState(() => end = d);
        }, dark: false, compact: true, icon: Icons.event_available_outlined),
      ],
    );
  }
}
