import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../gen.dart';
import 'auth.dart';
import 'backend.dart';
import 'talents.dart' show askText;

/// Données de profil réelles : référentiel des établissements et des départements, photo de profil et documents de
/// vérification (migration 20261104000100). Tout passe par le serveur : rien n'est affiché ni enregistré sans réponse du serveur.

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
const _violet = Color(0xFF5A3FE0);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

// ------------------------------------------------------------------ référentiel

class RefItem {
  const RefItem({required this.id, required this.name, this.city = '', this.kind = '', this.status = 'verified'});
  final String id, name, city, kind, status;
  bool get proposed => status == 'proposed';

  static RefItem fromRow(Map x) => RefItem(id: '${x['id']}', name: '${x['name']}', city: '${x['city'] ?? ''}', kind: '${x['kind'] ?? ''}', status: '${x['status'] ?? 'verified'}');

  String get subtitle {
    final k = switch (kind) { 'universite_etat' => 'Université d’État', 'institut' => 'Institut', 'ecole' => 'École', 'prive' => 'Établissement privé', _ => '' };
    return [if (k.isNotEmpty) k, if (city.isNotEmpty) city, if (proposed) 'en attente de validation'].join(' · ');
  }
}

Future<List<RefItem>> searchInstitutions(String q) async {
  final r = await Backend.rpc('institutions_search', {'p_query': q, 'p_limit': 60});
  if (r.error != null || r.data is! List) throw Exception(r.error ?? 'Réponse illisible');
  return [for (final x in r.data as List) RefItem.fromRow(x as Map)];
}

Future<List<RefItem>> listDepartments(String institutionId, String q) async {
  final r = await Backend.rpc('departments_list', {'p_institution': institutionId, 'p_query': q});
  if (r.error != null || r.data is! List) throw Exception(r.error ?? 'Réponse illisible');
  return [for (final x in r.data as List) RefItem.fromRow(x as Map)];
}

/// Fenêtre de sélection avec recherche. `load` interroge le serveur ; `propose` enregistre une proposition (relue par l'équipe).
Future<RefItem?> _pickRef(BuildContext context,
    {required String title, required String searchHint, required Future<List<RefItem>> Function(String q) load, required Future<RefItem?> Function(String name) propose, required String proposeLabel, required String emptyText}) {
  return showModalBottomSheet<RefItem>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => _RefSheet(title: title, searchHint: searchHint, load: load, propose: propose, proposeLabel: proposeLabel, emptyText: emptyText),
  );
}

class _RefSheet extends StatefulWidget {
  const _RefSheet({required this.title, required this.searchHint, required this.load, required this.propose, required this.proposeLabel, required this.emptyText});
  final String title, searchHint, proposeLabel, emptyText;
  final Future<List<RefItem>> Function(String q) load;
  final Future<RefItem?> Function(String name) propose;

  @override
  State<_RefSheet> createState() => _RefSheetState();
}

class _RefSheetState extends State<_RefSheet> {
  final _q = TextEditingController();
  List<RefItem>? items;
  String? error;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _run('');
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _run(String q) async {
    final my = ++_seq;
    setState(() {
      items = null;
      error = null;
    });
    try {
      final r = await widget.load(q);
      if (mounted && my == _seq) setState(() => items = r);
    } catch (_) {
      if (mounted && my == _seq) setState(() => error = 'La liste ne peut pas être chargée pour le moment. Vérifiez votre connexion.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final kb = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: kb),
      child: SizedBox(
        height: h * 0.78,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 10),
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFD9D6E0), borderRadius: BorderRadius.circular(2)))),
          Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 8), child: Text(widget.title, style: _st(18, w: FontWeight.w700))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _q,
              style: _st(15),
              textInputAction: TextInputAction.search,
              onChanged: _run,
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: const Icon(Icons.search, color: _grey),
                filled: true,
                fillColor: const Color(0xFFF4F2F8),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: error != null
                ? _note(error!)
                : items == null
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
                    : items!.isEmpty
                        ? _note(widget.emptyText)
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            itemCount: items!.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF0EDF5)),
                            itemBuilder: (_, i) {
                              final it = items![i];
                              return ListTile(
                                minVerticalPadding: 12,
                                title: Text(it.name, style: _st(15, w: FontWeight.w600)),
                                subtitle: it.subtitle.isEmpty ? null : Text(it.subtitle, style: _st(12.5, c: _grey)),
                                onTap: () => Navigator.of(context).pop(it),
                              );
                            },
                          ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)), side: const BorderSide(color: Color(0xFFCFC9DD))),
                  onPressed: () async {
                    final name = await widget.propose(_q.text.trim());
                    if (name != null && context.mounted) Navigator.of(context).pop(name);
                  },
                  child: Text(widget.proposeLabel, style: _st(14, w: FontWeight.w600, c: _violet)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _note(String t) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Text(t, textAlign: TextAlign.center, style: _st(14, c: _grey))));
}

Future<RefItem?> pickInstitution(BuildContext context) {
  if (!Backend.ready) {
    gToast(context, 'La liste des établissements nécessite la connexion au serveur.');
    return Future.value();
  }
  return _pickRef(
    context,
    title: 'Votre établissement',
    searchHint: 'Rechercher par nom ou par ville',
    load: searchInstitutions,
    proposeLabel: 'Mon établissement n’est pas dans la liste',
    emptyText: 'Aucun établissement ne correspond. Proposez le vôtre : il sera vérifié par l’équipe.',
    propose: (typed) async {
      final name = await askText(context, title: 'Proposer un établissement', body: 'Nom officiel complet de votre établissement. L’équipe le vérifie avant de le publier pour tous.', hint: 'Nom officiel', ok: 'Proposer', min: 3);
      if (name == null || !context.mounted) return null;
      final city = await askText(context, title: 'Ville', body: 'Dans quelle ville se trouve l’établissement ?', hint: 'Ville', ok: 'Envoyer', min: 2);
      if (city == null || !context.mounted) return null;
      final r = await Backend.rpc('institution_propose', {'p_name': name, 'p_city': city, 'p_kind': 'autre'});
      if (!context.mounted) return null;
      if (r.error != null) {
        await gAlert(context, 'Proposition impossible', Backend.userMessage(r.error!));
        return null;
      }
      gToast(context, 'Établissement proposé : il sera publié après vérification.');
      return RefItem(id: '${r.data}', name: name, city: city, status: 'proposed');
    },
  );
}

Future<RefItem?> pickDepartment(BuildContext context, String institutionId) {
  if (institutionId.isEmpty) {
    gToast(context, 'Choisissez d’abord votre établissement.');
    return Future.value();
  }
  return _pickRef(
    context,
    title: 'Votre département',
    searchHint: 'Rechercher un département',
    load: (q) => listDepartments(institutionId, q),
    proposeLabel: 'Mon département n’est pas dans la liste',
    emptyText: 'Aucun département n’est encore renseigné pour cet établissement. Proposez le vôtre : il sera vérifié par l’équipe.',
    propose: (typed) async {
      final name = await askText(context, title: 'Proposer un département', body: 'Nom du département, de la filière ou de la faculté.', hint: 'Nom du département', ok: 'Proposer', min: 2);
      if (name == null || !context.mounted) return null;
      final r = await Backend.rpc('department_propose', {'p_institution': institutionId, 'p_name': name});
      if (!context.mounted) return null;
      if (r.error != null) {
        await gAlert(context, 'Proposition impossible', Backend.userMessage(r.error!));
        return null;
      }
      gToast(context, 'Département proposé : il sera publié après vérification.');
      return RefItem(id: '${r.data}', name: name, status: 'proposed');
    },
  );
}

/// Champ de sélection (établissement, département) : texte choisi, ou texte d'invite ; ouvre la fenêtre de sélection au toucher.
class PickerField extends ConsumerWidget {
  const PickerField({super.key, required this.nameKey, required this.fallback, required this.placeholder, required this.onTap, this.enabled = true});
  final String nameKey, fallback, placeholder;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chosen = ref.watch(formProvider)[nameKey];
    final text = (chosen ?? fallback).trim();
    return Semantics(
      button: true,
      label: text.isEmpty ? placeholder : text,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.only(left: 52, right: 40),
          alignment: Alignment.centerLeft,
          child: Text(text.isEmpty ? placeholder : text, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(14.5, w: FontWeight.w500, c: text.isEmpty ? _grey : _ink)),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ fichiers

const maxDocBytes = 10 * 1024 * 1024;
const maxAvatarBytes = 2 * 1024 * 1024;

String? mimeFromName(String name) {
  final e = name.toLowerCase().split('.').last;
  return switch (e) { 'pdf' => 'application/pdf', 'jpg' || 'jpeg' => 'image/jpeg', 'png' => 'image/png', 'webp' => 'image/webp', _ => null };
}

/// Contrôles avant envoi : type autorisé et taille maximale. Renvoie le message d'erreur, ou null si le fichier convient.
String? checkUpload({required String name, required int size, required Set<String> mimes, required int maxBytes}) {
  final mime = mimeFromName(name);
  if (mime == null || !mimes.contains(mime)) return 'Format refusé. Formats acceptés : ${mimes.map((m) => m == 'application/pdf' ? 'PDF' : m.split('/').last.toUpperCase()).join(', ')}.';
  if (size <= 0) return 'Le fichier est vide.';
  if (size > maxBytes) return 'Fichier trop lourd : ${(maxBytes / (1024 * 1024)).round()} Mo au maximum.';
  return null;
}

String sizeLabel(int bytes) => bytes >= 1024 * 1024 ? '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} Mo' : '${(bytes / 1024).round()} Ko';

// ------------------------------------------------------------------ photo de profil

Future<void> changeProfilePhoto(BuildContext context, WidgetRef ref) async {
  if (!Backend.ready) return gToast(context, 'La photo de profil nécessite la connexion au serveur.');
  if (!await requireLogin(context, ref, 'ajouter une photo')) return;
  if (!context.mounted) return;
  final has = ref.read(profileAccountProvider).avatarUrl.isNotEmpty;
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        ListTile(leading: const Icon(Icons.photo_camera_outlined), title: Text('Prendre une photo', style: _st(15, w: FontWeight.w600)), onTap: () => Navigator.of(ctx).pop('camera')),
        ListTile(leading: const Icon(Icons.photo_library_outlined), title: Text('Choisir dans la galerie', style: _st(15, w: FontWeight.w600)), onTap: () => Navigator.of(ctx).pop('gallery')),
        if (has) ListTile(leading: const Icon(Icons.delete_outline, color: Color(0xFFC0261B)), title: Text('Supprimer la photo', style: _st(15, w: FontWeight.w600, c: const Color(0xFFC0261B))), onTap: () => Navigator.of(ctx).pop('remove')),
        const SizedBox(height: 8),
      ]),
    ),
  );
  if (choice == null || !context.mounted) return;
  if (choice == 'remove') return _setAvatar(context, ref, null);
  try {
    final x = await ImagePicker().pickImage(source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery, maxWidth: 1080, maxHeight: 1080, imageQuality: 82);
    if (x == null || !context.mounted) return;
    final bytes = await x.readAsBytes();
    final name = x.name.isEmpty ? 'photo.jpg' : x.name;
    final err = checkUpload(name: name, size: bytes.length, mimes: const {'image/jpeg', 'image/png', 'image/webp'}, maxBytes: maxAvatarBytes);
    if (err != null) return gToast(context, err);
    await _setAvatar(context, ref, (name, bytes));
  } catch (_) {
    if (context.mounted) gToast(context, choice == 'camera' ? 'Appareil photo indisponible. Autorisez l’accès ou choisissez dans la galerie.' : 'Impossible d’ouvrir la galerie. Autorisez l’accès aux photos dans les réglages.');
  }
}

Future<void> _setAvatar(BuildContext context, WidgetRef ref, (String, Uint8List)? file) async {
  final uid = Backend.userId;
  if (uid == null) return gToast(context, 'Connexion requise.');
  ref.read(uploadingProvider.notifier).start('avatar');
  try {
    if (file == null) {
      final r = await Backend.rpc('profile_set_avatar', {'p_path': '', 'p_url': ''});
      if (!context.mounted) return;
      if (r.error != null) return gToast(context, Backend.userMessage(r.error!));
      ref.read(authProvider.notifier).update(ref.read(profileAccountProvider).copyWith(avatarUrl: ''));
      return gToast(context, 'Photo supprimée');
    }
    final ext = file.$1.toLowerCase().split('.').last;
    final path = '$uid/${DateTime.now().microsecondsSinceEpoch}.${ext == 'jpeg' ? 'jpg' : ext}';
    final up = await Backend.uploadFile('avatars', path, file.$2, mimeFromName(file.$1)!);
    if (!context.mounted) return;
    if (up != null) return gToast(context, up);
    final url = Backend.publicFileUrl('avatars', path);
    final r = await Backend.rpc('profile_set_avatar', {'p_path': path, 'p_url': url});
    if (!context.mounted) return;
    if (r.error != null) {
      await Backend.removeFile('avatars', path);
      return gToast(context, Backend.userMessage(r.error!));
    }
    ref.read(authProvider.notifier).update(ref.read(profileAccountProvider).copyWith(avatarUrl: url));
    gToast(context, 'Photo de profil enregistrée');
  } finally {
    ref.read(uploadingProvider.notifier).stop('avatar');
  }
}

// ------------------------------------------------------------------ documents de vérification

class UserDoc {
  const UserDoc({required this.id, required this.kind, required this.name, required this.path, required this.size, required this.status, required this.note, required this.createdAt});
  final String id, kind, name, path, status, note;
  final int size;
  final DateTime createdAt;

  static UserDoc fromRow(Map x) => UserDoc(
        id: '${x['id']}',
        kind: '${x['kind']}',
        name: '${x['name']}',
        path: '${x['path']}',
        size: (x['size_bytes'] as num?)?.toInt() ?? 0,
        status: '${x['status']}',
        note: '${x['review_note'] ?? ''}',
        createdAt: DateTime.tryParse('${x['created_at']}') ?? DateTime.now(),
      );

  String get statusLabel => switch (status) { 'verified' => 'Vérifié', 'rejected' => 'Refusé', _ => 'En attente' };
}

/// `null` : lecture en cours ou serveur absent ; liste vide : aucun document.
class DocsNotifier extends Notifier<List<UserDoc>?> {
  @override
  List<UserDoc>? build() {
    if (!Backend.ready) return null;
    Future.microtask(refresh);
    return null;
  }

  Future<void> refresh() async {
    final uid = Backend.userId;
    if (uid == null) {
      state = const [];
      return;
    }
    final r = await Backend.rows('user_documents', 'id, kind, name, path, size_bytes, status, review_note, created_at', eq: {'owner_id': uid}, order: 'created_at', limit: 100);
    if (!ref.mounted) return;
    state = r.error == null ? [for (final x in r.rows) UserDoc.fromRow(x)] : const [];
  }
}

final myDocsProvider = NotifierProvider<DocsNotifier, List<UserDoc>?>(DocsNotifier.new);

/// Envois en cours (clé → vrai) : affichés comme « Envoi en cours… » ; le serveur ne fournit pas de pourcentage.
class UploadingNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};
  void start(String k) => state = {...state, k};
  void stop(String k) => state = {...state}..remove(k);
}

final uploadingProvider = NotifierProvider<UploadingNotifier, Set<String>>(UploadingNotifier.new);

/// Dernier document d'un type donné.
UserDoc? latestDoc(List<UserDoc>? docs, String kind) {
  if (docs == null) return null;
  final l = docs.where((d) => d.kind == kind).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return l.isEmpty ? null : l.first;
}

/// Sélection, contrôle, envoi dans le compartiment privé, puis enregistrement du document (type, nom, taille) pour la personne
/// connectée. Un document déjà envoyé pour ce type (non vérifié) est remplacé.
Future<UserDoc?> importDocument(BuildContext context, WidgetRef ref, {required String kind, bool replacePrevious = true}) async {
  if (!Backend.ready) {
    gToast(context, 'L’envoi de documents nécessite la connexion au serveur.');
    return null;
  }
  if (!await requireLogin(context, ref, 'envoyer un document') || !context.mounted) return null;
  final uid = Backend.userId;
  if (uid == null) return null;
  String name;
  Uint8List bytes;
  try {
    final r = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp']);
    if (r.isEmpty) return null;
    name = r.first.name;
    bytes = await r.first.readAsBytes();
  } catch (_) {
    if (context.mounted) gToast(context, 'Impossible d’ouvrir le sélecteur de fichiers. Autorisez l’accès aux fichiers dans les réglages.');
    return null;
  }
  if (!context.mounted) return null;
  const mimes = {'application/pdf', 'image/jpeg', 'image/png', 'image/webp'};
  final err = checkUpload(name: name, size: bytes.length, mimes: mimes, maxBytes: maxDocBytes);
  if (err != null) {
    gToast(context, err);
    return null;
  }
  final mime = mimeFromName(name)!;
  final key = 'doc:$kind';
  ref.read(uploadingProvider.notifier).start(key);
  try {
    final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    final path = '$uid/$kind/${DateTime.now().microsecondsSinceEpoch}-$safe';
    final up = await Backend.uploadFile('profile-documents', path, bytes, mime);
    if (!context.mounted) return null;
    if (up != null) {
      gToast(context, up);
      return null;
    }
    final reg = await Backend.rpc('document_register', {'p_kind': kind, 'p_path': path, 'p_name': name, 'p_mime': mime, 'p_size': bytes.length});
    if (!context.mounted) return null;
    if (reg.error != null) {
      await Backend.removeFile('profile-documents', path);
      gToast(context, Backend.userMessage(reg.error!));
      return null;
    }
    if (replacePrevious) {
      final old = latestDoc(ref.read(myDocsProvider), kind);
      if (old != null && old.status != 'verified') await removeDocument(ref, old);
    }
    await ref.read(myDocsProvider.notifier).refresh();
    if (!context.mounted) return null;
    gToast(context, 'Document envoyé : $name');
    return latestDoc(ref.read(myDocsProvider), kind);
  } finally {
    ref.read(uploadingProvider.notifier).stop(key);
  }
}

/// Suppression côté serveur (refusée pour un document déjà vérifié) puis retrait du fichier du stockage.
Future<String?> removeDocument(WidgetRef ref, UserDoc d) async {
  final r = await Backend.rpc('document_delete', {'p_id': d.id});
  if (r.error != null) return Backend.userMessage(r.error!);
  await Backend.removeFile('profile-documents', '${r.data}');
  await ref.read(myDocsProvider.notifier).refresh();
  return null;
}

Future<void> openDocument(BuildContext context, UserDoc d) async {
  final url = await Backend.signedFileUrl('profile-documents', d.path);
  if (!context.mounted) return;
  if (url == null) return gToast(context, 'Document inaccessible pour le moment.');
  if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication) && context.mounted) gToast(context, 'Impossible d’ouvrir le document.');
}

// ------------------------------------------------------------------ enregistrement du profil académique

/// Enregistre établissement, département, matricule et niveau (matricule vide accepté ; jamais généré).
Future<String?> saveAcademic(WidgetRef ref, {required String institutionId, required String departmentId, required String matricule, required String level}) async {
  final r = await Backend.rpc('profile_set_academic', {
    'p_institution': institutionId.isEmpty ? null : institutionId,
    'p_department': departmentId.isEmpty ? null : departmentId,
    'p_matricule': matricule,
    'p_level': level,
  });
  return r.error == null ? null : Backend.userMessage(r.error!);
}
