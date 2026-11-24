import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../gdata.dart' show gNetImage;
import '../i18n.dart' show Text;
import 'backend.dart';
import 'company_screens.dart' show companyContextProvider;
import 'f4_api.dart';
import 'marche/decouverte.dart' show marcheFilieres;
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';
import 'talent_pool.dart';
import 'tp_ui.dart' show GlassBack;

/// Recherche de talents réelle, partagée par les écrans 91 et 188 : champ de recherche (avec délai), filtres filière et compétences,
/// pagination « Voir plus », enregistrement dans les listes du vivier et accès au profil. Le serveur (fonction talents_search) applique
/// toutes les règles de visibilité : entreprise vérifiée, étudiant proposé aux recruteurs, nom abrégé, aucune coordonnée.

const _pageSize = 20;
const _maxSkills = 5;
const _talentFilieres = {...marcheFilieres, 'audiovisuel': 'Audiovisuel', 'mmi': 'MMI (multimédia)', 'design': 'Design'};

class TalentSearchPanel extends ConsumerStatefulWidget {
  const TalentSearchPanel({super.key});

  @override
  ConsumerState<TalentSearchPanel> createState() => _TalentSearchPanelState();
}

class _TalentSearchPanelState extends ConsumerState<TalentSearchPanel> {
  final _query = TextEditingController(), _skill = TextEditingController();
  Timer? _debounce;
  String _filiere = '', _list = '';
  final _skills = <String>[];
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _members = [];
  int _total = 0, _seq = 0;
  bool _loading = true, _more = false, _locked = false, _filters = false;
  String? _error, _reason;

  @override
  void initState() {
    super.initState();
    Future.microtask(_run);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _skill.dispose();
    super.dispose();
  }

  bool get _filtered => _filiere.isNotEmpty || _skills.isNotEmpty || _query.text.trim().isNotEmpty;

  void _onQuery(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _run);
    setState(() {});
  }

  /// Lance une nouvelle recherche (page 1), ou charge la page suivante quand [more] est vrai.
  Future<void> _run({bool more = false}) async {
    final seq = ++_seq;
    setState(() {
      if (more) {
        _more = true;
      } else {
        _loading = true;
        _error = null;
      }
    });
    if (_list.isNotEmpty) return _runList(seq);
    final res = await ref.read(f4RpcProvider)('talents_search', {'p_query': _query.text.trim(), 'p_filiere': _filiere, 'p_skills': _skills, 'p_limit': _pageSize, 'p_offset': more ? _items.length : 0});
    if (!mounted || seq != _seq) return;
    final d = res.data;
    setState(() {
      _loading = false;
      _more = false;
      if (res.error != null || d is! Map) {
        _error = res.error == 'offline' || res.error == 'missing' ? marcheErrorText(res.error) : Backend.userMessage(res.error ?? 'Recherche indisponible.');
        return;
      }
      final got = [for (final x in (d['items'] is List ? d['items'] as List : const []) ) if (x is Map) Map<String, dynamic>.from(x)];
      _locked = d['locked'] == true;
      _reason = d['reason'] as String?;
      _total = (d['total'] as num?)?.toInt() ?? 0;
      _items = more ? [..._items, ...got] : got;
    });
  }

  /// Mode « liste du vivier » : tous les membres de la liste (le serveur ne renvoie que les étudiants encore visibles), filtrés par le texte saisi.
  Future<void> _runList(int seq) async {
    final r = await ref.read(f4RpcProvider)('pool_list_members_get', poolArgs(ref.read(companyContextProvider), {'p_list': _list}));
    if (!mounted || seq != _seq) return;
    setState(() {
      _loading = false;
      _more = false;
      if (r.error != null) {
        _error = r.error == 'offline' || r.error == 'missing' ? marcheErrorText(r.error) : Backend.userMessage('${r.error}');
        return;
      }
      _members = [for (final x in (r.data as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
    });
  }

  List<Map<String, dynamic>> get _shownMembers {
    final q = _query.text.trim().toLowerCase();
    return q.isEmpty ? _members : [for (final m in _members) if ('${m['name']} ${m['department'] ?? ''}'.toLowerCase().contains(q)) m];
  }

  void _addSkill() {
    final s = _skill.text.trim();
    if (s.isEmpty || _skills.length >= _maxSkills || _skills.any((e) => e.toLowerCase() == s.toLowerCase())) return;
    setState(() => _skills.add(s));
    _skill.clear();
    _run();
  }

  void _reset() {
    _query.clear();
    setState(() {
      _filiere = '';
      _skills.clear();
    });
    _run();
  }

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(talentListsProvider).asData?.value ?? const <Map<String, dynamic>>[];
    final saved = ref.watch(talentSavedIdsProvider).asData?.value ?? const <String>{};
    final inList = _list.isNotEmpty;
    return Column(children: [
      Row(children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: TextField(
              controller: _query,
              textInputAction: TextInputAction.search,
              onChanged: _onQuery,
              onSubmitted: (_) {
                _debounce?.cancel();
                _run();
              },
              style: mst(14.5),
              decoration: InputDecoration(
                hintText: inList ? 'Chercher dans cette liste' : 'Nom, compétence, filière…',
                hintStyle: mst(14, c: kGrey),
                prefixIcon: const Icon(Icons.search_rounded, color: kGrey),
                suffixIcon: _query.text.isEmpty ? null : IconButton(tooltip: 'Effacer la recherche', icon: const Icon(Icons.close_rounded, color: kGrey), onPressed: _reset),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: const BorderSide(color: kLine)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: const BorderSide(color: kLine)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: const BorderSide(color: kViolet, width: 1.5)),
              ),
            ),
          ),
        ),
        if (!inList)
          SizedBox(
            width: 52,
            height: 52,
            child: IconButton(
              tooltip: 'Filtres : filière et compétences',
              onPressed: () => setState(() => _filters = !_filters),
              icon: Icon(Icons.tune_rounded, color: _filiere.isNotEmpty || _skills.isNotEmpty ? kViolet : kInk),
            ),
          ),
      ]),
      if (_filters && !inList)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            MDropdown(label: 'Filière', value: _filiere, items: _talentFilieres, onChanged: (v) {
              setState(() => _filiere = v);
              _run();
            }),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _skill,
                  maxLength: 40,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addSkill(),
                  decoration: InputDecoration(hintText: _skills.length >= _maxSkills ? '$_maxSkills compétences au plus' : 'Ajouter une compétence (Flutter, Figma…)', counterText: '', filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14), border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: kLine))),
                ),
              ),
              SizedBox(width: 48, height: 48, child: IconButton(tooltip: 'Ajouter la compétence', onPressed: _addSkill, icon: const Icon(Icons.add_circle_outline_rounded, color: kViolet))),
            ]),
            if (_skills.isNotEmpty)
              Wrap(spacing: 6, children: [
                for (final s in _skills) InputChip(label: Text(s), onDeleted: () {
                  setState(() => _skills.remove(s));
                  _run();
                }, deleteButtonTooltipMessage: 'Retirer $s'),
              ]),
          ]),
        ),
      SizedBox(
        height: 52,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          MChip('Tous', selected: !inList, onTap: () {
            if (!inList) return;
            setState(() => _list = '');
            _run();
          }),
          for (final l in lists) ...[
            const SizedBox(width: 6),
            MChip('${l['name']} (${mInt(l['count'])})', selected: _list == '${l['id']}', onTap: () {
              setState(() => _list = '${l['id']}');
              _run();
            }),
          ],
        ]),
      ),
      Expanded(child: _results(saved)),
    ]);
  }

  Widget _results(Set<String> saved) {
    final inList = _list.isNotEmpty;
    if (_loading) return const Center(child: Padding(padding: EdgeInsets.all(30), child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 12), Text('Recherche en cours…')])));
    if (_error != null) {
      return ListView(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 24, 16, 12), child: Text(_error!, textAlign: TextAlign.center, style: mst(14, c: kGrey).copyWith(height: 1.5))),
        mButton('Réessayer', _run, dark: false, icon: Icons.refresh_rounded),
      ]);
    }
    if (!inList && _locked) {
      return ListView(padding: const EdgeInsets.only(top: 8), children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFFFF1D6), borderRadius: BorderRadius.circular(6)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Icon(Icons.lock_outline_rounded, color: Color(0xFF9A5B00)), const SizedBox(width: 8), Expanded(child: Text('Recherche de talents réservée aux organisations vérifiées', style: mst(13.5, w: FontWeight.w800, c: const Color(0xFF9A5B00))))]),
            const SizedBox(height: 6),
            Text(_reason ?? 'Votre organisation doit être vérifiée avant de consulter les talents.', style: mst(12.5).copyWith(height: 1.4)),
          ]),
        ),
        const SizedBox(height: 10),
        mButton('Compléter la fiche d’organisation', () => context.push('/entreprise/profil'), icon: Icons.business_outlined),
      ]);
    }
    final rows = inList ? _shownMembers : _items;
    if (rows.isEmpty) {
      return ListView(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
          child: Text(
            inList ? (_members.isEmpty ? 'Cette liste est vide.\nEnregistrez des talents avec l’étoile pour les retrouver ici.' : 'Aucun talent de cette liste ne correspond à votre recherche.') : (_filtered ? 'Aucun talent ne correspond à votre recherche.\nEssayez moins de filtres ou un autre mot.' : 'Aucun talent n’est proposé aux recruteurs pour le moment.'),
            textAlign: TextAlign.center,
            style: mst(14, c: kGrey).copyWith(height: 1.5),
          ),
        ),
        if (!inList && _filtered) mButton('Effacer la recherche et les filtres', _reset, dark: false),
      ]);
    }
    final canMore = !inList && _items.length < _total;
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      itemCount: rows.length + 1 + (canMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == 0) return Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(inList ? '${rows.length} talent${rows.length > 1 ? 's' : ''} dans cette liste' : '$_total talent${_total > 1 ? 's' : ''} correspondent', style: mst(13, w: FontWeight.w700, c: kGrey)));
        if (i > rows.length) return mButton('Voir plus (${_total - _items.length} restants)', _more ? null : () => _run(more: true), dark: false, busy: _more);
        final t = rows[i - 1];
        return _TalentCard(t: t, saved: saved.contains('${t['id']}'));
      },
    );
  }
}

class _TalentCard extends ConsumerWidget {
  const _TalentCard({required this.t, required this.saved});
  final Map<String, dynamic> t;
  final bool saved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = '${t['id']}', name = '${t['name'] ?? ''}'.trim().isEmpty ? 'Étudiant' : '${t['name']}'.trim();
    final avatar = '${t['avatar_url'] ?? ''}';
    final line = [for (final k in ['department', 'institution']) if ('${t[k] ?? ''}'.trim().isNotEmpty) '${t[k]}'.trim()].join(' · ');
    final skills = '${t['skills'] ?? ''}'.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: kLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipOval(
            child: SizedBox(
              width: 48,
              height: 48,
              child: avatar.isEmpty ? _initials(name) : gNetImage(avatar, fit: BoxFit.cover, errorBuilder: (_, _, _) => _initials(name)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: mst(14.5, w: FontWeight.w800))),
                if (t['certified'] == true) ...[const SizedBox(width: 4), const Icon(Icons.verified_rounded, size: 16, color: kViolet)],
              ]),
              if (line.isNotEmpty) Text(line, maxLines: 1, overflow: TextOverflow.ellipsis, style: mst(12, c: kGrey)),
              if (skills.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(skills, maxLines: 2, overflow: TextOverflow.ellipsis, style: mst(12, c: kViolet, w: FontWeight.w600))),
            ]),
          ),
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              tooltip: saved ? 'Dans mes listes du vivier' : 'Enregistrer dans une liste du vivier',
              onPressed: () => showTalentListsSheet(context, ref, studentId: id, studentName: name),
              icon: Icon(saved ? Icons.star_rounded : Icons.star_border_rounded, color: saved ? const Color(0xFFF5A623) : kGrey),
            ),
          ),
        ]),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 8)),
            onPressed: () => context.push('/etudiant/$id'),
            child: Text('Voir le profil', style: mst(13, w: FontWeight.w700, c: kViolet)),
          ),
        ),
      ]),
    );
  }

  Widget _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final s = parts.isEmpty ? '?' : parts.take(2).map((e) => e[0].toUpperCase()).join();
    return Container(color: const Color(0xFFEFEBFA), alignment: Alignment.center, child: Text(s, style: mst(16, w: FontWeight.w800, c: kViolet)));
  }
}

/// Écran 91 (« Rechercher des talents ») en mise en page native : en-tête, puis le panneau de recherche.
class TalentSearchScreen extends StatelessWidget {
  const TalentSearchScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF4EFE6),
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
              child: SizedBox(
                height: 48,
                child: Row(children: [
                  Semantics(button: true, label: 'Retour', excludeSemantics: true, child: GlassBack(onTap: () => context.canPop() ? context.pop() : context.go('/s/03'))),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Rechercher des talents', maxLines: 1, overflow: TextOverflow.ellipsis, style: mst(21, w: FontWeight.w800))),
                ]),
              ),
            ),
            Expanded(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: TalentSearchPanel())))),
          ]),
        ),
      );
}
