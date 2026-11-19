import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gToast;
import '../i18n.dart' show Text;
import 'auth.dart';
import 'backend.dart';
import 'company_screens.dart' show companyContextProvider;
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';

/// Partenariats de l'organisation avec l'établissement (lot K4, migration 20261121040000) : l'organisation (propriétaire ou membre) voit SES partenariats décidés
/// par la direction ou suivis par un département ; le propriétaire et les administrateurs de l'équipe les acceptent ou les contestent (motif obligatoire).
/// Tout vient du serveur (org_partnerships_list / org_partnership_respond) ; le lecteur et la finance de l'équipe consultent sans répondre.

final orgPartnershipsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final ctx = ref.watch(companyContextProvider);
  final r = await marcheCall('org_partnerships_list', {'p_owner': ?ctx});
  if (r.error != null) throw MarcheException(r.error);
  return [for (final x in (r.data as List? ?? const [])) if (x is Map) Map<String, dynamic>.from(x)];
}, retry: (_, _) => null);

/// Nombre de partenariats que l'organisation doit encore confirmer (pastille de l'accueil) ; 0 si la lecture échoue.
final orgPartnershipsPendingProvider = Provider.autoDispose<int>((ref) => ref.watch(orgPartnershipsProvider).maybeWhen(
      data: (l) => l.where((p) => p['can_respond'] == true && p['org_response'] == 'pending').length,
      orElse: () => 0,
    ));

const _kinds = {
  'entreprise': 'Entreprise commerciale', 'association': 'Association', 'ong': 'ONG', 'institution': 'Institution', 'universite': 'Université ou école', 'collectivite': 'Collectivité',
  'stage': 'Stages', 'convention': 'Convention', 'sponsoring': 'Sponsoring', 'atelier': 'Ateliers', 'recherche': 'Recherche', 'mecenat': 'Mécénat', 'autre': 'Autre',
};

String _statusLabel(String s) => switch (s) {
      'active' || 'actif' => 'Actif',
      'suspended' => 'Suspendu',
      'ended' || 'termine' => 'Clos',
      _ => s,
    };

String _date(Object? iso) {
  final d = DateTime.tryParse('$iso');
  if (d == null) return '';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class OrgPartnershipsScreen extends ConsumerStatefulWidget {
  const OrgPartnershipsScreen({super.key});

  @override
  ConsumerState<OrgPartnershipsScreen> createState() => _OrgPartnershipsState();
}

class _OrgPartnershipsState extends ConsumerState<OrgPartnershipsScreen> {
  String? _busy;

  Future<String?> _askNote(String title) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text(title, style: mst(16, w: FontWeight.w800)),
          content: TextField(
            controller: c,
            maxLines: 3,
            maxLength: 1000,
            onChanged: (_) => set(() {}),
            decoration: const InputDecoration(labelText: 'Motif (5 caractères au moins)', border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            FilledButton(onPressed: c.text.trim().length < 5 ? null : () => Navigator.pop(ctx, c.text.trim()), child: const Text('Contester')),
          ],
        ),
      ),
    );
  }

  Future<void> _respond(Map<String, dynamic> p, bool accept) async {
    String? note;
    if (!accept) {
      note = await _askNote('Contester « ${p['name']} »');
      if (note == null || !mounted) return;
    }
    final key = '${p['source']}:${p['id']}';
    setState(() => _busy = key);
    final r = await marcheCall('org_partnership_respond', {'p_source': p['source'], 'p_id': p['id'], 'p_action': accept ? 'accept' : 'contest', 'p_note': note});
    if (!mounted) return;
    setState(() => _busy = null);
    gToast(context, r.error != null ? Backend.userMessage('${r.error}') : (accept ? 'Partenariat accepté : l’établissement est prévenu.' : 'Contestation envoyée : la direction est prévenue.'));
    if (r.error == null) ref.invalidate(orgPartnershipsProvider);
  }

  Widget _pill(String t, {Color bg = const Color(0xFFEFEBFA), Color fg = kViolet}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)),
        child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: mst(11, w: FontWeight.w700, c: fg)),
      );

  Widget _card(Map<String, dynamic> p) {
    final status = '${p['status']}';
    final active = status == 'active' || status == 'actif';
    final response = '${p['org_response']}';
    final period = [if (p['starts_on'] != null) _date(p['starts_on']), if (p['ends_on'] != null) _date(p['ends_on'])];
    final students = (p['students'] as num?)?.toInt() ?? 0;
    final subtitle = [
      _kinds['${p['kind']}'] ?? '${p['kind']}',
      if ('${p['department'] ?? ''}'.isNotEmpty) '${p['department']}' else 'Tout l’établissement',
      if (period.length == 2) 'du ${period[0]} au ${period[1]}' else if (period.length == 1 && p['starts_on'] != null) 'depuis le ${period[0]}',
      if (students > 0) '$students étudiant${students > 1 ? 's' : ''}',
    ].join(' · ');
    final domains = [for (final x in (p['domains'] as List? ?? const [])) '$x'];
    final busy = _busy == '${p['source']}:${p['id']}';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: kLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text('${p['name']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: mst(15, w: FontWeight.w800))),
          const SizedBox(width: 8),
          _pill(_statusLabel(status), bg: active ? const Color(0xFFDDF5EC) : const Color(0xFFF2EFF6), fg: active ? const Color(0xFF0F7A52) : kGrey),
        ]),
        const SizedBox(height: 3),
        Text(subtitle, style: mst(12, c: kGrey).copyWith(height: 1.4)),
        if ('${p['objective'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${p['objective']}', maxLines: 5, overflow: TextOverflow.ellipsis, style: mst(13).copyWith(height: 1.4))),
        if (domains.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Domaines : ${domains.join(', ')}', style: mst(12, c: kGrey))),
        if ('${p['decision_note'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Motif de l’établissement : ${p['decision_note']}', style: mst(12, c: kGrey))),
        if (active && const {'pending', 'accepted', 'contested'}.contains(response))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _pill(
              switch (response) { 'accepted' => 'Vous avez accepté', 'contested' => 'Vous avez contesté', _ => 'À confirmer par vous' },
              bg: response == 'accepted' ? const Color(0xFFDDF5EC) : (response == 'contested' ? const Color(0xFFFDE7E4) : const Color(0xFFFFF1D6)),
              fg: response == 'accepted' ? const Color(0xFF0F7A52) : (response == 'contested' ? const Color(0xFFB3261E) : const Color(0xFF8F5400)),
            ),
          ),
        if (response == 'contested' && '${p['org_response_note'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Votre motif : ${p['org_response_note']}', style: mst(12, c: kGrey))),
        if (p['can_respond'] == true) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: mButton('Contester', busy ? null : () => _respond(p, false), dark: false)),
            const SizedBox(width: 10),
            Expanded(child: mButton(response == 'accepted' ? 'Accepté' : 'Accepter', busy || response == 'accepted' ? null : () => _respond(p, true), busy: busy)),
          ]),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(orgPartnershipsProvider);
    return MarchePage(
      title: 'Partenariats',
      child: RefreshIndicator(
        onRefresh: () async => ref.refresh(orgPartnershipsProvider.future),
        child: async.when(
          loading: () => ListView(children: const [Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))]),
          error: (e, _) => ListView(children: [
            mNote(e is MarcheException ? e.toString() : marcheErrorText('$e')),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: mButton('Réessayer', () => ref.invalidate(orgPartnershipsProvider), icon: Icons.refresh)),
          ]),
          data: (l) => ListView(padding: const EdgeInsets.only(bottom: 90), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Text(
                'Les partenariats que l’établissement a validés ou suivis avec votre organisation. Le propriétaire et les administrateurs de l’équipe peuvent les accepter ou les contester ; les autres membres les consultent.',
                style: mst(13, c: kGrey).copyWith(height: 1.5),
              ),
            ),
            if (l.isEmpty) mNote('Aucun partenariat pour le moment.\nQuand l’établissement valide un partenariat avec votre organisation, il apparaît ici et vous êtes prévenu.'),
            for (final p in l) _card(p),
          ]),
        ),
      ),
    );
  }
}
