import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gdata.dart' show gNetImage;
import '../gen.dart' show gAlert, gToast;
import '../i18n.dart' show Text;
import 'auth.dart';
import 'backend.dart';
import 'communities.dart';
import 'share.dart' show openUrl;
import 'social_posts.dart' show uploadPostMedia;

/// Communautés : pièces jointes des publications (photo, vidéo, lien) et photo + couverture du groupe.
/// Les fichiers sont déposés dans `post-media/<uid>/…` ; le serveur (migration 20261114001700) vérifie le dossier, le type et le lien.

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
const _violet = Color(0xFF5A3FE0);
const _line = Color(0xFFECE8F2);

TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

/// Vrai pour un lien web complet (https:// ou http://, sans espace, 500 caractères au plus) : mêmes règles que le serveur.
bool isValidWebLink(String s) {
  final t = s.trim();
  return t.length <= 500 && RegExp(r'^https?://[^ ]+$', caseSensitive: false).hasMatch(t);
}

/// Pièce jointe en préparation dans le formulaire de publication.
class PostAttachment {
  const PostAttachment.media({required this.kind, required this.path, this.name = ''}) : link = null;
  const PostAttachment.link(this.link)
      : kind = 'link',
        path = null,
        name = '';
  final String kind; // image, video, link
  final String? path, link;
  final String name;
  String get label => kind == 'link' ? link! : (name.isEmpty ? (kind == 'video' ? 'Vidéo' : 'Photo') : name);
}

/// Feuille « Joindre » : photo, vidéo ou lien. Renvoie la pièce jointe prête à être envoyée avec la publication, ou null.
Future<PostAttachment?> chooseAttachment(BuildContext context, WidgetRef ref) async {
  if (!await requireLogin(context, ref, 'joindre un fichier') || !context.mounted) return null;
  final what = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.all(16), child: Align(alignment: Alignment.centerLeft, child: Text('Joindre à la publication', style: _st(16, w: FontWeight.w800)))),
        ListTile(leading: const Icon(Icons.photo_outlined), title: Text('Photo'), subtitle: Text('JPG, PNG, WebP ou GIF, 50 Mo au plus'), onTap: () => Navigator.pop(c, 'image')),
        ListTile(leading: const Icon(Icons.videocam_outlined), title: Text('Vidéo'), subtitle: Text('MP4 ou MOV, 50 Mo au plus'), onTap: () => Navigator.pop(c, 'video')),
        ListTile(leading: const Icon(Icons.link), title: Text('Lien'), subtitle: Text('Une page web, un article, une vidéo en ligne'), onTap: () => Navigator.pop(c, 'link')),
      ]),
    ),
  );
  if (what == null || !context.mounted) return null;
  if (what == 'link') {
    final ctl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Ajouter un lien'),
        content: TextField(controller: ctl, keyboardType: TextInputType.url, autofocus: true, decoration: const InputDecoration(hintText: 'https://…')),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Annuler')), TextButton(onPressed: () => Navigator.pop(c, true), child: Text('Ajouter'))],
      ),
    );
    if (ok != true || !context.mounted) return null;
    if (!isValidWebLink(ctl.text)) {
      gToast(context, 'Le lien doit commencer par https:// et ne pas contenir d’espace.');
      return null;
    }
    return PostAttachment.link(ctl.text.trim());
  }
  final p = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: what == 'video' ? const ['mp4', 'mov'] : const ['jpg', 'jpeg', 'png', 'webp', 'gif']);
  if (p.isEmpty || !context.mounted) return null;
  final up = await uploadPostMedia(context, p.first);
  if (up == null) return null;
  return PostAttachment.media(kind: up.kind, path: up.path, name: p.first.name);
}

/// Aperçu de la pièce jointe sous le champ de texte, avec la croix pour la retirer.
class AttachmentChip extends StatelessWidget {
  const AttachmentChip({super.key, required this.attachment, required this.onRemove});
  final PostAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final icon = switch (attachment.kind) { 'video' => Icons.videocam_outlined, 'link' => Icons.link, _ => Icons.photo_outlined };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(color: const Color(0xFFF2EFF6), borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        Icon(icon, size: 18, color: _violet),
        const SizedBox(width: 8),
        Expanded(child: Text(attachment.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(12.5, w: FontWeight.w600))),
        IconButton(tooltip: 'Retirer la pièce jointe', icon: const Icon(Icons.close, size: 18), onPressed: onRemove),
      ]),
    );
  }
}

/// Photo, vidéo ou lien d'une publication du fil.
class PostAttachmentView extends StatelessWidget {
  const PostAttachmentView({super.key, required this.post});
  final Map<String, dynamic> post;

  @override
  Widget build(BuildContext context) {
    final path = '${post['media_path'] ?? ''}', kind = '${post['media_kind'] ?? ''}', link = '${post['link_url'] ?? ''}';
    final children = <Widget>[];
    if (path.isNotEmpty) {
      final url = Backend.postMediaUrl(path);
      if (kind == 'video') {
        children.add(GestureDetector(
          onTap: () => openUrl(context, url),
          child: Container(
            height: 160,
            margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.play_circle_fill, color: Colors.white, size: 52), const SizedBox(height: 6), Text('Lire la vidéo', style: _st(12.5, w: FontWeight.w600, c: Colors.white))]),
          ),
        ));
      } else {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 10),
          child: GestureDetector(
            onTap: () => openUrl(context, url),
            child: ClipRRect(borderRadius: BorderRadius.circular(12), child: gNetImage(url, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(height: 120, color: const Color(0xFFEDE9F6), alignment: Alignment.center, child: Text('Photo indisponible', style: _st(12, c: _grey))))),
          ),
        ));
      }
    }
    if (link.isNotEmpty) {
      children.add(GestureDetector(
        onTap: () => openUrl(context, link),
        child: Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF2EFF6), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [const Icon(Icons.link, color: _violet), const SizedBox(width: 10), Expanded(child: Text(link, maxLines: 2, overflow: TextOverflow.ellipsis, style: _st(12.5, w: FontWeight.w600, c: _violet)))]),
        ),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}

final communityImagesProvider = FutureProvider.autoDispose.family<Map<String, String>, String>((ref, id) async {
  final r = await Backend.rpc('community_images', {'p_community': id});
  if (r.error != null || r.data is! Map) return const {};
  final m = Map<String, dynamic>.from(r.data as Map);
  return {for (final k in ['logo_path', 'cover_path']) if ('${m[k] ?? ''}'.isNotEmpty) k: '${m[k]}'};
});

/// Couverture et photo du groupe, en tête de la page ; le propriétaire et les administrateurs peuvent les changer.
class CommunityBanner extends ConsumerWidget {
  const CommunityBanner({super.key, required this.community});
  final Community community;

  Future<void> _change(BuildContext context, WidgetRef ref, {required bool logo}) async {
    final p = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp']);
    if (p.isEmpty || !context.mounted) return;
    final up = await uploadPostMedia(context, p.first);
    if (up == null || !context.mounted) return;
    final r = await Backend.rpc('community_set_images', {'p_community': community.id, if (logo) 'p_logo': up.path else 'p_cover': up.path});
    if (!context.mounted) return;
    if (r.error != null) return gAlert(context, 'Changement impossible', Backend.userMessage(r.error!));
    ref.invalidate(communityImagesProvider(community.id));
    gToast(context, logo ? 'Photo du groupe mise à jour' : 'Couverture mise à jour');
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, {required bool logo}) async {
    final r = await Backend.rpc('community_set_images', {'p_community': community.id, if (logo) 'p_clear_logo': true else 'p_clear_cover': true});
    if (!context.mounted) return;
    if (r.error != null) return gAlert(context, 'Changement impossible', Backend.userMessage(r.error!));
    ref.invalidate(communityImagesProvider(community.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imgs = ref.watch(communityImagesProvider(community.id)).asData?.value ?? const <String, String>{};
    final cover = imgs['cover_path'], logo = imgs['logo_path'];
    final canEdit = community.myRole == 'owner' || community.myRole == 'admin';
    final initial = community.name.trim().isEmpty ? '?' : community.name.trim().characters.first.toUpperCase();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 110,
            width: double.infinity,
            child: cover == null
                ? Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFEEE8F3), Color(0xFFF7E6D6)])), alignment: Alignment.center, child: Icon(Icons.groups_2_outlined, size: 44, color: _violet.withValues(alpha: 0.5)))
                : gNetImage(Backend.postMediaUrl(cover), fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: const Color(0xFFEDE9F6))),
          ),
        ),
        Transform.translate(
          offset: const Offset(14, -30),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFF1EEFB), border: Border.all(color: Colors.white, width: 3)),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: logo == null ? Text(initial, style: _st(24, w: FontWeight.w800, c: _violet)) : gNetImage(Backend.postMediaUrl(logo), width: 64, fit: BoxFit.cover, errorBuilder: (_, _, _) => Text(initial, style: _st(24, w: FontWeight.w800, c: _violet))),
            ),
          ]),
        ),
        if (canEdit)
          Transform.translate(
            offset: const Offset(0, -22),
            child: Wrap(spacing: 8, runSpacing: 4, children: [
              _EditChip(label: logo == null ? 'Ajouter une photo' : 'Changer la photo', onTap: () => _change(context, ref, logo: true)),
              _EditChip(label: cover == null ? 'Ajouter une couverture' : 'Changer la couverture', onTap: () => _change(context, ref, logo: false)),
              if (logo != null) _EditChip(label: 'Retirer la photo', onTap: () => _remove(context, ref, logo: true)),
              if (cover != null) _EditChip(label: 'Retirer la couverture', onTap: () => _remove(context, ref, logo: false)),
            ]),
          )
        else
          const SizedBox(height: 0),
      ]),
    );
  }
}

class _EditChip extends StatelessWidget {
  const _EditChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _line)), child: Text(label, style: _st(12, w: FontWeight.w600))),
      );
}
