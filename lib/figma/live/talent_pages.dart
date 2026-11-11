import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gToast;
import 'auth.dart';
import 'backend.dart';
import 'profile_data.dart';
import 'tp_ui.dart';

/// Talent Passport réel : compétences (domaine, métier, compétence, niveau, expérience, description, justificatif facultatif), documents
/// (CV, diplômes, certificats, justificatifs) et portfolio. Aucun champ n'est prérempli ; les listes s'adaptent au domaine et au métier.

const skillLevels = {'debutant': 'Débutant', 'intermediaire': 'Intermédiaire', 'avance': 'Avancé', 'expert': 'Expert'};
const _levelRank = {'debutant': .25, 'intermediaire': .5, 'avance': .75, 'expert': 1.0};

Widget _needLogin(BuildContext context, WidgetRef ref, String title, String what) => TpPage(
      title: title,
      children: [
        TpEmpty(title: 'Connexion requise', text: 'Connectez-vous pour $what.', action: 'Se connecter', onAction: () => requireLogin(context, ref, what)),
      ],
    );

bool _loggedOut(WidgetRef ref) => ref.watch(authProvider.select((a) => a.current == null));

// ------------------------------------------------------------------ catalogue

class SkillCatalog {
  SkillCatalog(this.rows);
  final List<Map<String, dynamic>> rows;
  List<String> _uniq(Iterable<String> l) => (l.where((e) => e.trim().isNotEmpty).toSet().toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())));
  List<String> get domains => _uniq(rows.map((r) => '${r['domain']}'));
  List<String> jobs(String domain) => _uniq(rows.where((r) => '${r['domain']}' == domain).map((r) => '${r['job']}'));
  List<String> skills(String domain, String job) => _uniq(rows.where((r) => '${r['domain']}' == domain && (job.isEmpty || '${r['job']}' == job)).map((r) => '${r['skill']}'));

  static Future<SkillCatalog> load() async {
    final r = await Backend.rows('skill_catalog', 'domain,job,skill', limit: 2000);
    return SkillCatalog(r.rows);
  }
}

// ------------------------------------------------------------------ liste « Mes compétences »

class SkillsPage extends ConsumerStatefulWidget {
  const SkillsPage({super.key});
  @override
  ConsumerState<SkillsPage> createState() => _SkillsPageState();
}

class _SkillsPageState extends ConsumerState<SkillsPage> {
  List<Map<String, dynamic>>? items;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = Backend.userId;
    if (uid == null) {
      setState(() => items = const []);
      return;
    }
    final r = await Backend.rows('talent_skills', 'id,domain,job,skill,level,years,description,proof_document_id', eq: {'owner_id': uid}, order: 'created_at', limit: 200);
    if (!mounted) return;
    setState(() {
      items = r.rows;
      error = r.error;
    });
  }

  Future<void> _edit([Map<String, dynamic>? s]) async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => SkillFormPage(existing: s)));
    if (ok == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> s) async {
    if (!await tpConfirm(context, 'Supprimer cette compétence ?', '« ${s['skill']} » sera retirée de votre profil.')) return;
    final r = await Backend.rpc('skill_delete', {'p_id': s['id']});
    if (!mounted) return;
    if (r.error != null) return gToast(context, Backend.userMessage(r.error!));
    gToast(context, 'Compétence supprimée');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loggedOut(ref)) return _needLogin(context, ref, 'Mes compétences', 'voir et ajouter vos compétences');
    final l = items;
    return TpPage(
      title: 'Mes compétences',
      subtitle: l == null ? null : '${l.length} compétence${l.length > 1 ? 's' : ''}',
      bottom: TpButton('Ajouter une compétence', () => _edit(), icon: Icons.add_rounded),
      children: [
        if (l == null) const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
        else if (error != null) TpEmpty(title: 'Lecture impossible', text: error!, icon: Icons.cloud_off_rounded)
        else if (l.isEmpty)
          TpEmpty(title: 'Aucune compétence', text: 'Ajoutez votre première compétence : domaine, métier, niveau et expérience. Un justificatif est facultatif.')
        else
          for (final s in l)
            TpCard(
              onTap: () => _edit(s),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('${s['skill']}', style: tpSt(15, w: FontWeight.w700))),
                  Text(skillLevels['${s['level']}'] ?? '', style: tpSt(12, w: FontWeight.w700, c: tpViolet)),
                ]),
                const SizedBox(height: 2),
                Text([s['domain'], if ('${s['job']}'.isNotEmpty) s['job']].join(' · '), style: tpSt(12, c: tpGrey)),
                const SizedBox(height: 8),
                ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: _levelRank['${s['level']}'] ?? .25, minHeight: 6, backgroundColor: const Color(0xFFE9E5F5), color: tpViolet)),
                if (s['years'] != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Expérience : ${_years(s['years'])}', style: tpSt(12, c: tpGrey))),
                if ('${s['description']}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${s['description']}', maxLines: 3, overflow: TextOverflow.ellipsis, style: tpSt(12.5, h: 1.4))),
                Row(children: [
                  if (s['proof_document_id'] != null) ...[const Icon(Icons.attach_file_rounded, size: 15, color: tpGreen), const SizedBox(width: 4), Text('Justificatif joint', style: tpSt(11.5, c: tpGreen, w: FontWeight.w600))],
                  const Spacer(),
                  TextButton(onPressed: () => _edit(s), child: Text('Modifier', style: tpSt(12.5, w: FontWeight.w700, c: tpViolet))),
                  TextButton(onPressed: () => _delete(s), child: Text('Supprimer', style: tpSt(12.5, w: FontWeight.w700, c: tpRed))),
                ]),
              ]),
            ),
      ],
    );
  }
}

String _years(Object? y) {
  final n = (y as num?)?.toDouble() ?? 0;
  if (n == 0) return 'moins d’un an';
  final t = n == n.roundToDouble() ? n.round().toString() : n.toString().replaceAll('.', ',');
  return '$t an${n > 1 ? 's' : ''}';
}

// ------------------------------------------------------------------ formulaire de compétence

class SkillFormPage extends ConsumerStatefulWidget {
  const SkillFormPage({super.key, this.existing});
  final Map<String, dynamic>? existing;
  @override
  ConsumerState<SkillFormPage> createState() => _SkillFormPageState();
}

class _SkillFormPageState extends ConsumerState<SkillFormPage> {
  SkillCatalog? cat;
  String domain = '', job = '', skill = '', level = '';
  String? proofId, proofName;
  final years = TextEditingController(), desc = TextEditingController();
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      domain = '${e['domain']}';
      job = '${e['job']}';
      skill = '${e['skill']}';
      level = '${e['level']}';
      if (e['years'] != null) years.text = '${e['years']}'.replaceAll(RegExp(r'\.0$'), '');
      desc.text = '${e['description']}';
      proofId = e['proof_document_id'] == null ? null : '${e['proof_document_id']}';
    }
    SkillCatalog.load().then((c) {
      if (mounted) setState(() => cat = c);
    });
    ref.read(myDocsProvider.notifier).refresh().then((_) {
      if (mounted && proofId != null) setState(() => proofName = ref.read(myDocsProvider)?.where((d) => d.id == proofId).map((d) => d.name).firstOrNull);
    });
  }

  @override
  void dispose() {
    years.dispose();
    desc.dispose();
    super.dispose();
  }

  Future<void> _proof() async {
    final docs = ref.read(myDocsProvider) ?? const <UserDoc>[];
    const addNew = '➕ Envoyer un nouveau fichier';
    final names = [for (final d in docs) d.name];
    final v = await tpPick(context, 'Justificatif', [addNew, ...names], allowCustom: false, current: proofName ?? '');
    if (v == null || !mounted) return;
    if (v == addNew) {
      final d = await importDocument(context, ref, kind: 'certificate', replacePrevious: false);
      if (d != null && mounted) setState(() {
        proofId = d.id;
        proofName = d.name;
      });
    } else {
      final d = docs.firstWhere((x) => x.name == v);
      setState(() {
        proofId = d.id;
        proofName = d.name;
      });
    }
  }

  Future<void> _save() async {
    final y = years.text.trim().isEmpty ? null : double.tryParse(years.text.trim().replaceAll(',', '.'));
    if (domain.isEmpty) return gToast(context, 'Choisissez un domaine.');
    if (skill.isEmpty) return gToast(context, 'Choisissez ou saisissez une compétence.');
    if (level.isEmpty) return gToast(context, 'Choisissez votre niveau.');
    if (years.text.trim().isNotEmpty && (y == null || y < 0 || y > 60)) return gToast(context, 'Expérience : nombre d’années entre 0 et 60.');
    setState(() => busy = true);
    final r = await Backend.rpc('skill_save', {
      'p_id': widget.existing?['id'], 'p_domain': domain, 'p_job': job, 'p_skill': skill, 'p_level': level,
      'p_years': y, 'p_description': desc.text.trim(), 'p_proof': proofId,
    });
    if (!mounted) return;
    setState(() => busy = false);
    if (r.error != null) return gToast(context, Backend.userMessage(r.error!));
    gToast(context, 'Compétence enregistrée');
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loggedOut(ref)) return _needLogin(context, ref, 'Ajouter une compétence', 'ajouter une compétence');
    final c = cat;
    final jobs = c == null || domain.isEmpty ? <String>[] : c.jobs(domain);
    final skills = c == null || domain.isEmpty ? <String>[] : c.skills(domain, job);
    return TpPage(
      title: widget.existing == null ? 'Ajouter une compétence' : 'Modifier la compétence',
      bottom: TpButton('Enregistrer', _save, busy: busy),
      children: [
        if (c == null) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator()),
        TpSelect('Domaine', domain, c?.domains ?? const [], (v) => setState(() {
              if (v != domain) {
                domain = v;
                job = '';
                skill = '';
              }
            }), required: true, customLabel: 'Autre domaine (saisir)'),
        TpSelect('Métier', job, jobs, (v) => setState(() {
              job = v;
              skill = '';
            }), enabled: domain.isNotEmpty, emptyHint: 'Choisissez d’abord un domaine.', customLabel: 'Autre métier (saisir)'),
        TpSelect('Compétence', skill, skills, (v) => setState(() => skill = v), required: true, enabled: domain.isNotEmpty, emptyHint: 'Choisissez d’abord un domaine.', customLabel: 'Autre compétence (saisir)'),
        tpNote('Votre domaine, métier ou compétence n’est pas dans la liste ? Choisissez « Autre » : la liste s’enrichit avec vos propositions.'),
        const SizedBox(height: 6),
        TpChoice('Niveau', skillLevels, level, (v) => setState(() => level = v), required: true),
        TpField('Expérience (années)', years, keyboard: const TextInputType.numberWithOptions(decimal: true), maxLength: 4, formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]),
        TpField('Description', desc, lines: 4, maxLength: 1000),
        const SizedBox(height: 2),
        Text('Justificatif (facultatif)', style: tpSt(12.5, w: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: TpButton(proofId == null ? 'Joindre un justificatif' : (proofName ?? 'Justificatif joint'), _proof, dark: false, icon: Icons.attach_file_rounded, compact: true),
          ),
          if (proofId != null) ...[const SizedBox(width: 8), TpRound(icon: Icons.close_rounded, label: 'Retirer le justificatif', onTap: () => setState(() {
              proofId = null;
              proofName = null;
            }))],
        ]),
        tpNote('Le justificatif est examiné par l’équipe ; il n’est jamais obligatoire pour enregistrer une compétence.'),
      ],
    );
  }
}

// ------------------------------------------------------------------ documents

const docKindLabels = {
  'cv': 'CV',
  'diploma': 'Diplômes',
  'certificate': 'Certificats et attestations',
  'student_card': 'Carte d’étudiant',
  'enrollment_certificate': 'Certificat de scolarité',
  'other': 'Autres justificatifs',
};
const _docKindSingular = {
  'cv': 'un CV', 'diploma': 'un diplôme', 'certificate': 'un certificat', 'student_card': 'une carte d’étudiant', 'enrollment_certificate': 'un certificat de scolarité', 'other': 'un justificatif',
};

class DocumentsPage extends ConsumerStatefulWidget {
  const DocumentsPage({super.key});
  @override
  ConsumerState<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends ConsumerState<DocumentsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(myDocsProvider.notifier).refresh());
  }

  Future<void> _add(String kind) async {
    await importDocument(context, ref, kind: kind, replacePrevious: false);
  }

  Future<void> _replace(UserDoc d) async {
    if (d.status == 'verified') return gToast(context, 'Un document vérifié ne peut pas être remplacé : ajoutez-en un nouveau.');
    final n = await importDocument(context, ref, kind: d.kind, replacePrevious: false);
    if (n == null || n.id == d.id || !mounted) return;
    final err = await removeDocument(ref, d);
    if (mounted && err != null) gToast(context, err);
  }

  Future<void> _delete(UserDoc d) async {
    if (d.status == 'verified') return gToast(context, 'Un document vérifié ne peut pas être supprimé.');
    if (!await tpConfirm(context, 'Supprimer ce document ?', '« ${d.name} » sera définitivement retiré de votre dossier.')) return;
    final err = await removeDocument(ref, d);
    if (mounted) gToast(context, err ?? 'Document supprimé');
  }

  @override
  Widget build(BuildContext context) {
    if (_loggedOut(ref)) return _needLogin(context, ref, 'Mes documents', 'envoyer et consulter vos documents');
    final docs = ref.watch(myDocsProvider);
    final busy = ref.watch(uploadingProvider).any((k) => k.startsWith('doc:'));
    Widget section(String kind) {
      final l = [for (final d in docs ?? const <UserDoc>[]) if (d.kind == kind) d];
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        tpSection(docKindLabels[kind]!),
        if (l.isEmpty) tpNote('Aucun document.'),
        for (final d in l)
          TpCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.description_outlined, color: tpViolet),
                const SizedBox(width: 10),
                Expanded(child: Text(d.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: tpSt(14, w: FontWeight.w600))),
                const SizedBox(width: 8),
                Text(d.statusLabel, style: tpSt(11.5, w: FontWeight.w700, c: switch (d.status) { 'verified' => tpGreen, 'rejected' => tpRed, _ => const Color(0xFF8F5400) })),
              ]),
              Padding(padding: const EdgeInsets.only(top: 4, left: 34), child: Text('${sizeLabel(d.size)} · ajouté le ${tpDate(d.createdAt.toIso8601String())}', style: tpSt(11.5, c: tpGrey))),
              if (d.status == 'rejected' && d.note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4, left: 34), child: Text('Motif : ${d.note}', style: tpSt(12, c: tpRed))),
              const SizedBox(height: 6),
              Wrap(spacing: 4, children: [
                TextButton(onPressed: () => openDocument(context, d), child: Text('Voir', style: tpSt(12.5, w: FontWeight.w700, c: tpViolet))),
                TextButton(onPressed: () => _replace(d), child: Text('Remplacer', style: tpSt(12.5, w: FontWeight.w700, c: tpViolet))),
                TextButton(onPressed: () => _delete(d), child: Text('Supprimer', style: tpSt(12.5, w: FontWeight.w700, c: tpRed))),
              ]),
            ]),
          ),
        TpButton('Ajouter ${_docKindSingular[kind]}', busy ? null : () => _add(kind), dark: false, compact: true, icon: Icons.upload_file_rounded),
      ]);
    }

    return TpPage(
      title: 'Mes documents',
      subtitle: busy ? 'Envoi en cours…' : null,
      children: [
        tpNote('Formats : PDF, JPG, PNG ou WebP, 10 Mo au maximum. Les documents vérifiés affichent un badge de confiance sur votre profil. Vos fichiers sont privés : seule l’équipe de validation peut les consulter avec vous.'),
        if (docs == null) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())) else ...[
          for (final k in const ['cv', 'diploma', 'certificate', 'other', 'student_card', 'enrollment_certificate']) section(k),
        ],
      ],
    );
  }
}

// ------------------------------------------------------------------ « Ajouter à mon profil » (écran 72)

class AddToProfilePage extends ConsumerWidget {
  const AddToProfilePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_loggedOut(ref)) return _needLogin(context, ref, 'Ajouter à mon profil', 'enrichir votre profil');
    Widget tile(IconData i, String t, String s, Widget Function() page) => TpCard(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page())),
          child: Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFF1EEFB), borderRadius: BorderRadius.circular(14)), child: Icon(i, color: tpViolet)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: tpSt(15, w: FontWeight.w700)), const SizedBox(height: 2), Text(s, style: tpSt(12, c: tpGrey, h: 1.35))])),
            const Icon(Icons.chevron_right_rounded, color: tpGrey),
          ]),
        );
    return TpPage(title: 'Ajouter à mon profil', children: [
      tile(Icons.psychology_alt_outlined, 'Une compétence', 'Domaine, métier, niveau, expérience et justificatif facultatif.', () => const SkillFormPage()),
      tile(Icons.work_outline_rounded, 'Une réalisation', 'Projet, image, vidéo ou lien à montrer dans votre portfolio.', () => const PortfolioFormPage()),
      tile(Icons.description_outlined, 'Un document', 'CV, diplôme, certificat ou autre justificatif.', () => const DocumentsPage()),
      tile(Icons.collections_bookmark_outlined, 'Mon portfolio', 'Voir, modifier et choisir l’élément phare.', () => const PortfolioPage()),
    ]);
  }
}

// ------------------------------------------------------------------ portfolio

const portfolioKinds = {'realisation': 'Réalisation', 'image': 'Image', 'video': 'Vidéo', 'link': 'Lien externe'};

/// Portfolio d'une personne ([userId] vide : le mien). Sans élément : état vide avec action d'ajout (jamais de page inexistante).
class PortfolioPage extends ConsumerStatefulWidget {
  const PortfolioPage({super.key, this.userId = '', this.ownerName = ''});
  final String userId, ownerName;
  @override
  ConsumerState<PortfolioPage> createState() => _PortfolioPageState();
}

class _PortfolioPageState extends ConsumerState<PortfolioPage> {
  List<Map<String, dynamic>>? items;
  String? error;
  bool get mine => widget.userId.isEmpty || widget.userId == Backend.userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = mine ? Backend.userId : widget.userId;
    if (uid == null) {
      setState(() => items = const []);
      return;
    }
    final r = await Backend.rows('portfolio_items', 'id,kind,title,description,category,happened_on,url,media_path,featured,created_at', eq: {'owner_id': uid}, order: 'created_at', limit: 200);
    if (!mounted) return;
    final l = [...r.rows]..sort((a, b) => (b['featured'] == true ? 1 : 0).compareTo(a['featured'] == true ? 1 : 0));
    setState(() {
      items = l;
      error = r.error;
    });
  }

  Future<void> _edit([Map<String, dynamic>? it]) async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => PortfolioFormPage(existing: it)));
    if (ok == true) _load();
  }

  Future<void> _feature(Map<String, dynamic> it) async {
    final on = it['featured'] != true;
    final r = await Backend.rpc('portfolio_save', {
      'p_id': it['id'], 'p_kind': it['kind'], 'p_title': it['title'], 'p_description': it['description'], 'p_category': it['category'], 'p_date': it['happened_on'], 'p_url': it['url'], 'p_media_path': null, 'p_featured': on,
    });
    if (!mounted) return;
    if (r.error != null) return gToast(context, Backend.userMessage(r.error!));
    gToast(context, on ? 'Élément phare défini' : 'Élément phare retiré');
    _load();
  }

  Future<void> _delete(Map<String, dynamic> it) async {
    if (!await tpConfirm(context, 'Supprimer cet élément ?', '« ${it['title']} » sera retiré de votre portfolio.')) return;
    final r = await Backend.rpc('portfolio_delete', {'p_id': it['id']});
    if (!mounted) return;
    if (r.error != null) return gToast(context, Backend.userMessage(r.error!));
    final p = '${r.data ?? ''}';
    if (p.isNotEmpty) await Backend.removeFile('portfolio-media', p);
    gToast(context, 'Élément supprimé');
    _load();
  }

  void _open(Map<String, dynamic> it) {
    final p = it['media_path'];
    if (p != null && '$p'.isNotEmpty) {
      tpOpenUrl(context, Backend.publicUrl('portfolio-media', '$p'));
    } else if ('${it['url']}'.isNotEmpty) {
      tpOpenUrl(context, '${it['url']}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = items;
    final title = mine ? 'Mon portfolio' : (widget.ownerName.isEmpty ? 'Portfolio' : 'Portfolio de ${widget.ownerName}');
    return TpPage(
      title: title,
      bottom: mine && l != null && l.isNotEmpty ? TpButton('Ajouter un élément', () => _edit(), icon: Icons.add_rounded) : null,
      children: [
        if (l == null) const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
        else if (error != null) TpEmpty(title: 'Lecture impossible', text: error!, icon: Icons.cloud_off_rounded)
        else if (l.isEmpty)
          mine
              ? TpEmpty(
                  title: 'Votre portfolio est vide',
                  text: 'Ajoutez des réalisations, des images, des vidéos ou des liens externes. Vous choisissez librement la photo ou la vidéo phare.',
                  action: 'Créer mon portfolio',
                  onAction: () => requireLogin(context, ref, 'créer votre portfolio').then((ok) {
                    if (ok && mounted) _edit();
                  }),
                  icon: Icons.collections_bookmark_outlined)
              : const TpEmpty(title: 'Aucun portfolio', text: 'Cette personne n’a pas encore ajouté de réalisation.', icon: Icons.collections_bookmark_outlined)
        else
          for (final it in l) _item(it),
      ],
    );
  }

  Widget _item(Map<String, dynamic> it) {
    final path = it['media_path'] == null ? '' : '${it['media_path']}';
    final kind = '${it['kind']}';
    final thumb = path.isNotEmpty && kind == 'image' ? Backend.publicUrl('portfolio-media', path) : '';
    return TpCard(
      onTap: () => _open(it),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (thumb.isNotEmpty)
          Padding(padding: const EdgeInsets.only(bottom: 10), child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(thumb, height: 170, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox(height: 60)))),
        Row(children: [
          Icon(switch (kind) { 'video' => Icons.play_circle_outline_rounded, 'link' => Icons.link_rounded, 'image' => Icons.image_outlined, _ => Icons.work_outline_rounded }, color: tpViolet, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text('${it['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: tpSt(15, w: FontWeight.w700))),
          if (it['featured'] == true) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFFFF1D6), borderRadius: BorderRadius.circular(100)), child: Text('Phare', style: tpSt(11, w: FontWeight.w700, c: const Color(0xFFB26A00)))),
        ]),
        Padding(padding: const EdgeInsets.only(top: 3), child: Text([portfolioKinds[kind], if ('${it['category']}'.isNotEmpty) it['category'], if ('${it['happened_on']}'.isNotEmpty) it['happened_on']].join(' · '), style: tpSt(12, c: tpGrey))),
        if ('${it['description']}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${it['description']}', maxLines: 3, overflow: TextOverflow.ellipsis, style: tpSt(12.5, h: 1.4))),
        if ('${it['url']}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${it['url']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tpSt(12, c: tpViolet, w: FontWeight.w600))),
        if (mine)
          Wrap(spacing: 2, children: [
            TextButton(onPressed: () => _feature(it), child: Text(it['featured'] == true ? 'Retirer des favoris' : 'Mettre en phare', style: tpSt(12.5, w: FontWeight.w700, c: tpViolet))),
            TextButton(onPressed: () => _edit(it), child: Text('Modifier', style: tpSt(12.5, w: FontWeight.w700, c: tpViolet))),
            TextButton(onPressed: () => _delete(it), child: Text('Supprimer', style: tpSt(12.5, w: FontWeight.w700, c: tpRed))),
          ]),
      ]),
    );
  }
}

class PortfolioFormPage extends ConsumerStatefulWidget {
  const PortfolioFormPage({super.key, this.existing});
  final Map<String, dynamic>? existing;
  @override
  ConsumerState<PortfolioFormPage> createState() => _PortfolioFormPageState();
}

class _PortfolioFormPageState extends ConsumerState<PortfolioFormPage> {
  String kind = 'realisation';
  final title = TextEditingController(), category = TextEditingController(), date = TextEditingController(), desc = TextEditingController(), url = TextEditingController();
  bool featured = false, busy = false;
  PickedFile? file;
  String? oldPath;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      kind = '${e['kind']}';
      title.text = '${e['title']}';
      category.text = '${e['category'] ?? ''}';
      date.text = '${e['happened_on'] ?? ''}';
      desc.text = '${e['description'] ?? ''}';
      url.text = '${e['url'] ?? ''}';
      featured = e['featured'] == true;
      oldPath = e['media_path'] == null ? null : '${e['media_path']}';
    }
  }

  @override
  void dispose() {
    for (final c in [title, category, date, desc, url]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick() async {
    final f = await tpPickFile(context, images: kind != 'video', videos: kind == 'video' || kind == 'realisation', maxMb: 50);
    if (f != null && mounted) setState(() => file = f);
  }

  Future<void> _save() async {
    if (title.text.trim().length < 2) return gToast(context, 'Donnez un titre à cet élément.');
    final u = url.text.trim();
    if (u.isNotEmpty && !tpValidUrl(u)) return gToast(context, 'Le lien doit commencer par http:// ou https://');
    if (kind == 'link' && u.isEmpty) return gToast(context, 'Saisissez le lien externe.');
    if ((kind == 'image' || kind == 'video') && file == null && oldPath == null && u.isEmpty) return gToast(context, 'Ajoutez un fichier ou un lien.');
    setState(() => busy = true);
    String? path;
    if (file != null) {
      path = await tpUpload(context, 'portfolio-media', 'portfolio', file!);
      if (path == null) {
        if (mounted) setState(() => busy = false);
        return;
      }
    }
    final r = await Backend.rpc('portfolio_save', {
      'p_id': widget.existing?['id'], 'p_kind': kind, 'p_title': title.text.trim(), 'p_description': desc.text.trim(), 'p_category': category.text.trim(),
      'p_date': date.text.trim(), 'p_url': u, 'p_media_path': path, 'p_featured': featured,
    });
    if (!mounted) return;
    setState(() => busy = false);
    if (r.error != null) {
      if (path != null) await Backend.removeFile('portfolio-media', path);
      return gToast(context, Backend.userMessage(r.error!));
    }
    if (path != null && oldPath != null) await Backend.removeFile('portfolio-media', oldPath!);
    gToast(context, 'Portfolio mis à jour');
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loggedOut(ref)) return _needLogin(context, ref, 'Ajouter au portfolio', 'ajouter à votre portfolio');
    final media = kind != 'link';
    return TpPage(
      title: widget.existing == null ? 'Ajouter au portfolio' : 'Modifier l’élément',
      bottom: TpButton('Enregistrer', _save, busy: busy),
      children: [
        TpChoice('Type', portfolioKinds, kind, (v) => setState(() {
              kind = v;
              file = null;
            }), required: true),
        TpField('Titre', title, required: true, maxLength: 120),
        TpField('Catégorie', category, maxLength: 80),
        TpField('Date', date, maxLength: 40),
        TpField('Description (contexte, rôle, résultats)', desc, lines: 4, maxLength: 2000),
        TpField(kind == 'link' ? 'Lien externe' : 'Lien externe (facultatif)', url, keyboard: TextInputType.url, required: kind == 'link', maxLength: 500),
        if (media) ...[
          Text(kind == 'video' ? 'Fichier vidéo (MP4, WebM, MOV — 50 Mo max.)' : 'Image ou capture (JPG, PNG, WebP — 50 Mo max.)', style: tpSt(12.5, w: FontWeight.w600)),
          const SizedBox(height: 6),
          TpButton(file != null ? file!.name : (oldPath != null ? 'Remplacer le fichier' : 'Choisir un fichier'), _pick, dark: false, icon: Icons.upload_file_rounded, compact: true),
          const SizedBox(height: 14),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: featured,
          onChanged: (v) => setState(() => featured = v),
          activeThumbColor: tpViolet,
          title: Text('Photo ou vidéo phare', style: tpSt(14, w: FontWeight.w600)),
          subtitle: Text('Mis en avant en premier dans votre portfolio.', style: tpSt(12, c: tpGrey)),
        ),
      ],
    );
  }
}
