import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gToast;
import 'auth.dart';
import 'backend.dart';
import 'talent_pages.dart' show SkillCatalog;
import 'tp_ui.dart';

/// Projets et innovations : fiche complète, NON préremplie, brouillon enregistrable, modification, publication (envoi à l'établissement)
/// quand les conditions sont remplies. Les contrôles de publication sont refaits côté serveur (`project_save_full`).

const projectKinds = {'innovation': 'Innovation', 'projet': 'Projet'};
const projectProgress = {'idee': 'Idée', 'conception': 'Conception', 'prototype': 'Prototype', 'tests': 'Tests sur le terrain', 'lance': 'Lancé'};
const projectVisibility = {'public': 'Public', 'private': 'Privé (moi seul)'};
const projectStatusLabels = {'draft': 'Brouillon', 'submitted': 'En cours d’examen', 'approved': 'Publié', 'rejected': 'Refusé'};

class _Member {
  _Member([String n = '', String r = '']) : name = TextEditingController(text: n), role = TextEditingController(text: r);
  final TextEditingController name, role;
  void dispose() {
    name.dispose();
    role.dispose();
  }
}

class ProjectFormPage extends ConsumerStatefulWidget {
  const ProjectFormPage({super.key, this.existing, this.kind = 'projet'});
  final Map<String, dynamic>? existing;
  final String kind;
  @override
  ConsumerState<ProjectFormPage> createState() => _ProjectFormPageState();
}

class _ProjectFormPageState extends ConsumerState<ProjectFormPage> {
  late String kind = widget.kind, progress = '', visibility = 'public', domain = '', status = 'draft';
  String? id;
  final title = TextEditingController(), department = TextEditingController(), summary = TextEditingController(), problem = TextEditingController(), solution = TextEditingController(),
      doneSteps = TextEditingController(), objectives = TextEditingController(), prototype = TextEditingController(), demo = TextEditingController(), docs = TextEditingController(),
      videoUrl = TextEditingController(), funding = TextEditingController(), support = TextEditingController(), email = TextEditingController(), phone = TextEditingController();
  final team = <_Member>[];
  final media = <Map<String, String>>[]; // {type: image|video, path}
  final newPaths = <String>[];
  final removedPaths = <String>[];
  List<String> domains = const [];
  bool busy = false, uploading = false;

  bool get locked => status == 'submitted' || status == 'approved';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      id = '${e['id']}';
      kind = '${e['kind'] ?? 'projet'}';
      status = '${e['status']}';
      visibility = '${e['visibility'] ?? 'public'}';
      title.text = '${e['title']}';
      department.text = '${e['department'] ?? ''}';
      summary.text = '${e['summary'] ?? ''}';
      final d = e['details'] is Map ? Map<String, dynamic>.from(e['details'] as Map) : <String, dynamic>{};
      String g(String k) => '${d[k] ?? ''}';
      domain = g('domain');
      progress = g('progress');
      problem.text = g('problem');
      solution.text = g('solution');
      doneSteps.text = g('done_steps');
      objectives.text = g('objectives');
      prototype.text = g('prototype_url');
      demo.text = g('demo_url');
      docs.text = g('doc_url');
      videoUrl.text = g('video_url');
      funding.text = g('funding_xaf');
      support.text = g('support_needs');
      email.text = g('contact_email');
      phone.text = g('contact_phone');
      for (final m in (d['team'] as List? ?? const [])) {
        if (m is Map) team.add(_Member('${m['name'] ?? ''}', '${m['role'] ?? ''}'));
      }
      for (final m in (e['media'] as List? ?? const [])) {
        if (m is Map) media.add({'type': '${m['type']}', 'path': '${m['path']}'});
      }
    }
    SkillCatalog.load().then((c) {
      if (mounted) setState(() => domains = c.domains);
    });
  }

  @override
  void dispose() {
    for (final c in [title, department, summary, problem, solution, doneSteps, objectives, prototype, demo, docs, videoUrl, funding, support, email, phone]) {
      c.dispose();
    }
    for (final m in team) {
      m.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _details() => {
        'domain': domain,
        'progress': progress,
        'problem': problem.text.trim(),
        'solution': solution.text.trim(),
        'done_steps': doneSteps.text.trim(),
        'objectives': objectives.text.trim(),
        'prototype_url': prototype.text.trim(),
        'demo_url': demo.text.trim(),
        'doc_url': docs.text.trim(),
        'video_url': videoUrl.text.trim(),
        'funding_xaf': funding.text.trim(),
        'support_needs': support.text.trim(),
        'contact_email': email.text.trim(),
        'contact_phone': phone.text.trim(),
        'team': [for (final m in team) if (m.name.text.trim().isNotEmpty) {'name': m.name.text.trim(), 'role': m.role.text.trim()}],
      };

  /// Champs obligatoires pour publier (mêmes règles que le serveur) : liste des champs manquants.
  List<String> _missing() => [
        if (title.text.trim().length < 3) 'titre',
        if (summary.text.trim().length < 30) 'description (30 caractères minimum)',
        if (domain.isEmpty) 'domaine',
        if (problem.text.trim().length < 10) 'problème résolu',
        if (solution.text.trim().length < 10) 'solution proposée',
        if (progress.isEmpty) 'état d’avancement',
        if (email.text.trim().length + phone.text.trim().length < 5) 'un contact (e-mail ou téléphone)',
      ];

  String? _badLink() {
    for (final c in [prototype, demo, docs, videoUrl]) {
      if (c.text.trim().isNotEmpty && !tpValidUrl(c.text)) return 'Un lien est invalide : il doit commencer par http:// ou https://';
    }
    return null;
  }

  Future<void> _addMedia(String type) async {
    if (type == 'image' && media.where((m) => m['type'] == 'image').length >= 5) return gToast(context, '5 images au maximum.');
    if (type == 'video' && media.any((m) => m['type'] == 'video')) return gToast(context, 'Une seule vidéo : retirez l’actuelle pour la remplacer.');
    final f = await tpPickFile(context, images: type == 'image', videos: type == 'video', maxMb: 50);
    if (f == null || !mounted) return;
    setState(() => uploading = true);
    final p = await tpUpload(context, 'project-media', 'projects', f);
    if (!mounted) return;
    setState(() => uploading = false);
    if (p == null) return;
    newPaths.add(p);
    setState(() => media.add({'type': type, 'path': p}));
  }

  void _removeMedia(Map<String, String> m) {
    final p = m['path']!;
    setState(() => media.remove(m));
    if (newPaths.remove(p)) {
      Backend.removeFile('project-media', p);
    } else {
      removedPaths.add(p);
    }
  }

  Future<bool> _save({required bool publish}) async {
    if (title.text.trim().length < 3) {
      gToast(context, 'Donnez un titre d’au moins 3 caractères.');
      return false;
    }
    final bad = _badLink();
    if (bad != null) {
      gToast(context, bad);
      return false;
    }
    if (publish) {
      final m = _missing();
      if (m.isNotEmpty) {
        await showDialog<void>(
          context: context,
          builder: (d) => AlertDialog(
            backgroundColor: Colors.white,
            title: Text('Publication impossible', style: tpSt(17, w: FontWeight.w700)),
            content: Text('Complétez d’abord : ${m.join(', ')}.\n\nVous pouvez enregistrer un brouillon à tout moment.', style: tpSt(14, c: tpGrey, h: 1.45)),
            actions: [TextButton(onPressed: () => Navigator.pop(d), child: Text('Compris', style: tpSt(14, w: FontWeight.w700)))],
          ),
        );
        return false;
      }
      if (!await tpConfirm(context, 'Publier ce $kind ?', 'Il sera envoyé à votre établissement pour examen. Pendant l’examen, vous ne pourrez plus le modifier.', yes: 'Publier')) return false;
    }
    setState(() => busy = true);
    final r = await Backend.rpc('project_save_full', {
      'p_id': id, 'p_kind': kind, 'p_title': title.text.trim(), 'p_summary': summary.text.trim(), 'p_department': department.text.trim(), 'p_details': _details(),
      'p_media': media, 'p_visibility': visibility, 'p_publish': publish,
    });
    if (!mounted) return false;
    setState(() => busy = false);
    if (r.error != null) {
      gToast(context, Backend.userMessage(r.error!));
      return false;
    }
    id = '${r.data}';
    for (final p in removedPaths) {
      Backend.removeFile('project-media', p);
    }
    removedPaths.clear();
    newPaths.clear();
    if (publish) status = 'submitted';
    gToast(context, publish ? 'Envoyé pour examen. Vous serez notifié de la décision.' : 'Brouillon enregistré');
    return true;
  }

  Future<void> _delete() async {
    if (id == null) return Navigator.of(context).pop();
    if (!await tpConfirm(context, 'Supprimer ce brouillon ?', 'Cette action est définitive.')) return;
    final r = await Backend.rpc('project_delete', {'p_id': id});
    if (!mounted) return;
    if (r.error != null) return gToast(context, Backend.userMessage(r.error!));
    for (final m in media) {
      Backend.removeFile('project-media', m['path']!);
    }
    gToast(context, 'Brouillon supprimé');
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(authProvider.select((a) => a.current == null))) {
      return TpPage(title: kind == 'innovation' ? 'Déclarer une innovation' : 'Soumettre un projet', children: [
        TpEmpty(title: 'Connexion requise', text: 'Connectez-vous avec votre compte étudiant pour soumettre un projet.', action: 'Se connecter', onAction: () => requireLogin(context, ref, 'soumettre un projet')),
      ]);
    }
    final form = <Widget>[
      TpChoice('Type', projectKinds, kind, (v) => setState(() => kind = v), required: true),
      TpField('Titre', title, required: true, maxLength: 120),
      TpSelect('Domaine', domain, domains, (v) => setState(() => domain = v), required: true, customLabel: 'Autre domaine (saisir)'),
      TpField('Département ou filière', department, maxLength: 120),
      TpField('Description', summary, lines: 4, required: true, maxLength: 4000),
      TpField('Problème résolu', problem, lines: 3, required: true, maxLength: 2000),
      TpField('Solution proposée', solution, lines: 3, required: true, maxLength: 2000),
      TpChoice('État d’avancement', projectProgress, progress, (v) => setState(() => progress = v), required: true),
      TpField('Étapes réalisées (une par ligne)', doneSteps, lines: 4, maxLength: 3000),
      TpField('Objectifs', objectives, lines: 3, maxLength: 2000),
      tpSection('Équipe', hint: 'Les membres que vous citez ne sont pas notifiés automatiquement.'),
      for (var i = 0; i < team.length; i++)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 5, child: TpField('Nom du membre', team[i].name, maxLength: 80)),
          const SizedBox(width: 8),
          Expanded(flex: 4, child: TpField('Rôle', team[i].role, maxLength: 80)),
          Padding(padding: const EdgeInsets.only(top: 24, left: 4), child: IconButton(tooltip: 'Retirer ce membre', icon: const Icon(Icons.close_rounded, color: tpGrey), onPressed: () => setState(() => team.removeAt(i).dispose()))),
        ]),
      TpButton('Ajouter un membre', () => setState(() => team.add(_Member())), dark: false, compact: true, icon: Icons.person_add_alt_rounded),
      tpSection('Images et vidéo', hint: '5 images (JPG, PNG, WebP) et 1 vidéo explicative (MP4, WebM, MOV), 50 Mo maximum chacune.'),
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (final m in media)
          Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: const Color(0xFFF1EEFB), border: Border.all(color: Colors.white, width: 1.5)),
              clipBehavior: Clip.antiAlias,
              child: m['type'] == 'image'
                  ? Image.network(Backend.publicUrl('project-media', m['path']!), fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.image_outlined, color: tpViolet))
                  : const Icon(Icons.play_circle_outline_rounded, color: tpViolet, size: 36),
            ),
            Positioned(right: -6, top: -6, child: GestureDetector(onTap: () => _removeMedia(m), child: Container(width: 26, height: 26, decoration: const BoxDecoration(color: tpInk, shape: BoxShape.circle), child: const Icon(Icons.close_rounded, size: 15, color: Colors.white)))),
          ]),
      ]),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        TpButton(uploading ? 'Envoi…' : 'Ajouter une image', uploading ? null : () => _addMedia('image'), dark: false, compact: true, icon: Icons.add_photo_alternate_outlined),
        TpButton('Ajouter une vidéo', uploading ? null : () => _addMedia('video'), dark: false, compact: true, icon: Icons.videocam_outlined),
      ]),
      const SizedBox(height: 14),
      TpField('Ou lien de la vidéo explicative', videoUrl, keyboard: TextInputType.url, maxLength: 500),
      tpSection('Liens'),
      TpField('Lien du prototype', prototype, keyboard: TextInputType.url, maxLength: 500),
      TpField('Lien de démonstration', demo, keyboard: TextInputType.url, maxLength: 500),
      TpField('Lien de la documentation', docs, keyboard: TextInputType.url, maxLength: 500),
      tpSection('Besoins'),
      TpField('Besoin de financement (FCFA)', funding, keyboard: TextInputType.number, maxLength: 12, formatters: [FilteringTextInputFormatter.digitsOnly]),
      TpField('Accompagnement recherché (mentor, matériel, compétences…)', support, lines: 3, maxLength: 2000),
      tpSection('Contacts', hint: 'Au moins un moyen de contact est nécessaire pour publier.'),
      TpField('E-mail de contact', email, keyboard: TextInputType.emailAddress, maxLength: 120),
      TpField('Téléphone de contact', phone, keyboard: TextInputType.phone, maxLength: 30),
      tpSection('Visibilité et statut'),
      TpChoice('Visibilité une fois publié', projectVisibility, visibility, (v) => setState(() => visibility = v)),
      Text('Statut : ${projectStatusLabels[status] ?? status}', style: tpSt(13, w: FontWeight.w700, c: status == 'rejected' ? tpRed : tpViolet)),
      if (status == 'rejected' && '${widget.existing?['review_note'] ?? ''}'.isNotEmpty) tpNote('Motif du refus : ${widget.existing!['review_note']}', c: tpRed),
    ];
    return TpPage(
      title: kind == 'innovation' ? 'Déclarer une innovation' : 'Soumettre un projet',
      subtitle: id == null ? 'Nouvelle fiche' : projectStatusLabels[status],
      actions: [TpRound(icon: Icons.folder_open_rounded, label: 'Mes projets', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyProjectsPage())))],
      bottom: locked
          ? Text(status == 'submitted' ? 'Cette fiche est en cours d’examen : elle ne peut plus être modifiée.' : 'Cette fiche est publiée.', textAlign: TextAlign.center, style: tpSt(13, c: tpGrey))
          : Row(children: [
              Expanded(child: TpButton('Enregistrer le brouillon', busy ? null : () => _save(publish: false), dark: false, busy: busy)),
              const SizedBox(width: 10),
              Expanded(
                  child: TpButton('Publier', busy
                      ? null
                      : () async {
                          final ok = await _save(publish: true);
                          if (ok && context.mounted) Navigator.of(context).pop(true);
                        })),
            ]),
      children: [
        ...form,
        if (id != null && !locked) Padding(padding: const EdgeInsets.only(top: 16), child: TpButton('Supprimer ce brouillon', _delete, danger: true, compact: true)),
      ],
    );
  }
}

/// Mes projets et innovations : brouillons, en examen, publiés, refusés.
class MyProjectsPage extends ConsumerStatefulWidget {
  const MyProjectsPage({super.key});
  @override
  ConsumerState<MyProjectsPage> createState() => _MyProjectsPageState();
}

class _MyProjectsPageState extends ConsumerState<MyProjectsPage> {
  List<Map<String, dynamic>>? items;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = Backend.userId;
    if (uid == null) return setState(() => items = const []);
    final r = await Backend.rows('projects', 'id,kind,title,summary,department,details,media,visibility,status,review_note,updated_at', eq: {'owner_id': uid}, order: 'updated_at', limit: 100);
    if (!mounted) return;
    setState(() {
      items = r.rows;
      error = r.error;
    });
  }

  Future<void> _open([Map<String, dynamic>? p, String kind = 'projet']) async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => ProjectFormPage(existing: p, kind: kind)));
    if (ok == true || p != null) _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = items;
    return TpPage(
      title: 'Mes projets',
      bottom: Row(children: [
        Expanded(child: TpButton('Nouveau projet', () => _open(null, 'projet'), icon: Icons.add_rounded)),
        const SizedBox(width: 10),
        Expanded(child: TpButton('Innovation', () => _open(null, 'innovation'), dark: false, icon: Icons.lightbulb_outline_rounded)),
      ]),
      children: [
        if (l == null) const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
        else if (error != null) TpEmpty(title: 'Lecture impossible', text: error!, icon: Icons.cloud_off_rounded)
        else if (l.isEmpty)
          TpEmpty(title: 'Aucun projet', text: 'Décrivez votre projet ou votre innovation : vous pouvez enregistrer un brouillon et le publier quand il est prêt.', icon: Icons.lightbulb_outline_rounded)
        else
          for (final p in l)
            TpCard(
              onTap: () => _open(p),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('${p['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: tpSt(15, w: FontWeight.w700))),
                  Text(projectStatusLabels['${p['status']}'] ?? '', style: tpSt(12, w: FontWeight.w700, c: switch ('${p['status']}') { 'approved' => tpGreen, 'rejected' => tpRed, 'submitted' => const Color(0xFF8F5400), _ => tpViolet })),
                ]),
                Padding(padding: const EdgeInsets.only(top: 3), child: Text([projectKinds['${p['kind']}'] ?? 'Projet', if ('${p['department'] ?? ''}'.isNotEmpty) p['department'], tpDate(p['updated_at'])].join(' · '), style: tpSt(12, c: tpGrey))),
                if ('${p['summary'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${p['summary']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: tpSt(12.5, h: 1.4))),
                if ('${p['status']}' == 'rejected' && '${p['review_note'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Motif : ${p['review_note']}', style: tpSt(12, c: tpRed))),
              ]),
            ),
      ],
    );
  }
}
