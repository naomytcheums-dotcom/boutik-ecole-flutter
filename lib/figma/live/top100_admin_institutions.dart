import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gToast;
import '../i18n.dart' show Text;
import 'access.dart' show roleKey;
import 'admin.dart' show serverAccountsProvider;
import 'auth.dart';
import 'profile_data.dart' show RefItem, listDepartments, searchInstitutions;
import 'tp_ui.dart';
import 'top100_admin_common.dart';
import 'top100_admin_form.dart';

/// Établissements, filières et responsables (permission `institutions.manage`), et file des rattachements d'étudiants (périmètre de l'appelant : administration = tout,
/// responsable d'établissement = son établissement, responsable de département = les filières de son département). Le référentiel est vide tant que l'administration ne l'a pas saisi.

final top100InstitutionsProvider = FutureProvider.autoDispose.family<List<RefItem>, String>((ref, q) async {
  ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  try {
    return await searchInstitutions(q);
  } catch (e) {
    throw Top100Error(top100Msg(e));
  }
}, retry: (_, _) => null);

final top100ProgramsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, institution) async {
  ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  return top100List('programs_list', {'p_institution': institution});
}, retry: (_, _) => null);

final top100AffiliationQueueProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  return top100List('student_affiliation_queue');
}, retry: (_, _) => null);

class Top100InstitutionsSection extends ConsumerStatefulWidget {
  const Top100InstitutionsSection({super.key});

  @override
  ConsumerState<Top100InstitutionsSection> createState() => _InstitutionsState();
}

class _InstitutionsState extends ConsumerState<Top100InstitutionsSection> {
  final _q = TextEditingController();
  String _query = '';
  RefItem? _institution;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _program(RefItem inst, {Map<String, dynamic>? program}) async {
    var departments = <RefItem>[];
    String? departmentsNote;
    try {
      departments = await listDepartments(inst.id, '');
    } catch (e) {
      departmentsNote = 'Les départements n’ont pas pu être lus : ${top100Msg(e)}';
    }
    if (!mounted) return;
    final ok = await top100Form(
      context,
      title: program == null ? 'Nouvelle filière · ${inst.name}' : 'Modifier la filière',
      body: departmentsNote,
      fields: [
        T100Field('name', 'Nom de la filière (2 à 120 caractères)', initial: top100Str(program?['name']), required: true, maxLength: 120),
        if (departments.isNotEmpty) T100Field('department', 'Département (facultatif)', kind: T100Kind.choice, initial: top100Str(program?['department_id']), options: {'': 'Aucun', for (final d in departments) d.id: d.name}),
        T100Field('active', 'Filière active', kind: T100Kind.toggle, initial: '${program == null ? true : program['active'] == true}'),
      ],
      ok: 'Enregistrer',
      validate: (v) => (v['name'] ?? '').length < 2 ? 'Le nom doit contenir au moins 2 caractères.' : null,
      submit: (v) async {
        await top100Call('admin_program_upsert', {
          'p_id': program?['id'],
          'p_institution': inst.id,
          'p_department': (v['department'] ?? '').isEmpty ? null : v['department'],
          'p_name': v['name'],
          'p_active': v['active'] == 'true',
        });
      },
    );
    if (ok && mounted) {
      gToast(context, 'Filière enregistrée.');
      ref.invalidate(top100ProgramsProvider(inst.id));
    }
  }

  Future<void> _manager(RefItem inst) async {
    final picked = await showModalBottomSheet<({String id, String name})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 420),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) => const _AccountSheet(),
    );
    if (picked == null || !mounted) return;
    final ok = await top100Form(
      context,
      title: 'Responsable de ${inst.name}',
      body: '${picked.name} : le responsable n’a de pouvoir que sur cet établissement (validation des rattachements). Un compte étudiant ne peut pas être nommé.',
      fields: const [T100Field('on', 'Responsable de cet établissement', kind: T100Kind.toggle, initial: 'true')],
      ok: 'Enregistrer',
      submit: (v) async => top100Call('admin_institution_manager_set', {'p_user': picked.id, 'p_institution': inst.id, 'p_on': v['on'] == 'true'}),
    );
    if (ok && mounted) gToast(context, 'Responsable enregistré.');
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(top100InstitutionsProvider(_query));
    final inst = _institution;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      tpNote('Le référentiel est vide tant que l’administration ne l’a pas saisi : aucun établissement ni filière n’est créé d’office.'),
      TpField('Rechercher un établissement', _q),
      TpButton('Rechercher', () => setState(() => _query = _q.text.trim()), compact: true, dark: false, icon: Icons.search_rounded),
      const SizedBox(height: 10),
      list.when(
        loading: top100Loading,
        error: (e, _) => top100Failed(top100Msg(e), () => ref.invalidate(top100InstitutionsProvider(_query))),
        data: (rows) => rows.isEmpty
            ? const TpEmpty(title: 'Aucun établissement', text: 'Aucun établissement ne correspond : le référentiel est peut-être encore vide.', icon: Icons.account_balance_outlined)
            : Column(children: [
                for (final i in rows)
                  TpCard(
                    onTap: () => setState(() => _institution = i),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(i.name, style: tpSt(14, w: FontWeight.w700)),
                          if (i.subtitle.isNotEmpty) Text(i.subtitle, style: tpSt(12, c: tpGrey)),
                        ]),
                      ),
                      if (inst?.id == i.id) const Icon(Icons.check_circle_rounded, color: tpGreen) else const Icon(Icons.chevron_right_rounded, color: tpGrey),
                    ]),
                  ),
              ]),
      ),
      if (inst != null) ...[
        tpSection('Filières · ${inst.name}', hint: 'Les filières inactives sont visibles ici et masquées du public.'),
        if (inst.proposed) tpNote('Cet établissement est seulement proposé : il doit être vérifié avant de recevoir des filières.', c: tpRed),
        ref.watch(top100ProgramsProvider(inst.id)).when(
              loading: top100Loading,
              error: (e, _) => top100Failed(top100Msg(e), () => ref.invalidate(top100ProgramsProvider(inst.id))),
              data: (rows) => rows.isEmpty
                  ? const TpEmpty(title: 'Aucune filière', text: 'Cet établissement n’a encore aucune filière.', icon: Icons.school_outlined)
                  : Column(children: [
                      for (final p in rows)
                        TpCard(
                          child: Row(children: [
                            Expanded(child: Text('${p['name']}', style: tpSt(13.5, w: FontWeight.w600))),
                            top100Chip(p['active'] == false ? 'Inactive' : 'Active', c: p['active'] == false ? tpGrey : tpGreen),
                            const SizedBox(width: 8),
                            TpButton('Modifier', () => _program(inst, program: p), compact: true, dark: false),
                          ]),
                        ),
                    ]),
            ),
        const SizedBox(height: 4),
        TpButton('Ajouter une filière', inst.proposed ? null : () => _program(inst), icon: Icons.add_rounded),
        const SizedBox(height: 8),
        TpButton('Nommer ou retirer un responsable', () => _manager(inst), dark: false, icon: Icons.manage_accounts_outlined),
      ],
    ]);
  }
}

class _AccountSheet extends ConsumerStatefulWidget {
  const _AccountSheet();

  @override
  ConsumerState<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends ConsumerState<_AccountSheet> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.watch(serverAccountsProvider.notifier);
    final accounts = ref.watch(serverAccountsProvider);
    final q = _q.text.trim().toLowerCase();
    final rows = [for (final a in accounts) if (a.serverId.isNotEmpty && roleKey(a) != 'student' && (q.isEmpty || a.name.toLowerCase().contains(q) || a.email.toLowerCase().contains(q))) a];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 8), child: Text('Choisir un compte', style: tpSt(17, w: FontWeight.w700))),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: TextField(controller: _q, onChanged: (_) => setState(() {}), decoration: InputDecoration(hintText: 'Nom ou e-mail', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))))),
            const SizedBox(height: 8),
            Flexible(
              child: notifier.failed
                  ? Padding(padding: const EdgeInsets.all(20), child: Text('La liste des comptes n’a pas pu être lue.', style: tpSt(13, c: tpRed)))
                  : rows.isEmpty
                      ? Padding(padding: const EdgeInsets.all(20), child: Text('Aucun compte non étudiant trouvé.', style: tpSt(13, c: tpGrey)))
                      : ListView(shrinkWrap: true, children: [
                          for (final a in rows)
                            ListTile(
                              title: Text(a.name, style: tpSt(13.5, w: FontWeight.w600)),
                              subtitle: Text('${a.email} · ${a.roleLabel}', style: tpSt(11.5, c: tpGrey)),
                              onTap: () => Navigator.of(context).pop((id: a.serverId, name: a.name)),
                            ),
                        ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class Top100AffiliationsSection extends ConsumerWidget {
  const Top100AffiliationsSection({super.key});

  Future<void> _decide(BuildContext context, WidgetRef ref, Map<String, dynamic> r, String decision) async {
    final verified = decision == 'verified';
    final ok = await top100Form(
      context,
      title: verified ? 'Valider le rattachement de ${r['student']} ?' : 'Refuser le rattachement de ${r['student']} ?',
      body: '${top100Str(r['program'])} · ${top100Str(r['institution'])} · promotion ${top100Str(r['promotion'])}. La décision est définitive et l’étudiant en est notifié.${verified ? ' Un éventuel rattachement précédent est clos.' : ''}',
      fields: [T100Field('note', verified ? 'Note (facultative)' : 'Motif du refus (obligatoire)', kind: T100Kind.multiline, required: !verified, maxLength: 500)],
      ok: verified ? 'Valider' : 'Refuser',
      danger: !verified,
      submit: (v) async => top100Call('student_affiliation_decide', {'p_id': r['id'], 'p_decision': decision, if ((v['note'] ?? '').isNotEmpty) 'p_note': v['note']}),
    );
    if (ok && context.mounted) {
      gToast(context, verified ? 'Rattachement validé.' : 'Rattachement refusé.');
      ref.invalidate(top100AffiliationQueueProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(top100AffiliationQueueProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      tpNote('Vous ne voyez que les demandes de votre périmètre. Un rattachement vérifié conditionne la présence d’un étudiant dans les classements.'),
      queue.when(
        loading: top100Loading,
        error: (e, _) => top100Failed(top100Msg(e), () => ref.invalidate(top100AffiliationQueueProvider)),
        data: (rows) => rows.isEmpty
            ? const TpEmpty(title: 'Aucune demande en attente', text: 'Aucune demande de rattachement n’attend dans votre périmètre.', icon: Icons.verified_user_outlined)
            : Column(children: [
                for (final r in rows)
                  TpCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(top100Str(r['student'], 'Étudiant'), style: tpSt(14, w: FontWeight.w700)),
                      top100Line('Établissement', r['institution']),
                      top100Line('Filière', r['program']),
                      top100Line('Promotion', r['promotion']),
                      top100Line('Demandé le', tpDate(r['requested_at'])),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: TpButton('Valider', () => _decide(context, ref, r, 'verified'), compact: true)),
                        const SizedBox(width: 8),
                        Expanded(child: TpButton('Refuser', () => _decide(context, ref, r, 'rejected'), compact: true, danger: true)),
                      ]),
                    ]),
                  ),
              ]),
      ),
    ]);
  }
}
