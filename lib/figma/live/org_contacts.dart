import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gAlert, gToast;
import '../i18n.dart' show Text;
import 'auth.dart';
import 'company_screens.dart' show companyContextProvider;
import 'lots.dart' show formDialog;
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';
import 'talent_pool.dart' show poolArgs, poolErrorText;

/// Suivi des demandes de contact envoyées aux talents (migration 20261128062000) : côté ORGANISATION (statut, réponse du talent, délai de réponse) et côté TALENT (répondre : accepter ou décliner).
/// Tout vient du serveur : aucune réponse n'est inventée, un suivi vide est dit vide, une erreur est dite erreur (jamais « 0 »), et aucune confirmation n'apparaît si l'écriture échoue.

const contactKindLabels = {'contact': 'Prise de contact', 'interview': 'Entretien', 'internship_offer': 'Offre de stage', 'job_offer': 'Offre d’emploi', 'mission_offer': 'Proposition de mission'};
const contactStatusLabels = {'sent': 'Envoyée', 'seen': 'Vue', 'accepted': 'Acceptée', 'declined': 'Déclinée', 'expired': 'Sans réponse (expirée)'};

Color contactStatusColor(String s) => switch (s) {
      'accepted' => kGreen,
      'declined' => kRed,
      'expired' => kGrey,
      _ => kViolet,
    };

String _day(Object? v) {
  final s = v == null ? '' : '$v';
  return s.length >= 10 ? s.substring(0, 10) : s;
}

/// Délai de réponse lisible : « 3 h », « 2 j » ; vide si le talent n'a pas répondu.
String contactDelayText(Object? hours) {
  if (hours is! num) return '';
  if (hours < 1) return 'moins d’une heure';
  if (hours < 48) return '${hours.round()} h';
  return '${(hours / 24).round()} j';
}

final poolContactRequestsProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, status) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final r = await marcheCall('pool_contact_requests_get', poolArgs(ref.watch(companyContextProvider), {if (status.isNotEmpty) 'p_status': status}));
  if (r.error != null) throw MarcheException(r.error);
  return r.data is Map ? Map<String, dynamic>.from(r.data as Map) : <String, dynamic>{};
}, retry: (_, _) => null);

class OrgContactRequestsScreen extends ConsumerStatefulWidget {
  const OrgContactRequestsScreen({super.key});

  @override
  ConsumerState<OrgContactRequestsScreen> createState() => _OrgContactRequestsState();
}

class _OrgContactRequestsState extends ConsumerState<OrgContactRequestsScreen> {
  String _status = '';

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(poolContactRequestsProvider(_status));
    return MarchePage(
      title: 'Demandes aux talents',
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(poolContactRequestsProvider(_status)),
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
          Text('Les demandes envoyées par votre équipe et la réponse de chaque talent. Un talent qui n’est plus visible des recruteurs n’apparaît plus ici.', style: mst(12, c: kGrey).copyWith(height: 1.4)),
          const SizedBox(height: 10),
          data.when(
            loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Column(children: [
              Text(e is MarcheException ? '$e' : poolErrorText(e), textAlign: TextAlign.center, style: mst(13.5, c: kGrey).copyWith(height: 1.5)),
              const SizedBox(height: 8),
              mButton('Réessayer', () => ref.invalidate(poolContactRequestsProvider(_status)), dark: false, icon: Icons.refresh_rounded),
            ]),
            data: (d) {
              final stats = d['stats'] is Map ? Map<String, dynamic>.from(d['stats'] as Map) : const <String, dynamic>{};
              final items = [for (final x in (d['items'] as List? ?? const [])) if (x is Map) Map<String, dynamic>.from(x)];
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _stat('envoyées', stats['total']),
                  _stat('en attente', stats['pending']),
                  _stat('acceptées', stats['accepted']),
                  _stat('déclinées', stats['declined']),
                  _stat('sans réponse', stats['expired']),
                  _stat('délai moyen', stats['avg_delay_hours'] == null ? null : contactDelayText(stats['avg_delay_hours'])),
                ]),
                const SizedBox(height: 12),
                MDropdown(label: 'Statut', value: _status, items: const {'': 'Tous les statuts', 'pending': 'En attente', 'accepted': 'Acceptées', 'declined': 'Déclinées', 'expired': 'Sans réponse'}, onChanged: (v) => setState(() => _status = v)),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  mNote(_status.isEmpty ? 'Aucune demande envoyée pour le moment.\nContactez un talent depuis « Rechercher des talents » : sa réponse apparaîtra ici.' : 'Aucune demande avec ce statut.')
                else
                  for (final c in items) _RequestCard(c),
              ]);
            },
          ),
        ]),
      ),
    );
  }

  Widget _stat(String label, Object? v) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: kLine)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(v == null ? '—' : '$v', style: mst(18, w: FontWeight.w800)), Text(label, style: mst(11.5, c: kGrey))]),
      );
}

class _RequestCard extends StatelessWidget {
  const _RequestCard(this.c);
  final Map<String, dynamic> c;

  @override
  Widget build(BuildContext context) {
    final status = '${c['status']}';
    final delay = contactDelayText(c['delay_hours']);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: kLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${c['name']}', style: mst(14.5, w: FontWeight.w800))),
          Text(contactStatusLabels[status] ?? status, style: mst(12, w: FontWeight.w700, c: contactStatusColor(status))),
        ]),
        Text('${contactKindLabels['${c['kind']}'] ?? c['kind']} · envoyée le ${_day(c['created_at'])} par ${c['author'] ?? 'un membre'}', style: mst(12, c: kGrey)),
        if ('${c['message'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${c['message']}', style: mst(13))),
        if (c['responded_at'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Réponse le ${_day(c['responded_at'])}${delay.isEmpty ? '' : ' (en $delay)'}${'${c['response'] ?? ''}'.isEmpty ? '' : ' : ${c['response']}'}', style: mst(12.5, w: FontWeight.w600)),
          )
        else if (status == 'expired')
          Padding(padding: const EdgeInsets.only(top: 6), child: Text('Sans réponse à l’échéance du ${_day(c['expires_at'])}.', style: mst(12.5, c: kGrey)))
        else if (c['expires_at'] != null)
          Padding(padding: const EdgeInsets.only(top: 6), child: Text('Réponse attendue avant le ${_day(c['expires_at'])}.', style: mst(12.5, c: kGrey))),
      ]),
    );
  }
}

/// Côté talent : une demande reçue avec son statut ; « Accepter » / « Décliner » (une seule réponse, message facultatif) tant qu'elle n'a pas expiré.
class TalentContactCard extends StatelessWidget {
  const TalentContactCard({super.key, required this.request, required this.onChanged});
  final Map<String, dynamic> request;
  final VoidCallback onChanged;

  Future<void> _respond(BuildContext context, String decision) async {
    final accept = decision == 'accepted';
    final v = await formDialog(context, accept ? 'Accepter cette demande ?' : 'Décliner cette demande ?', [('Message (facultatif, transmis à l’organisation)', '')],
        intro: accept ? 'L’organisation est prévenue de votre accord. Aucune de vos coordonnées privées ne lui est transmise.' : 'L’organisation est prévenue que vous ne donnez pas suite.', submit: accept ? 'Accepter' : 'Décliner');
    if (v == null || !context.mounted) return;
    final r = await marcheCall('talent_contact_respond', {'p_id': request['id'], 'p_decision': decision, 'p_message': v.first.trim()});
    if (!context.mounted) return;
    if (r.error != null) {
      await gAlert(context, 'Réponse non enregistrée', poolErrorText(r.error));
      onChanged();
      return;
    }
    gToast(context, accept ? 'Demande acceptée : l’organisation est prévenue.' : 'Demande déclinée : l’organisation est prévenue.');
    onChanged();
  }

  Future<void> _markSeen(BuildContext context) async {
    final r = await marcheCall('talent_contact_seen', {'p_id': request['id']});
    if (r.error == null) onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final c = request;
    final status = '${c['status'] ?? 'sent'}';
    final canRespond = c['can_respond'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: kLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${c['sender']}', style: mst(14.5, w: FontWeight.w800))),
          Text(contactStatusLabels[status] ?? status, style: mst(12, w: FontWeight.w700, c: contactStatusColor(status))),
        ]),
        Text('${contactKindLabels['${c['kind']}'] ?? c['kind']} · ${_day(c['created_at'])}', style: mst(12, c: kGrey)),
        if ('${c['message'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${c['message']}', style: mst(13))),
        if (c['responded_at'] != null)
          Padding(padding: const EdgeInsets.only(top: 6), child: Text('Votre réponse du ${_day(c['responded_at'])}${'${c['response'] ?? ''}'.isEmpty ? '' : ' : ${c['response']}'}', style: mst(12.5, w: FontWeight.w600)))
        else if (status == 'expired')
          Padding(padding: const EdgeInsets.only(top: 6), child: Text('Cette demande a expiré : vous ne pouvez plus y répondre.', style: mst(12.5, c: kGrey)))
        else if (canRespond) ...[
          if (c['expires_at'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Réponse attendue avant le ${_day(c['expires_at'])}.', style: mst(12.5, c: kGrey))),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: mButton('Décliner', () => _respond(context, 'declined'), dark: false)),
            const SizedBox(width: 10),
            Expanded(child: mButton('Accepter', () => _respond(context, 'accepted'))),
          ]),
          if (status == 'sent') TextButton(onPressed: () => _markSeen(context), child: const Text('Marquer comme vue')),
        ],
      ]),
    );
  }
}
