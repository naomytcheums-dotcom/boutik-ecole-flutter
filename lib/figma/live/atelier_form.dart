import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/paths.dart' show screenPath;
import '../../core/utils/money.dart' show fcfa;
import '../gen.dart' show gAlert, gToast;
import '../i18n.dart' show Text;
import 'atelier.dart' show atelierMineProvider, atelierUpcomingProvider, atelierWhen;
import 'atelier_action.dart' show kLiveActionLabels;
import 'auth.dart' show authProvider, requireLogin;
import 'backend.dart';
import 'form_options.dart' show pickDate;
import 'lives.dart' show canBroadcastLive, liveBroadcastRule;
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';

/// Préparation d'un live (/atelier/preparer) : titre, catégorie, filière, secteur, hashtags, entreprises taguées (3 au plus), audience, commentaires, participation,
/// lancement immédiat ou programmation (date, fréquence, durée), gratuit ou payant (le prix est celui d'un événement existant : aucune règle financière nouvelle), rappels,
/// qualité vidéo, clips, audio seul, enregistrement du replay, message de notification et Action Unique. Création : create_live ; audience et événement : live_configure ;
/// réglages : live_set_settings ; enregistrement : live_recording_request (consentement des co-animateurs géré côté serveur). Modification : live_update (live programmé).

const kPrepareQualities = {'auto': 'Automatique', '480p': '480p', '720p': '720p', '1080p': '1080p'};
const kPrepareDurations = [30, 45, 60, 90, 120, 180];

/// Genre de cible attendu par action (null : l'action n'a pas de cible). « Postuler » ne propose que des opportunités : une mission n'a pas de fiche à ouvrir.
const kActionKinds = {
  'acheter': 'listing',
  'reserver': 'listing',
  'demander_devis': 'listing',
  'telecharger': 'listing',
  'noter': 'listing',
  'postuler': 'opportunity',
  's_inscrire': 'event',
  'voter': 'project',
  'soutenir': 'project',
  'encourager': 'project',
  'parrainer': null,
  'offrir': null,
};

const _kindNames = {'listing': 'annonce', 'opportunity': 'opportunité', 'event': 'événement', 'project': 'projet'};

bool actionFits(String action, Map<String, dynamic> target) {
  final t = '${target['offer_type'] ?? ''}';
  return switch (action) {
    'acheter' => const {'product', 'tech', 'project'}.contains(t),
    'reserver' => t == 'service',
    'demander_devis' => const {'service', 'tech', 'project'}.contains(t),
    'telecharger' => t == 'tech',
    _ => true,
  };
}

/// « #Soudure, bois  atelier » -> [soudure, bois, atelier] (minuscules, sans # ni doublon).
List<String> parseHashtags(String raw) {
  final out = <String>[];
  for (final p in raw.split(RegExp(r'[\s,;]+'))) {
    final t = p.replaceFirst(RegExp(r'^#+'), '').toLowerCase();
    if (t.isNotEmpty && !out.contains(t)) out.add(t);
  }
  return out;
}

final _tagRe = RegExp(r'^[a-z0-9_àâäçéèêëîïôöùûüœ]{2,30}$');

Map<String, dynamic> _map(Object? o) => o is Map ? Map<String, dynamic>.from(o) : <String, dynamic>{};

class LivePrepareScreen extends ConsumerStatefulWidget {
  const LivePrepareScreen({super.key, this.liveId, this.startNow = false});
  final String? liveId;
  final bool startNow;

  @override
  ConsumerState<LivePrepareScreen> createState() => _LivePrepareState();
}

class _LivePrepareState extends ConsumerState<LivePrepareScreen> {
  final _title = TextEditingController(), _desc = TextEditingController(), _category = TextEditingController(), _filiere = TextEditingController();
  final _sector = TextEditingController(), _tags = TextEditingController(), _notify = TextEditingController();
  List<Map<String, dynamic>> _orgs = [];
  String _audience = 'public', _frequency = 'once', _quality = 'auto', _comments = 'all', _participation = 'on_request';
  bool _eventIsFree = false, _schedule = true, _reminders = true, _clips = true, _audioOnly = false, _record = false, _paid = false, _loading = false, _busy = false;
  int _sessions = 2;
  int? _duration;
  DateTime? _when;
  String? _event, _action, _targetKind, _targetId, _targetTitle, _loadError, _liveType, _mission, _opportunity, _status;
  bool get _editing => widget.liveId != null;

  @override
  void initState() {
    super.initState();
    _schedule = !widget.startNow;
    if (_editing) {
      _loading = true;
      _load();
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _desc, _category, _filiere, _sector, _tags, _notify]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final s = await marcheCall('live_settings_get', {'p_live': widget.liveId});
    final g = await marcheCall('live_get', {'p_live': widget.liveId});
    if (!mounted) return;
    final d = s.data is Map ? _map(s.data) : null;
    if (s.error != null || d == null || d['mine'] != true) {
      return setState(() {
        _loading = false;
        _loadError = s.error != null ? Backend.userMessage('${s.error}') : 'Seul l’hôte peut modifier ce live.';
      });
    }
    final live = g.data is Map ? _map(g.data) : <String, dynamic>{};
    setState(() {
      _loading = false;
      _status = '${d['status']}';
      _title.text = '${d['title'] ?? ''}';
      _desc.text = '${d['description'] ?? ''}';
      _category.text = '${d['category'] ?? ''}';
      _filiere.text = '${d['filiere'] ?? ''}';
      _sector.text = '${d['sector'] ?? ''}';
      _tags.text = [for (final t in (d['hashtags'] as List? ?? const [])) '#$t'].join(' ');
      _notify.text = '${d['notify_message'] ?? ''}';
      _orgs = [for (final o in (d['tagged_orgs'] as List? ?? const [])) _map(o)];
      _audience = d['visibilite'] == 'prive' ? 'prive' : 'public';
      _frequency = '${d['frequency'] ?? 'once'}';
      _quality = '${d['video_quality'] ?? 'auto'}';
      _comments = '${d['comments_mode'] ?? 'all'}';
      _participation = '${d['participation_mode'] ?? 'on_request'}';
      _reminders = d['reminders_enabled'] != false;
      _clips = d['clips_allowed'] != false;
      _audioOnly = d['audio_only'] == true;
      _record = d['record_replay'] == true;
      _duration = (d['duration_min'] as num?)?.toInt();
      _when = DateTime.tryParse('${d['scheduled_at'] ?? ''}')?.toLocal();
      _schedule = d['status'] == 'scheduled';
      _event = d['event_id'] as String?;
      _paid = ((d['price'] as num?)?.toInt() ?? 0) > 0;
      _eventIsFree = _event != null && !_paid;
      _liveType = '${d['live_type'] ?? 'public'}';
      _mission = live['mission_id'] as String?;
      _opportunity = live['opportunity_id'] as String?;
      _action = d['main_action_raw'] as String?;
      _targetKind = d['action_target_kind_raw'] as String?;
      _targetId = d['action_target_id_raw'] as String?;
      _targetTitle = d['action_target_title'] as String?;
    });
  }

  // ------------------------------------------------------------ choix

  Future<void> _addOrg() async {
    if (_orgs.length >= 3) return gToast(context, 'Trois entreprises taguées au plus.');
    final picked = await showModalBottomSheet<Map<String, dynamic>>(context: context, isScrollControlled: true, backgroundColor: Colors.white, builder: (_) => const _OrgPicker());
    if (picked == null || !mounted) return;
    if (_orgs.any((o) => '${o['owner_id']}' == '${picked['owner_id']}')) return gToast(context, 'Cette entreprise est déjà taguée.');
    if (_orgs.length >= 3) return gToast(context, 'Trois entreprises taguées au plus.');
    setState(() => _orgs = [..._orgs, picked]);
  }

  Future<void> _pickWhen() async {
    final d = await pickDate(context: context, initialDate: _when ?? DateTime.now().add(const Duration(days: 1)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_when ?? DateTime(2026, 1, 1, 16)));
    if (t == null || !mounted) return;
    setState(() => _when = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<List<Map<String, dynamic>>?> _targets(String kind) async {
    final r = await marcheCall('live_action_targets', {'p_kind': kind});
    if (!mounted) return null;
    if (r.error != null) {
      gToast(context, Backend.userMessage('${r.error}'));
      return null;
    }
    return [for (final x in (r.data as List? ?? const [])) _map(x)];
  }

  Future<void> _chooseAction(String? action) async {
    if (action == null) return setState(() { _action = null; _targetKind = null; _targetId = null; _targetTitle = null; });
    final kind = kActionKinds[action];
    if (kind == null) return setState(() { _action = action; _targetKind = null; _targetId = null; _targetTitle = null; });
    final all = await _targets(kind);
    if (all == null || !mounted) return;
    final fit = [for (final t in all) if (kind != 'listing' || actionFits(action, t)) t];
    if (fit.isEmpty) return gAlert(context, 'Aucune cible disponible', 'Vous n’avez aucun(e) ${_kindNames[kind]} publié(e) qui convienne à « ${kLiveActionLabels[action]} ». Publiez-en un(e) d’abord.');
    final t = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 4), child: Text('${kLiveActionLabels[action]} : choisir ${_kindNames[kind] == 'annonce' ? 'l’annonce' : 'la cible'}', style: mst(17, w: FontWeight.w800))),
          for (final x in fit) ListTile(title: Text('${x['title']}'), subtitle: x['price'] != null ? Text(fcfa((x['price'] as num).toInt())) : null, onTap: () => Navigator.of(ctx).pop(x)),
        ]),
      ),
    );
    if (t == null || !mounted) return;
    setState(() { _action = action; _targetKind = kind; _targetId = '${t['id']}'; _targetTitle = '${t['title']}'; });
  }

  Future<void> _choosePaidEvent() async {
    final all = await _targets('event');
    if (all == null || !mounted) return;
    final paid = [for (final e in all) if (((e['price'] as num?)?.toInt() ?? 0) > 0) e];
    if (paid.isEmpty) {
      setState(() => _paid = false);
      return gAlert(context, 'Aucun événement payant', 'Un live payant s’appuie sur un événement payant existant (son prix et son inscription). Créez d’abord l’événement, puis liez-le ici.');
    }
    final e = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 4), child: Text('Événement payant lié', style: mst(17, w: FontWeight.w800))),
          for (final x in paid) ListTile(title: Text('${x['title']}'), subtitle: Text('${fcfa((x['price'] as num).toInt())} · ${atelierWhen(x['starts_at'])}'), onTap: () => Navigator.of(ctx).pop(x)),
        ]),
      ),
    );
    if (!mounted) return;
    setState(() { if (e == null) { _paid = _event != null; } else { _event = '${e['id']}'; _paid = true; } });
  }

  // ------------------------------------------------------------ enregistrement

  String? _validate() {
    final title = _title.text.trim();
    if (title.length < 3 || title.length > 100) return 'Le titre est obligatoire (3 à 100 caractères).';
    if (_desc.text.trim().length > 500) return 'La description fait 500 caractères au plus.';
    final tags = parseHashtags(_tags.text);
    if (tags.length > 8) return '8 hashtags au plus.';
    if (tags.any((t) => !_tagRe.hasMatch(t))) return 'Hashtag invalide : 2 à 30 lettres ou chiffres, sans espace ni lien.';
    if (_orgs.length > 3) return 'Trois entreprises taguées au plus.';
    if (_schedule && (_status ?? 'scheduled') == 'scheduled') {
      if (_when == null) return 'Choisissez la date et l’heure du live.';
      if (_when!.isBefore(DateTime.now().add(const Duration(minutes: 5)))) return 'Choisissez une date et une heure à venir.';
    }
    if (_paid && _event == null) return 'Un live payant doit être lié à un événement payant existant.';
    if (_action != null && kActionKinds[_action] != null && _targetId == null) return 'L’action « ${kLiveActionLabels[_action]} » exige une cible : choisissez l’élément concerné.';
    return null;
  }

  Map<String, dynamic> _settings() => {
        'category': _category.text.trim(),
        'filiere': _filiere.text.trim(),
        'sector': _sector.text.trim(),
        'hashtags': parseHashtags(_tags.text),
        'tagged_orgs': [for (final o in _orgs) '${o['owner_id']}'],
        'comments_mode': _comments,
        'participation_mode': _participation,
        'frequency': _schedule ? _frequency : 'once',
        'duration_min': _duration,
        'reminders_enabled': _reminders,
        'video_quality': _quality,
        'clips_allowed': _clips,
        'audio_only': _audioOnly,
        'record_replay': _record,
        'notify_message': _notify.text.trim(),
        'main_action': _action,
        'action_target_kind': _targetKind,
        'action_target_id': _targetId,
      };

  Future<String?> _configure(String live) async {
    final type = _audience == 'prive' ? 'prive' : ((_liveType == null || _liveType == 'prive') ? 'public' : _liveType);
    final c = await Backend.rpc('live_configure', {'p_live': live, 'p_type': type, 'p_visibilite': _audience, 'p_event': _paid || _eventIsFree ? _event : null, 'p_mission': _mission, 'p_opportunity': _opportunity});
    if (c.error != null) return Backend.userMessage(c.error!);
    final s = await Backend.rpc('live_set_settings', {'p_live': live, 'p_settings': _settings()});
    if (s.error != null) return Backend.userMessage(s.error!);
    if (_record) {
      final r = await Backend.rpc('live_recording_request', {'p_live': live});
      if (r.error != null) return Backend.userMessage(r.error!);
    }
    return null;
  }

  Future<void> _save() async {
    if (_busy) return;
    final problem = _validate();
    if (problem != null) return gAlert(context, 'Live incomplet', problem);
    if (!Backend.ready) return gAlert(context, 'Hors connexion', 'Cette action nécessite la connexion au serveur.');
    if (!await requireLogin(context, ref, 'créer un live') || !mounted) return;
    if (!canBroadcastLive(ref.read(authProvider).current)) return gAlert(context, 'Diffusion réservée', liveBroadcastRule);
    setState(() => _busy = true);
    final title = _title.text.trim(), desc = _desc.text.trim();
    if (_editing) {
      final id = widget.liveId!;
      if (_status == 'scheduled') {
        final u = await Backend.rpc('live_update', {'p_live': id, 'p_title': title, 'p_description': desc, 'p_scheduled_at': _when?.toUtc().toIso8601String()});
        if (!mounted) return;
        if (u.error != null) return _fail('Modification impossible', Backend.userMessage(u.error!));
      }
      final err = await _configure(id);
      if (!mounted) return;
      if (err != null) return _fail('Réglages non enregistrés', err);
      _refresh();
      gToast(context, 'Modifications enregistrées.');
      return _leave();
    }
    final count = _schedule && _frequency == 'weekly' ? _sessions : 1;
    final ids = <String>[];
    for (var i = 0; i < count; i++) {
      final at = _schedule ? _when!.add(Duration(days: 7 * i)) : null;
      final c = await Backend.rpc('create_live', {'p_title': title, 'p_description': desc, 'p_cover_path': null, 'p_scheduled_at': at?.toUtc().toIso8601String()});
      if (!mounted) return;
      if (c.error != null) {
        _refresh();
        return _fail(ids.isEmpty ? 'Live non créé' : 'Série incomplète', ids.isEmpty ? Backend.userMessage(c.error!) : '${ids.length} séance(s) créée(s) sur $count : ${Backend.userMessage(c.error!)} Retrouvez-les dans « Mes lives ».');
      }
      ids.add('${c.data}');
    }
    String? err;
    for (final id in ids) {
      err = await _configure(id);
      if (!mounted) return;
      if (err != null) break;
    }
    _refresh();
    if (err != null) return _fail('Live créé, réglages non enregistrés', '$err Le live existe : ouvrez « Mes lives » puis « Modifier » pour terminer.');
    if (!_schedule) {
      final target = '${screenPath('L1')}?live=${ids.first}';
      GoRouter.of(context).pushReplacement(target);
      return;
    }
    gToast(context, count > 1 ? '$count séances programmées.' : 'Live programmé : il apparaît dans « À venir ».');
    _leave();
  }

  void _fail(String title, String message) {
    setState(() => _busy = false);
    gAlert(context, title, message);
  }

  void _refresh() {
    ref.invalidate(atelierMineProvider);
    ref.invalidate(atelierUpcomingProvider);
  }

  void _leave() {
    setState(() => _busy = false);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/atelier?tab=3');
    }
  }

  // ------------------------------------------------------------ interface

  Widget _section(String t) => Padding(padding: const EdgeInsets.only(top: 22, bottom: 8), child: Text(t, style: mst(16, w: FontWeight.w800)));

  Widget _field(TextEditingController c, String label, {int? maxLength, int lines = 1, String? hint, Key? key}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          key: key,
          controller: c,
          maxLength: maxLength,
          minLines: lines,
          maxLines: lines + 1,
          decoration: InputDecoration(labelText: label, hintText: hint, counterText: '', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLine))),
        ),
      );

  Widget _switch(String label, bool v, ValueChanged<bool> on, {String? note}) => SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(label, style: mst(14, w: FontWeight.w600)), subtitle: note == null ? null : Text(note, style: mst(12, c: kGrey)), value: v, onChanged: on);

  @override
  Widget build(BuildContext context) {
    final signed = ref.watch(authProvider.select((a) => a.current != null));
    final allowed = !Backend.ready || canBroadcastLive(ref.watch(authProvider).current);
    return MarchePage(
      title: _editing ? 'Modifier le live' : (widget.startNow ? 'Lancer un live' : 'Préparer un live'),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? mNote(_loadError!)
              : !signed
                  ? mNote('Connectez-vous pour créer un live.')
                  : !allowed
                      ? mNote(liveBroadcastRule)
                      : _form(),
    );
  }

  Widget _form() {
    final editable = !_editing || _status == 'scheduled';
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 120), children: [
      _section('Votre live'),
      _field(_title, 'Titre du live *', maxLength: 100, key: const Key('prep-title')),
      _field(_desc, 'Description (facultatif)', maxLength: 500, lines: 3),
      _field(_category, 'Catégorie', maxLength: 60, hint: 'Ex. Atelier, démonstration, vente…'),
      _field(_filiere, 'Filière', maxLength: 80),
      _field(_sector, 'Secteur d’activité', maxLength: 80),
      _field(_tags, 'Hashtags', hint: '#soudure #atelier (8 au plus)'),
      _section('Entreprises taguées (3 au plus)'),
      Wrap(spacing: 8, runSpacing: 4, children: [
        for (final o in _orgs) InputChip(label: Text('${o['name']}'), onDeleted: () => setState(() => _orgs = [for (final x in _orgs) if (x != o) x])),
        ActionChip(avatar: const Icon(Icons.add_business_outlined, size: 18), label: const Text('Taguer une entreprise'), onPressed: _addOrg),
      ]),
      Padding(padding: const EdgeInsets.only(top: 4), child: Text('Seules les entreprises vérifiées peuvent être taguées.', style: mst(12, c: kGrey))),
      _section('Audience et interactions'),
      Wrap(spacing: 8, children: [
        ChoiceChip(label: const Text('Tout le monde'), selected: _audience == 'public', onSelected: (_) => setState(() => _audience = 'public')),
        ChoiceChip(label: const Text('Sur invitation'), selected: _audience == 'prive', onSelected: (_) => setState(() => _audience = 'prive')),
      ]),
      _switch('Autoriser les commentaires', _comments == 'all', (v) => setState(() => _comments = v ? 'all' : 'off')),
      _switch('Autoriser la participation en direct (sur demande)', _participation == 'on_request', (v) => setState(() => _participation = v ? 'on_request' : 'off')),
      _section('Date et durée'),
      if (!_editing)
        Wrap(spacing: 8, children: [
          ChoiceChip(label: const Text('Lancer maintenant'), selected: !_schedule, onSelected: (_) => setState(() => _schedule = false)),
          ChoiceChip(label: const Text('Programmer'), selected: _schedule, onSelected: (_) => setState(() => _schedule = true)),
        ]),
      if (_schedule && editable) ...[
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: _pickWhen, icon: const Icon(Icons.event_outlined), label: Text(_when == null ? 'Choisir la date et l’heure' : atelierWhen(_when!.toIso8601String()))),
        if (!_editing)
          Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            ChoiceChip(label: const Text('Une seule fois'), selected: _frequency == 'once', onSelected: (_) => setState(() => _frequency = 'once')),
            ChoiceChip(label: const Text('Chaque semaine'), selected: _frequency == 'weekly', onSelected: (_) => setState(() => _frequency = 'weekly')),
            if (_frequency == 'weekly') ...[
              IconButton(tooltip: 'Moins de séances', icon: const Icon(Icons.remove_circle_outline), onPressed: _sessions > 2 ? () => setState(() => _sessions--) : null),
              Text('$_sessions séances', style: mst(13, w: FontWeight.w700)),
              IconButton(tooltip: 'Plus de séances', icon: const Icon(Icons.add_circle_outline), onPressed: _sessions < 8 ? () => setState(() => _sessions++) : null),
            ],
          ]),
      ],
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        for (final d in kPrepareDurations) ChoiceChip(label: Text('$d min'), selected: _duration == d, onSelected: (s) => setState(() => _duration = s ? d : null)),
      ]),
      _section('Gratuit ou payant'),
      Wrap(spacing: 8, children: [
        ChoiceChip(label: const Text('Gratuit'), selected: !_paid, onSelected: (_) => setState(() { _paid = false; if (!_eventIsFree) _event = null; })),
        ChoiceChip(label: const Text('Payant'), selected: _paid, onSelected: (_) => _choosePaidEvent()),
      ]),
      Padding(padding: const EdgeInsets.only(top: 4), child: Text(_paid && _event != null ? 'Le prix et l’inscription sont ceux de l’événement lié.' : 'Un live payant s’appuie sur un événement payant existant : son prix et son inscription ne changent pas.', style: mst(12, c: kGrey))),
      _section('Diffusion'),
      _switch('Rappels pour les inscrits', _reminders, (v) => setState(() => _reminders = v)),
      _switch('Autoriser les clips', _clips, (v) => setState(() => _clips = v), note: 'Création de clips : service à configurer.'),
      _switch('Audio seul', _audioOnly, (v) => setState(() => _audioOnly = v), note: 'Réglage enregistré ; son application par la régie vidéo : service à configurer.'),
      _switch('Enregistrer le replay', _record, (v) => setState(() => _record = v), note: 'Les co-animateurs doivent y consentir. Sans enregistreur configuré sur ce serveur, aucun replay n’est créé.'),
      Align(alignment: Alignment.centerLeft, child: Text('Qualité vidéo (service à configurer)', style: mst(13, w: FontWeight.w600))),
      Wrap(spacing: 8, children: [
        for (final e in kPrepareQualities.entries) ChoiceChip(label: Text(e.value), selected: _quality == e.key, onSelected: (_) => setState(() => _quality = e.key)),
      ]),
      _section('Message de notification'),
      _field(_notify, 'Message ajouté au rappel (facultatif)', maxLength: 200),
      _section('Action Unique'),
      Text('Un seul bouton clair pour les spectateurs, qui ouvre le parcours existant sans quitter le live.', style: mst(12.5, c: kGrey)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 4, children: [
        ChoiceChip(label: const Text('Aucune'), selected: _action == null, onSelected: (_) => _chooseAction(null)),
        for (final e in kLiveActionLabels.entries) ChoiceChip(label: Text(e.value), selected: _action == e.key, onSelected: (_) => _chooseAction(e.key)),
      ]),
      if (_action != null && _targetTitle != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Cible : $_targetTitle', style: mst(13, w: FontWeight.w700, c: kViolet))),
      const SizedBox(height: 24),
      mButton(_editing ? 'Enregistrer les modifications' : (_schedule ? 'Programmer le live' : 'Lancer le live'), _busy ? null : _save, busy: _busy),
    ]);
  }
}

class _OrgPicker extends ConsumerStatefulWidget {
  const _OrgPicker();
  @override
  ConsumerState<_OrgPicker> createState() => _OrgPickerState();
}

class _OrgPickerState extends ConsumerState<_OrgPicker> {
  final _q = TextEditingController();
  List<Map<String, dynamic>>? _rows;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    final r = await marcheCall('live_orgs_search', {'p_query': q, 'p_limit': 20});
    if (!mounted) return;
    setState(() {
      _error = r.error == null ? null : Backend.userMessage('${r.error}');
      _rows = r.error == null ? [for (final x in (r.data as List? ?? const [])) _map(x)] : null;
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: TextField(controller: _q, onChanged: _search, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Rechercher une entreprise vérifiée'))),
              Expanded(
                child: _error != null
                    ? mNote(_error!)
                    : _rows == null
                        ? const Center(child: CircularProgressIndicator())
                        : _rows!.isEmpty
                            ? mNote('Aucune entreprise vérifiée ne correspond.')
                            : ListView(children: [for (final o in _rows!) ListTile(title: Text('${o['name']}'), subtitle: '${o['sector'] ?? ''}'.isEmpty ? null : Text('${o['sector']}'), onTap: () => Navigator.of(context).pop(o))]),
              ),
            ]),
          ),
        ),
      );
}
