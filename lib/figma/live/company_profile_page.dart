import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../gdata.dart' show gNetImage;
import '../gen.dart' show gToast;
import '../i18n.dart' show Text;
import 'auth.dart';
import 'backend.dart';
import 'coequipiers_screens.dart' show MateNavPill;
import 'company_screens.dart' show companySizes, companyStatusColor, companyStatusLabel;
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';
import 'opportunites_screens.dart' show oppKinds;
import 'share.dart' show openUrl;
import 'social_posts.dart' show uploadPostMedia;
import 'tp_ui.dart' show GlassBack;

/// Profil de l'entreprise (page « Profil » du menu) : couverture, logo, nom, secteur, présentation, chiffres et publications en cours.
/// La fiche de vérification (pièces, interlocuteur…) reste un écran à part, ouvert par « Modifier la fiche et la vérification ».

final companyProfileViewProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, owner) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final r = await marcheCall('company_profile_view', {if (owner.isNotEmpty) 'p_owner': owner});
  if (r.error != null) throw MarcheException(r.error);
  return r.data is Map ? Map<String, dynamic>.from(r.data as Map) : null;
});

class CompanyPublicProfileScreen extends ConsumerWidget {
  const CompanyPublicProfileScreen({super.key, this.owner = '', this.showNav = true});

  /// Vide : l'entreprise de la personne connectée.
  final String owner;
  final bool showNav;

  Future<void> _pickCover(BuildContext context, WidgetRef ref) async {
    final p = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp']);
    if (p.isEmpty || !context.mounted) return;
    final up = await uploadPostMedia(context, p.first);
    if (up == null || !context.mounted) return;
    final r = await marcheCall('company_cover_set', {'p_path': up.path, if (owner.isNotEmpty) 'p_owner': owner});
    if (!context.mounted) return;
    gToast(context, r.error != null ? Backend.userMessage('${r.error}') : 'Couverture mise à jour.');
    ref.invalidate(companyProfileViewProvider);
  }

  Widget _stat(String value, String label) => Expanded(
        child: Column(children: [
          Text(value, style: mst(18, w: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: mst(11, c: kGrey)),
        ]),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(companyProfileViewProvider(owner));
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4FA),
      body: Stack(children: [
        mAsync<Map<String, dynamic>?>(async, (c) {
          if (c == null) {
            return SafeArea(
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 60, 16, 130), children: [
                Icon(Icons.business_outlined, size: 56, color: kViolet.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                Text('Créez le profil de votre entreprise', textAlign: TextAlign.center, style: mst(18, w: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('Ajoutez votre nom, votre logo et votre présentation : c’est ce que les étudiants voient.', textAlign: TextAlign.center, style: mst(13, c: kGrey)),
                const SizedBox(height: 16),
                mButton('Compléter la fiche', () => context.push('/entreprise/profil'), icon: Icons.edit_outlined),
              ]),
            );
          }
          final mine = c['mine'] == true;
          final name = '${c['company_name'] ?? ''}';
          final verified = c['verified'] == true;
          final status = '${c['status'] ?? ''}';
          final cover = '${c['cover_path'] ?? ''}';
          final logo = '${c['logo_path'] ?? ''}';
          final meta = [
            if ('${c['sector'] ?? ''}'.isNotEmpty) '${c['sector']}',
            if ('${c['city'] ?? ''}'.isNotEmpty) '${c['city']}',
            if ('${c['size'] ?? ''}'.isNotEmpty) companySizes['${c['size']}'] ?? '${c['size']}',
          ];
          final offers = [for (final x in (c['offers'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
          final contests = [for (final x in (c['contests'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
          int n(String k) => (c[k] as num?)?.toInt() ?? 0;
          return ListView(padding: EdgeInsets.only(bottom: showNav ? 130 : 40), children: [
            SizedBox(
              height: 210,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned.fill(
                  bottom: 50,
                  child: cover.isEmpty
                      ? Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFCDB2F2), Color(0xFFFFC38A)])))
                      : gNetImage(Backend.postMediaUrl(cover), fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: const Color(0xFFEDE9F6))),
                ),
                Positioned(
                  top: 8,
                  left: 4,
                  child: SafeArea(child: GlassBack(onTap: () => context.canPop() ? context.pop() : context.go('/s/03'))),
                ),
                if (mine)
                  Positioned(
                    top: 8,
                    right: 12,
                    child: SafeArea(child: TextButton.icon(onPressed: () => _pickCover(context, ref), icon: const Icon(Icons.photo_camera_outlined, size: 16), label: Text('Couverture'), style: TextButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.85), foregroundColor: kInk))),
                  ),
                Positioned(
                  left: 16,
                  bottom: 0,
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4), boxShadow: const [BoxShadow(color: Color(0x29403366), blurRadius: 12, offset: Offset(0, 4))]),
                    clipBehavior: Clip.antiAlias,
                    child: logo.isEmpty ? const Icon(Icons.business, size: 38, color: kViolet) : gNetImage(Backend.postMediaUrl(logo), fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.business, size: 38, color: kViolet)),
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: mst(22, w: FontWeight.w800))),
                  if (verified) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.verified, size: 20, color: Color(0xFF2F6BFF))),
                ]),
                if (meta.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(meta.join(' · '), style: mst(13, c: kGrey))),
                if (mine && status.isNotEmpty && status != 'approved')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: GestureDetector(
                      onTap: () => context.push('/entreprise/profil'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: companyStatusColor(status).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.info_outline, size: 16, color: companyStatusColor(status)), const SizedBox(width: 6), Flexible(child: Text('${companyStatusLabel(status)} · Compléter', style: mst(12, w: FontWeight.w700, c: companyStatusColor(status))))]),
                      ),
                    ),
                  ),
                if ('${c['description'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text('${c['description']}', style: mst(13.5, c: kInk).copyWith(height: 1.5))),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if ('${c['website'] ?? ''}'.isNotEmpty) ActionChip(avatar: const Icon(Icons.language, size: 16), label: Text('Site web'), onPressed: () => openUrl(context, '${c['website']}')),
                  if (c['founded_year'] != null) Chip(label: Text('Fondée en ${c['founded_year']}')),
                ]),
              ]),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
              child: Row(children: [_stat('${offers.length}', 'Offres'), _stat('${contests.length}', 'Concours'), _stat('${n('needs_open')}', 'Besoins'), _stat('${n('recruits')}', 'Recrutés')]),
            ),
            if (mine) ...[
              Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: mButton('Modifier la fiche et la vérification', () => context.push('/entreprise/profil'), icon: Icons.edit_outlined, dark: false, width: double.infinity)),
              Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: mButton('Publier une offre', () => context.push('/opportunites/publier'), icon: Icons.add, width: double.infinity)),
            ],
            mSectionTitle('Offres en cours'),
            if (offers.isEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(mine ? 'Aucune offre publiée. Publiez un stage, un emploi ou une mission.' : 'Aucune offre pour le moment.', style: mst(13, c: kGrey))),
            for (final o in offers)
              ListTile(
                leading: const Icon(Icons.work_outline, color: kViolet),
                title: Text('${o['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: mst(14, w: FontWeight.w700)),
                subtitle: Text([oppKinds['${o['kind']}'] ?? '${o['kind']}', if ('${o['location'] ?? ''}'.isNotEmpty) '${o['location']}'].join(' · '), style: mst(12, c: kGrey)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/opportunites/${o['id']}'),
              ),
            if (contests.isNotEmpty) mSectionTitle('Concours et défis'),
            for (final a in contests)
              ListTile(
                leading: const Icon(Icons.emoji_events_outlined, color: kViolet),
                title: Text('${a['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: mst(14, w: FontWeight.w700)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/concours/${a['id']}'),
              ),
          ]);
        }),
        if (showNav) const Positioned(left: 0, right: 0, bottom: 14, child: Center(child: MateNavPill())),
      ]),
    );
  }
}
