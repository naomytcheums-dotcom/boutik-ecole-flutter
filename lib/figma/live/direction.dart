import 'dart:convert';

import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../gen.dart' show gAlert, gConfirm, gDialog, gToast;
import 'access.dart' show roleKey;
import 'auth.dart';
import 'backend.dart';
import 'download_stub.dart' if (dart.library.js_interop) 'download_web.dart';
import 'entreprise.dart' show dateCourte;
import 'impact.dart' show SponsorReportPanel;
import 'lot20.dart' show journalListing;
import 'lots.dart' show toCsv;
import 'partnership_org_picker.dart';
import 'store.dart' show fcfa;

/// Espace de la direction (lot H3) : autorité institutionnelle, distincte de l'administrateur global.
/// Vision transversale en LECTURE (tableau de bord, départements, activités, performances, rapports consolidés, finance consolidée),
/// partenariats institutionnels et validations institutionnelles. Toutes les données viennent des fonctions serveur direction_*,
/// partnership_* et institutional_* (migrations 20261120030000 à 20261120030200) ; le serveur reste l'autorité. Rien n'est inventé.

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
const _accent = Color(0xFF5A3FE0);
const _lineColor = Color(0xFFEEECE8);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

typedef DirectionRpc = Future<({Object? data, String? error})> Function(String fn, Map<String, dynamic> args);

/// Appel serveur des écrans de la direction (remplaçable dans les tests).
DirectionRpc directionRpc = (fn, args) => Backend.rpc(fn, args);

int _n(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
List<Map<String, dynamic>> _list(Object? v) => [for (final x in (v is List ? v : const [])) if (x is Map) Map<String, dynamic>.from(x)];
Map<String, dynamic> _map(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
String _s(Object? v) => v == null ? '' : '$v';
String _day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const partnerKinds = {
  'entreprise': 'Entreprise commerciale',
  'association': 'Association',
  'ong': 'ONG',
  'institution': 'Institution',
  'universite': 'Université ou école',
  'collectivite': 'Collectivité',
  'autre': 'Autre',
};
const partnerStatuses = {'proposed': 'À valider', 'active': 'Actif', 'suspended': 'Suspendu', 'ended': 'Clos', 'rejected': 'Refusé'};
const validationKinds = {'partnership': 'Partenariat', 'report': 'Rapport', 'event': 'Événement', 'department_request': 'Demande de département', 'other': 'Autre demande'};
const _validationStatuses = {'pending': 'En attente', 'approved': 'Accordée', 'rejected': 'Refusée', 'cancelled': 'Retirée'};
const _projectStatuses = {'submitted': 'En attente', 'approved': 'Validé', 'rejected': 'Refusé'};

Widget _note(String t, {double? width, double? height, VoidCallback? retry}) => Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(t, textAlign: TextAlign.center, style: _st(13, c: _grey).copyWith(height: 1.5)),
        if (retry != null) TextButton(style: TextButton.styleFrom(minimumSize: const Size(48, 48)), onPressed: retry, child: Text('Réessayer', style: _st(13, w: FontWeight.w700, c: _accent))),
      ]),
    );

Widget _card(Widget child, {EdgeInsets padding = const EdgeInsets.all(14), VoidCallback? onTap, String? label}) {
  final box = Container(
    padding: padding,
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _lineColor)),
    child: child,
  );
  if (onTap == null) return box;
  return Semantics(button: true, label: label, child: InkWell(borderRadius: BorderRadius.circular(18), onTap: onTap, child: box));
}

Widget _kpi(String label, String value, double w, {String? hint, VoidCallback? onTap}) => SizedBox(
      width: w,
      child: _card(
        onTap: onTap,
        label: '$label : $value',
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(20, w: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: _st(11.5, c: _grey)),
          if (hint != null && hint.isNotEmpty) ...[const SizedBox(height: 4), Text(hint, maxLines: 2, overflow: TextOverflow.ellipsis, style: _st(10.5, c: _accent, w: FontWeight.w600))],
        ]),
      ),
    );

Widget _chip(String label, bool selected, VoidCallback onTap) => Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: selected ? _ink : Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: selected ? _ink : const Color(0xFFE6E1EE))),
            child: Text(label, style: _st(12.5, w: FontWeight.w700, c: selected ? Colors.white : _ink)),
          ),
        ),
      ),
    );

Widget _pill(String t, {Color bg = const Color(0xFFEEE9FF), Color fg = _accent}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)),
      child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(11, w: FontWeight.w700, c: fg)),
    );

Widget _action(String label, VoidCallback onTap, {bool dark = true, IconData? icon}) => Semantics(
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: dark ? _ink : Colors.white, borderRadius: BorderRadius.circular(24), border: dark ? null : Border.all(color: const Color(0xFFE6E1EE))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(icon, size: 18, color: dark ? Colors.white : _ink), const SizedBox(width: 6)],
              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(13, w: FontWeight.w700, c: dark ? Colors.white : _ink))),
            ]),
          ),
        ),
      ),
    );

/// Lecture serveur avec états explicites : hors connexion, non connecté, chargement, accès refusé, erreur (avec « Réessayer »).
class DirLoader extends ConsumerStatefulWidget {
  const DirLoader({super.key, required this.fn, this.args = const {}, required this.builder, this.width, this.height});
  final String fn;
  final Map<String, dynamic> args;
  final Widget Function(BuildContext context, Object? data, Future<void> Function() reload) builder;
  final double? width, height;

  @override
  ConsumerState<DirLoader> createState() => _DirLoaderState();
}

class _DirLoaderState extends ConsumerState<DirLoader> {
  Object? _data;
  String? _error;
  bool _loading = true;
  String _sig = '';

  String _signature() => '${widget.fn}|${jsonEncode(widget.args)}';

  @override
  void initState() {
    super.initState();
    _sig = _signature();
    _load();
  }

  @override
  void didUpdateWidget(DirLoader old) {
    super.didUpdateWidget(old);
    final s = _signature();
    if (s != _sig) {
      _sig = s;
      _load();
    }
  }

  Future<void> _load() async {
    if (!Backend.ready) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted) setState(() => _loading = true);
    final r = await directionRpc(widget.fn, widget.args);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = r.error;
      _data = r.data;
    });
  }

  @override
  Widget build(BuildContext context) {
    final signedOut = ref.watch(authProvider.select((a) => a.current == null));
    final w = widget.width, h = widget.height;
    if (!Backend.ready) return _note('Aucun serveur connecté : aucune donnée à afficher.', width: w, height: h);
    if (signedOut) return _note('Connectez-vous avec un compte de la direction pour voir ces données.', width: w, height: h);
    if (_loading && _data == null) return _note('Chargement…', width: w, height: h);
    if (_error != null) {
      final denied = RegExp('Réservé|non autorisée|permission', caseSensitive: false).hasMatch(_error!);
      return _note(denied ? 'Accès réservé à la direction de l’établissement.' : 'Les données ne peuvent pas être chargées pour le moment.', width: w, height: h, retry: denied ? null : _load);
    }
    final body = widget.builder(context, _data, _load);
    return w == null ? body : SizedBox(width: w, height: h, child: body);
  }
}

Future<String?> _askNote(BuildContext context, String title, {required bool required, String? intro, String confirm = 'Confirmer'}) {
  final c = TextEditingController();
  return gDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final tooShort = required && c.text.trim().length < 5;
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(title, style: _st(16, w: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (intro != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(intro, style: _st(12.5, c: _grey))),
              TextField(controller: c, maxLines: 3, maxLength: 500, onChanged: (_) => set(() {}), decoration: InputDecoration(labelText: required ? 'Motif (obligatoire)' : 'Commentaire (facultatif)', border: const OutlineInputBorder())),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            FilledButton(onPressed: tooShort ? null : () => Navigator.pop(ctx, c.text.trim()), child: Text(confirm)),
          ],
        );
      },
    ),
  );
}

Future<bool> _call(BuildContext context, String fn, Map<String, dynamic> args, String ok) async {
  final r = await directionRpc(fn, args);
  if (!context.mounted) return false;
  if (r.error != null) {
    await gAlert(context, 'Action refusée', r.error!);
    return false;
  }
  gToast(context, ok);
  return true;
}

// ------------------------------------------------------------------ tableau de bord institutionnel (117)

class DirectionDashboardPanel extends StatelessWidget {
  const DirectionDashboardPanel({super.key, this.width = 960, this.height = 640});
  final double width, height;

  @override
  Widget build(BuildContext context) => DirLoader(
        fn: 'direction_dashboard',
        width: width,
        height: height,
        builder: (context, data, reload) {
          final d = _map(data);
          final cols = width >= 900 ? 4 : (width >= 600 ? 3 : 2);
          final w = (width - (cols - 1) * 12) / cols;
          final months = _list(d['months']);
          String trend(String a, String b) {
            final diff = _n(d[a]) - _n(d[b]);
            return diff == 0 ? 'stable sur 30 jours' : '${diff > 0 ? '+' : ''}$diff sur 30 jours';
          }

          void go(String path) => GoRouter.of(context).push(path);
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(padding: EdgeInsets.zero, children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                _action('Partenariats', () => go('/direction/partenariats'), dark: false, icon: Icons.handshake_outlined),
                _action('Validations', () => go('/direction/validations'), dark: false, icon: Icons.verified_outlined),
                _action('Actualiser', reload, dark: false, icon: Icons.refresh),
              ]),
              const SizedBox(height: 14),
              Wrap(spacing: 12, runSpacing: 12, children: [
                _kpi('Étudiants vérifiés', '${_n(d['students_verified'])}', w, hint: '${_n(d['students'])} inscrits · ${trend('students_new_30d', 'students_new_prev_30d')}'),
                _kpi('Départements', '${_n(d['departments'])}', w, hint: '${_n(d['dept_heads'])} responsable${_n(d['dept_heads']) > 1 ? 's' : ''}', onTap: () => GoRouter.of(context).push('/s/119')),
                _kpi('Projets validés', '${_n(d['projects'])}', w, hint: '${_n(d['projects_pending'])} en attente · ${trend('projects_30d', 'projects_prev_30d')}'),
                _kpi('Innovations validées', '${_n(d['innovations'])}', w),
                _kpi('Productions en cours', '${_n(d['productions_active'])}', w, hint: '${_n(d['productions_done'])} terminée${_n(d['productions_done']) > 1 ? 's' : ''} · ${_n(d['mentors'])} encadreur${_n(d['mentors']) > 1 ? 's' : ''}'),
                _kpi('Événements à venir', '${_n(d['events_upcoming'])}', w, hint: '${_n(d['events_30d'])} tenus sur 30 jours'),
                _kpi('Offres publiées', '${_n(d['opportunities'])}', w, hint: '${_n(d['applications_30d'])} candidature${_n(d['applications_30d']) > 1 ? 's' : ''} sur 30 jours'),
                _kpi('Partenariats actifs', '${_n(d['partnerships_active'])}', w, hint: '${_n(d['partnerships_proposed'])} à valider', onTap: () => go('/direction/partenariats')),
                _kpi('Validations en attente', '${_n(d['validations_pending'])}', w, hint: 'Ouvrir la file', onTap: () => go('/direction/validations')),
                _kpi('Partenariats des départements', '${_n(d['dept_partnerships_active'])}', w, hint: 'actifs, suivis par les départements'),
                _kpi('Commandes payées', '${_n(d['orders_paid'])}', w, hint: '${_n(d['listings_approved'])} annonces publiées'),
                _kpi('Montant encaissé', fcfa(_n(d['paid_revenue'])), w, hint: 'consolidé, hors détail des paiements'),
              ]),
              const SizedBox(height: 20),
              Text('Évolution sur six mois', style: _st(15, w: FontWeight.w700)),
              const SizedBox(height: 8),
              if (months.isEmpty)
                Text('Aucune donnée mensuelle pour le moment.', style: _st(12.5, c: _grey))
              else
                _card(
                  Column(children: [
                    Row(children: [
                      Expanded(flex: 2, child: Text('Mois', style: _st(11, w: FontWeight.w700, c: _grey))),
                      Expanded(child: Text('Projets', textAlign: TextAlign.right, style: _st(11, w: FontWeight.w700, c: _grey))),
                      Expanded(child: Text('Commandes', textAlign: TextAlign.right, style: _st(11, w: FontWeight.w700, c: _grey))),
                      Expanded(child: Text('Étudiants', textAlign: TextAlign.right, style: _st(11, w: FontWeight.w700, c: _grey))),
                    ]),
                    const Divider(height: 14),
                    for (final m in months)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(children: [
                          Expanded(flex: 2, child: Text(_s(m['month']), style: _st(12.5, w: FontWeight.w600))),
                          Expanded(child: Text('${_n(m['projects'])}', textAlign: TextAlign.right, style: _st(12.5))),
                          Expanded(child: Text('${_n(m['orders_paid'])}', textAlign: TextAlign.right, style: _st(12.5))),
                          Expanded(child: Text('${_n(m['students_new'])}', textAlign: TextAlign.right, style: _st(12.5))),
                        ]),
                      ),
                  ]),
                ),
              const SizedBox(height: 12),
              Text('Les chiffres sont consolidés : aucun détail de paiement ni donnée personnelle n’est affiché.', style: _st(11.5, c: _grey)),
            ]),
          );
        },
      );
}

// ------------------------------------------------------------------ départements (119)

class DirectionDepartmentsPanel extends StatelessWidget {
  const DirectionDepartmentsPanel({super.key, this.width = 940, this.height = 520});
  final double width, height;

  @override
  Widget build(BuildContext context) => DirLoader(
        fn: 'direction_departments',
        width: width,
        height: height,
        builder: (context, data, reload) {
          final rows = _list(data);
          if (rows.isEmpty) return _note('Aucun département enregistré pour le moment.', width: width, height: height);
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final r = rows[i];
                final head = _s(r['head']);
                return _card(
                  onTap: () => showDepartmentDetail(context, _s(r['id'])),
                  label: 'Ouvrir la fiche du département ${r['name']}',
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(_s(r['name']), maxLines: 2, overflow: TextOverflow.ellipsis, style: _st(14.5, w: FontWeight.w700))),
                      const SizedBox(width: 8),
                      _pill(r['status'] == 'verified' ? 'Vérifié' : 'À valider'),
                    ]),
                    const SizedBox(height: 2),
                    Text(head.isEmpty ? 'Aucun responsable rattaché' : 'Responsable : $head', style: _st(11.5, c: _grey)),
                    const SizedBox(height: 10),
                    Wrap(spacing: 14, runSpacing: 6, children: [
                      _stat('Étudiants', '${_n(r['students_verified'])}/${_n(r['students'])}'),
                      _stat('Projets', '${_n(r['projects'])}'),
                      _stat('Innovations', '${_n(r['innovations'])}'),
                      _stat('En attente', '${_n(r['projects_pending'])}'),
                      _stat('Annonces', '${_n(r['listings'])}'),
                      _stat('Ventes', fcfa(_n(r['sales']))),
                      _stat('Partenariats', '${_n(r['partnerships'])}+${_n(r['dept_partnerships'])}'),
                    ]),
                  ]),
                );
              },
            ),
          );
        },
      );
}

Widget _stat(String l, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(v, style: _st(13.5, w: FontWeight.w800)),
      Text(l, style: _st(10.5, c: _grey)),
    ]);

Future<void> showDepartmentDetail(BuildContext context, String id) => gDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        content: SizedBox(
          width: 360,
          height: 420,
          child: DirLoader(
            fn: 'direction_department_detail',
            args: {'p_id': id},
            builder: (c, data, reload) {
              final d = _map(data);
              final heads = [for (final h in (d['heads'] as List? ?? const [])) '$h'];
              final projects = _list(d['recent_projects']);
              final partners = _list(d['partnerships']);
              return ListView(padding: EdgeInsets.zero, children: [
                Text(_s(d['name']), style: _st(17, w: FontWeight.w800)),
                Text(_s(d['institution']), style: _st(12, c: _grey)),
                const SizedBox(height: 10),
                Text(heads.isEmpty ? 'Aucun responsable rattaché.' : 'Responsable${heads.length > 1 ? 's' : ''} : ${heads.join(', ')}', style: _st(12.5)),
                const SizedBox(height: 6),
                Text('${_n(d['students_verified'])} étudiant${_n(d['students_verified']) > 1 ? 's' : ''} vérifié${_n(d['students_verified']) > 1 ? 's' : ''} sur ${_n(d['students'])}', style: _st(12.5, w: FontWeight.w600)),
                const SizedBox(height: 14),
                Text('Projets et innovations récents', style: _st(13.5, w: FontWeight.w700)),
                const SizedBox(height: 6),
                if (projects.isEmpty) Text('Aucun projet déposé.', style: _st(12, c: _grey)),
                for (final p in projects)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_s(p['title']), style: _st(12.5, w: FontWeight.w600)),
                      Text('${p['kind'] == 'innovation' ? 'Innovation' : 'Projet'} · ${_s(p['owner'])} · ${_projectStatuses[p['status']] ?? _s(p['status'])}', style: _st(11, c: _grey)),
                    ]),
                  ),
                const SizedBox(height: 10),
                Text('Partenariats institutionnels', style: _st(13.5, w: FontWeight.w700)),
                const SizedBox(height: 6),
                if (partners.isEmpty) Text('Aucun partenariat rattaché.', style: _st(12, c: _grey)),
                for (final p in partners) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('${_s(p['name'])} · ${partnerStatuses[p['status']] ?? _s(p['status'])}', style: _st(12))),
              ]);
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer'))],
      ),
    );

// ------------------------------------------------------------------ personnes (120, 121)

/// Personnes de l'établissement en lecture seule : étudiants avec leur département, responsables de département, encadreurs.
/// Aucune modification de compte, de rôle ou d'affectation : c'est le rôle de l'administrateur global.
class DirectionPeoplePanel extends StatefulWidget {
  const DirectionPeoplePanel({super.key, this.kinds = const ['students'], this.width = 940, this.height = 520});
  final List<String> kinds;
  final double width, height;

  @override
  State<DirectionPeoplePanel> createState() => _DirectionPeoplePanelState();
}

class _DirectionPeoplePanelState extends State<DirectionPeoplePanel> {
  late String _kind = widget.kinds.first;
  String _q = '';
  static const _labels = {'students': 'Étudiants', 'responsables': 'Responsables', 'mentors': 'Encadreurs'};

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (widget.kinds.length > 1)
            for (final k in widget.kinds) _chip(_labels[k] ?? k, _kind == k, () => setState(() => _kind = k)),
          SizedBox(
            width: widget.width < 420 ? widget.width : 280,
            child: TextField(
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search, size: 20), hintText: 'Rechercher un nom ou un département', isDense: true, border: OutlineInputBorder()),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: DirLoader(
            fn: 'direction_people',
            args: {'p_kind': _kind, 'p_limit': 200},
            builder: (context, data, reload) {
              final rows = [for (final r in _list(data)) if (_q.isEmpty || '${r['name']} ${r['department'] ?? ''} ${r['specialty'] ?? ''}'.toLowerCase().contains(_q)) r];
              if (rows.isEmpty) return _note(_q.isEmpty ? 'Aucune personne à afficher pour le moment.' : 'Aucun résultat pour cette recherche.');
              return RefreshIndicator(
                onRefresh: reload,
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const Divider(height: 4, color: Color(0xFFF2EFF6)),
                  itemBuilder: (_, i) {
                    final r = rows[i];
                    final sub = switch (_kind) {
                      'students' => [if (_s(r['department']).isNotEmpty) _s(r['department']) else 'Département non renseigné', if (_s(r['level']).isNotEmpty) _s(r['level']), '${_n(r['projects'])} projet${_n(r['projects']) > 1 ? 's' : ''} validé${_n(r['projects']) > 1 ? 's' : ''}'].join(' · '),
                      'responsables' => _s(r['department']).isEmpty ? 'Aucun département rattaché' : _s(r['department']),
                      _ => [_s(r['role']), if (_s(r['specialty']).isNotEmpty) _s(r['specialty']), '${_n(r['productions'])} production${_n(r['productions']) > 1 ? 's' : ''}'].join(' · '),
                    };
                    final badge = _kind == 'students' ? (r['verified'] == true ? 'Vérifié' : 'Non vérifié') : (_kind == 'mentors' ? (r['active'] == true ? 'Actif' : 'Inactif') : '');
                    return ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 56),
                      child: Row(children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(_s(r['name']), maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(13.5, w: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: _st(11.5, c: _grey)),
                            ]),
                          ),
                        ),
                        if (badge.isNotEmpty) ...[const SizedBox(width: 8), _pill(badge, bg: badge.startsWith('Non') ? const Color(0xFFF2EFF6) : const Color(0xFFDDF5EC), fg: badge.startsWith('Non') ? _grey : const Color(0xFF0F7A52))],
                      ]),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ activités et ventes (123)

class DirectionActivityPanel extends StatefulWidget {
  const DirectionActivityPanel({super.key, this.width = 940, this.height = 560});
  final double width, height;

  @override
  State<DirectionActivityPanel> createState() => _DirectionActivityPanelState();
}

class _DirectionActivityPanelState extends State<DirectionActivityPanel> {
  String _view = 'projects';
  static const _views = {'projects': 'Projets', 'innovations': 'Innovations', 'productions': 'Productions', 'events': 'Événements', 'opportunities': 'Offres', 'sales': 'Ventes'};

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [for (final e in _views.entries) _chip(e.value, _view == e.key, () => setState(() => _view = e.key))]),
        const SizedBox(height: 12),
        Expanded(child: _view == 'sales' ? _sales() : _activity()),
      ]),
    );
  }

  Widget _sales() => DirLoader(
        fn: 'direction_finance_summary',
        args: const {'p_months': 12},
        builder: (context, data, reload) {
          final d = _map(data);
          final months = _list(d['months']);
          final t = _map(d['totals']);
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(padding: EdgeInsets.zero, children: [
              Wrap(spacing: 12, runSpacing: 12, children: [
                _kpi('Commandes payées', '${_n(t['orders_paid'])}', (widget.width - 12) / 2),
                _kpi('Montant encaissé', fcfa(_n(t['collected'])), (widget.width - 12) / 2),
              ]),
              const SizedBox(height: 14),
              _card(Column(children: [
                for (final m in months)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Expanded(flex: 2, child: Text(_s(m['month']), style: _st(12.5, w: FontWeight.w600))),
                      Expanded(flex: 2, child: Text('${_n(m['orders_paid'])} commande${_n(m['orders_paid']) > 1 ? 's' : ''}', style: _st(12))),
                      Expanded(flex: 3, child: Text(fcfa(_n(m['collected'])), textAlign: TextAlign.right, style: _st(12.5, w: FontWeight.w700))),
                    ]),
                  ),
              ])),
            ]),
          );
        },
      );

  Widget _activity() => DirLoader(
        fn: 'direction_activity',
        args: {'p_kind': _view, 'p_limit': 100},
        builder: (context, data, reload) {
          final rows = _list(data);
          if (rows.isEmpty) return _note('Aucune activité à afficher pour le moment.');
          String sub(Map<String, dynamic> r) => switch (_view) {
                'projects' || 'innovations' => '${_s(r['owner'])} · ${_s(r['department']).isEmpty ? 'sans département' : _s(r['department'])} · ${dateCourte(r['created_at'])}',
                'productions' => '${_s(r['team']).isEmpty ? 'Équipe non renseignée' : _s(r['team'])}${_s(r['mentor']).isEmpty ? '' : ' · encadreur ${_s(r['mentor'])}'} · ${_n(r['progress'])} %',
                'events' => '${dateCourte(r['starts_at'])}${_s(r['place']).isEmpty ? '' : ' · ${_s(r['place'])}'} · ${_n(r['registrations'])} inscrit${_n(r['registrations']) > 1 ? 's' : ''}',
                _ => '${_s(r['org'])} · ${_n(r['applications'])} candidature${_n(r['applications']) > 1 ? 's' : ''}${r['deadline'] == null ? '' : ' · avant le ${dateCourte(r['deadline'])}'}',
              };
          String badge(Map<String, dynamic> r) => switch (_view) {
                'projects' || 'innovations' => _projectStatuses[r['status']] ?? _s(r['status']),
                'productions' => const {'en_cours': 'En cours', 'terminee': 'Terminée', 'annulee': 'Annulée'}[r['status']] ?? _s(r['status']),
                'events' => const {'published': 'Publié', 'cancelled': 'Annulé'}[r['status']] ?? _s(r['status']),
                _ => const {'pending': 'À valider', 'published': 'Publiée', 'rejected': 'Refusée', 'closed': 'Clôturée'}[r['status']] ?? _s(r['status']),
              };
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: rows.length,
              separatorBuilder: (_, _) => const Divider(height: 4, color: Color(0xFFF2EFF6)),
              itemBuilder: (_, i) => ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Row(children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_s(rows[i]['title']), maxLines: 2, overflow: TextOverflow.ellipsis, style: _st(13.5, w: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(sub(rows[i]), maxLines: 3, overflow: TextOverflow.ellipsis, style: _st(11.5, c: _grey)),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(constraints: const BoxConstraints(maxWidth: 110), child: _pill(badge(rows[i]))),
                ]),
              ),
            ),
          );
        },
      );
}

// ------------------------------------------------------------------ rapports consolidés et performances (125)

class DirectionReportPanel extends StatefulWidget {
  const DirectionReportPanel({super.key, this.width = 940, this.height = 640});
  final double width, height;

  @override
  State<DirectionReportPanel> createState() => _DirectionReportPanelState();
}

class _DirectionReportPanelState extends State<DirectionReportPanel> {
  int _period = 0;
  static const _periods = ['Année en cours', '12 derniers mois', '30 derniers jours'];
  List<Map<String, dynamic>> _lines = const [];
  String _from = '', _to = '';

  Map<String, dynamic> get _args {
    final now = DateTime.now();
    final from = switch (_period) { 0 => DateTime(now.year, 1, 1), 1 => DateTime(now.year - 1, now.month, now.day), _ => now.subtract(const Duration(days: 30)) };
    return {'p_from': _day(from), 'p_to': _day(now)};
  }

  Future<void> _export() async {
    if (_lines.isEmpty) {
      await gAlert(context, 'Rien à exporter', 'Le rapport n’est pas encore chargé ou ne contient aucune ligne.');
      return;
    }
    final rows = [for (final l in _lines) {'Période': '$_from au $_to', 'Rubrique': l['section'], 'Indicateur': l['indicator'], 'Département': l['department'], 'Valeur': l['value']}];
    final file = 'rapport-consolide-$_from-$_to.csv';
    final saved = await saveTextFile(file, toCsv(const ['Période', 'Rubrique', 'Indicateur', 'Département', 'Valeur'], rows), 'text/csv');
    if (mounted) gToast(context, saved ? '${rows.length} lignes exportées ($file).' : '${rows.length} lignes copiées dans le presse-papiers.');
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          for (var i = 0; i < _periods.length; i++) _chip(_periods[i], _period == i, () => setState(() => _period = i)),
          _action('Exporter (CSV)', _export, icon: Icons.download),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: DirLoader(
            fn: 'direction_consolidated_report',
            args: _args,
            builder: (context, data, reload) {
              final d = _map(data);
              _lines = _list(d['lines']);
              _from = _s(d['from']);
              _to = _s(d['to']);
              final sections = <String, List<Map<String, dynamic>>>{};
              for (final l in _lines) {
                if (_s(l['department']).isEmpty) sections.putIfAbsent(_s(l['section']), () => []).add(l);
              }
              final byDept = <String, List<Map<String, dynamic>>>{};
              for (final l in _lines) {
                if (_s(l['department']).isNotEmpty) byDept.putIfAbsent(_s(l['department']), () => []).add(l);
              }
              Widget value(Map<String, dynamic> l) {
                final money = _s(l['indicator']).contains('FCFA');
                return Text(money ? fcfa(_n(l['value'])) : '${_n(l['value'])}', style: _st(12.5, w: FontWeight.w800));
              }

              return RefreshIndicator(
                onRefresh: reload,
                child: ListView(padding: EdgeInsets.zero, children: [
                  Text('Période du ${dateCourte(_from)} au ${dateCourte(_to)} · généré par ${_s(d['generated_by']).isEmpty ? 'la direction' : _s(d['generated_by'])}', style: _st(11.5, c: _grey)),
                  const SizedBox(height: 10),
                  for (final e in sections.entries) ...[
                    Text(e.key, style: _st(14, w: FontWeight.w700)),
                    const SizedBox(height: 6),
                    _card(Column(children: [
                      for (final l in e.value)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(children: [Expanded(child: Text(_s(l['indicator']), style: _st(12.5))), const SizedBox(width: 10), value(l)]),
                        ),
                    ])),
                    const SizedBox(height: 14),
                  ],
                  if (byDept.isNotEmpty) ...[
                    Text('Par département', style: _st(14, w: FontWeight.w700)),
                    const SizedBox(height: 6),
                    for (final e in byDept.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(e.key, style: _st(13.5, w: FontWeight.w700)),
                          const SizedBox(height: 6),
                          for (final l in e.value) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [Expanded(child: Text(_s(l['indicator']), style: _st(12, c: _grey))), const SizedBox(width: 10), value(l)])),
                        ])),
                      ),
                  ],
                  const SizedBox(height: 6),
                  Text('Performances par département', style: _st(14, w: FontWeight.w700)),
                  const SizedBox(height: 6),
                  SizedBox(height: 360, child: DirectionPerformanceList(width: widget.width)),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }
}

/// Indicateurs de performance par département (taux de validation, projets pour 100 étudiants, ventes, partenariats) et comparaison de périodes.
class DirectionPerformanceList extends StatelessWidget {
  const DirectionPerformanceList({super.key, required this.width});
  final double width;

  @override
  Widget build(BuildContext context) => DirLoader(
        fn: 'direction_performance',
        builder: (context, data, reload) {
          final d = _map(data);
          final deps = _list(d['departments']);
          final p = _map(d['periods']);
          String cmp(String k, String label) {
            final x = _map(p[k]);
            final cur = _n(x['current']), prev = _n(x['previous']);
            return '$label : $cur (${cur - prev >= 0 ? '+' : ''}${cur - prev} sur 90 j)';
          }

          String pct(Object? v) => v == null ? '—' : '$v %';
          return ListView(physics: const ClampingScrollPhysics(), padding: EdgeInsets.zero, children: [
            _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cmp('projects', 'Projets déposés'), style: _st(12)),
              Text(cmp('orders', 'Commandes payées'), style: _st(12)),
              Text(cmp('students', 'Nouveaux étudiants'), style: _st(12)),
              Text(cmp('applications', 'Candidatures'), style: _st(12)),
              Text('Taux de validation des projets : ${pct(d['validation_rate'])}', style: _st(12, w: FontWeight.w700)),
            ])),
            const SizedBox(height: 10),
            if (deps.isEmpty) Text('Aucun département vérifié pour le moment.', style: _st(12.5, c: _grey)),
            for (final x in deps)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_s(x['name']), style: _st(13.5, w: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 14, runSpacing: 6, children: [
                    _stat('Validation', pct(x['approval_rate'])),
                    _stat('Réalisations / 100 étudiants', x['projects_per_100_students'] == null ? '—' : '${x['projects_per_100_students']}'),
                    _stat('Vendeurs actifs', '${_n(x['active_sellers'])}'),
                    _stat('Ventes', fcfa(_n(x['sales']))),
                    _stat('Partenariats', '${_n(x['partnerships'])}'),
                  ]),
                ])),
              ),
          ]);
        },
      );
}

// ------------------------------------------------------------------ journal des décisions (126)

class DirectionDecisionsPanel extends StatelessWidget {
  const DirectionDecisionsPanel({super.key, this.width = 940, this.height = 560});
  final double width, height;

  @override
  Widget build(BuildContext context) => DirLoader(
        fn: 'direction_decisions_journal',
        args: const {'p_limit': 200},
        width: width,
        height: height,
        builder: (context, data, reload) {
          final rows = _list(data);
          if (rows.isEmpty) return _note('Aucune décision institutionnelle enregistrée pour le moment.\nLes validations et les décisions sur les partenariats apparaissent ici.', width: width, height: height);
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: rows.length,
              separatorBuilder: (_, _) => const Divider(height: 4, color: Color(0xFFF2EFF6)),
              itemBuilder: (_, i) {
                final r = rows[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${_s(r['action'])} · ${_s(r['title'])}', maxLines: 2, overflow: TextOverflow.ellipsis, style: _st(13.5, w: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('${_s(r['actor'])} · ${dateCourte(r['created_at'])}${_s(r['department']).isEmpty ? '' : ' · ${_s(r['department'])}'}', style: _st(11.5, c: _grey)),
                    if (_s(r['note']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text('Motif : ${_s(r['note'])}', style: _st(11.5, c: _grey))),
                  ]),
                );
              },
            ),
          );
        },
      );
}

// ------------------------------------------------------------------ validations institutionnelles (122 et écran dédié)

class InstitutionalValidationsPanel extends ConsumerStatefulWidget {
  const InstitutionalValidationsPanel({super.key, this.width = 940, this.height = 560});
  final double width, height;

  @override
  ConsumerState<InstitutionalValidationsPanel> createState() => _ValidationsState();
}

class _ValidationsState extends ConsumerState<InstitutionalValidationsPanel> {
  String _status = 'pending';
  int _tick = 0;
  static const _filters = {'pending': 'À traiter', 'approved': 'Accordées', 'rejected': 'Refusées', 'all': 'Toutes'};

  Future<void> _decide(String id, bool approve) async {
    final note = await _askNote(context, approve ? 'Accorder la validation' : 'Refuser la validation', required: !approve, confirm: approve ? 'Accorder' : 'Refuser', intro: approve ? 'Un commentaire est facultatif.' : 'Le demandeur recevra ce motif.');
    if (note == null || !mounted) return;
    if (await _call(context, 'institutional_validation_decide', {'p_id': id, 'p_approve': approve, 'p_note': note.isEmpty ? null : note}, approve ? 'Validation accordée : le demandeur est prévenu.' : 'Validation refusée : le demandeur est prévenu.')) {
      setState(() => _tick++);
    }
  }

  Future<void> _cancel(String id) async {
    if (!await gConfirm(context, 'Retirer la demande', 'Voulez-vous retirer cette demande de validation ?', yes: 'Retirer') || !mounted) return;
    if (await _call(context, 'institutional_validation_cancel', {'p_id': id}, 'Demande retirée.')) setState(() => _tick++);
  }

  Future<void> _request() async {
    var kind = 'report';
    final title = TextEditingController(), details = TextEditingController();
    final ok = await gDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Nouvelle demande de validation', style: _st(16, w: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue: kind,
                decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                items: [for (final e in validationKinds.entries) if (e.key != 'partnership') DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (v) => set(() => kind = v ?? kind),
              ),
              const SizedBox(height: 10),
              TextField(controller: title, maxLength: 160, decoration: const InputDecoration(labelText: 'Objet', border: OutlineInputBorder())),
              const SizedBox(height: 6),
              TextField(controller: details, maxLines: 4, maxLength: 2000, decoration: const InputDecoration(labelText: 'Détails', border: OutlineInputBorder())),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Envoyer'))],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    if (await _call(context, 'institutional_validation_request', {'p_kind': kind, 'p_title': title.text.trim(), 'p_details': details.text.trim()}, 'Demande envoyée à la direction.')) setState(() => _tick++);
  }

  @override
  Widget build(BuildContext context) {
    final role = roleKey(ref.watch(authProvider).current);
    final decider = role == 'direction' || role == 'admin';
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          for (final e in _filters.entries) _chip(e.value, _status == e.key, () => setState(() => _status = e.key)),
          _action('Nouvelle demande', _request, dark: false, icon: Icons.add),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: DirLoader(
            key: ValueKey('v$_tick$_status'),
            fn: 'institutional_validations_list',
            args: {'p_status': _status, 'p_limit': 200},
            builder: (context, data, reload) {
              final rows = _list(data);
              if (rows.isEmpty) return _note(_status == 'pending' ? 'Aucune validation en attente.' : 'Aucune validation dans cette catégorie.');
              return RefreshIndicator(
                onRefresh: reload,
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final r = rows[i];
                    final pending = r['status'] == 'pending';
                    final isPartnership = r['kind'] == 'partnership';
                    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(_s(r['title']), maxLines: 2, overflow: TextOverflow.ellipsis, style: _st(13.5, w: FontWeight.w700))),
                        const SizedBox(width: 8),
                        _pill(_validationStatuses[r['status']] ?? _s(r['status']), bg: pending ? const Color(0xFFFFF1D6) : const Color(0xFFF2EFF6), fg: pending ? const Color(0xFF8F5400) : _grey),
                      ]),
                      const SizedBox(height: 3),
                      Text('${validationKinds[r['kind']] ?? _s(r['kind'])}${_s(r['department']).isEmpty ? '' : ' · ${_s(r['department'])}'} · ${_s(r['requester']).isEmpty ? 'Demandeur inconnu' : _s(r['requester'])} · ${dateCourte(r['created_at'])}', style: _st(11.5, c: _grey)),
                      if (_s(r['details']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_s(r['details']), maxLines: 4, overflow: TextOverflow.ellipsis, style: _st(12))),
                      if (!pending && _s(r['decision_note']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Décision : ${_s(r['decision_note'])}${_s(r['decider']).isEmpty ? '' : ' (${_s(r['decider'])})'}', style: _st(11.5, c: _grey))),
                      if (pending) ...[
                        const SizedBox(height: 10),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          if (isPartnership) _action('Voir le partenariat', () => GoRouter.of(context).push('/direction/partenariats'), dark: false),
                          if (decider) _action('Accorder', () => _decide(_s(r['id']), true)),
                          if (decider) _action('Refuser', () => _decide(_s(r['id']), false), dark: false),
                          if (!decider && r['mine'] == true && !isPartnership) _action('Retirer ma demande', () => _cancel(_s(r['id'])), dark: false),
                        ]),
                      ],
                    ]));
                  },
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ partenariats institutionnels

class PartnershipsPanel extends ConsumerStatefulWidget {
  const PartnershipsPanel({super.key, this.width = 940, this.height = 560});
  final double width, height;

  @override
  ConsumerState<PartnershipsPanel> createState() => _PartnershipsState();
}

class _PartnershipsState extends ConsumerState<PartnershipsPanel> {
  String _status = 'all';
  bool _depts = false;
  int _tick = 0;

  bool get _decider {
    final r = roleKey(ref.read(authProvider).current);
    return r == 'direction' || r == 'admin';
  }

  Future<void> _decide(Map<String, dynamic> p, String action, String done) async {
    final needs = action == 'reject' || action == 'suspend' || action == 'end';
    final note = await _askNote(context, '${const {'approve': 'Valider', 'reject': 'Refuser', 'suspend': 'Suspendre', 'resume': 'Reprendre', 'end': 'Clore'}[action]} le partenariat', required: needs, confirm: 'Confirmer', intro: _s(p['name']));
    if (note == null || !mounted) return;
    if (await _call(context, 'partnership_decide', {'p_id': p['id'], 'p_action': action, 'p_note': note.isEmpty ? null : note}, done)) setState(() => _tick++);
  }

  Future<void> _edit([Map<String, dynamic>? p]) async {
    List<Map<String, dynamic>> deps = const [];
    if (_decider) {
      final r = await directionRpc('direction_departments', const {});
      deps = _list(r.data);
    }
    if (!mounted) return;
    final name = TextEditingController(text: _s(p?['name'])), cname = TextEditingController(text: _s(p?['contact_name']));
    final cmail = TextEditingController(text: _s(p?['contact_email'])), cphone = TextEditingController(text: _s(p?['contact_phone']));
    final obj = TextEditingController(text: _s(p?['objective'])), domains = TextEditingController(text: [for (final x in (p?['domains'] as List? ?? const [])) '$x'].join(', '));
    final starts = TextEditingController(text: _s(p?['starts_on'])), ends = TextEditingController(text: _s(p?['ends_on']));
    var kind = partnerKinds.containsKey(p?['kind']) ? _s(p?['kind']) : 'entreprise';
    String? dept = deps.any((d) => d['id'] == p?['department_id']) ? _s(p?['department_id']) : null;
    var registered = p == null ? true : (p['organization_registered'] == true || _s(p['organization_id']).isNotEmpty);
    OrgChoice? org = registered && p != null ? OrgChoice(id: _s(p['organization_id']), name: _s(p['organization_name']).isEmpty ? _s(p['name']) : _s(p['organization_name'])) : null;
    String? error;
    final ok = await gDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          bool badDate(String v) => v.trim().isNotEmpty && !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v.trim());
          return AlertDialog(
            backgroundColor: Colors.white,
            title: Text(p == null ? (_decider ? 'Nouveau partenariat' : 'Proposer un partenariat') : 'Modifier le partenariat', style: _st(16, w: FontWeight.w700)),
            content: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  PartnershipOrgPicker(
                    registered: registered,
                    selected: org,
                    search: (q) => directionRpc('partnership_org_search', {'p_q': q, 'p_limit': 20}),
                    onMode: (v) => set(() {
                      registered = v;
                      error = null;
                    }),
                    onSelect: (c) => set(() {
                      org = c;
                      error = null;
                    }),
                  ),
                  const SizedBox(height: 10),
                  if (!registered) ...[
                    TextField(controller: name, maxLength: 160, decoration: const InputDecoration(labelText: 'Nom du partenaire', border: OutlineInputBorder())),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: kind,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                      items: [for (final e in partnerKinds.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                      onChanged: (v) => set(() => kind = v ?? kind),
                    ),
                  ] else
                    Text('Le nom et le type du partenaire sont repris de la fiche de l’organisation.', style: _st(11.5, c: _grey)),
                  if (_decider) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String?>(
                      initialValue: dept,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Département concerné', border: OutlineInputBorder()),
                      items: [const DropdownMenuItem<String?>(value: null, child: Text('Tout l’établissement')), for (final d in deps) DropdownMenuItem<String?>(value: _s(d['id']), child: Text(_s(d['name']), overflow: TextOverflow.ellipsis))],
                      onChanged: (v) => set(() => dept = v),
                    ),
                  ] else
                    Padding(padding: const EdgeInsets.only(top: 8), child: Text('La proposition est rattachée à votre département et soumise à la validation de la direction.', style: _st(11.5, c: _grey))),
                  const SizedBox(height: 10),
                  TextField(controller: cname, maxLength: 120, decoration: const InputDecoration(labelText: 'Personne à contacter', border: OutlineInputBorder())),
                  const SizedBox(height: 6),
                  TextField(controller: cmail, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail du contact', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: cphone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Téléphone du contact', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: obj, maxLines: 3, maxLength: 2000, decoration: const InputDecoration(labelText: 'Objectif du partenariat', border: OutlineInputBorder())),
                  const SizedBox(height: 6),
                  TextField(controller: domains, decoration: const InputDecoration(labelText: 'Domaines (séparés par des virgules, 8 au plus)', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: starts, decoration: const InputDecoration(labelText: 'Début (AAAA-MM-JJ)', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: ends, decoration: const InputDecoration(labelText: 'Fin (AAAA-MM-JJ)', border: OutlineInputBorder())),
                  if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: _st(12, c: const Color(0xFFB3261E)))),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
              FilledButton(
                onPressed: () {
                  if (registered && org == null) return set(() => error = 'Choisissez une organisation inscrite, ou passez à « Organisation non inscrite ».');
                  if (!registered && name.text.trim().length < 2) return set(() => error = 'Indiquez le nom du partenaire.');
                  if (badDate(starts.text) || badDate(ends.text)) return set(() => error = 'Les dates doivent être au format AAAA-MM-JJ.');
                  Navigator.pop(ctx, true);
                },
                child: Text(p == null ? 'Enregistrer' : 'Mettre à jour'),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true || !mounted) return;
    final done = await _call(
      context,
      'partnership_save',
      {
        'p_id': p?['id'],
        'p_name': registered ? org!.name : name.text.trim(),
        'p_kind': kind,
        'p_department': dept,
        'p_company_owner': registered ? org!.id : null,
        'p_contact_name': cname.text.trim(),
        'p_contact_email': cmail.text.trim(),
        'p_contact_phone': cphone.text.trim(),
        'p_objective': obj.text.trim(),
        'p_domains': [for (final x in domains.text.split(',')) if (x.trim().isNotEmpty) x.trim()],
        'p_starts': starts.text.trim().isEmpty ? null : starts.text.trim(),
        'p_ends': ends.text.trim().isEmpty ? null : ends.text.trim(),
      },
      p == null ? (_decider ? 'Partenariat enregistré : il est à valider dans la file.' : 'Proposition envoyée à la direction.') : 'Partenariat mis à jour.',
    );
    if (done) setState(() => _tick++);
  }

  void _detail(Map<String, dynamic> p) {
    final status = _s(p['status']);
    final mine = p['mine'] == true;
    final editable = _decider ? const {'proposed', 'active', 'suspended'}.contains(status) : (mine && status == 'proposed');
    gDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(_s(p['name']), style: _st(16, w: FontWeight.w800)),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Wrap(spacing: 8, runSpacing: 6, children: [_pill(partnerStatuses[status] ?? status), _pill(partnerKinds[p['kind']] ?? _s(p['kind']), bg: const Color(0xFFF2EFF6), fg: _grey)]),
              const SizedBox(height: 10),
              Text(_s(p['department']).isEmpty ? 'Tout l’établissement' : 'Département : ${_s(p['department'])}', style: _st(12.5)),
              if (_s(p['organization_registered']) == 'true' || p['organization_registered'] == true)
                Text('Organisation inscrite : ${_s(p['company']).isEmpty ? _s(p['organization_name']) : _s(p['company'])}', style: _st(12.5))
              else
                Text('Organisation non inscrite sur Boutik-École : ${_s(p['organization_name']).isEmpty ? _s(p['name']) : _s(p['organization_name'])}', style: _st(12.5)),
              if (orgResponseLabel(p['org_response']).isNotEmpty)
                Text('${orgResponseLabel(p['org_response'])}${_s(p['org_response_note']).isEmpty ? '' : ' : ${_s(p['org_response_note'])}'}', style: _st(12.5, w: FontWeight.w600, c: p['org_response'] == 'contested' ? const Color(0xFFB3261E) : _ink)),
              if (_s(p['proposer']).isNotEmpty) Text('Proposé par : ${_s(p['proposer'])}', style: _st(12.5)),
              if (p['starts_on'] != null || p['ends_on'] != null) Text('Période : ${p['starts_on'] == null ? '—' : dateCourte(p['starts_on'])} → ${p['ends_on'] == null ? '—' : dateCourte(p['ends_on'])}', style: _st(12.5)),
              if (_s(p['objective']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_s(p['objective']), style: _st(12.5))),
              if ((p['domains'] as List? ?? const []).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Domaines : ${(p['domains'] as List).join(', ')}', style: _st(12, c: _grey))),
              if (_s(p['contact_name']).isNotEmpty || _s(p['contact_email']).isNotEmpty || _s(p['contact_phone']).isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 8), child: Text('Contact : ${[for (final k in ['contact_name', 'contact_email', 'contact_phone']) if (_s(p[k]).isNotEmpty) _s(p[k])].join(' · ')}', style: _st(12, c: _grey))),
              if (_s(p['decision_note']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Décision : ${_s(p['decision_note'])}', style: _st(12, c: _grey))),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
          if (editable) TextButton(onPressed: () { Navigator.pop(ctx); _edit(p); }, child: const Text('Modifier')),
          if (_decider && status == 'proposed') ...[
            TextButton(onPressed: () { Navigator.pop(ctx); _decide(p, 'reject', 'Partenariat refusé : le proposant est prévenu.'); }, child: const Text('Refuser')),
            FilledButton(onPressed: () { Navigator.pop(ctx); _decide(p, 'approve', 'Partenariat validé : il est désormais actif.'); }, child: const Text('Valider')),
          ],
          if (_decider && status == 'active') ...[
            TextButton(onPressed: () { Navigator.pop(ctx); _decide(p, 'end', 'Partenariat clos.'); }, child: const Text('Clore')),
            FilledButton(onPressed: () { Navigator.pop(ctx); _decide(p, 'suspend', 'Partenariat suspendu.'); }, child: const Text('Suspendre')),
          ],
          if (_decider && status == 'suspended') ...[
            TextButton(onPressed: () { Navigator.pop(ctx); _decide(p, 'end', 'Partenariat clos.'); }, child: const Text('Clore')),
            FilledButton(onPressed: () { Navigator.pop(ctx); _decide(p, 'resume', 'Partenariat repris.'); }, child: const Text('Reprendre')),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = roleKey(ref.watch(authProvider).current);
    final canWrite = role == 'direction' || role == 'admin' || role == 'dept';
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          _chip('Établissement', !_depts, () => setState(() => _depts = false)),
          if (_decider) _chip('Suivi des départements', _depts, () => setState(() => _depts = true)),
          if (canWrite && !_depts) _action(_decider ? 'Nouveau partenariat' : 'Proposer un partenariat', _edit, icon: Icons.add),
        ]),
        if (!_depts) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final s in const ['all', 'proposed', 'active', 'suspended', 'ended', 'rejected']) _chip(s == 'all' ? 'Tous' : partnerStatuses[s]!, _status == s, () => setState(() => _status = s))]),
        ],
        const SizedBox(height: 12),
        Expanded(child: _depts ? _deptList() : _mainList()),
      ]),
    );
  }

  Widget _mainList() => DirLoader(
        key: ValueKey('p$_tick$_status'),
        fn: 'partnerships_list',
        args: {'p_status': _status == 'all' ? null : _status},
        builder: (context, data, reload) {
          final rows = _list(data);
          if (rows.isEmpty) return _note(_status == 'all' ? 'Aucun partenariat pour le moment.' : 'Aucun partenariat dans cette catégorie.');
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final p = rows[i];
                final status = _s(p['status']);
                return _card(
                  onTap: () => _detail(p),
                  label: 'Ouvrir le partenariat ${p['name']}',
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_s(p['name']), maxLines: 2, overflow: TextOverflow.ellipsis, style: _st(14, w: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text('${partnerKinds[p['kind']] ?? _s(p['kind'])} · ${_s(p['department']).isEmpty ? 'Tout l’établissement' : _s(p['department'])}${p['organization_registered'] == true ? ' · Organisation inscrite' : ''}${orgResponseLabel(p['org_response']).isEmpty ? '' : ' · ${orgResponseLabel(p['org_response'])}'}${p['ends_on'] == null ? '' : ' · jusqu’au ${dateCourte(p['ends_on'])}'}', maxLines: 3, overflow: TextOverflow.ellipsis, style: _st(11.5, c: _grey)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    _pill(partnerStatuses[status] ?? status, bg: status == 'active' ? const Color(0xFFDDF5EC) : (status == 'proposed' ? const Color(0xFFFFF1D6) : const Color(0xFFF2EFF6)), fg: status == 'active' ? const Color(0xFF0F7A52) : (status == 'proposed' ? const Color(0xFF8F5400) : _grey)),
                  ]),
                );
              },
            ),
          );
        },
      );

  Widget _deptList() => DirLoader(
        fn: 'direction_dept_partnerships',
        builder: (context, data, reload) {
          final rows = _list(data);
          if (rows.isEmpty) return _note('Aucun partenariat n’est suivi par les départements pour le moment.');
          const st = {'prospect': 'Prospect', 'negociation': 'Négociation', 'actif': 'Actif', 'termine': 'Terminé', 'abandonne': 'Abandonné'};
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: rows.length,
              separatorBuilder: (_, _) => const Divider(height: 4, color: Color(0xFFF2EFF6)),
              itemBuilder: (_, i) {
                final p = rows[i];
                return ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Row(children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_s(p['partner']), maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(13.5, w: FontWeight.w600)),
                          Text('${_s(p['department'])} · ${_n(p['students'])} étudiant${_n(p['students']) > 1 ? 's' : ''}${_n(p['amount']) > 0 ? ' · ${fcfa(_n(p['amount']))}' : ''}${p['organization_registered'] == true ? ' · Organisation inscrite' : ''}${orgResponseLabel(p['org_response']).isEmpty ? '' : ' · ${orgResponseLabel(p['org_response'])}'}', maxLines: 3, overflow: TextOverflow.ellipsis, style: _st(11.5, c: _grey)),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _pill(st[p['status']] ?? _s(p['status'])),
                  ]),
                );
              },
            ),
          );
        },
      );
}

// ------------------------------------------------------------------ écrans dédiés (routes /direction/…)

class _DirectionPage extends StatelessWidget {
  const _DirectionPage({required this.title, required this.subtitle, required this.builder});
  final String title, subtitle;
  final Widget Function(double width, double height) builder;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF7F6F4),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                IconButton(
                  tooltip: 'Retour',
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => GoRouter.of(context).canPop() ? GoRouter.of(context).pop() : GoRouter.of(context).go('/'),
                ),
                Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(18, w: FontWeight.w800))),
              ]),
              Padding(padding: const EdgeInsets.only(left: 12, bottom: 10), child: Text(subtitle, style: _st(12, c: _grey))),
              Expanded(child: LayoutBuilder(builder: (context, k) => builder(k.maxWidth, k.maxHeight))),
            ]),
          ),
        ),
      );
}

class DirectionPartnershipsScreen extends StatelessWidget {
  const DirectionPartnershipsScreen({super.key});

  @override
  Widget build(BuildContext context) => _DirectionPage(
        title: 'Partenariats institutionnels',
        subtitle: 'Conventions et partenaires de l’établissement : proposition, validation, suivi.',
        builder: (w, h) => PartnershipsPanel(width: w, height: h),
      );
}

class DirectionValidationsScreen extends StatelessWidget {
  const DirectionValidationsScreen({super.key});

  @override
  Widget build(BuildContext context) => _DirectionPage(
        title: 'Validations institutionnelles',
        subtitle: 'Demandes soumises à la direction : décision motivée, demandeur prévenu.',
        builder: (w, h) => InstitutionalValidationsPanel(width: w, height: h),
      );
}

// ------------------------------------------------------------------ finance consolidée (284) et sponsoring (239)

/// Registre consolidé (écran 284) : la direction lit des totaux mensuels, jamais les écritures ni les paiements individuels.
class DirectionRegisterPanel extends StatelessWidget {
  const DirectionRegisterPanel({super.key, this.width = 342, this.height = 620});
  final double width, height;

  @override
  Widget build(BuildContext context) => DirLoader(
        fn: 'direction_finance_summary',
        args: const {'p_months': 12},
        width: width,
        height: height,
        builder: (context, data, reload) {
          final d = _map(data);
          final months = _list(d['months']);
          final t = _map(d['totals']);
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(padding: EdgeInsets.zero, children: [
              _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Cumul', style: _st(12, c: _grey)),
                Text(fcfa(_n(t['collected'])), style: _st(22, w: FontWeight.w800)),
                Text('${_n(t['orders_paid'])} commande${_n(t['orders_paid']) > 1 ? 's' : ''} payée${_n(t['orders_paid']) > 1 ? 's' : ''} · frais ${fcfa(_n(t['fees']))} · versé sur 30 jours ${fcfa(_n(t['paid_out_30d']))}', style: _st(11.5, c: _grey)),
              ])),
              const SizedBox(height: 10),
              for (final m in months)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _card(Row(children: [
                    Expanded(child: Text(_s(m['month']), style: _st(13, w: FontWeight.w700))),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(fcfa(_n(m['collected'])), style: _st(13, w: FontWeight.w700)),
                      Text('${_n(m['orders_paid'])} commande${_n(m['orders_paid']) > 1 ? 's' : ''}', style: _st(11, c: _grey)),
                    ]),
                  ])),
                ),
              Text('Lecture seule : le détail des paiements et des versements est tenu par la finance.', style: _st(11, c: _grey)),
            ]),
          );
        },
      );
}

/// Contenu de l'écran 284 selon le rôle : registre détaillé pour la finance et l'administration, registre consolidé pour la direction.
Widget financialRegisterView(WidgetRef ref, {double width = 342, double height = 620}) =>
    roleKey(ref.watch(authProvider).current) == 'direction' ? DirectionRegisterPanel(width: width, height: height) : journalListing(width: width, height: height);

/// Export de l'écran 284 pour la direction : totaux mensuels consolidés (CSV).
Future<void> exportDirectionRegister(BuildContext context) async {
  final r = await directionRpc('direction_finance_summary', const {'p_months': 36});
  if (!context.mounted) return;
  if (r.error != null) return gAlert(context, 'Export impossible', r.error!);
  final rows = [for (final m in _list(_map(r.data)['months'])) {'Mois': m['month'], 'Commandes payées': m['orders_paid'], 'Montant encaissé': m['collected'], 'Frais': m['fees']}];
  if (rows.isEmpty) return gAlert(context, 'Rien à exporter', 'Aucune donnée consolidée à exporter.');
  final saved = await saveTextFile('registre-consolide.csv', toCsv(const ['Mois', 'Commandes payées', 'Montant encaissé', 'Frais'], rows), 'text/csv');
  if (context.mounted) gToast(context, saved ? '${rows.length} mois exportés (registre-consolide.csv).' : '${rows.length} mois copiés dans le presse-papiers.');
}

/// Rapport de sponsoring consolidé de la direction (écran 239) : tous les sponsors, leurs contributions et les étudiants soutenus.
class DirectionSponsorsPanel extends StatelessWidget {
  const DirectionSponsorsPanel({super.key, this.width = 1180, this.height = 640});
  final double width, height;

  @override
  Widget build(BuildContext context) => DirLoader(
        fn: 'direction_sponsors_report',
        width: width,
        height: height,
        builder: (context, data, reload) {
          final d = _map(data);
          final rows = _list(d['rows']);
          if (rows.isEmpty) return _note('Aucun sponsoring enregistré pour le moment.\nL’administration de la plateforme saisit les contributions des sponsors.', width: width, height: height);
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(padding: EdgeInsets.zero, children: [
              Text('${fcfa(_n(d['total']))} de sponsoring · ${_n(d['students'])} étudiant${_n(d['students']) > 1 ? 's' : ''} soutenus · ${_n(d['sponsors'])} sponsor${_n(d['sponsors']) > 1 ? 's' : ''}', style: _st(16, w: FontWeight.w800)),
              const SizedBox(height: 12),
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(_s(r['title']), maxLines: 2, overflow: TextOverflow.ellipsis, style: _st(13.5, w: FontWeight.w700))),
                      const SizedBox(width: 8),
                      _pill(r['status'] == 'termine' ? 'Terminé' : 'En cours'),
                    ]),
                    const SizedBox(height: 3),
                    Text('${_s(r['sponsor'])}${_s(r['department']).isEmpty ? '' : ' · ${_s(r['department'])}'} · ${fcfa(_n(r['amount']))} · ${_n(r['students'])} étudiant${_n(r['students']) > 1 ? 's' : ''} · ${_s(r['year'])}', style: _st(11.5, c: _grey)),
                    if (_s(r['outcome']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Résultat : ${_s(r['outcome'])}', style: _st(12))),
                  ])),
                ),
            ]),
          );
        },
      );
}

/// Écran 239 : consolidé pour la direction, rapport du sponsor connecté pour les autres rôles.
class SponsorReportByRole extends ConsumerWidget {
  const SponsorReportByRole({super.key, this.width = 1180, this.height = 640});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) => roleKey(ref.watch(authProvider).current) == 'direction' ? DirectionSponsorsPanel(width: width, height: height) : SponsorReportPanel(width: width, height: height);
}
