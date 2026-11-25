import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../gen.dart' show gAlert, gToast;
import '../i18n.dart' show Text;
import 'auth.dart';
import 'company_screens.dart' show companyContextProvider;
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';
import 'talent_pool.dart' show poolArgs, poolErrorText, refreshTalentPool, talentListsProvider;
import 'talent_pool_org.dart' show poolStageLabels;
import 'top100_admin_common.dart' show top100Str;

/// Talent Discovery (migration 20261127020300) : l'entreprise vérifiée (ou un membre actif de son équipe) cherche parmi les talents CLASSÉS qui ont consenti, selon des critères
/// concrets, comprend « pourquoi ce talent lui est proposé », compare 2 à 4 profils, garde des favoris et un vivier privé (Talent Cloud, `talent_pool_org.dart`) et contacte
/// (connexion, entretien, stage, emploi, mission). Aucune décision n'est automatique et aucun score n'est opaque : seules les rubriques partagées par le talent servent de critère.
/// Tout vient du serveur : serveur muet ou en panne = message d'erreur (jamais « aucun talent »), et aucune confirmation n'apparaît si l'écriture échoue.

/// Page publique d'un talent (écran de l'espace Top 100).
String top100TalentPath(String id) => '/top100/talent/$id';

const kDiscoveryLevels = {'': 'Tous niveaux', 'debutant': 'Débutant', 'intermediaire': 'Intermédiaire', 'avance': 'Avancé', 'expert': 'Expert'};
const kDiscoveryScopes = {'national': 'National', 'program': 'Filière', 'institution': 'Établissement', 'department': 'Département', 'domain': 'Domaine'};
const kDiscoverySorts = {'rank': 'Classement', 'score': 'Score', 'progression': 'Progression'};
const kDiscoveryAvailability = {'': 'Toute disponibilité', 'internship': 'Stage', 'vacation': 'Vacation', 'mission': 'Mission', 'job': 'Emploi', 'volunteer': 'Bénévolat'};
const kDiscoveryContactKinds = {
  'contact': 'Demande de connexion',
  'interview': 'Invitation à un entretien',
  'internship_offer': 'Proposition de stage',
  'job_offer': 'Proposition d’emploi',
  'mission_offer': 'Proposition de mission',
};
const _criterionLabels = {
  'national_rank': 'Rang national',
  'score': 'Score',
  'progression': 'Progression (rangs gagnés)',
  'skills': 'Compétences',
  'badges': 'Badges',
  'projects': 'Projets approuvés',
  'availability': 'Disponibilité',
};

Future<Map<String, dynamic>> _map(String fn, Map<String, dynamic> p) async {
  final r = await marcheCall(fn, p);
  if (r.error != null) throw MarcheException(r.error);
  return r.data is Map ? Map<String, dynamic>.from(r.data as Map) : <String, dynamic>{};
}

Future<List<Map<String, dynamic>>> _list(String fn, Map<String, dynamic> p) async {
  final r = await marcheCall(fn, p);
  if (r.error != null) throw MarcheException(r.error);
  return [for (final x in (r.data as List? ?? const [])) if (x is Map) Map<String, dynamic>.from(x)];
}

/// Établissements du dernier classement publié (filtre « établissement ») : vide tant qu'aucun classement n'est publié.
final discoveryInstitutionsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final d = await _map('ranking_institutions_public', const {});
  return [for (final x in (d['items'] is List ? d['items'] as List : const [])) if (x is Map) Map<String, dynamic>.from(x)];
}, retry: (_, _) => null);

final discoveryProgramsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, institution) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  return _list('programs_list', {'p_institution': institution});
}, retry: (_, _) => null);

final discoveryFavoritesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  return _list('discovery_favorites', poolArgs(ref.watch(companyContextProvider)));
}, retry: (_, _) => null);

/// Comparaison de 2 à 4 talents (clé = identifiants séparés par des virgules).
final discoveryCompareProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, ids) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  return _map('discovery_compare', poolArgs(ref.watch(companyContextProvider), {'p_students': ids.split(',')}));
}, retry: (_, _) => null);

String _fmt(Object? v) {
  if (v == null) return 'Non partagé';
  if (v is bool) return v ? 'Oui' : 'Non';
  if (v is num) return v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);
  if (v is List) {
    if (v.isEmpty) return 'Aucun';
    return v.map((e) {
      if (e is Map) {
        final name = e['skill'] ?? e['code'] ?? e['kind'] ?? e['name'];
        final extra = e['level'] ?? e['count'];
        return extra == null ? '$name' : '$name ($extra)';
      }
      return _fmt(e);
    }).join(', ');
  }
  if (v is Map) {
    final kinds = v['kinds'];
    if (kinds is List) {
      final labels = kinds.map((k) => kDiscoveryAvailability['$k'] ?? '$k').join(', ');
      return v['available_from'] == null ? labels : '$labels (dès ${v['available_from']})';
    }
    return v.entries.map((e) => '${e.key} : ${_fmt(e.value)}').join(', ');
  }
  return '$v';
}

InputDecoration _dec(String hint) => InputDecoration(
      hintText: hint,
      counterText: '',
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: kLine)),
    );

class TalentDiscoveryScreen extends ConsumerStatefulWidget {
  const TalentDiscoveryScreen({super.key});

  @override
  ConsumerState<TalentDiscoveryScreen> createState() => _DiscoveryState();
}

class _DiscoveryState extends ConsumerState<TalentDiscoveryScreen> {
  static const _pageSize = 20;
  final _skill = TextEditingController(), _domain = TextEditingController(), _promotion = TextEditingController(), _badge = TextEditingController();
  final _maxRank = TextEditingController(), _minScore = TextEditingController(), _minProgression = TextEditingController(), _minProjects = TextEditingController();
  String _institution = '', _program = '', _level = '', _scope = 'national', _kind = '', _sort = 'rank';
  bool _available = false, _showFilters = false, _loading = false;
  String? _error, _filterError;
  Map<String, dynamic>? _meta;
  final List<Map<String, dynamic>> _items = [];
  int _total = 0;
  final _picked = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _search());
  }

  @override
  void dispose() {
    for (final c in [_skill, _domain, _promotion, _badge, _maxRank, _minScore, _minProgression, _minProjects]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _org => ref.read(companyContextProvider);

  int get _activeFilters => [
        _institution, _program, _skill.text.trim(), _domain.text.trim(), _promotion.text.trim(), _badge.text.trim(), _maxRank.text.trim(), _minScore.text.trim(), _minProgression.text.trim(), _minProjects.text.trim(), _kind,
      ].where((s) => s.isNotEmpty).length + (_available ? 1 : 0) + (_scope != 'national' ? 1 : 0);

  /// Paramètres de la recherche, ou null (et message) si un nombre est invalide.
  Map<String, dynamic>? _args(int offset) {
    final out = <String, dynamic>{};
    for (final e in {'p_max_rank': _maxRank, 'p_min_score': _minScore, 'p_min_progression': _minProgression, 'p_min_projects': _minProjects}.entries) {
      final t = e.value.text.trim();
      if (t.isEmpty) continue;
      final n = int.tryParse(t);
      if (n == null || n < 0) {
        setState(() => _filterError = 'Les filtres chiffrés (classement, score, progression, projets) attendent un nombre entier positif.');
        return null;
      }
      out[e.key] = n;
    }
    setState(() => _filterError = null);
    final skill = _skill.text.trim();
    return poolArgs(_org, {
      ...out,
      if (_institution.isNotEmpty) 'p_institution': _institution,
      if (_program.isNotEmpty) 'p_program': _program,
      if (skill.isNotEmpty) 'p_skill': skill,
      if (skill.isNotEmpty && _level.isNotEmpty) 'p_min_level': _level,
      if (_domain.text.trim().isNotEmpty) 'p_domain': _domain.text.trim(),
      'p_scope': _scope,
      if (_available) 'p_available': true,
      if (_kind.isNotEmpty) 'p_availability_kind': _kind,
      if (_promotion.text.trim().isNotEmpty) 'p_promotion': _promotion.text.trim(),
      if (_badge.text.trim().isNotEmpty) 'p_badge': _badge.text.trim(),
      'p_sort': _sort,
      'p_limit': _pageSize,
      'p_offset': offset,
    });
  }

  Future<void> _search({bool more = false}) async {
    final args = _args(more ? _items.length : 0);
    if (args == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await _map('discovery_search', args);
      if (!mounted) return;
      setState(() {
        _meta = d;
        if (!more) _items.clear();
        _items.addAll([for (final x in (d['items'] is List ? d['items'] as List : const []) ) if (x is Map) Map<String, dynamic>.from(x)]);
        _total = mInt(d['total']);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is MarcheException ? '$e' : poolErrorText(e);
        if (!more) {
          _items.clear();
          _meta = null;
        }
        _loading = false;
      });
    }
  }

  void _reset() {
    for (final c in [_skill, _domain, _promotion, _badge, _maxRank, _minScore, _minProgression, _minProjects]) {
      c.clear();
    }
    setState(() {
      _institution = _program = _level = _kind = '';
      _scope = 'national';
      _sort = 'rank';
      _available = false;
    });
    _search();
  }

  Future<void> _favorite(Map<String, dynamic> t) async {
    final on = t['favorite'] != true;
    final r = await marcheCall('discovery_favorite_set', poolArgs(_org, {'p_student': t['user_id'], 'p_on': on}));
    if (!mounted) return;
    if (r.error != null) {
      await gAlert(context, 'Favori non modifié', poolErrorText(r.error));
      return;
    }
    setState(() => t['favorite'] = r.data is Map ? (r.data as Map)['favorite'] == true : on);
    ref.invalidate(discoveryFavoritesProvider);
    gToast(context, t['favorite'] == true ? 'Ajouté aux favoris.' : 'Retiré des favoris.');
  }

  Future<void> _pool(Map<String, dynamic> t) async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 420),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PoolSheet(student: '${t['user_id']}', name: '${t['name']}'),
    );
    if (added == true && mounted) {
      setState(() => t['in_pool'] = true);
      refreshTalentPool(ref);
    }
  }

  Future<void> _contact(Map<String, dynamic> t) async {
    final kind = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 420),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ContactSheet(student: '${t['user_id']}', name: '${t['name']}'),
    );
    if (kind == null || !mounted) return;
    setState(() => t['contact_sent'] = kDiscoveryContactKinds[kind] ?? kind);
    gToast(context, 'Demande envoyée à ${t['name']}.');
  }

  void _togglePick(String id, bool on) {
    if (on && _picked.length >= 4) {
      gToast(context, 'Vous pouvez comparer 4 profils au plus.');
      return;
    }
    setState(() => on ? _picked.add(id) : _picked.remove(id));
  }

  void _compare() => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TalentCompareScreen(ids: _picked.toList())));

  Widget _filters() {
    final institutions = ref.watch(discoveryInstitutionsProvider);
    final programs = _institution.isEmpty ? null : ref.watch(discoveryProgramsProvider(_institution));
    Widget input(String hint, TextEditingController c, {bool number = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextField(controller: c, keyboardType: number ? TextInputType.number : TextInputType.text, maxLength: 60, textInputAction: TextInputAction.search, onSubmitted: (_) => _search(), decoration: _dec(hint)),
        );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: kLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        institutions.when(
          loading: () => const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
          error: (e, _) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Établissements indisponibles : ${e is MarcheException ? e : poolErrorText(e)}', style: mst(12, c: kRed))),
          data: (rows) => rows.isEmpty
              ? Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Les filtres par établissement et filière apparaissent dès qu’un classement est publié.', style: mst(12, c: kGrey)))
              : Column(children: [
                  MDropdown(label: 'Établissement', value: _institution, items: {'': 'Tous les établissements', for (final i in rows) '${i['institution_id']}': '${i['name']}'}, onChanged: (v) => setState(() {
                        _institution = v;
                        _program = '';
                      })),
                  const SizedBox(height: 8),
                ]),
        ),
        if (programs != null)
          programs.when(
            loading: () => const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
            error: (e, _) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Filières indisponibles : ${e is MarcheException ? e : poolErrorText(e)}', style: mst(12, c: kRed))),
            data: (rows) => rows.isEmpty
                ? const SizedBox.shrink()
                : Padding(padding: const EdgeInsets.only(bottom: 8), child: MDropdown(label: 'Filière', value: _program, items: {'': 'Toutes les filières', for (final p in rows) '${p['id']}': '${p['name']}'}, onChanged: (v) => setState(() => _program = v))),
          ),
        input('Compétence (ex. Flutter)', _skill),
        MDropdown(label: 'Niveau minimal de la compétence', value: _level, items: kDiscoveryLevels, onChanged: (v) => setState(() => _level = v)),
        const SizedBox(height: 8),
        input('Domaine de compétence', _domain),
        input('Promotion', _promotion),
        input('Code de badge', _badge),
        MDropdown(label: 'Portée du classement', value: _scope, items: kDiscoveryScopes, onChanged: (v) => setState(() => _scope = v)),
        const SizedBox(height: 8),
        input('Rang maximal', _maxRank, number: true),
        input('Score minimal', _minScore, number: true),
        input('Progression minimale (rangs gagnés)', _minProgression, number: true),
        input('Nombre minimal de projets', _minProjects, number: true),
        MDropdown(label: 'Type de disponibilité', value: _kind, items: kDiscoveryAvailability, onChanged: (v) => setState(() => _kind = v)),
        const SizedBox(height: 4),
        Material(
          color: Colors.white,
          child: CheckboxListTile(contentPadding: EdgeInsets.zero, dense: true, controlAffinity: ListTileControlAffinity.leading, value: _available, onChanged: (v) => setState(() => _available = v == true), title: Text('Disponibles uniquement', style: mst(13, w: FontWeight.w600))),
        ),
        MDropdown(label: 'Trier par', value: _sort, items: kDiscoverySorts, onChanged: (v) => setState(() => _sort = v)),
        if (_filterError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_filterError!, style: mst(12.5, c: kRed))),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: mButton('Rechercher', _loading ? null : _search, icon: Icons.search_rounded)),
          const SizedBox(width: 8),
          Expanded(child: mButton('Réinitialiser', _reset, dark: false)),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final published = _meta == null ? null : _meta!['published'] != false;
    return MarchePage(
      title: 'Découvrir des talents',
      actions: [
        IconButton(tooltip: 'Mes favoris', icon: const Icon(Icons.star_border_rounded), onPressed: () => context.push('/discovery/favoris')),
        IconButton(tooltip: 'Vivier de talents', icon: const Icon(Icons.groups_2_outlined), onPressed: () => context.push('/entreprise/vivier')),
      ],
      child: Column(children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _search(),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
              Text('Les talents proposés ont consenti à être visibles, sont vérifiés et figurent au dernier classement publié. Seules les rubriques qu’ils partagent servent de critère : aucune décision de recrutement n’est prise automatiquement.', style: mst(12, c: kGrey).copyWith(height: 1.4)),
              const SizedBox(height: 10),
              Semantics(
                button: true,
                child: mButton(_showFilters ? 'Masquer les filtres' : 'Filtres${_activeFilters > 0 ? ' ($_activeFilters)' : ''}', () => setState(() => _showFilters = !_showFilters), dark: false, icon: Icons.tune_rounded),
              ),
              const SizedBox(height: 10),
              if (_showFilters) _filters(),
              if (_loading && _items.isEmpty) const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator())),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    Text(_error!, textAlign: TextAlign.center, style: mst(13.5, c: kGrey).copyWith(height: 1.5)),
                    const SizedBox(height: 8),
                    mButton('Réessayer', () => _search(more: _items.isNotEmpty), dark: false, icon: Icons.refresh_rounded),
                  ]),
                ),
              if (published == false && _error == null) mNote(top100Str(_meta?['note'], 'Aucun classement n’est publié pour le moment.')),
              if (published == true && _items.isEmpty && !_loading && _error == null)
                mNote(_activeFilters == 0 ? 'Aucun talent n’est proposé pour le moment : aucun talent classé n’a consenti à être visible.' : 'Aucun talent ne correspond à ces critères.'),
              if (_meta != null && _items.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('$_total talent${_total > 1 ? 's' : ''} · période ${_meta!['period'] ?? ''}', style: mst(12.5, w: FontWeight.w700, c: kGrey))),
              for (final t in _items)
                DiscoveryTalentCard(
                  key: ValueKey('talent-${t['user_id']}'),
                  talent: t,
                  picked: _picked.contains('${t['user_id']}'),
                  onPick: (on) => _togglePick('${t['user_id']}', on),
                  onProfile: () => context.push(top100TalentPath('${t['user_id']}')),
                  onFavorite: () => _favorite(t),
                  onPool: () => _pool(t),
                  onContact: () => _contact(t),
                ),
              if (_items.isNotEmpty && _items.length < _total) mButton(_loading ? 'Un instant…' : 'Voir plus de talents', _loading ? null : () => _search(more: true), dark: false),
              if (_meta != null && top100Str(_meta!['notice']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text('${_meta!['notice']}', style: mst(11.5, c: kGrey).copyWith(height: 1.4))),
            ]),
          ),
        ),
        if (_picked.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: kLine))),
            child: Row(children: [
              Expanded(child: Text(_picked.length < 2 ? 'Cochez au moins 2 profils pour comparer.' : '${_picked.length} profils choisis (4 au plus).', style: mst(12.5, c: kGrey))),
              mButton('Comparer (${_picked.length})', _picked.length >= 2 ? _compare : null, icon: Icons.compare_arrows_rounded),
            ]),
          ),
      ]),
    );
  }
}


/// Carte d'un talent : classement, preuves partagées, « pourquoi ce talent vous est proposé » et actions.
class DiscoveryTalentCard extends StatelessWidget {
  const DiscoveryTalentCard({super.key, required this.talent, required this.picked, required this.onPick, required this.onProfile, required this.onFavorite, required this.onPool, required this.onContact});
  final Map<String, dynamic> talent;
  final bool picked;
  final ValueChanged<bool> onPick;
  final VoidCallback onProfile, onFavorite, onPool, onContact;

  @override
  Widget build(BuildContext context) {
    final t = talent;
    final skills = [for (final s in (t['skills'] is List ? t['skills'] as List : const [])) if (s is Map) s];
    final badges = [for (final b in (t['badges'] is List ? t['badges'] as List : const [])) if (b is Map) b];
    final why = [for (final w in (t['why'] is List ? t['why'] as List : const [])) if (w is Map) w];
    final delta = t['is_new'] == true ? 'Nouveau' : (t['delta_rank'] is num ? ((t['delta_rank'] as num) > 0 ? '▲ ${t['delta_rank']}' : ((t['delta_rank'] as num) < 0 ? '▼ ${(t['delta_rank'] as num).abs()}' : '=')) : '');
    final sub = [for (final k in ['institution', 'program', 'promotion']) if (top100Str(t[k]).isNotEmpty) '${t[k]}'].join(' · ');
    final stage = top100Str(t['stage']);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: kLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFFEFEAFB), borderRadius: BorderRadius.circular(22)),
            child: Text(t['rank'] == null ? '—' : '#${t['rank']}', style: mst(13, w: FontWeight.w800, c: kViolet)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(top100Str(t['name'], 'Talent'), style: mst(15, w: FontWeight.w800)),
              if (sub.isNotEmpty) Text(sub, style: mst(12, c: kGrey).copyWith(height: 1.4)),
              const SizedBox(height: 4),
              Text([
                if (t['score'] != null) 'Score ${t['score']}',
                if (t['month_points'] != null) '${t['month_points']} pts ce mois',
                if (delta.isNotEmpty) delta,
                if (mInt(t['projects']) > 0) '${t['projects']} projet(s)',
              ].join(' · '), style: mst(12, w: FontWeight.w600)),
            ]),
          ),
        ]),
        if (skills.isNotEmpty || badges.isNotEmpty || stage.isNotEmpty || t['availability'] != null || t['contact_sent'] != null) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            if (t['contact_sent'] != null) _tag('Demande envoyée : ${t['contact_sent']}', c: kGreen),
            for (final s in skills) _tag('${s['skill']}${s['level'] == null ? '' : ' · ${kDiscoveryLevels['${s['level']}'] ?? s['level']}'}'),
            for (final b in badges) _tag('Badge ${b['code']}${b['count'] == null ? '' : ' ×${b['count']}'}'),
            if (t['availability'] != null) _tag('Disponible : ${_fmt(t['availability'])}', c: kGreen),
            if (stage.isNotEmpty) _tag('Vivier : ${poolStageLabels[stage] ?? stage}', c: kViolet),
          ]),
        ],
        const SizedBox(height: 10),
        Text('Pourquoi ce talent vous est proposé', style: mst(12.5, w: FontWeight.w800)),
        const SizedBox(height: 4),
        if (why.isEmpty) Text('Le serveur n’a communiqué aucun critère pour ce talent.', style: mst(12, c: kGrey)),
        for (final w in why)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(w['satisfied'] == false ? Icons.radio_button_unchecked_rounded : Icons.check_circle_rounded, size: 15, color: w['satisfied'] == false ? kGrey : kGreen),
              const SizedBox(width: 6),
              Expanded(child: Text('${w['label'] ?? w['criterion']}', style: mst(12, c: kGrey).copyWith(height: 1.35))),
            ]),
          ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          TextButton.icon(onPressed: onProfile, icon: const Icon(Icons.person_outline_rounded, size: 18), label: const Text('Profil')),
          TextButton.icon(onPressed: onFavorite, icon: Icon(t['favorite'] == true ? Icons.star_rounded : Icons.star_border_rounded, size: 18), label: Text(t['favorite'] == true ? 'Favori' : 'Ajouter aux favoris')),
          TextButton.icon(onPressed: onPool, icon: Icon(t['in_pool'] == true ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, size: 18), label: Text(t['in_pool'] == true ? 'Dans le vivier' : 'Vivier')),
          TextButton.icon(onPressed: onContact, icon: const Icon(Icons.mail_outline_rounded, size: 18), label: const Text('Contacter')),
          FilterChip(label: const Text('Comparer'), selected: picked, onSelected: onPick),
        ]),
      ]),
    );
  }

  Widget _tag(String s, {Color c = kInk}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: c.withValues(alpha: .08), borderRadius: BorderRadius.circular(100)),
        child: Text(s, style: mst(11.5, w: FontWeight.w600, c: c)),
      );
}

/// Fenêtre « Ajouter au vivier » : liste privée de l'organisation (Talent Cloud) et note interne.
class _PoolSheet extends ConsumerStatefulWidget {
  const _PoolSheet({required this.student, required this.name});
  final String student, name;

  @override
  ConsumerState<_PoolSheet> createState() => _PoolSheetState();
}

class _PoolSheetState extends ConsumerState<_PoolSheet> {
  final _note = TextEditingController();
  String? _list, _error;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await marcheCall('discovery_pool_add', poolArgs(ref.read(companyContextProvider), {'p_student': widget.student, 'p_list': _list, 'p_note': _note.text.trim()}));
    if (!mounted) return;
    if (r.error != null) {
      setState(() {
        _busy = false;
        _error = poolErrorText(r.error);
      });
      return;
    }
    Navigator.of(context).pop(true);
    gToast(context, '${widget.name} ajouté au vivier.');
  }

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(talentListsProvider);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Ajouter ${widget.name} au vivier', style: mst(17, w: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Le vivier est privé à votre organisation. Le talent n’est pas prévenu.', style: mst(12, c: kGrey)),
            const SizedBox(height: 10),
            lists.when(
              loading: () => const Padding(padding: EdgeInsets.all(18), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Column(children: [
                Text(e is MarcheException ? '$e' : poolErrorText(e), style: mst(13, c: kGrey)),
                mButton('Réessayer', () => ref.invalidate(talentListsProvider), dark: false, icon: Icons.refresh_rounded),
              ]),
              data: (rows) => rows.isEmpty
                  ? Column(children: [
                      Text('Aucune liste de vivier : créez-en une depuis « Vivier de talents ».', style: mst(13, c: kGrey)),
                      const SizedBox(height: 8),
                      mButton('Ouvrir le vivier', () {
                        Navigator.of(context).pop(false);
                        context.push('/entreprise/vivier');
                      }, dark: false),
                    ])
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      MDropdown(label: 'Liste', value: _list ?? '', items: {'': 'Choisir une liste', for (final l in rows) '${l['id']}': '${l['name']}'}, onChanged: (v) => setState(() => _list = v.isEmpty ? null : v)),
                      const SizedBox(height: 8),
                      TextField(controller: _note, maxLength: 300, minLines: 2, maxLines: 4, decoration: _dec('Note interne (facultative)')),
                      if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: mst(12.5, c: kRed))),
                      mButton('Ajouter au vivier', _list == null ? null : _add, busy: _busy, icon: Icons.bookmark_add_outlined),
                    ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Fenêtre « Contacter » : connexion, entretien, stage, emploi ou mission. Le talent est notifié ; le serveur limite les envois et respecte les blocages.
class _ContactSheet extends ConsumerStatefulWidget {
  const _ContactSheet({required this.student, required this.name});
  final String student, name;

  @override
  ConsumerState<_ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends ConsumerState<_ContactSheet> {
  final _message = TextEditingController();
  String _kind = 'contact';
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final m = _message.text.trim();
    if (_kind != 'contact' && m.length < 10) {
      setState(() => _error = 'Écrivez un message d’au moins 10 caractères pour cette demande.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await marcheCall('discovery_contact_request', poolArgs(ref.read(companyContextProvider), {'p_student': widget.student, 'p_kind': _kind, 'p_message': m}));
    if (!mounted) return;
    if (r.error != null) {
      setState(() {
        _busy = false;
        _error = poolErrorText(r.error);
      });
      return;
    }
    Navigator.of(context).pop(_kind);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Contacter ${widget.name}', style: mst(17, w: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Le talent est notifié et peut répondre ou refuser. La demande reste dans l’historique de votre vivier. Limites : 10 demandes par jour.', style: mst(12, c: kGrey).copyWith(height: 1.4)),
              const SizedBox(height: 10),
              MDropdown(label: 'Type de demande', value: _kind, items: kDiscoveryContactKinds, onChanged: (v) => setState(() => _kind = v)),
              const SizedBox(height: 8),
              TextField(controller: _message, maxLength: 500, minLines: 3, maxLines: 6, decoration: _dec(_kind == 'contact' ? 'Message (facultatif)' : 'Message (10 caractères au moins)')),
              if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: mst(12.5, c: kRed))),
              mButton('Envoyer', _send, busy: _busy, icon: Icons.send_rounded),
            ]),
          ),
        ),
      );
}

/// Comparaison de 2 à 4 talents : mêmes critères pour tous, valeur « non partagé » quand le talent ne partage pas la rubrique. Aucune recommandation automatique.
class TalentCompareScreen extends ConsumerWidget {
  const TalentCompareScreen({super.key, required this.ids});
  final List<String> ids;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = ids.join(',');
    final data = ref.watch(discoveryCompareProvider(key));
    return MarchePage(
      title: 'Comparer des talents',
      child: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(e is MarcheException ? '$e' : poolErrorText(e), textAlign: TextAlign.center, style: mst(13.5, c: kGrey).copyWith(height: 1.5)),
            const SizedBox(height: 10),
            mButton('Réessayer', () => ref.invalidate(discoveryCompareProvider(key)), dark: false, icon: Icons.refresh_rounded),
          ]),
        ),
        data: (d) {
          final talents = [for (final t in (d['talents'] is List ? d['talents'] as List : const [])) if (t is Map) Map<String, dynamic>.from(t)];
          final matrix = [for (final m in (d['matrix'] is List ? d['matrix'] as List : const [])) if (m is Map) Map<String, dynamic>.from(m)];
          final names = {for (final t in talents) '${t['user_id']}': top100Str(t['name'], 'Talent')};
          if (talents.isEmpty) return mNote('Aucun profil à comparer : les talents choisis ne sont plus visibles.');
          return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
            Text('Mêmes critères pour tous. « Non partagé » signifie que le talent n’a pas partagé cette rubrique : ce n’est pas un zéro. Aucune décision n’est prise automatiquement.', style: mst(12, c: kGrey).copyWith(height: 1.4)),
            const SizedBox(height: 10),
            for (final t in talents)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: kLine)),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(top100Str(t['name'], 'Talent'), style: mst(14.5, w: FontWeight.w800)),
                      Text([for (final k in ['institution', 'program', 'promotion']) if (top100Str(t[k]).isNotEmpty) '${t[k]}'].join(' · '), style: mst(12, c: kGrey)),
                      if (t['in_pool'] == true) Text('Dans votre vivier${top100Str(t['stage']).isEmpty ? '' : ' · ${poolStageLabels['${t['stage']}'] ?? t['stage']}'}', style: mst(11.5, c: kViolet, w: FontWeight.w600)),
                    ]),
                  ),
                  TextButton(onPressed: () => context.push(top100TalentPath('${t['user_id']}')), child: const Text('Profil')),
                ]),
              ),
            for (final m in matrix)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: kLine)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_criterionLabels['${m['criterion']}'] ?? '${m['criterion']}', style: mst(13, w: FontWeight.w800)),
                  const SizedBox(height: 4),
                  for (final v in (m['values'] is List ? m['values'] as List : const []))
                    if (v is Map)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(flex: 4, child: Text(names['${v['user_id']}'] ?? '', style: mst(12, c: kGrey))),
                          Expanded(flex: 6, child: Text(_fmt(v['value']), textAlign: TextAlign.right, style: mst(12.5, w: FontWeight.w600, c: v['value'] == null ? kGrey : kInk))),
                        ]),
                      ),
                ]),
              ),
            if (top100Str(d['notice']).isNotEmpty) Text('${d['notice']}', style: mst(11.5, c: kGrey).copyWith(height: 1.4)),
          ]);
        },
      ),
    );
  }
}

/// Favoris de l'organisation (talents encore consentants) ; le vivier complet et ses listes restent ceux du Talent Cloud.
class TalentFavoritesScreen extends ConsumerWidget {
  const TalentFavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs = ref.watch(discoveryFavoritesProvider);
    return MarchePage(
      title: 'Mes talents favoris',
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(discoveryFavoritesProvider),
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
          Text('Liste privée à votre organisation. Un talent qui retire son consentement disparaît de la liste.', style: mst(12, c: kGrey).copyWith(height: 1.4)),
          const SizedBox(height: 10),
          favs.when(
            loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Text(e is MarcheException ? '$e' : poolErrorText(e), textAlign: TextAlign.center, style: mst(13.5, c: kGrey).copyWith(height: 1.5)),
                const SizedBox(height: 8),
                mButton('Réessayer', () => ref.invalidate(discoveryFavoritesProvider), dark: false, icon: Icons.refresh_rounded),
              ]),
            ),
            data: (rows) => rows.isEmpty
                ? mNote('Aucun favori pour le moment.\nUtilisez « Ajouter aux favoris » depuis la recherche de talents.')
                : Column(children: [
                    for (final f in rows)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: kLine)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(top100Str(f['name'], 'Talent'), style: mst(15, w: FontWeight.w800)),
                          if (top100Str(f['stage']).isNotEmpty) Text('Étape : ${poolStageLabels['${f['stage']}'] ?? f['stage']}', style: mst(12, c: kGrey)),
                          if (top100Str(f['note']).isNotEmpty) Text('Note : ${f['note']}', style: mst(12, c: kGrey)),
                          Wrap(children: [
                            TextButton(onPressed: () => context.push(top100TalentPath('${f['user_id']}')), child: const Text('Profil')),
                            TextButton(
                              onPressed: () async {
                                final r = await marcheCall('discovery_favorite_set', poolArgs(ref.read(companyContextProvider), {'p_student': f['user_id'], 'p_on': false}));
                                if (!context.mounted) return;
                                if (r.error != null) {
                                  await gAlert(context, 'Favori non retiré', poolErrorText(r.error));
                                  return;
                                }
                                ref.invalidate(discoveryFavoritesProvider);
                                gToast(context, 'Retiré des favoris.');
                              },
                              child: const Text('Retirer des favoris'),
                            ),
                          ]),
                        ]),
                      ),
                  ]),
          ),
          const SizedBox(height: 8),
          mButton('Ouvrir le vivier de talents', () => context.push('/entreprise/vivier'), dark: false, icon: Icons.groups_2_outlined),
        ]),
      ),
    );
  }
}
