import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gToast;
import 'backend.dart';
import 'l9_common.dart';
import 'lots.dart' show pickAndUpload;
import 'project_pages.dart' show ProjectFormPage, ipFormFields, IpDeclaration, projectStatusLabels;
import 'tp_ui.dart';

String _ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Message d'erreur serveur lisible.
String _err(Object? e) => Backend.userMessage('$e');

/// Aucun projet du compte : explication et chemin vers la création.
Widget _noProject(BuildContext context, String text) => Column(children: [
      TpEmpty(title: 'Aucun projet', text: text, icon: Icons.lightbulb_outline_rounded),
      TpButton('Soumettre un projet', () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ProjectFormPage())), icon: Icons.add_rounded),
    ]);

/// Charge « mes projets », garde la sélection courante et la renvoie à chaque rechargement.
mixin _MyProjectsLoader<T extends StatefulWidget> on State<T> {
  List<Map<String, dynamic>>? projects;
  String? loadError;
  String selected = '';

  Map<String, dynamic>? get project {
    for (final p in projects ?? const <Map<String, dynamic>>[]) {
      if ('${p['id']}' == selected) return p;
    }
    return null;
  }

  Future<void> loadProjects({bool approvedOnly = false, String preferred = '', bool includeMember = false}) async {
    final r = await loadMyProjects(approvedOnly: approvedOnly, includeMember: includeMember);
    if (!mounted) return;
    setState(() {
      projects = r;
      final ids = [for (final p in r) '${p['id']}'];
      selected = ids.contains(preferred) ? preferred : (ids.contains(selected) ? selected : (ids.isEmpty ? '' : ids.first));
    });
    if (selected.isNotEmpty) onProjectChanged();
  }

  void onProjectChanged();
}

// ---------------------------------------------------------------- équipe

/// Équipe d'un projet : des étudiants réels invités, qui acceptent ou refusent ; la fiche publique n'affiche que ceux qui ont accepté.
class ProjectTeamPage extends StatelessWidget {
  const ProjectTeamPage({super.key, this.projectId});
  final String? projectId;

  @override
  Widget build(BuildContext context) => ProjectRoleGate(title: 'Équipe du projet', action: 'gérer l’équipe d’un projet', child: _TeamBody(projectId: projectId));
}

class _TeamBody extends ConsumerStatefulWidget {
  const _TeamBody({this.projectId});
  final String? projectId;
  @override
  ConsumerState<_TeamBody> createState() => _TeamBodyState();
}

class _TeamBodyState extends ConsumerState<_TeamBody> with _MyProjectsLoader<_TeamBody> {
  List<Map<String, dynamic>> members = const [], invitations = const [], found = const [];
  final query = TextEditingController(), role = TextEditingController();
  bool busy = false, searched = false;
  String? membersError;

  @override
  void initState() {
    super.initState();
    loadProjects(preferred: widget.projectId ?? '', includeMember: true);
    _loadInvitations();
  }

  @override
  void dispose() {
    query.dispose();
    role.dispose();
    super.dispose();
  }

  @override
  void onProjectChanged() => _loadMembers();

  Future<void> _loadInvitations() async {
    final r = await Backend.rpc('my_project_invitations', const {});
    if (!mounted) return;
    setState(() => invitations = r.data is List ? [for (final x in r.data as List) Map<String, dynamic>.from(x as Map)] : const []);
  }

  Future<void> _loadMembers() async {
    if (selected.isEmpty) return;
    final r = await Backend.rpc('project_members_list', {'p_project': selected});
    if (!mounted) return;
    setState(() {
      membersError = r.error;
      members = r.data is List ? [for (final x in r.data as List) Map<String, dynamic>.from(x as Map)] : const [];
    });
  }

  Future<void> _respond(Map<String, dynamic> inv, bool accept) async {
    final r = await Backend.rpc('project_member_respond', {'p_project': inv['project_id'], 'p_accept': accept});
    if (!mounted) return;
    if (r.error != null) return gToast(context, _err(r.error));
    gToast(context, accept ? 'Vous avez rejoint l’équipe de « ${inv['title']} ».' : 'Invitation refusée.');
    _loadInvitations();
    if (accept) _loadMembers();
  }

  Future<void> _search() async {
    final q = query.text.trim();
    if (q.length < 3) return gToast(context, 'Saisissez au moins 3 lettres du nom.');
    setState(() => busy = true);
    final r = await Backend.rpc('project_member_search', {'p_q': q});
    if (!mounted) return;
    setState(() {
      busy = false;
      searched = true;
      found = r.data is List ? [for (final x in r.data as List) Map<String, dynamic>.from(x as Map)] : const [];
    });
    if (r.error != null) gToast(context, _err(r.error));
  }

  Future<void> _invite(Map<String, dynamic> s) async {
    final r = await Backend.rpc('project_member_invite', {'p_project': selected, 'p_user': s['id'], 'p_role': role.text.trim()});
    if (!mounted) return;
    if (r.error != null) return gToast(context, _err(r.error));
    gToast(context, '${s['name']} est invité(e) : une notification lui a été envoyée.');
    setState(() {
      found = const [];
      searched = false;
      query.clear();
      role.clear();
    });
    _loadMembers();
  }

  Future<void> _remove(Map<String, dynamic> m) async {
    if (!await tpConfirm(context, 'Retirer ${m['name']} ?', 'Cette personne ne figurera plus sur l’équipe du projet.', yes: 'Retirer')) return;
    final r = await Backend.rpc('project_member_remove', {'p_project': selected, 'p_user': m['user_id']});
    if (!mounted) return;
    if (r.error != null) return gToast(context, _err(r.error));
    _loadMembers();
  }

  Future<void> _leave() async {
    if (!await tpConfirm(context, 'Quitter l’équipe ?', 'Vous ne verrez plus ce projet, son journal ni ses fichiers. Le porteur sera prévenu.', yes: 'Quitter l’équipe')) return;
    final r = await Backend.rpc('project_member_remove', {'p_project': selected, 'p_user': Backend.userId});
    if (!mounted) return;
    if (r.error != null) return gToast(context, _err(r.error));
    gToast(context, 'Vous avez quitté l’équipe.');
    members = const [];
    await loadProjects(includeMember: true);
  }

  @override
  Widget build(BuildContext context) {
    final l = projects;
    final asMember = isMemberProject(project);
    return TpPage(title: 'Équipe du projet', subtitle: project == null ? null : '${project!['title']}', children: [
      for (final inv in invitations)
        TpCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Invitation : ${inv['title']}', style: tpSt(14.5, w: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('${inv['from']} vous invite${'${inv['role']}'.isEmpty ? '' : ' comme ${inv['role']}'}.', style: tpSt(12.5, c: tpGrey, h: 1.4)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TpButton('Accepter', () => _respond(inv, true), compact: true)),
              const SizedBox(width: 8),
              Expanded(child: TpButton('Refuser', () => _respond(inv, false), dark: false, compact: true)),
            ]),
          ]),
        ),
      if (l == null)
        l9Loading()
      else if (l.isEmpty)
        _noProject(context, 'Créez d’abord votre projet : vous pourrez ensuite inviter des étudiants de la plateforme dans son équipe.')
      else ...[
        ProjectPicker(projects: l, value: selected, onChanged: (v) => setState(() {
              selected = v;
              members = const [];
              onProjectChanged();
            })),
        tpSection('Membres', hint: 'Seuls les étudiants qui ont accepté l’invitation apparaissent sur la fiche publique du projet.'),
        if (membersError != null) tpNote(Backend.userMessage(membersError!), c: tpRed),
        for (final m in members)
          TpCard(
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${m['name']}', style: tpSt(14, w: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text([if ('${m['role']}'.isNotEmpty) '${m['role']}', if (m['status'] == 'invited') 'Invitation en attente'].join(' · '), style: tpSt(12, c: tpGrey)),
                ]),
              ),
              if (m['status'] != 'owner' && !asMember) IconButton(tooltip: 'Retirer', icon: const Icon(Icons.close_rounded, color: tpGrey), onPressed: () => _remove(m)),
            ]),
          ),
        if (asMember) ...[
          tpNote('Vous faites partie de l’équipe de ce projet : vous pouvez tenir son journal et déposer des fichiers. Seul le porteur invite ou retire des membres.'),
          TpButton('Quitter l’équipe', _leave, dark: false, compact: true, icon: Icons.logout_rounded),
        ] else ...[
        tpSection('Inviter un étudiant', hint: 'Recherchez par nom (3 lettres au moins). Seuls les comptes étudiants peuvent rejoindre un projet.'),
        TpField('Rôle dans le projet (facultatif)', role, maxLength: 80),
        TpField('Nom de l’étudiant', query, maxLength: 60),
        TpButton(busy ? 'Recherche…' : 'Rechercher', busy ? null : _search, dark: false, compact: true, icon: Icons.search_rounded),
        const SizedBox(height: 10),
        if (searched && found.isEmpty) tpNote('Aucun étudiant trouvé avec ce nom.'),
        for (final s in found)
          TpCard(
            onTap: () => _invite(s),
            child: Row(children: [
              Expanded(child: Text('${s['name']}${'${s['department']}'.isEmpty ? '' : ' · ${s['department']}'}', style: tpSt(13.5, w: FontWeight.w600))),
              const Icon(Icons.person_add_alt_rounded, color: tpViolet, size: 20),
            ]),
          ),
        ],
      ],
    ]);
  }
}

// ---------------------------------------------------------------- journal

/// Journal du projet : les étapes de MES projets, avec ajout, modification et suppression.
class ProjectJournalPage extends StatelessWidget {
  const ProjectJournalPage({super.key});
  @override
  Widget build(BuildContext context) => const ProjectRoleGate(title: 'Journal du projet', action: 'tenir le journal d’un projet', child: _JournalBody());
}

class _JournalBody extends ConsumerStatefulWidget {
  const _JournalBody();
  @override
  ConsumerState<_JournalBody> createState() => _JournalBodyState();
}

class _JournalBodyState extends ConsumerState<_JournalBody> with _MyProjectsLoader<_JournalBody> {
  List<Map<String, dynamic>>? steps;
  String? stepsError;

  @override
  void initState() {
    super.initState();
    loadProjects(includeMember: true);
  }

  @override
  void onProjectChanged() => _loadSteps();

  Future<void> _loadSteps() async {
    final r = await Backend.rpc('my_project_steps', {'p_project': selected});
    if (!mounted) return;
    setState(() {
      stepsError = r.error;
      steps = r.data is List ? [for (final x in r.data as List) Map<String, dynamic>.from(x as Map)] : const [];
    });
  }

  Future<void> _edit([Map<String, dynamic>? step]) async {
    final res = await showDialog<({String title, DateTime on})>(context: context, builder: (_) => _StepDialog(step: step));
    if (res == null || !mounted) return;
    final r = step == null
        ? await Backend.rpc('add_project_step', {'p_project': selected, 'p_title': res.title, 'p_on': _ymd(res.on)})
        : await Backend.rpc('project_step_update', {'p_id': step['id'], 'p_title': res.title, 'p_on': _ymd(res.on)});
    if (!mounted) return;
    if (r.error != null) return gToast(context, _err(r.error));
    gToast(context, step == null ? 'Étape ajoutée au journal.' : 'Étape modifiée.');
    _loadSteps();
  }

  Future<void> _delete(Map<String, dynamic> step) async {
    if (!await tpConfirm(context, 'Supprimer cette étape ?', '« ${step['title']} » sera retirée du journal.')) return;
    final r = await Backend.rpc('project_step_delete', {'p_id': step['id']});
    if (!mounted) return;
    if (r.error != null) return gToast(context, _err(r.error));
    _loadSteps();
  }

  @override
  Widget build(BuildContext context) {
    final l = projects;
    final s = steps;
    return TpPage(
      title: 'Journal du projet',
      subtitle: project == null ? null : '${project!['title']}',
      bottom: selected.isEmpty ? null : TpButton('Ajouter une étape', () => _edit(), icon: Icons.add_rounded),
      children: [
        if (l == null)
          l9Loading()
        else if (l.isEmpty)
          _noProject(context, 'Le journal se tient sur l’un de vos projets : créez-le d’abord, puis notez ici chaque étape réalisée.')
        else ...[
          ProjectPicker(projects: l, value: selected, onChanged: (v) => setState(() {
                selected = v;
                steps = null;
                onProjectChanged();
              })),
          const SizedBox(height: 8),
          tpNote('Ce journal est privé : il n’est visible que de l’équipe du projet et du département, jamais du public (la fiche publique affiche le champ « Étapes réalisées » du formulaire).'),
                    if (s == null)
                      l9Loading()
                    else if (stepsError != null)
                      TpEmpty(title: 'Lecture impossible', text: Backend.userMessage(stepsError!), icon: Icons.cloud_off_rounded)
          else if (s.isEmpty)
            const TpEmpty(title: 'Journal vide', text: 'Aucune étape enregistrée pour ce projet. Ajoutez la première étape réalisée.', icon: Icons.timeline_rounded)
          else
            for (final st in s)
              TpCard(
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${st['title']}', style: tpSt(14, w: FontWeight.w700, h: 1.3)),
                      const SizedBox(height: 3),
                      Text([tpDate(st['happened_on']), if ('${st['author'] ?? ''}'.isNotEmpty) '${st['author']}'].join(' · '), style: tpSt(12, c: tpGrey)),
                    ]),
                  ),
                  if (st['mine'] == true) ...[
                    IconButton(tooltip: 'Modifier', icon: const Icon(Icons.edit_outlined, color: tpGrey, size: 20), onPressed: () => _edit(st)),
                    IconButton(tooltip: 'Supprimer', icon: const Icon(Icons.delete_outline_rounded, color: tpGrey, size: 20), onPressed: () => _delete(st)),
                  ],
                ]),
              ),
        ],
      ],
    );
  }
}

class _StepDialog extends StatefulWidget {
  const _StepDialog({this.step});
  final Map<String, dynamic>? step;
  @override
  State<_StepDialog> createState() => _StepDialogState();
}

class _StepDialogState extends State<_StepDialog> {
  late final title = TextEditingController(text: '${widget.step?['title'] ?? ''}');
  late DateTime on = DateTime.tryParse('${widget.step?['happened_on']}') ?? DateTime.now();

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(widget.step == null ? 'Nouvelle étape' : 'Modifier l’étape', style: tpSt(17, w: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TpField('Étape réalisée', title, lines: 2, maxLength: 160),
          const SizedBox(height: 6),
          TpButton('Date : ${tpDate(on.toIso8601String())}', () async {
            final d = await showDatePicker(context: context, initialDate: on, firstDate: DateTime(2020), lastDate: DateTime.now());
            if (d != null) setState(() => on = d);
          }, dark: false, compact: true, icon: Icons.event_outlined),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: tpSt(14, c: tpGrey))),
          TextButton(
            onPressed: () {
              if (title.text.trim().length < 3) return gToast(context, 'Décrivez l’étape en 3 caractères au moins.');
              Navigator.pop(context, (title: title.text.trim(), on: on));
            },
            child: Text('Enregistrer', style: tpSt(14, w: FontWeight.w700)),
          ),
        ],
      );
}

// ---------------------------------------------------------------- fichiers

/// Fichiers déposés sur MES projets : dépôt, liste relue sur le serveur, ouverture et retrait.
class ProjectFilesPage extends StatelessWidget {
  const ProjectFilesPage({super.key, this.title = 'Fichiers du projet'});
  final String title;
  @override
  Widget build(BuildContext context) => ProjectRoleGate(title: title, action: 'déposer des fichiers sur un projet', child: _FilesBody(title: title));
}

class _FilesBody extends ConsumerStatefulWidget {
  const _FilesBody({required this.title});
  final String title;
  @override
  ConsumerState<_FilesBody> createState() => _FilesBodyState();
}

class _FilesBodyState extends ConsumerState<_FilesBody> with _MyProjectsLoader<_FilesBody> {
  List<Map<String, dynamic>>? files;
  String? filesError;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    loadProjects(includeMember: true);
  }

  @override
  void onProjectChanged() => _loadFiles();

  Future<void> _loadFiles() async {
    final r = await Backend.rpc('project_files_list', {'p_project': selected});
    if (!mounted) return;
    setState(() {
      filesError = r.error;
      files = r.data is List ? [for (final x in r.data as List) Map<String, dynamic>.from(x as Map)] : const [];
    });
  }

  Future<void> _add() async {
    setState(() => busy = true);
    await pickAndUpload(context, ref, 'project', selected);
    if (!mounted) return;
    setState(() => busy = false);
    _loadFiles();
  }

  Future<void> _open(Map<String, dynamic> f) async {
    final url = await Backend.signedFileUrl('project-files', '${f['path']}');
    if (!mounted) return;
    if (url == null) return gToast(context, 'Ce fichier ne peut pas être ouvert pour le moment.');
    await tpOpenUrl(context, url);
  }

  Future<void> _remove(Map<String, dynamic> f) async {
    if (!await tpConfirm(context, 'Retirer ce fichier ?', '« ${f['name']} » sera supprimé du projet.', yes: 'Retirer')) return;
    final r = await Backend.rpc('project_file_remove', {'p_file': f['id']});
    if (!mounted) return;
    if (r.error != null) return gToast(context, _err(r.error));
    Backend.removeFile('project-files', '${r.data}');
    _loadFiles();
  }

  String _size(Object? b) {
    final n = (b as num?)?.toInt() ?? 0;
    return n >= 1048576 ? '${(n / 1048576).toStringAsFixed(1)} Mo' : '${(n / 1024).ceil()} Ko';
  }

  @override
  Widget build(BuildContext context) {
    final l = projects;
    final f = files;
    return TpPage(
      title: widget.title,
      subtitle: project == null ? null : '${project!['title']}',
      bottom: selected.isEmpty ? null : TpButton(busy ? 'Dépôt…' : 'Ajouter un fichier', busy ? null : _add, icon: Icons.upload_file_rounded),
      children: [
        if (l == null)
          l9Loading()
        else if (l.isEmpty)
          _noProject(context, 'Les fichiers se déposent sur l’un de vos projets : créez-le d’abord.')
        else ...[
          ProjectPicker(projects: l, value: selected, onChanged: (v) => setState(() {
                selected = v;
                files = null;
                onProjectChanged();
              })),
          tpNote('JPG, PNG, WebP (5 Mo au plus), PDF, MP4 et ZIP (50 Mo au plus). Seuls le type et la taille sont contrôlés ; les fichiers ne sont pas analysés. Ils ne sont visibles que de l’équipe du projet et du département (50 fichiers et 500 Mo au plus par projet).'),
          const SizedBox(height: 6),
          if (f == null)
            l9Loading()
          else if (filesError != null)
            TpEmpty(title: 'Lecture impossible', text: Backend.userMessage(filesError!), icon: Icons.cloud_off_rounded)
          else if (f.isEmpty)
            const TpEmpty(title: 'Aucun fichier', text: 'Aucun fichier n’a encore été déposé sur ce projet.', icon: Icons.folder_open_rounded)
          else
            for (final x in f)
              TpCard(
                onTap: () => _open(x),
                child: Row(children: [
                  Icon('${x['mime']}'.startsWith('image/') ? Icons.image_outlined : ('${x['mime']}'.startsWith('video/') ? Icons.videocam_outlined : Icons.insert_drive_file_outlined), color: tpViolet),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${x['name']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: tpSt(13.5, w: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text([_size(x['size_bytes']), tpDate(x['created_at']), if ('${x['author'] ?? ''}'.isNotEmpty) '${x['author']}'].join(' · '), style: tpSt(12, c: tpGrey)),
                    ]),
                  ),
                  if (x['mine'] == true || !isMemberProject(project)) IconButton(tooltip: 'Retirer', icon: const Icon(Icons.delete_outline_rounded, color: tpGrey, size: 20), onPressed: () => _remove(x)),
                ]),
              ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- liens et propriété intellectuelle

/// Liens et propriété intellectuelle d'un de MES projets : enregistrés là où la fiche publique les lit.
class ProjectLinksPage extends StatelessWidget {
  const ProjectLinksPage({super.key});
  @override
  Widget build(BuildContext context) => const ProjectRoleGate(title: 'Liens et propriété intellectuelle', action: 'renseigner les liens d’un projet', child: _LinksBody());
}

class _LinksBody extends ConsumerStatefulWidget {
  const _LinksBody();
  @override
  ConsumerState<_LinksBody> createState() => _LinksBodyState();
}

class _LinksBodyState extends ConsumerState<_LinksBody> with _MyProjectsLoader<_LinksBody> {
  final prototype = TextEditingController(), demo = TextEditingController(), docs = TextEditingController(), video = TextEditingController();
  IpDeclaration ip = IpDeclaration();
  bool busy = false;

  @override
  void initState() {
    super.initState();
    loadProjects();
  }

  @override
  void dispose() {
    for (final c in [prototype, demo, docs, video]) {
      c.dispose();
    }
    ip.dispose();
    super.dispose();
  }

  @override
  void onProjectChanged() {
    final p = project;
    if (p == null) return;
    final d = p['details'] is Map ? Map<String, dynamic>.from(p['details'] as Map) : <String, dynamic>{};
    String g(String k) => '${d[k] ?? ''}';
    setState(() {
      prototype.text = g('prototype_url');
      demo.text = g('demo_url');
      docs.text = g('doc_url');
      video.text = g('video_url');
      ip.dispose();
      ip = IpDeclaration(d['ip']);
    });
  }

  Future<void> _save() async {
    final p = project;
    if (p == null) return;
    for (final c in [prototype, demo, docs, video]) {
      if (c.text.trim().isNotEmpty && !tpValidUrl(c.text)) return gToast(context, 'Un lien est invalide : il doit commencer par http:// ou https://');
    }
    final status = '${p['status']}';
    if (status == 'submitted') return gToast(context, 'Ce projet est en cours d’examen : il ne peut pas être modifié avant la décision.');
    if (status == 'approved' &&
        !await tpConfirm(context, 'Renvoyer le projet en validation ?', 'Ce projet est publié. Modifier ses liens le renverra au département : il sera retiré du catalogue public jusqu’à sa nouvelle validation.', yes: 'Enregistrer')) {
      return;
    }
    setState(() => busy = true);
    final urls = {'prototype_url': prototype.text.trim(), 'demo_url': demo.text.trim(), 'doc_url': docs.text.trim(), 'video_url': video.text.trim()};
    final r = await Backend.rpc('save_project', {
      'p_id': p['id'], 'p_title': p['title'], 'p_summary': '', 'p_department': '', 'p_submit': false,
      'p_links': {'prototype': urls['prototype_url'], 'demo': urls['demo_url'], 'docs': urls['doc_url'], 'video': urls['video_url']},
      'p_details': {...urls, 'ip': ip.toMap()},
    });
    if (!mounted) return;
    setState(() => busy = false);
    if (r.error != null) return gToast(context, _err(r.error));
    gToast(context, status == 'approved' ? 'Informations enregistrées : le projet repasse en validation.' : 'Informations du projet enregistrées.');
    loadProjects(preferred: selected);
  }

  @override
  Widget build(BuildContext context) {
    final l = projects;
    final p = project;
    final locked = p != null && '${p['status']}' == 'submitted';
    return TpPage(
      title: 'Liens et propriété intellectuelle',
      subtitle: p == null ? null : '${p['title']} · ${projectStatusLabels['${p['status']}'] ?? ''}',
      bottom: p == null || locked ? null : TpButton('Enregistrer les informations', busy ? null : _save, busy: busy),
      children: [
        if (l == null)
          l9Loading()
        else if (l.isEmpty)
          _noProject(context, 'Les liens et la propriété intellectuelle se renseignent sur l’un de vos projets : créez-le d’abord.')
        else ...[
          ProjectPicker(projects: l, value: selected, onChanged: (v) {
            selected = v;
            onProjectChanged();
          }),
          if (locked) tpNote('Ce projet est en cours d’examen : ses informations sont verrouillées jusqu’à la décision.', c: tpRed),
          IgnorePointer(
            ignoring: locked,
            child: Opacity(
              opacity: locked ? .6 : 1,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                tpSection('Liens', hint: 'Adresses commençant par http:// ou https://. Elles apparaissent sur la fiche publique du projet.'),
                TpField('Lien du prototype', prototype, keyboard: TextInputType.url, maxLength: 300),
                TpField('Lien de démonstration', demo, keyboard: TextInputType.url, maxLength: 300),
                TpField('Lien de la documentation', docs, keyboard: TextInputType.url, maxLength: 300),
                TpField('Lien de la vidéo', video, keyboard: TextInputType.url, maxLength: 300),
                tpSection('Propriété intellectuelle'),
                ...ipFormFields(ip, (v) => setState(() => ip.license = v == ip.license ? '' : v)),
              ]),
            ),
          ),
        ],
      ],
    );
  }
}
