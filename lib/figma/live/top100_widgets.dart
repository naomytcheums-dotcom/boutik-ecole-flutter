import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';
import 'social_posts.dart' show socialAvatar;
import 'top100_data.dart';

/// Éléments communs des pages du TOP 100 : états chargement / erreur / vide honnêtes, ligne de classement, barre de filtres.

/// Chargement, erreur lisible avec « Réessayer » (jamais un état vide ni un zéro), puis le contenu.
Widget top100Async<T>(AsyncValue<T> v, VoidCallback retry, Widget Function(T) builder) => v.when(
      loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        mNote(e is Top100Exception ? e.message : top100ErrorText('$e')),
        mButton('Réessayer', retry, dark: false),
      ]),
      data: builder,
    );

Widget top100Card(List<Widget> children, {EdgeInsets margin = const EdgeInsets.only(bottom: 12), VoidCallback? onTap}) {
  final box = Container(
    width: double.infinity,
    margin: margin,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );
  return onTap == null ? box : GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: box);
}

Widget top100Line(String label, String value, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(label, style: mst(13, c: kGrey))),
        const SizedBox(width: 8),
        Flexible(child: Text(value, textAlign: TextAlign.right, style: mst(13, w: FontWeight.w700, c: color ?? kInk))),
      ]),
    );

Widget top100Pill(String t, {Color bg = const Color(0xFFEEE9FF), Color fg = kViolet}) =>
    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)), child: Text(t, style: mst(11.5, w: FontWeight.w600, c: fg)));

/// Évolution du rang : positif = progression (le serveur donne rang précédent − rang actuel) ; null + nouveau = entrée du mois.
Widget? top100Delta(Map<String, dynamic> it) {
  if (it['is_new'] == true) return top100Pill('Nouveau', bg: const Color(0xFFE3F5EC), fg: kGreen);
  final d = it['delta_rank'];
  if (d is! num || d == 0) return null;
  return d > 0 ? top100Pill('▲ ${d.toInt()}', bg: const Color(0xFFE3F5EC), fg: kGreen) : top100Pill('▼ ${(-d).toInt()}', bg: const Color(0xFFFDE8E8), fg: kRed);
}

/// Ligne de classement : rang, photo (si acceptée), nom public, établissement, filière, compétences, badges, projets, score.
class Top100Row extends StatelessWidget {
  const Top100Row(this.it, {super.key, this.onTap});
  final Map<String, dynamic> it;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final name = tStr(it['name']);
    final skills = [for (final s in tList(it['skills'])) tStr(s['skill'])].where((s) => s.isNotEmpty).toList();
    final badges = tList(it['badges']);
    final projects = it['projects'];
    final delta = top100Delta(it);
    final place = [tStr(it['institution']), tStr(it['program'])].where((s) => s.isNotEmpty).join(' · ');
    final id = tStr(it['user_id']);
    return Semantics(
      container: true,
      label: 'Rang ${tNum(it['rank'])}, $name',
      child: top100Card(
        onTap: onTap ?? (id.isEmpty ? null : () => GoRouter.of(context).push('/top100/talent/$id')),
        [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 38, child: Text('#${tNum(it['rank'])}', style: mst(17, w: FontWeight.w800, c: kViolet))),
            socialAvatar(tStr(it['photo']), name, 44),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: mst(15, w: FontWeight.w800)),
                if (place.isNotEmpty) Text(place, maxLines: 2, overflow: TextOverflow.ellipsis, style: mst(12.5, c: kGrey)),
                if (tStr(it['promotion']).isNotEmpty) Text('Promotion ${it['promotion']}', style: mst(12, c: kGrey)),
              ]),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (it['score'] != null) Text('${tNum(it['score'])} pts', style: mst(15, w: FontWeight.w800)) else Text('Score non partagé', style: mst(11, c: kGrey)),
              if (it['month_points'] != null) Text('+${tNum(it['month_points'])} ce mois', style: mst(11.5, c: kGrey)),
              if (delta != null) Padding(padding: const EdgeInsets.only(top: 4), child: delta),
            ]),
          ]),
          if (skills.isNotEmpty || badges.isNotEmpty || projects != null) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final s in skills.take(5)) top100Pill(s),
              for (final b in badges) top100Pill('${b['code']}${mInt(b['count']) > 1 ? ' ×${mInt(b['count'])}' : ''}', bg: const Color(0xFFFFF3D6), fg: const Color(0xFF8A5A00)),
              if (projects != null) top100Pill('${mInt(projects)} projet${mInt(projects) > 1 ? 's' : ''}', bg: const Color(0xFFEFEFF3), fg: kInk),
            ]),
          ],
        ],
      ),
    );
  }
}

Map<String, String> _items(String all, Iterable<Top100Option> o) => {'': all, for (final x in o) x.id: x.name};

/// Barre de filtres d'un classement. Chaque changement renvoie une nouvelle requête (les paramètres envoyés suivent les filtres affichés).
class Top100FilterBar extends ConsumerWidget {
  const Top100FilterBar({super.key, required this.query, required this.onChanged, this.institution = true, this.program = true, this.department = false, this.domain = true, this.level = false, this.period = true});
  final Top100Query query;
  final ValueChanged<Top100Query> onChanged;
  final bool institution, program, department, domain, level, period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periods = ref.watch(top100PeriodsProvider).asData?.value ?? const <String>[];
    final inst = institution ? (ref.watch(top100InstitutionsProvider).asData?.value ?? const <Top100Option>[]) : const <Top100Option>[];
    final deps = department ? (ref.watch(top100DepartmentsProvider).asData?.value ?? const <Top100Option>[]) : const <Top100Option>[];
    final progs = program && query.institution.isNotEmpty ? (ref.watch(top100ProgramsProvider(query.institution)).asData?.value ?? const <Top100Option>[]) : const <Top100Option>[];
    Widget gap(Widget w) => Padding(padding: const EdgeInsets.only(bottom: 8), child: w);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(children: [
        if (period && periods.isNotEmpty)
          gap(MDropdown(label: 'Mois et année', value: query.period, items: {'': 'Dernier mois publié', for (final p in periods) p: top100PeriodLabel(p)}, onChanged: (v) => onChanged(query.copy(period: v)))),
        if (inst.isNotEmpty)
          gap(MDropdown(label: 'Établissement', value: query.institution, items: _items('Tous les établissements', inst), onChanged: (v) => onChanged(query.copy(institution: v, program: '')))),
        if (progs.isNotEmpty)
          gap(MDropdown(label: 'Filière', value: query.program, items: _items('Toutes les filières', progs), onChanged: (v) => onChanged(query.copy(program: v)))),
        if (deps.isNotEmpty)
          gap(MDropdown(label: 'Département', value: query.department, items: _items('Tous les départements', deps), onChanged: (v) => onChanged(query.copy(department: v)))),
        if (domain || level)
          Row(children: [
            if (domain) Expanded(child: _TextFilter(label: 'Domaine de compétence', initial: query.domain, onSubmit: (v) => onChanged(query.copy(domain: v)))),
            if (domain && level) const SizedBox(width: 8),
            if (level) Expanded(child: _TextFilter(label: 'Promotion vérifiée', initial: query.level, onSubmit: (v) => onChanged(query.copy(level: v)))),
          ]),
      ]),
    );
  }
}

class _TextFilter extends StatefulWidget {
  const _TextFilter({required this.label, required this.initial, required this.onSubmit});
  final String label, initial;
  final ValueChanged<String> onSubmit;
  @override
  State<_TextFilter> createState() => _TextFilterState();
}

class _TextFilterState extends State<_TextFilter> {
  late final c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: widget.label,
        textField: true,
        child: TextField(
          controller: c,
          textInputAction: TextInputAction.search,
          style: mst(13, w: FontWeight.w600),
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle: mst(12.5, c: kGrey),
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: kLine)),
            suffixIcon: IconButton(tooltip: 'Appliquer', icon: const Icon(Icons.search, size: 20), onPressed: () => widget.onSubmit(c.text.trim())),
          ),
          onSubmitted: (v) => widget.onSubmit(v.trim()),
        ),
      );
}

/// Contenu d'une liste de classement : « rien de publié » (note du serveur), filtres sans résultat, ou lignes.
List<Widget> top100ListBody(Map<String, dynamic> d, {String emptyFilter = 'Aucun talent ne correspond à ces filtres pour ce mois.'}) {
  if (d['published'] != true) return [mNote(tStr(d['note']).isEmpty ? top100NothingPublished : tStr(d['note']))];
  final items = tList(d['items']);
  return [
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Text('Classement de ${top100PeriodLabel(d['period'])}${d['total'] != null ? ' · ${tNum(d['total'])} talent${mInt(d['total']) > 1 ? 's' : ''}' : ''}', style: mst(12.5, w: FontWeight.w700, c: kGrey)),
    ),
    if (items.isEmpty) mNote(emptyFilter),
    for (final it in items) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Top100Row(it)),
  ];
}
