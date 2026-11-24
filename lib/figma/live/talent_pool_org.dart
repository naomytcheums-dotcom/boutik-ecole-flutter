import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../gen.dart' show gAlert, gToast;
import '../i18n.dart' show Text;
import 'auth.dart';
import 'company_screens.dart' show companyContextProvider;
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';
import 'talent_pool.dart' show poolArgs, poolErrorText, refreshTalentPool;

/// Vivier de talents de l'ORGANISATION (migration 20261126060300) : tableau de bord, recherche dans le vivier (étape, étiquette, disponibilité), fiche d'un talent
/// (étape, étiquettes, notes internes, historique de contact, rappels, alerte de disponibilité), comparaison de 2 à 5 talents. Tout vient du serveur : un vivier vide est dit vide,
/// une erreur est dite erreur (jamais « 0 »), et aucune confirmation n'apparaît si l'écriture échoue. Le lecteur d'équipe consulte sans écrire. Aucune décision n'est automatique.

const poolStageLabels = {
  'candidat': 'Candidat',
  'preselectionne': 'Présélectionné',
  'evalue': 'Évalué',
  'recommande': 'Recommandé',
  'ancien_collaborateur': 'Ancien collaborateur',
  'favori': 'Favori',
  'a_recontacter': 'À recontacter',
};
const _channelLabels = {'message': 'Message', 'appel': 'Appel', 'entretien': 'Entretien', 'email': 'E-mail', 'autre': 'Autre'};

Future<Map<String, dynamic>> _map(String fn, Map<String, dynamic> p) async {
  final r = await marcheCall(fn, p);
  if (r.error != null) throw MarcheException(r.error);
  return r.data is Map ? Map<String, dynamic>.from(r.data as Map) : <String, dynamic>{};
}

Future<List<Map<String, dynamic>>> _list(String fn, Map<String, dynamic> p) async {
  final r = await marcheCall(fn, p);
  if (r.error != null) throw MarcheException(r.error);
  return [for (final x in (r.data as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
}

final poolOverviewProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  return _map('pool_overview', poolArgs(ref.watch(companyContextProvider)));
}, retry: (_, _) => null);

typedef PoolFilter = ({String stage, String tag, bool available});

final poolSearchProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, PoolFilter>((ref, f) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final org = ref.watch(companyContextProvider);
  return _list('pool_search', poolArgs(org, {if (f.stage.isNotEmpty) 'p_stage': f.stage, if (f.tag.isNotEmpty) 'p_tag': f.tag, if (f.available) 'p_available': true}));
}, retry: (_, _) => null);

final poolRemindersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  return _list('pool_reminders_get', poolArgs(ref.watch(companyContextProvider)));
}, retry: (_, _) => null);

class TalentPoolOrgScreen extends ConsumerStatefulWidget {
  const TalentPoolOrgScreen({super.key});

  @override
  ConsumerState<TalentPoolOrgScreen> createState() => _TalentPoolOrgState();
}

class _TalentPoolOrgState extends ConsumerState<TalentPoolOrgScreen> {
  final _tag = TextEditingController();
  PoolFilter _filter = (stage: '', tag: '', available: false);
  final _picked = <String>{};

  @override
  void dispose() {
    _tag.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(poolOverviewProvider);
    ref.invalidate(poolSearchProvider);
    ref.invalidate(poolRemindersProvider);
    refreshTalentPool(ref);
  }

  Widget _error(Object e, VoidCallback retry) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Text(e is MarcheException ? '$e' : poolErrorText(e), textAlign: TextAlign.center, style: mst(13.5, c: kGrey).copyWith(height: 1.5)),
          const SizedBox(height: 8),
          mButton('Réessayer', retry, dark: false, icon: Icons.refresh_rounded),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(poolOverviewProvider);
    final results = ref.watch(poolSearchProvider(_filter));
    final reminders = ref.watch(poolRemindersProvider);
    final canWrite = overview.asData?.value['my_role'] == null || const {'owner', 'admin'}.contains(overview.asData?.value['my_role']);
    return MarchePage(
      title: 'Vivier de talents',
      child: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
          Text('Privé à votre organisation : seules les personnes autorisées de votre équipe voient ces listes, notes et rappels. Les talents ne sont pas prévenus.', style: mst(12, c: kGrey).copyWith(height: 1.4)),
          const SizedBox(height: 10),
          overview.when(
            loading: () => const Padding(padding: EdgeInsets.all(18), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => _error(e, () => ref.invalidate(poolOverviewProvider)),
            data: (o) => _Overview(o),
          ),
          const SizedBox(height: 12),
          MDropdown(label: 'Étape', value: _filter.stage, items: {'': 'Toutes les étapes', ...poolStageLabels}, onChanged: (v) => setState(() => _filter = (stage: v, tag: _filter.tag, available: _filter.available))),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _tag,
                maxLength: 30,
                textInputAction: TextInputAction.search,
                onSubmitted: (v) => setState(() => _filter = (stage: _filter.stage, tag: v.trim(), available: _filter.available)),
                decoration: InputDecoration(hintText: 'Filtrer par étiquette', counterText: '', filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14), border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: kLine))),
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(label: const Text('Disponibles'), selected: _filter.available, onSelected: (v) => setState(() => _filter = (stage: _filter.stage, tag: _tag.text.trim(), available: v))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text('Comparer : cochez 2 à 5 talents', style: mst(12, c: kGrey))),
            TextButton(onPressed: _picked.length >= 2 && _picked.length <= 5 ? () => _compare(context) : null, child: Text('Comparer (${_picked.length})')),
          ]),
          results.when(
            loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => _error(e, () => ref.invalidate(poolSearchProvider(_filter))),
            data: (rows) => rows.isEmpty
                ? mNote(_filter.stage.isEmpty && _filter.tag.isEmpty && !_filter.available
                    ? 'Votre vivier est vide.\nEnregistrez des talents avec l’étoile depuis « Rechercher des talents » pour les retrouver ici.'
                    : 'Aucun talent du vivier ne correspond à ces filtres.')
                : Column(children: [
                    for (final t in rows)
                      _PoolCard(
                        t: t,
                        picked: _picked.contains('${t['id']}'),
                        onPick: (v) => setState(() => v ? _picked.add('${t['id']}') : _picked.remove('${t['id']}')),
                        onOpen: () async {
                          await showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.white,
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                            builder: (c) => PoolTalentSheet(talent: t, canWrite: canWrite),
                          );
                          _refresh();
                        },
                      ),
                  ]),
          ),
          mSectionTitle('Rappels'),
          reminders.when(
            loading: () => const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => _error(e, () => ref.invalidate(poolRemindersProvider)),
            data: (rows) => rows.isEmpty
                ? Text('Aucun rappel ouvert.', style: mst(13, c: kGrey))
                : Column(children: [
                    for (final r in rows)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${r['name']} · ${r['due_on']}', style: mst(13.5, w: FontWeight.w700, c: r['due'] == true ? kRed : kInk)),
                        subtitle: Text('${r['note'] ?? ''}'.isEmpty ? 'Recontacter' : '${r['note']}', style: mst(12, c: kGrey)),
                        trailing: canWrite
                            ? TextButton(
                                onPressed: () async {
                                  final res = await marcheCall('pool_reminder_done', poolArgs(ref.read(companyContextProvider), {'p_id': r['id']}));
                                  if (!context.mounted) return;
                                  if (res.error != null) {
                                    await gAlert(context, 'Rappel non clos', poolErrorText(res.error));
                                    return;
                                  }
                                  ref.invalidate(poolRemindersProvider);
                                  ref.invalidate(poolOverviewProvider);
                                },
                                child: const Text('Fait'),
                              )
                            : null,
                      ),
                  ]),
          ),
        ]),
      ),
    );
  }

  Future<void> _compare(BuildContext context) async {
    final r = await marcheCall('pool_compare', poolArgs(ref.read(companyContextProvider), {'p_students': _picked.toList()}));
    if (!context.mounted) return;
    if (r.error != null || r.data is! Map) {
      await gAlert(context, 'Comparaison impossible', poolErrorText(r.error ?? 'Réponse inattendue du serveur.'));
      return;
    }
    final d = Map<String, dynamic>.from(r.data as Map);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => _CompareSheet(d),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview(this.o);
  final Map<String, dynamic> o;

  @override
  Widget build(BuildContext context) {
    Widget stat(String label, Object? v, {bool warn = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: kLine)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${mInt(v)}', style: mst(18, w: FontWeight.w800, c: warn && mInt(v) > 0 ? kRed : kInk)), Text(label, style: mst(11.5, c: kGrey))]),
        );
    final by = o['by_stage'] is Map ? Map<String, dynamic>.from(o['by_stage'] as Map) : const <String, dynamic>{};
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        stat('talents', o['total']),
        stat('disponibles', o['available']),
        stat('rappels échus', o['reminders_due'], warn: true),
        stat('alertes', o['alerts']),
        stat('contacts (30 j)', o['contacts_30d']),
        stat('listes', o['lists']),
      ]),
      if (by.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text([for (final e in by.entries) '${poolStageLabels[e.key] ?? 'Sans étape'} : ${mInt(e.value)}'].join(' · '), style: mst(12, c: kGrey)),
        ),
    ]);
  }
}

class _PoolCard extends StatelessWidget {
  const _PoolCard({required this.t, required this.picked, required this.onPick, required this.onOpen});
  final Map<String, dynamic> t;
  final bool picked;
  final ValueChanged<bool> onPick;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final tags = [for (final x in (t['tags'] as List? ?? const [])) '$x'];
    final stage = poolStageLabels['${t['stage']}'];
    final label = [?stage, if (t['available'] == true) 'Disponible', ...tags].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: kLine)),
      child: Row(children: [
        Checkbox(value: picked, onChanged: (v) => onPick(v == true)),
        Expanded(
          child: InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${t['name'] ?? 'Étudiant'}', style: mst(14.5, w: FontWeight.w800)),
                if ('${t['department'] ?? ''}'.isNotEmpty) Text('${t['department']}', style: mst(12, c: kGrey)),
                Text(label.isEmpty ? 'Sans étape' : label, style: mst(12, c: kViolet, w: FontWeight.w600)),
              ]),
            ),
          ),
        ),
        IconButton(tooltip: 'Ouvrir la fiche', onPressed: onOpen, icon: const Icon(Icons.chevron_right_rounded)),
      ]),
    );
  }
}

/// Fiche d'un talent du vivier : étape, étiquettes, notes internes, historique de contact, rappel, alerte.
class PoolTalentSheet extends ConsumerStatefulWidget {
  const PoolTalentSheet({super.key, required this.talent, required this.canWrite});
  final Map<String, dynamic> talent;
  final bool canWrite;

  @override
  ConsumerState<PoolTalentSheet> createState() => _PoolTalentSheetState();
}

class _PoolTalentSheetState extends ConsumerState<PoolTalentSheet> {
  final _tags = TextEditingController(), _note = TextEditingController(), _contact = TextEditingController(), _remind = TextEditingController();
  String _stage = '', _channel = 'appel';
  bool _busy = false, _alert = false;
  List<Map<String, dynamic>>? _notes, _contacts;
  String? _loadError;

  String get _id => '${widget.talent['id']}';
  String? get _org => ref.read(companyContextProvider);

  @override
  void initState() {
    super.initState();
    _stage = '${widget.talent['stage'] ?? ''}';
    _tags.text = [for (final x in (widget.talent['tags'] as List? ?? const [])) '$x'].join(', ');
    _load();
  }

  @override
  void dispose() {
    _tags.dispose();
    _note.dispose();
    _contact.dispose();
    _remind.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final notes = await _list('pool_notes_get', poolArgs(_org, {'p_student': _id}));
      final contacts = await _list('pool_contacts_get', poolArgs(_org, {'p_student': _id}));
      final alerts = await _list('pool_alerts_get', poolArgs(_org));
      if (!mounted) return;
      setState(() {
        _notes = notes;
        _contacts = contacts;
        _alert = alerts.any((a) => '${a['student_id']}' == _id);
        _loadError = null;
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = '$e');
    }
  }

  /// Écrit sur le serveur ; en cas d'échec, message d'erreur et aucune confirmation. Renvoie vrai si l'écriture a réussi.
  Future<bool> _write(String fn, Map<String, dynamic> p, String failTitle, String done) async {
    setState(() => _busy = true);
    final r = await marcheCall(fn, poolArgs(_org, p));
    if (!mounted) return false;
    setState(() => _busy = false);
    if (r.error != null) {
      await gAlert(context, failTitle, poolErrorText(r.error));
      return false;
    }
    if (done.isNotEmpty) gToast(context, done);
    await _load();
    return true;
  }

  Future<void> _saveStage() => _write('pool_talent_set', {
        'p_student': _id,
        'p_stage': _stage,
        'p_tags': [for (final x in _tags.text.split(',')) if (x.trim().isNotEmpty) x.trim()],
      }, 'Étape non enregistrée', 'Étape et étiquettes enregistrées.');

  Future<void> _addNote() async {
    final body = _note.text.trim();
    if (body.isEmpty) return;
    if (await _write('pool_note_add', {'p_student': _id, 'p_body': body}, 'Note non enregistrée', 'Note enregistrée.')) _note.clear();
  }

  Future<void> _logContact() async {
    final s = _contact.text.trim();
    if (s.length < 2) return;
    if (await _write('pool_contact_log', {'p_student': _id, 'p_channel': _channel, 'p_summary': s}, 'Contact non enregistré', 'Contact enregistré.')) _contact.clear();
  }

  Future<void> _addReminder() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: now.add(const Duration(days: 7)), firstDate: now, lastDate: now.add(const Duration(days: 730)));
    if (d == null || !mounted) return;
    final iso = '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    if (await _write('pool_reminder_set', {'p_student': _id, 'p_due': iso, 'p_note': _remind.text.trim()}, 'Rappel non créé', 'Rappel créé pour le $iso.')) _remind.clear();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.canWrite;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${widget.talent['name'] ?? 'Étudiant'}', style: mst(18, w: FontWeight.w800)),
          Wrap(children: [
            TextButton(onPressed: () => context.push('/passeport/$_id'), child: const Text('Passeport Talent 360°')),
            TextButton(onPressed: () => context.push('/etudiant/$_id'), child: const Text('Profil')),
          ]),
          if (!w) Text('Lecture seule : votre rôle ne permet pas de modifier le vivier.', style: mst(12, c: kGrey)),
          if (w) ...[
            MDropdown(label: 'Étape', value: _stage, items: {'': 'Sans étape', ...poolStageLabels}, onChanged: (v) => setState(() => _stage = v)),
            const SizedBox(height: 8),
            TextField(controller: _tags, maxLength: 120, decoration: const InputDecoration(labelText: 'Étiquettes (séparées par des virgules, 8 au plus)', counterText: '')),
            mButton('Enregistrer l’étape et les étiquettes', _busy ? null : _saveStage, busy: _busy),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: Text('Alerte de disponibilité', style: mst(13.5, w: FontWeight.w700))),
              Switch(
                value: _alert,
                onChanged: _busy
                    ? null
                    : (v) async {
                        if (await _write('pool_alert_set', {'p_student': _id, 'p_on': v}, 'Alerte non modifiée', v ? 'Alerte activée.' : 'Alerte retirée.')) {
                          if (mounted) setState(() => _alert = v);
                        }
                      },
              ),
            ]),
          ],
          mSectionTitle('Notes internes'),
          if (_loadError != null) Column(children: [Text(_loadError!, style: mst(13, c: kGrey)), TextButton(onPressed: _load, child: const Text('Réessayer'))]),
          if (_loadError == null && _notes == null) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
          if (_notes != null && _notes!.isEmpty) Text('Aucune note pour ce talent.', style: mst(13, c: kGrey)),
          if (_notes != null)
            for (final n in _notes!)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${n['body']}', style: mst(13.5)),
                subtitle: Text('${n['author']} · ${'${n['created_at']}'.split('T').first}', style: mst(11.5, c: kGrey)),
                trailing: n['can_delete'] == true && w
                    ? IconButton(tooltip: 'Supprimer la note', icon: const Icon(Icons.delete_outline_rounded), onPressed: _busy ? null : () => _write('pool_note_delete', {'p_note': n['id']}, 'Note non supprimée', 'Note supprimée.'))
                    : null,
              ),
          if (w) ...[
            TextField(controller: _note, maxLength: 1000, minLines: 1, maxLines: 4, decoration: const InputDecoration(labelText: 'Nouvelle note interne', counterText: '')),
            mButton('Ajouter la note', _busy ? null : _addNote, dark: false),
          ],
          mSectionTitle('Historique de contact'),
          if (_contacts != null && _contacts!.isEmpty) Text('Aucun contact enregistré.', style: mst(13, c: kGrey)),
          if (_contacts != null)
            for (final c in _contacts!)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text('${c['summary']}', style: mst(13)),
                subtitle: Text('${_channelLabels['${c['channel']}'] ?? c['channel']} · ${c['source'] == 'plateforme' ? 'via la plateforme' : 'noté par l’équipe'} · ${c['author']} · ${'${c['at']}'.split('T').first}', style: mst(11.5, c: kGrey)),
              ),
          if (w) ...[
            MDropdown(label: 'Canal', value: _channel, items: _channelLabels, onChanged: (v) => setState(() => _channel = v)),
            const SizedBox(height: 6),
            TextField(controller: _contact, maxLength: 500, decoration: const InputDecoration(labelText: 'Résumé du contact', counterText: '')),
            mButton('Enregistrer le contact', _busy ? null : _logContact, dark: false),
            mSectionTitle('Rappel'),
            TextField(controller: _remind, maxLength: 300, decoration: const InputDecoration(labelText: 'Motif du rappel (facultatif)', counterText: '')),
            mButton('Programmer un rappel…', _busy ? null : _addReminder, dark: false, icon: Icons.event_outlined),
          ],
        ]),
      ),
    );
  }
}

class _CompareSheet extends StatelessWidget {
  const _CompareSheet(this.d);
  final Map<String, dynamic> d;

  @override
  Widget build(BuildContext context) {
    final talents = [for (final x in (d['talents'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
    return SafeArea(
      child: ListView(padding: const EdgeInsets.all(20), shrinkWrap: true, children: [
        Text('Comparaison', style: mst(18, w: FontWeight.w800)),
        Text('${d['notice'] ?? ''}', style: mst(12, c: kGrey).copyWith(height: 1.4)),
        const SizedBox(height: 10),
        for (final t in talents)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border.all(color: kLine), borderRadius: BorderRadius.circular(6)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${t['name']}', style: mst(14.5, w: FontWeight.w800)),
              Text([if ('${t['department']}'.isNotEmpty) '${t['department']}', poolStageLabels['${t['stage']}'] ?? 'Sans étape'].join(' · '), style: mst(12, c: kGrey)),
              const SizedBox(height: 4),
              if (t['skills'] is List && (t['skills'] as List).isNotEmpty)
                for (final s in (t['skills'] as List))
                  Text('${(s as Map)['skill']} · ${s['level'] ?? 'niveau non indiqué'}${s['years'] != null ? ' · ${s['years']} an(s)' : ''}${s['proof_verified'] == true ? ' · justificatif vérifié' : ''}', style: mst(12.5))
              else if (t['skills'] is List)
                Text('Aucune compétence déclarée.', style: mst(12.5, c: kGrey))
              else
                Text('Rubrique « compétences » non partagée par ce talent${'${t['skills_text'] ?? ''}'.isEmpty ? '' : ' · profil : ${t['skills_text']}'}.', style: mst(12.5, c: kGrey)),
              if (t['availability'] is Map) Text('Disponibilités : ${((t['availability'] as Map)['kinds'] as List? ?? const []).join(', ')}', style: mst(12.5)),
              if (t['certificates'] != null) Text('Certificats vérifiables : ${t['certificates']}', style: mst(12.5)),
              Text('Notes internes : ${mInt(t['notes_count'])}', style: mst(12, c: kGrey)),
            ]),
          ),
      ]),
    );
  }
}
