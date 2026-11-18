import 'dart:convert';

import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../gen.dart' show gAlert, gConfirm, gToast;
import '../nav.dart' show gOpen;
import 'auth.dart';
import 'backend.dart';
import 'access.dart' show roleKey;
import 'download_stub.dart' if (dart.library.js_interop) 'download_web.dart';
import 'lots.dart' show issueCertificateDialog, reviewCampaignsDialog, reviewMilestonesDialog, reviewProjectsDialog, reviewWishesDialog, revokeCertificateDialog;
import 'store.dart' show StrV, fcfa;
import 'tp_ui.dart';
import 'verification_equipe.dart' show certificationQueueDialog, documentReviewDialog;

/// Espace du département (lot H2) : un compte Département gère SON département (rattaché par l'administrateur) : identité, étudiants, projets et innovations,
/// compétences, opportunités, partenariats, validations de son ressort, statistiques et rapports. Toutes les lectures passent par des fonctions serveur
/// cloisonnées (20261120020000 à 20261120020400) : aucune donnée d'un autre département n'arrive jamais ici. La direction et l'administrateur lisent un
/// département choisi (ou tous) ; seuls le département concerné et l'administrateur écrivent. Aucune donnée de maquette.

typedef Json = Map<String, dynamic>;

/// Appel de lecture serveur (clé de cache : fonction + paramètres).
class DeptCall {
  const DeptCall(this.fn, [this.args = const {}]);
  final String fn;
  final Json args;
  @override
  bool operator ==(Object other) => other is DeptCall && other.fn == fn && jsonEncode(other.args) == jsonEncode(args);
  @override
  int get hashCode => Object.hash(fn, jsonEncode(args));
}

final deptCallProvider = FutureProvider.autoDispose.family<Object?, DeptCall>((ref, c) async {
  ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  if (!Backend.ready) throw 'Hors connexion : les données du département se lisent sur le serveur.';
  final r = await Backend.rpc(c.fn, c.args);
  if (r.error != null) throw r.error!;
  return r.data;
}, retry: (_, _) => null);

/// Département consulté par l'administrateur ou la direction (identifiant ; vide = tous).
final deptTargetProvider = NotifierProvider<StrV, String>(StrV.new);

String deptErrorText(Object e) => '$e'.replaceFirst('Exception: ', '');

/// Contexte d'une page de l'espace : rôle, département ciblé et droit d'écriture.
class DeptCtx {
  const DeptCtx({required this.role, required this.target, required this.name, required this.attached});
  final String role;
  final String target;
  final String name;
  final bool attached;

  bool get isDept => role == 'dept';
  bool get canWrite => (role == 'dept' && attached) || (role == 'admin' && target.isNotEmpty);

  /// Paramètres de département : le compte Département n'en envoie jamais (le serveur impose le sien).
  Json a([Json extra = const {}]) => {if (!isDept && target.isNotEmpty) 'p_department': target, ...extra};
}

/// Lit une fonction serveur : chargement, erreur avec « Réessayer », puis [builder].
class DeptData extends ConsumerWidget {
  const DeptData(this.call, this.builder, {super.key});
  final DeptCall call;
  final Widget Function(Object? data) builder;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(deptCallProvider(call)).when(
          loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => TpEmpty(
            title: 'Lecture impossible',
            text: deptErrorText(e),
            icon: Icons.cloud_off_rounded,
            action: 'Réessayer',
            onAction: () => ref.invalidate(deptCallProvider),
          ),
          data: builder,
        );
  }
}

List<Json> deptList(Object? d) => d is List ? [for (final x in d) if (x is Map) Map<String, dynamic>.from(x)] : const [];
Json deptMap(Object? d) => d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
int deptInt(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

/// Cadre commun : rattachement (compte non rattaché = message clair), choix du département pour la direction et l'administrateur, puis le contenu.
class DeptShell extends ConsumerWidget {
  const DeptShell({super.key, required this.title, required this.builder, this.needDepartment = false});
  final String title;
  final bool needDepartment;
  final List<Widget> Function(BuildContext context, DeptCtx c) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(authProvider.select((s) => s.current));
    final role = roleKey(account);
    if (!Backend.ready || account == null) {
      return TpPage(title: title, children: const [TpEmpty(title: 'Connexion requise', text: 'Connectez-vous avec un compte Département pour lire les données de votre département.', icon: Icons.lock_outline_rounded)]);
    }
    final me = ref.watch(deptCallProvider(const DeptCall('my_department')));
    return me.when(
      loading: () => TpPage(title: title, children: const [Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: CircularProgressIndicator()))]),
      error: (e, _) => TpPage(title: title, children: [TpEmpty(title: 'Lecture impossible', text: deptErrorText(e), icon: Icons.cloud_off_rounded, action: 'Réessayer', onAction: () => ref.invalidate(deptCallProvider))]),
      data: (d) {
        final m = deptMap(d);
        final attached = m['attached'] == true;
        if (role == 'dept' && !attached) {
          return TpPage(title: title, children: const [
            TpEmpty(
              title: 'Compte non rattaché',
              text: 'Votre compte n’est rattaché à aucun département : l’administrateur doit le faire avant que vous puissiez suivre vos étudiants. Aucune donnée n’est affichée en attendant.',
              icon: Icons.link_off_rounded,
            ),
          ]);
        }
        final target = ref.watch(deptTargetProvider);
        final c = DeptCtx(role: role, target: role == 'dept' ? '' : target, name: '${m['department'] ?? ''}', attached: attached);
        final sub = role == 'dept' ? '${m['department'] ?? ''}' : null;
        return TpPage(
          title: title,
          subtitle: sub,
          children: [
            if (role != 'dept') _DeptPicker(allowAll: !needDepartment),
            if (role != 'dept' && needDepartment && target.isEmpty)
              const TpEmpty(title: 'Choisissez un département', text: 'Cette page se lit pour un département à la fois.', icon: Icons.account_balance_outlined)
            else
              ...builder(context, c),
          ],
        );
      },
    );
  }
}

/// Choix du département pour la direction et l'administrateur (liste serveur, jamais de nom inventé).
class _DeptPicker extends ConsumerWidget {
  const _DeptPicker({required this.allowAll});
  final bool allowAll;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(deptTargetProvider);
    return ref.watch(deptCallProvider(const DeptCall('admin_departments'))).when(
          loading: () => const SizedBox(height: 50),
          error: (e, _) => tpNote('Liste des départements indisponible : ${deptErrorText(e)}', c: tpRed),
          data: (d) {
            final rows = [for (final x in deptList(d)) if (x['id'] != null) x];
            String label(Json x) => '${x['name']} · ${x['institution']}';
            const all = 'Tous les départements';
            final current = rows.where((x) => '${x['id']}' == target).map(label).firstOrNull ?? (allowAll ? all : 'Choisir un département');
            return TpSelect('Département', current, [if (allowAll) all, ...rows.map(label)], (v) {
              final hit = rows.where((x) => label(x) == v).firstOrNull;
              ref.read(deptTargetProvider.notifier).set(hit == null ? '' : '${hit['id']}');
            }, allowCustom: false);
          },
        );
  }
}

Widget _stat(String label, String value, {VoidCallback? onTap, Color? color}) => Semantics(
      button: onTap != null,
      label: '$label : $value',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 166,
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xCCFFFFFF), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white, width: 1.5)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: tpSt(22, w: FontWeight.w700, c: color ?? tpInk)),
            const SizedBox(height: 2),
            Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: tpSt(12, c: tpGrey)),
          ]),
        ),
      ),
    );

Widget _chip(String t, {Color c = tpGrey}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: .12), borderRadius: BorderRadius.circular(100)),
      child: Text(t, style: tpSt(11, w: FontWeight.w600, c: c)),
    );

Widget _tile(IconData icon, String title, String sub, VoidCallback onTap, {String? badge}) => TpCard(
      onTap: onTap,
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: tpViolet.withValues(alpha: .1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 20, color: tpViolet)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: tpSt(14.5, w: FontWeight.w700)),
            Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: tpSt(12, c: tpGrey)),
          ]),
        ),
        if (badge != null) Padding(padding: const EdgeInsets.only(right: 6), child: _chip(badge, c: tpRed)),
        const Icon(Icons.chevron_right_rounded, color: tpGrey),
      ]),
    );

void _go(BuildContext context, String path) => GoRouter.of(context).push(path);

// ============================================================ Tableau de bord ============================================================

class DepartmentHubScreen extends ConsumerWidget {
  const DepartmentHubScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => DeptShell(
        title: 'Mon département',
        builder: (context, c) => [
          DeptData(DeptCall('dept_overview', c.a()), (d) {
            final o = deptMap(d);
            final pending = deptInt(deptMap(o['validations'])['total']);
            final proj = deptMap(o['projects']), inn = deptMap(o['innovations']), sk = deptMap(o['skills']), op = deptMap(o['opportunities']), pa = deptMap(o['partnerships']), sales = deptMap(o['sales']);
            final name = '${o['department'] ?? ''}'.isEmpty ? 'Tous les départements' : '${o['department']}';
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TpCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: tpSt(18, w: FontWeight.w700)),
                  if ('${o['institution'] ?? ''}'.isNotEmpty) Text('${o['institution']}', style: tpSt(12.5, c: tpGrey)),
                  if (!c.canWrite) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Lecture seule', style: tpSt(12, w: FontWeight.w600, c: tpGrey))),
                ]),
              ),
              Wrap(spacing: 12, runSpacing: 12, children: [
                _stat('Étudiants', '${deptInt(o['students'])}', onTap: () => _go(context, '/departement/etudiants')),
                _stat('Étudiants vérifiés', '${deptInt(o['students_verified'])}'),
                _stat('Projets', '${deptInt(proj['total'])}', onTap: () => _go(context, '/departement/projets')),
                _stat('Innovations', '${deptInt(inn['total'])}', onTap: () => _go(context, '/departement/projets')),
                _stat('Compétences', '${deptInt(sk['total'])}', onTap: () => _go(context, '/departement/competences')),
                _stat('Vendeurs actifs', '${deptInt(o['sellers'])}'),
                _stat('Offres publiées', '${deptInt(op['published'])}', onTap: () => _go(context, '/departement/opportunites')),
                _stat('Candidatures', '${deptInt(op['applications'])}'),
                _stat('Partenariats actifs', '${deptInt(pa['actif'])}', onTap: () => _go(context, '/departement/partenariats')),
                _stat('Chiffre d’affaires', fcfa(deptInt(sales['revenue']))),
                _stat('À valider', '$pending', color: pending > 0 ? tpRed : tpGreen, onTap: () => _go(context, '/departement/validations')),
              ]),
              tpSection('Gérer le département'),
              _tile(Icons.badge_outlined, 'Identité du département', 'Présentation, filières, contacts publiés', () => _go(context, '/departement/identite')),
              _tile(Icons.groups_outlined, 'Étudiants', 'Suivi des étudiants et de leurs activités', () => _go(context, '/departement/etudiants')),
              _tile(Icons.lightbulb_outline_rounded, 'Projets et innovations', 'Productions, innovations, mise en avant', () => _go(context, '/departement/projets')),
              _tile(Icons.workspace_premium_outlined, 'Compétences', 'Compétences déclarées et réalisations', () => _go(context, '/departement/competences')),
              _tile(Icons.verified_outlined, 'Registre des certificats', 'Certificats émis, révocation, mise en avant', () => _go(context, '/departement/certificats')),
              _tile(Icons.work_outline_rounded, 'Opportunités', 'Offres, candidatures et embauches', () => _go(context, '/departement/opportunites')),
              _tile(Icons.handshake_outlined, 'Partenariats', 'Conventions, stages, sponsoring', () => _go(context, '/departement/partenariats')),
              _tile(Icons.fact_check_outlined, 'Validations', 'Ce qui relève de votre département', () => _go(context, '/departement/validations'), badge: pending > 0 ? '$pending' : null),
              _tile(Icons.description_outlined, 'Rapports et exports', 'Synthèse, étudiants, projets, ventes (CSV)', () => _go(context, '/departement/rapports')),
              if (c.role == 'admin') _tile(Icons.link_rounded, 'Rattachement des comptes', 'Définir le département de chaque compte Département', () => _go(context, '/departement/rattachements')),
              tpSection('Outils détaillés'),
              _tile(Icons.dashboard_outlined, 'Console du département', 'Ventes, validations d’annonces, productions', () => gOpen(context, '108')),
              tpSection('Activité récente'),
              DeptData(DeptCall('dept_activity', c.a({'p_limit': 12})), (d) {
                final rows = deptList(d);
                if (rows.isEmpty) return tpNote('Aucune activité pour le moment.');
                return Column(children: [
                  for (final r in rows)
                    TpCard(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${r['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: tpSt(13.5, w: FontWeight.w600)),
                            Text('${r['who'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tpSt(11.5, c: tpGrey)),
                          ]),
                        ),
                      ]),
                    ),
                ]);
              }),
            ]);
          }),
        ],
      );
}

// ============================================================ Identité ============================================================

class DepartmentIdentityScreen extends ConsumerWidget {
  const DepartmentIdentityScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => DeptShell(
        title: 'Identité du département',
        needDepartment: true,
        builder: (context, c) => [DeptData(DeptCall('dept_identity_get', c.a()), (d) => _IdentityForm(key: ValueKey('${deptMap(d)['department_id']}'), data: deptMap(d), c: c))],
      );
}

class _IdentityForm extends ConsumerStatefulWidget {
  const _IdentityForm({super.key, required this.data, required this.c});
  final Json data;
  final DeptCtx c;
  @override
  ConsumerState<_IdentityForm> createState() => _IdentityFormState();
}

class _IdentityFormState extends ConsumerState<_IdentityForm> {
  late final desc = TextEditingController(text: '${widget.data['description'] ?? ''}');
  late final mission = TextEditingController(text: '${widget.data['mission'] ?? ''}');
  late final programs = TextEditingController(text: [for (final p in (widget.data['programs'] as List? ?? const [])) '$p'].join(', '));
  late final head = TextEditingController(text: '${widget.data['head_name'] ?? ''}');
  late final mail = TextEditingController(text: '${widget.data['contact_email'] ?? ''}');
  late final phone = TextEditingController(text: '${widget.data['contact_phone'] ?? ''}');
  late final address = TextEditingController(text: '${widget.data['address'] ?? ''}');
  late final web = TextEditingController(text: '${widget.data['website'] ?? ''}');
  late bool pub = widget.data['contact_public'] == true;
  bool busy = false;

  @override
  void dispose() {
    for (final x in [desc, mission, programs, head, mail, phone, address, web]) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    setState(() => busy = true);
    final r = await Backend.rpc('dept_identity_save', {
      'p': {
        'description': desc.text.trim(),
        'mission': mission.text.trim(),
        'programs': [for (final p in programs.text.split(',')) if (p.trim().length >= 2) p.trim()],
        'head_name': head.text.trim(),
        'contact_email': mail.text.trim(),
        'contact_phone': phone.text.trim(),
        'address': address.text.trim(),
        'website': web.text.trim(),
        'contact_public': pub,
      },
      ...widget.c.a(),
    });
    if (!mounted) return;
    setState(() => busy = false);
    if (r.error != null) return gAlert(context, 'Enregistrement impossible', r.error!);
    ref.invalidate(deptCallProvider);
    gToast(context, 'Identité du département enregistrée.');
  }

  @override
  Widget build(BuildContext context) {
    final ro = !widget.c.canWrite;
    final accounts = [for (final a in (widget.data['accounts'] as List? ?? const [])) if (a is Map) '${a['name']} (${a['title']})'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TpCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${widget.data['name']}', style: tpSt(17, w: FontWeight.w700)),
          Text('${widget.data['institution']}', style: tpSt(12.5, c: tpGrey)),
          if (accounts.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Responsables : ${accounts.join(', ')}', style: tpSt(12, c: tpGrey))),
          tpNote('Le nom et l’établissement du département sont gérés par l’administrateur.'),
        ]),
      ),
      if (ro) tpNote('Lecture seule : seul le département concerné ou l’administrateur modifie sa fiche.'),
      AbsorbPointer(
        absorbing: ro,
        child: Opacity(
          opacity: ro ? .7 : 1,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TpField('Présentation', desc, lines: 4, maxLength: 2000),
            TpField('Mission', mission, lines: 2, maxLength: 1000),
            TpField('Filières et parcours (séparés par des virgules)', programs, maxLength: 400),
            TpField('Responsable du département', head, maxLength: 120),
            TpField('E-mail de contact', mail, keyboard: TextInputType.emailAddress, maxLength: 120),
            TpField('Téléphone de contact', phone, keyboard: TextInputType.phone, maxLength: 30),
            TpField('Adresse', address, maxLength: 200),
            TpField('Site web (https://…)', web, keyboard: TextInputType.url, maxLength: 200),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: pub,
              onChanged: (v) => setState(() => pub = v),
              title: Text('Publier les contacts sur la fiche publique', style: tpSt(13.5, w: FontWeight.w600)),
              subtitle: Text('Désactivé : seuls la présentation, les filières et le site sont publics.', style: tpSt(12, c: tpGrey)),
            ),
            const SizedBox(height: 8),
            if (!ro) TpButton('Enregistrer', save, busy: busy),
          ]),
        ),
      ),
    ]);
  }
}

// ============================================================ Étudiants ============================================================

class DepartmentStudentsScreen extends ConsumerStatefulWidget {
  const DepartmentStudentsScreen({super.key});
  @override
  ConsumerState<DepartmentStudentsScreen> createState() => _StudentsState();
}

class _StudentsState extends ConsumerState<DepartmentStudentsScreen> {
  final q = TextEditingController();
  String query = '';
  int limit = 50;
  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DeptShell(
        title: 'Étudiants',
        builder: (context, c) => [
          TpField('Rechercher un étudiant', q, onChanged: (v) => setState(() {
                query = v.trim();
                limit = 50;
              })),
          DeptData(DeptCall('dept_students_list', c.a({'p_query': query, 'p_limit': limit, 'p_offset': 0})), (d) {
            final m = deptMap(d);
            final rows = deptList(m['rows']);
            final total = deptInt(m['total']);
            if (rows.isEmpty) {
              return TpEmpty(title: query.isEmpty ? 'Aucun étudiant' : 'Aucun résultat', text: query.isEmpty ? 'Aucun étudiant n’est rattaché à ce département pour le moment.' : 'Aucun étudiant ne correspond à « $query ».', icon: Icons.groups_outlined);
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              tpNote('$total étudiant${total > 1 ? 's' : ''}'),
              for (final r in rows)
                TpCard(
                  onTap: () => _studentSheet(context, '${r['id']}'),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${r['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tpSt(14.5, w: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Wrap(spacing: 6, runSpacing: 4, children: [
                          if ('${r['level'] ?? ''}'.isNotEmpty) _chip('${r['level']}'),
                          _chip(r['verified_student'] == true ? 'Vérifié' : 'Non vérifié', c: r['verified_student'] == true ? tpGreen : tpGrey),
                          if (r['certified'] == true) _chip('Certifié', c: tpViolet),
                          if (r['suspended'] == true) _chip('Suspendu', c: tpRed),
                          _chip('${deptInt(r['projects'])} projet(s)'),
                          _chip('${deptInt(r['skills'])} compétence(s)'),
                        ]),
                      ]),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: tpGrey),
                  ]),
                ),
              if (rows.length < total) TpButton('Voir plus', () => setState(() => limit += 50), dark: false),
            ]);
          }),
        ],
      );
}

Future<void> _studentSheet(BuildContext context, String id) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .85),
        child: SafeArea(
          child: Consumer(
            builder: (context, ref, _) => DeptData(DeptCall('dept_student_detail', {'p_user': id}), (d) {
              final s = deptMap(d);
              final projects = deptList(s['projects']), skills = deptList(s['skills']);
              return ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 28), shrinkWrap: true, children: [
                Text('${s['name']}', style: tpSt(20, w: FontWeight.w700)),
                Text([if ('${s['level'] ?? ''}'.isNotEmpty) '${s['level']}', '${s['department'] ?? ''}'].where((x) => x.isNotEmpty).join(' · '), style: tpSt(12.5, c: tpGrey)),
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  _chip(s['verified_student'] == true ? 'Étudiant vérifié' : 'Non vérifié', c: s['verified_student'] == true ? tpGreen : tpGrey),
                  if (s['certified'] == true) _chip('Certifié', c: tpViolet),
                  _chip('${deptInt(s['listings'])} annonce(s)'),
                  _chip('Ventes : ${fcfa(deptInt(s['sales']))}'),
                  _chip('${deptInt(s['applications'])} candidature(s)'),
                  _chip('${deptInt(s['hired'])} embauche(s)'),
                ]),
                tpSection('Projets et innovations'),
                if (projects.isEmpty) tpNote('Aucun projet.'),
                for (final p in projects) Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [Expanded(child: Text('${p['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: tpSt(13.5, w: FontWeight.w600))), const SizedBox(width: 8), _chip(_statusLabel('${p['status']}'))])),
                tpSection('Compétences'),
                if (skills.isEmpty) tpNote('Aucune compétence déclarée.'),
                Wrap(spacing: 6, runSpacing: 6, children: [for (final k in skills) _chip('${k['skill']} · ${_levelLabel('${k['level']}')}', c: tpViolet)]),
              ]);
            }),
          ),
        ),
      ),
    );

String _statusLabel(String s) => const {'draft': 'Brouillon', 'submitted': 'À valider', 'approved': 'Validé', 'rejected': 'Refusé', 'pending': 'En attente', 'published': 'Publié', 'closed': 'Clôturé'}[s] ?? s;
String _levelLabel(String s) => const {'debutant': 'débutant', 'intermediaire': 'intermédiaire', 'avance': 'avancé', 'expert': 'expert'}[s] ?? s;

// ============================================================ Projets et innovations ============================================================

class DepartmentProjectsScreen extends ConsumerStatefulWidget {
  const DepartmentProjectsScreen({super.key});
  @override
  ConsumerState<DepartmentProjectsScreen> createState() => _ProjectsState();
}

class _ProjectsState extends ConsumerState<DepartmentProjectsScreen> {
  String kind = '';
  String status = '';

  Future<void> feature(DeptCtx c, Json p, bool on) async {
    final r = await Backend.rpc('dept_highlight_set', {'p_kind': 'project', 'p_ref': p['id'], 'p_note': '', 'p_on': on, ...c.a()});
    if (!mounted) return;
    if (r.error != null) return gAlert(context, 'Mise en avant impossible', r.error!);
    ref.invalidate(deptCallProvider);
    gToast(context, on ? 'Réalisation mise en avant sur la fiche du département.' : 'Mise en avant retirée.');
  }

  @override
  Widget build(BuildContext context) => DeptShell(
        title: 'Projets et innovations',
        builder: (context, c) => [
          TpChoice('Type', const {'': 'Tous', 'projet': 'Projets', 'innovation': 'Innovations'}, kind, (v) => setState(() => kind = v)),
          TpChoice('Statut', const {'': 'Tous', 'submitted': 'À valider', 'approved': 'Validés', 'draft': 'Brouillons', 'rejected': 'Refusés'}, status, (v) => setState(() => status = v)),
          if (c.canWrite) TpButton('Examiner les projets à valider', () => reviewProjectsDialog(context, ref), dark: false, icon: Icons.fact_check_outlined),
          const SizedBox(height: 12),
          DeptData(DeptCall('dept_projects', c.a({if (kind.isNotEmpty) 'p_kind': kind, if (status.isNotEmpty) 'p_status': status})), (d) {
            final rows = deptList(d);
            if (rows.isEmpty) return const TpEmpty(title: 'Aucun projet', text: 'Aucun projet ou innovation ne correspond pour ce département.', icon: Icons.lightbulb_outline_rounded);
            return Column(children: [
              for (final p in rows)
                TpCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('${p['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: tpSt(14.5, w: FontWeight.w700))),
                      const SizedBox(width: 8),
                      _chip(_statusLabel('${p['status']}'), c: p['status'] == 'approved' ? tpGreen : (p['status'] == 'rejected' ? tpRed : tpGrey)),
                    ]),
                    const SizedBox(height: 4),
                    Text('${p['kind'] == 'innovation' ? 'Innovation' : 'Projet'} · ${p['owner']}${deptInt(p['members']) > 0 ? ' · ${deptInt(p['members'])} membre(s)' : ''}', style: tpSt(12, c: tpGrey)),
                    if ('${p['summary'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${p['summary']}', maxLines: 3, overflow: TextOverflow.ellipsis, style: tpSt(12.5, h: 1.4))),
                    if (c.canWrite && p['status'] == 'approved' && p['visibility'] == 'public')
                      Padding(padding: const EdgeInsets.only(top: 10), child: TpButton(p['featured'] == true ? 'Retirer la mise en avant' : 'Mettre en avant', () => feature(c, p, p['featured'] != true), dark: false, icon: p['featured'] == true ? Icons.star_rounded : Icons.star_outline_rounded)),
                  ]),
                ),
            ]);
          }),
        ],
      );
}

// ============================================================ Compétences ============================================================

class DepartmentSkillsScreen extends ConsumerWidget {
  const DepartmentSkillsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => DeptShell(
        title: 'Compétences',
        builder: (context, c) => [
          DeptData(DeptCall('dept_skills', c.a()), (d) {
            final s = deptMap(d);
            final skills = deptList(s['skills']), domains = deptList(s['domains']);
            if (deptInt(s['total']) == 0) return const TpEmpty(title: 'Aucune compétence déclarée', text: 'Les compétences déclarées par les étudiants du département apparaîtront ici.', icon: Icons.workspace_premium_outlined);
            final maxN = skills.fold<int>(1, (m, x) => deptInt(x['students']) > m ? deptInt(x['students']) : m);
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 12, runSpacing: 12, children: [_stat('Compétences déclarées', '${deptInt(s['total'])}'), _stat('Étudiants concernés', '${deptInt(s['students_with_skills'])}')]),
              tpSection('Domaines'),
              Wrap(spacing: 6, runSpacing: 6, children: [for (final x in domains) _chip('${x['domain']} · ${deptInt(x['count'])}', c: tpViolet)]),
              tpSection('Compétences les plus présentes', hint: 'Étudiants qui la déclarent, dont niveau avancé ou expert.'),
              for (final x in skills)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('${x['skill']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tpSt(13.5, w: FontWeight.w600))),
                      Text('${deptInt(x['students'])} · ${deptInt(x['advanced'])} avancé(s)', style: tpSt(12, c: tpGrey)),
                    ]),
                    const SizedBox(height: 4),
                    ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: deptInt(x['students']) / maxN, minHeight: 8, backgroundColor: tpLine, color: tpViolet)),
                  ]),
                ),
            ]);
          }),
        ],
      );
}

// ============================================================ Opportunités ============================================================

class DepartmentOpportunitiesScreen extends ConsumerWidget {
  const DepartmentOpportunitiesScreen({super.key});

  Future<void> decide(BuildContext context, WidgetRef ref, Json o, bool approve) async {
    String note = '';
    if (!approve) {
      final ctl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Motif du refus'),
          content: TextField(controller: ctl, maxLines: 3, maxLength: 300, decoration: const InputDecoration(hintText: 'Expliquez la raison à l’organisation')),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Refuser'))],
        ),
      );
      note = ctl.text.trim();
      ctl.dispose();
      if (ok != true) return;
      if (note.length < 3 && context.mounted) return gAlert(context, 'Motif obligatoire', 'Indiquez le motif du refus (3 caractères au moins).');
    }
    final r = await Backend.rpc('opp_decide', {'p_id': o['id'], 'p_approve': approve, 'p_verified': false, 'p_note': note});
    if (!context.mounted) return;
    if (r.error != null) return gAlert(context, 'Décision impossible', r.error!);
    ref.invalidate(deptCallProvider);
    gToast(context, approve ? 'Offre publiée : les étudiants la voient.' : 'Offre refusée : l’organisation est prévenue.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => DeptShell(
        title: 'Opportunités',
        builder: (context, c) => [
          DeptData(DeptCall('dept_opportunities', c.a()), (d) {
            final rows = deptList(d);
            if (rows.isEmpty) return const TpEmpty(title: 'Aucune offre', text: 'Aucune offre publiée ou ciblant ce département pour le moment.', icon: Icons.work_outline_rounded);
            return Column(children: [
              for (final o in rows)
                TpCard(
                  onTap: () => _applicantsSheet(context, c, o),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('${o['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: tpSt(14.5, w: FontWeight.w700))),
                      const SizedBox(width: 8),
                      _chip(_statusLabel('${o['status']}'), c: o['status'] == 'published' ? tpGreen : (o['status'] == 'rejected' ? tpRed : tpGrey)),
                    ]),
                    Text('${o['org']} · ${o['kind']}${o['targeted'] == true ? ' · cible votre département' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tpSt(12, c: tpGrey)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 4, children: [_chip('${deptInt(o['applications'])} candidature(s) du département'), _chip('${deptInt(o['hired'])} embauche(s)', c: tpGreen)]),
                    if (c.canWrite && o['status'] == 'pending' && (o['targeted'] == true || c.role == 'admin'))
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Row(children: [
                          Expanded(child: TpButton('Valider', () => decide(context, ref, o, true))),
                          const SizedBox(width: 10),
                          Expanded(child: TpButton('Refuser', () => decide(context, ref, o, false), danger: true)),
                        ]),
                      ),
                  ]),
                ),
            ]);
          }),
        ],
      );
}

Future<void> _applicantsSheet(BuildContext context, DeptCtx c, Json o) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .8),
        child: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 28), shrinkWrap: true, children: [
            Text('${o['title']}', style: tpSt(18, w: FontWeight.w700)),
            tpNote('Candidats de votre département uniquement.'),
            Consumer(
              builder: (context, ref, _) => DeptData(DeptCall('dept_opportunity_applicants', c.a({'p_opportunity': o['id']})), (d) {
                final rows = deptList(d);
                if (rows.isEmpty) return const TpEmpty(title: 'Aucun candidat', text: 'Aucun étudiant du département n’a postulé à cette offre.', icon: Icons.person_search_outlined);
                return Column(children: [
                  for (final r in rows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [Expanded(child: Text('${r['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tpSt(14, w: FontWeight.w600))), _chip(r['hired'] == true ? 'Embauché' : '${r['status']}', c: r['hired'] == true ? tpGreen : tpGrey)]),
                    ),
                ]);
              }),
            ),
          ]),
        ),
      ),
    );

// ============================================================ Partenariats ============================================================

const _pKinds = {'convention': 'Convention', 'stage': 'Stages', 'sponsoring': 'Sponsoring', 'atelier': 'Ateliers', 'recherche': 'Recherche', 'mecenat': 'Mécénat', 'autre': 'Autre'};
const _pStatus = {'prospect': 'Prospect', 'negociation': 'Négociation', 'actif': 'Actif', 'termine': 'Terminé', 'abandonne': 'Abandonné'};

class DepartmentPartnershipsScreen extends ConsumerWidget {
  const DepartmentPartnershipsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => DeptShell(
        title: 'Partenariats',
        builder: (context, c) => [
          if (c.canWrite) TpButton('Nouveau partenariat', () => _partnershipForm(context, c, null), icon: Icons.add_rounded),
          const SizedBox(height: 12),
          DeptData(DeptCall('dept_partnerships', c.a()), (d) {
            final m = deptMap(d);
            final rows = deptList(m['partnerships']), spons = deptList(m['sponsorships']);
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (rows.isEmpty) const TpEmpty(title: 'Aucun partenariat', text: 'Suivez ici les conventions, stages, ateliers et sponsorings de votre département.', icon: Icons.handshake_outlined),
              for (final p in rows)
                TpCard(
                  onTap: c.canWrite ? () => _partnershipForm(context, c, p) : null,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('${p['partner_name']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: tpSt(14.5, w: FontWeight.w700))),
                      const SizedBox(width: 8),
                      _chip(_pStatus['${p['status']}'] ?? '${p['status']}', c: p['status'] == 'actif' ? tpGreen : tpGrey),
                    ]),
                    Text('${_pKinds['${p['kind']}'] ?? p['kind']}${deptInt(p['students']) > 0 ? ' · ${deptInt(p['students'])} étudiant(s)' : ''}${deptInt(p['amount']) > 0 ? ' · ${fcfa(deptInt(p['amount']))}' : ''}', style: tpSt(12, c: tpGrey)),
                    if ('${p['description'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${p['description']}', maxLines: 3, overflow: TextOverflow.ellipsis, style: tpSt(12.5, h: 1.4))),
                  ]),
                ),
              if (spons.isNotEmpty) ...[
                tpSection('Sponsorings enregistrés', hint: 'Saisis par l’administration pour ce département (lecture seule).'),
                for (final s in spons) TpCard(child: Row(children: [Expanded(child: Text('${s['sponsor']} · ${s['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: tpSt(13, w: FontWeight.w600))), Text(fcfa(deptInt(s['amount'])), style: tpSt(12.5, c: tpGrey))])),
              ],
            ]);
          }),
        ],
      );
}

Future<void> _partnershipForm(BuildContext context, DeptCtx c, Json? p) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _PartnershipForm(c: c, p: p),
    );

class _PartnershipForm extends ConsumerStatefulWidget {
  const _PartnershipForm({required this.c, this.p});
  final DeptCtx c;
  final Json? p;
  @override
  ConsumerState<_PartnershipForm> createState() => _PartnershipFormState();
}

class _PartnershipFormState extends ConsumerState<_PartnershipForm> {
  late final name = TextEditingController(text: '${widget.p?['partner_name'] ?? ''}');
  late final contact = TextEditingController(text: '${widget.p?['contact_name'] ?? ''}');
  late final mail = TextEditingController(text: '${widget.p?['contact_email'] ?? ''}');
  late final phone = TextEditingController(text: '${widget.p?['contact_phone'] ?? ''}');
  late final desc = TextEditingController(text: '${widget.p?['description'] ?? ''}');
  late final start = TextEditingController(text: '${widget.p?['starts_on'] ?? ''}');
  late final end = TextEditingController(text: '${widget.p?['ends_on'] ?? ''}');
  late final amount = TextEditingController(text: '${deptInt(widget.p?['amount'])}');
  late final students = TextEditingController(text: '${deptInt(widget.p?['students'])}');
  late String kind = '${widget.p?['kind'] ?? 'convention'}';
  late String status = '${widget.p?['status'] ?? 'prospect'}';
  bool busy = false;

  @override
  void dispose() {
    for (final x in [name, contact, mail, phone, desc, start, end, amount, students]) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (name.text.trim().length < 2) return gAlert(context, 'Nom manquant', 'Indiquez le nom du partenaire (2 caractères au moins).');
    setState(() => busy = true);
    final r = await Backend.rpc('dept_partnership_save', {
      'p': {
        if (widget.p != null) 'id': widget.p!['id'],
        'partner_name': name.text.trim(),
        'kind': kind,
        'status': status,
        'contact_name': contact.text.trim(),
        'contact_email': mail.text.trim(),
        'contact_phone': phone.text.trim(),
        'description': desc.text.trim(),
        'starts_on': start.text.trim(),
        'ends_on': end.text.trim(),
        'amount': int.tryParse(amount.text.trim()) ?? 0,
        'students': int.tryParse(students.text.trim()) ?? 0,
      },
      ...widget.c.a(),
    });
    if (!mounted) return;
    setState(() => busy = false);
    if (r.error != null) return gAlert(context, 'Enregistrement impossible', r.error!);
    ref.invalidate(deptCallProvider);
    Navigator.of(context).pop();
    gToast(context, 'Partenariat enregistré.');
  }

  Future<void> remove() async {
    if (!await gConfirm(context, 'Supprimer ce partenariat ?', 'Cette action est définitive.', yes: 'Supprimer')) return;
    final r = await Backend.rpc('dept_partnership_delete', {'p_id': widget.p!['id']});
    if (!mounted) return;
    if (r.error != null) return gAlert(context, 'Suppression impossible', r.error!);
    ref.invalidate(deptCallProvider);
    Navigator.of(context).pop();
    gToast(context, 'Partenariat supprimé.');
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .9),
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 20), shrinkWrap: true, children: [
              Text(widget.p == null ? 'Nouveau partenariat' : 'Modifier le partenariat', style: tpSt(18, w: FontWeight.w700)),
              const SizedBox(height: 14),
              TpField('Partenaire', name, required: true, maxLength: 120),
              TpChoice('Type', _pKinds, kind, (v) => setState(() => kind = v)),
              TpChoice('Statut', _pStatus, status, (v) => setState(() => status = v)),
              TpField('Interlocuteur', contact, maxLength: 120),
              TpField('E-mail', mail, keyboard: TextInputType.emailAddress, maxLength: 120),
              TpField('Téléphone', phone, keyboard: TextInputType.phone, maxLength: 30),
              TpField('Début (AAAA-MM-JJ)', start, maxLength: 10),
              TpField('Fin (AAAA-MM-JJ)', end, maxLength: 10),
              TpField('Montant (FCFA)', amount, keyboard: TextInputType.number, maxLength: 10),
              TpField('Étudiants concernés', students, keyboard: TextInputType.number, maxLength: 6),
              TpField('Description', desc, lines: 3, maxLength: 2000),
              TpButton('Enregistrer', save, busy: busy),
              if (widget.p != null) Padding(padding: const EdgeInsets.only(top: 10), child: TpButton('Supprimer', remove, danger: true)),
            ]),
          ),
        ),
      );
}

// ============================================================ Validations ============================================================

class DepartmentValidationsScreen extends ConsumerWidget {
  const DepartmentValidationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => DeptShell(
        title: 'Validations',
        builder: (context, c) => [
          tpNote('Seuls les éléments de votre département sont proposés ; ce qui n’a pas de département (offre sans cible, annonce d’un organisme extérieur) est décidé par l’administration.'),
          DeptData(DeptCall('dept_validations', c.a()), (d) {
            final v = deptMap(d);
            Widget row(IconData icon, String key, String title, String sub, VoidCallback? onTap) {
              final n = deptInt(v[key]);
              return _tile(icon, title, n == 0 ? 'Rien à valider' : sub, onTap ?? () => gToast(context, 'Lecture seule : la décision revient au département.'), badge: n > 0 ? '$n' : null);
            }

            final w = c.canWrite;
            return Column(children: [
              row(Icons.verified_user_outlined, 'certifications', 'Certifications', 'Dossiers étudiants à examiner', w ? () => certificationQueueDialog(context, ref) : null),
              row(Icons.badge_outlined, 'documents', 'Pièces d’étudiant', 'Cartes et certificats de scolarité', w ? () => documentReviewDialog(context, ref) : null),
              row(Icons.storefront_outlined, 'listings', 'Annonces de vos vendeurs', 'Produits et services à valider', w ? () => gOpen(context, '110') : null),
              row(Icons.lightbulb_outline_rounded, 'projects', 'Projets soumis', 'Projets et innovations à valider', w ? () => reviewProjectsDialog(context, ref) : null),
              row(Icons.campaign_outlined, 'campaigns', 'Campagnes de financement', 'Campagnes à valider', w ? () => reviewCampaignsDialog(context, ref) : null),
              row(Icons.flag_outlined, 'milestones', 'Jalons de campagne', 'Jalons déclarés atteints, à valider sur preuve', w ? () => reviewMilestonesDialog(context, ref) : null),
              row(Icons.support_agent_outlined, 'support_requests', 'Demandes d’accompagnement', 'Mentor, financement, matériel, compétences', w ? () => _go(context, '/accompagnement') : null),
              row(Icons.star_outline_rounded, 'wishes', 'Vœux de produits', 'Vœux à valider ou planifier', w ? () => reviewWishesDialog(context, ref) : null),
              row(Icons.work_outline_rounded, 'opportunities', 'Offres ciblant le département', 'Stages et emplois à valider', () => _go(context, '/departement/opportunites')),
              row(Icons.emoji_events_outlined, 'announcements', 'Annonces de concours', 'Concours et défis de vos membres', w ? () => _go(context, '/concours') : null),
              tpSection('Mentors à valider'),
              DeptData(const DeptCall('mentors_pending'), (d) {
                final rows = deptList(d);
                if (rows.isEmpty) return tpNote('Aucun profil mentor en attente dans votre département.');
                return Column(children: [for (final m in rows) _MentorRow(m: m, canWrite: w)]);
              }),
            ]);
          }),
        ],
      );
}

class _MentorRow extends ConsumerWidget {
  const _MentorRow({required this.m, required this.canWrite});
  final Json m;
  final bool canWrite;

  Future<void> decide(BuildContext context, WidgetRef ref, bool ok) async {
    final r = await Backend.rpc('mentor_validate', {'p_user': m['user_id'], 'p_approve': ok, 'p_note': ok ? null : 'Profil non retenu par le département'});
    if (!context.mounted) return;
    if (r.error != null) return gAlert(context, 'Décision impossible', r.error!);
    ref.invalidate(deptCallProvider);
    gToast(context, ok ? 'Profil mentor validé.' : 'Profil mentor refusé.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => TpCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${m['name']}', style: tpSt(14.5, w: FontWeight.w700)),
          Text('${m['works_at'] ?? ''}', style: tpSt(12, c: tpGrey)),
          if (canWrite)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(children: [
                Expanded(child: TpButton('Valider', () => decide(context, ref, true))),
                const SizedBox(width: 10),
                Expanded(child: TpButton('Refuser', () => decide(context, ref, false), danger: true)),
              ]),
            ),
        ]),
      );
}

// ============================================================ Rapports ============================================================

const _reportKinds = {
  'synthese': 'Synthèse',
  'etudiants': 'Étudiants',
  'projets': 'Projets',
  'competences': 'Compétences',
  'opportunites': 'Opportunités',
  'partenariats': 'Partenariats',
  'ventes': 'Ventes',
};

/// CSV d'un rapport : en-têtes puis lignes ; une cellule qui commencerait par = + - @ est neutralisée (injection de formule dans un tableur).
String deptReportCsv(Json report) {
  final cols = deptList(report['columns']);
  String esc(Object? v) {
    var s = v == null ? '' : '$v';
    if (RegExp(r'^[=+\-@\t\r]').hasMatch(s)) s = "'$s";
    return '"${s.replaceAll('"', '""')}"';
  }

  final b = StringBuffer('\uFEFF');
  b.writeln(cols.map((c) => esc(c['label'])).join(';'));
  for (final r in deptList(report['rows'])) {
    b.writeln(cols.map((c) => esc(r[c['key']])).join(';'));
  }
  return b.toString();
}

class DepartmentReportsScreen extends ConsumerStatefulWidget {
  const DepartmentReportsScreen({super.key});
  @override
  ConsumerState<DepartmentReportsScreen> createState() => _ReportsState();
}

class _ReportsState extends ConsumerState<DepartmentReportsScreen> {
  String kind = 'synthese';
  final from = TextEditingController();
  final to = TextEditingController();
  Json? report;
  bool busy = false;
  String? error;

  @override
  void dispose() {
    from.dispose();
    to.dispose();
    super.dispose();
  }

  Future<void> generate(DeptCtx c) async {
    setState(() {
      busy = true;
      error = null;
    });
    final r = await Backend.rpc('dept_report', {'p_kind': kind, if (from.text.trim().isNotEmpty) 'p_from': from.text.trim(), if (to.text.trim().isNotEmpty) 'p_to': to.text.trim(), ...c.a()});
    if (!mounted) return;
    setState(() {
      busy = false;
      if (r.error != null) {
        error = r.error;
        report = null;
      } else {
        report = deptMap(r.data);
      }
    });
  }

  Future<void> export() async {
    final saved = await saveTextFile('rapport-departement-$kind-${DateTime.now().toIso8601String().substring(0, 10)}.csv', deptReportCsv(report!), 'text/csv;charset=utf-8');
    if (!mounted) return;
    gToast(context, saved ? 'Rapport téléchargé (CSV).' : 'Rapport copié dans le presse-papiers (format CSV).');
  }

  @override
  Widget build(BuildContext context) => DeptShell(
        title: 'Rapports et exports',
        builder: (context, c) {
          final rows = deptList(report?['rows']);
          final cols = deptList(report?['columns']);
          return [
            TpChoice('Rapport', _reportKinds, kind, (v) => setState(() {
                  kind = v;
                  report = null;
                })),
            if (kind != 'synthese' && kind != 'competences' && kind != 'partenariats') ...[
              TpField('Du (AAAA-MM-JJ, facultatif)', from, maxLength: 10),
              TpField('Au (AAAA-MM-JJ, facultatif)', to, maxLength: 10),
            ],
            TpButton('Générer le rapport', () => generate(c), busy: busy, icon: Icons.description_outlined),
            if (error != null) tpNote(error!, c: tpRed),
            if (report != null) ...[
              tpSection('${report!['title']}', hint: '${rows.length} ligne(s) · ${'${report!['department'] ?? ''}'.isEmpty ? 'tous les départements' : report!['department']}'),
              if (rows.isEmpty) const TpEmpty(title: 'Rapport vide', text: 'Aucune donnée pour cette période.', icon: Icons.inbox_outlined),
              for (final r in rows.take(20))
                TpCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final col in cols)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(flex: 5, child: Text('${col['label']}', style: tpSt(11.5, c: tpGrey))),
                          const SizedBox(width: 8),
                          Expanded(flex: 6, child: Text('${r[col['key']] ?? ''}', style: tpSt(12.5, w: FontWeight.w600))),
                        ]),
                      ),
                  ]),
                ),
              if (rows.length > 20) tpNote('${rows.length - 20} autre(s) ligne(s) dans le fichier exporté.'),
              if (rows.isNotEmpty) TpButton('Exporter en CSV', export, icon: Icons.download_rounded),
            ],
          ];
        },
      );
}

// ============================================================ Certificats ============================================================

class DepartmentCertificatesScreen extends ConsumerWidget {
  const DepartmentCertificatesScreen({super.key});

  Future<void> feature(BuildContext context, WidgetRef ref, DeptCtx c, Json x, bool on) async {
    final r = await Backend.rpc('dept_highlight_set', {'p_kind': 'certificate', 'p_ref': x['id'], 'p_note': '', 'p_on': on, ...c.a()});
    if (!context.mounted) return;
    if (r.error != null) return gAlert(context, 'Mise en avant impossible', r.error!);
    ref.invalidate(deptCallProvider);
    gToast(context, on ? 'Certificat mis en avant sur la fiche du département.' : 'Mise en avant retirée.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => DeptShell(
        title: 'Registre des certificats',
        builder: (context, c) => [
          if (c.canWrite)
            Row(children: [
              Expanded(child: TpButton('Émettre', () async {
                await issueCertificateDialog(context, ref);
                ref.invalidate(deptCallProvider);
              }, icon: Icons.add_rounded)),
              const SizedBox(width: 10),
              Expanded(child: TpButton('Révoquer', () async {
                await revokeCertificateDialog(context, ref);
                ref.invalidate(deptCallProvider);
              }, dark: false)),
            ]),
          const SizedBox(height: 12),
          DeptData(DeptCall('dept_certificates', c.a()), (d) {
            final rows = deptList(d);
            if (rows.isEmpty) return const TpEmpty(title: 'Aucun certificat', text: 'Les certificats émis pour les étudiants de ce département apparaîtront ici.', icon: Icons.workspace_premium_outlined);
            return Column(children: [
              for (final x in rows)
                TpCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('${x['subject']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: tpSt(14.5, w: FontWeight.w700))),
                      const SizedBox(width: 8),
                      _chip(x['revoked'] == true ? 'Révoqué' : 'Valide', c: x['revoked'] == true ? tpRed : tpGreen),
                    ]),
                    Text('${x['holder']} · ${x['code']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tpSt(12, c: tpGrey)),
                    if (x['revoked'] == true && '${x['revoked_reason'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Motif : ${x['revoked_reason']}', style: tpSt(12, c: tpRed))),
                    if (c.canWrite && x['revoked'] != true)
                      Padding(padding: const EdgeInsets.only(top: 10), child: TpButton(x['featured'] == true ? 'Retirer la mise en avant' : 'Mettre en avant', () => feature(context, ref, c, x, x['featured'] != true), dark: false, icon: x['featured'] == true ? Icons.star_rounded : Icons.star_outline_rounded)),
                  ]),
                ),
            ]);
          }),
        ],
      );
}

// ============================================================ Rattachement (administrateur) ============================================================

class DepartmentAttachScreen extends ConsumerWidget {
  const DepartmentAttachScreen({super.key});

  Future<void> attach(BuildContext context, WidgetRef ref, Json a) async {
    final deps = deptList(await ref.read(deptCallProvider(const DeptCall('admin_departments')).future));
    if (!context.mounted) return;
    String label(Json x) => '${x['name']} · ${x['institution']}';
    final v = await tpPick(context, 'Département de ${a['name']}', [for (final x in deps) if (x['id'] != null) label(x)], allowCustom: false, current: '');
    if (v == null) return;
    final hit = deps.where((x) => label(x) == v).firstOrNull;
    if (hit == null) return;
    final r = await Backend.rpc('admin_dept_assign', {'p_user': a['id'], 'p_department': hit['id'], 'p_title': 'Responsable'});
    if (!context.mounted) return;
    if (r.error != null) return gAlert(context, 'Rattachement impossible', r.error!);
    ref.invalidate(deptCallProvider);
    gToast(context, '${a['name']} est rattaché à ${hit['name']}.');
  }

  Future<void> detach(BuildContext context, WidgetRef ref, Json a) async {
    if (!await gConfirm(context, 'Retirer le rattachement ?', '${a['name']} ne verra plus aucune donnée de département.', yes: 'Retirer')) return;
    final r = await Backend.rpc('admin_dept_unassign', {'p_user': a['id']});
    if (!context.mounted) return;
    if (r.error != null) return gAlert(context, 'Retrait impossible', r.error!);
    ref.invalidate(deptCallProvider);
    gToast(context, 'Rattachement retiré.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(authProvider.select((s) => s.current));
    if (!Backend.ready || account == null) return const TpPage(title: 'Rattachement des comptes', children: [TpEmpty(title: 'Connexion requise', text: 'Connectez-vous avec le compte administrateur.', icon: Icons.lock_outline_rounded)]);
    return TpPage(
      title: 'Rattachement des comptes',
      subtitle: 'Un compte Département appartient à un seul département',
      children: [
        DeptData(const DeptCall('admin_dept_accounts'), (d) {
          final rows = deptList(d);
          if (rows.isEmpty) return const TpEmpty(title: 'Aucun compte Département', text: 'Attribuez d’abord le rôle Département à un compte depuis la gestion des utilisateurs.', icon: Icons.person_off_outlined);
          return Column(children: [
            for (final a in rows)
              TpCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('${a['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tpSt(14.5, w: FontWeight.w700))),
                    _chip(a['attached'] == true ? 'Rattaché' : 'Non rattaché', c: a['attached'] == true ? tpGreen : tpRed),
                  ]),
                  if (a['attached'] == true) Text('${a['department']} · ${a['institution']}', style: tpSt(12, c: tpGrey)),
                  if (a['suspended'] == true) Text('Compte suspendu', style: tpSt(12, c: tpRed)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TpButton(a['attached'] == true ? 'Changer' : 'Rattacher', () => attach(context, ref, a))),
                    if (a['attached'] == true) ...[const SizedBox(width: 10), Expanded(child: TpButton('Retirer', () => detach(context, ref, a), danger: true))],
                  ]),
                ]),
              ),
          ]);
        }),
      ],
    );
  }
}

/// Écran du registre dont la version « connectée » est une page réelle de l'espace du département : hors connexion (démonstration), la maquette reste affichée.
/// 116 (rapports et exports) et 169 (modération des concours et des offres) deviennent les pages réelles correspondantes.
Widget deptLiveScreen(String id, Widget mock) => switch (id) {
      '116' => DeptConnectedSwap(real: const DepartmentReportsScreen(), mock: mock),
      '169' => DeptConnectedSwap(real: const DepartmentValidationsScreen(), mock: mock),
      '213' || '283' => DeptConnectedSwap(real: const DepartmentCertificatesScreen(), mock: mock),
      _ => mock,
    };

class DeptConnectedSwap extends ConsumerWidget {
  const DeptConnectedSwap({super.key, required this.real, required this.mock});
  final Widget real, mock;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(authProvider.select((s) => s.current));
    final connected = Backend.ready && account != null && const {'dept', 'direction', 'admin'}.contains(roleKey(account));
    return connected ? real : mock;
  }
}
