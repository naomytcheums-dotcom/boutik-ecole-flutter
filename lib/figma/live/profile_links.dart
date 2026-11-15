import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gAlert, gDialog, gToast;
import 'auth.dart' show authProvider, requireLogin;
import 'backend.dart';
import 'integrations_widgets.dart';
import 'lots.dart' show formDialog;
import 'share.dart' show openUrl;

/// Lien enregistré sur le profil (colonne `profiles.links`, au plus 12, adresse https://).
class ProfileLink {
  const ProfileLink(this.label, this.url);
  final String label, url;

  String get host => (Uri.tryParse(url)?.host ?? '').replaceFirst('www.', '').toLowerCase();

  Map<String, String> toJson() => {'label': label, 'url': url};
}

/// Liens réellement enregistrés par le titulaire (lecture de sa propre ligne de profil). Une erreur est une erreur, pas une liste vide.
final savedProfileLinksProvider = FutureProvider.autoDispose<List<ProfileLink>>((ref) async {
  final uid = ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  if (!Backend.ready || uid.isEmpty) return const [];
  final r = await Backend.rows('profiles', 'links', eq: {'id': uid}, limit: 1);
  if (r.error != null) throw StateError(r.error!);
  final raw = r.rows.isEmpty ? const [] : (r.rows.first['links'] as List? ?? const []);
  return [
    for (final l in raw)
      if (l is Map && '${l['url'] ?? ''}'.startsWith('https://')) ProfileLink('${l['label'] ?? ''}'.trim(), '${l['url']}'),
  ];
}, retry: (_, _) => null);

/// Contrôle d'un lien saisi (mêmes règles que le serveur) ; null si valide.
String? profileLinkError(String label, String url) {
  if (!RegExp(r'^https://[^\s<>"]+$').hasMatch(url) || url.length < 12 || url.length > 300) {
    return 'Une adresse commençant par https:// est attendue (12 à 300 caractères, sans espace).';
  }
  if (label.length > 60) return 'Le nom du lien ne doit pas dépasser 60 caractères.';
  return null;
}

Future<bool> _saveAll(BuildContext context, WidgetRef ref, List<ProfileLink> links, String okMessage) async {
  final r = await Backend.rpc('save_profile_links', {'p_links': [for (final l in links) l.toJson()]});
  if (!context.mounted) return false;
  if (r.error != null) {
    await gAlert(context, 'Liens non enregistrés', Backend.userMessage(r.error!));
    return false;
  }
  ref.invalidate(savedProfileLinksProvider);
  gToast(context, okMessage);
  return true;
}

Future<void> editProfileLink(BuildContext context, WidgetRef ref, List<ProfileLink> all, int index) async {
  if (!await requireLogin(context, ref, 'modifier vos liens') || !context.mounted) return;
  final cur = all[index];
  final v = await formDialog(context, 'Modifier le lien', [('Nom (portfolio, site, Drive…)', cur.label), ('Adresse https://', cur.url)], submit: 'Enregistrer');
  if (v == null || !context.mounted) return;
  final label = v[0].trim(), url = v[1].trim();
  final err = profileLinkError(label, url);
  if (err != null) return gAlert(context, 'Lien invalide', err);
  if (all.indexWhere((l) => l.url == url) case final i when i >= 0 && i != index) {
    return gAlert(context, 'Lien déjà enregistré', 'Cette adresse figure déjà dans vos liens.');
  }
  final next = [...all]..[index] = ProfileLink(label.isEmpty ? 'Lien' : label, url);
  await _saveAll(context, ref, next, 'Lien modifié.');
}

Future<void> deleteProfileLink(BuildContext context, WidgetRef ref, List<ProfileLink> all, int index) async {
  if (!await requireLogin(context, ref, 'supprimer un lien') || !context.mounted) return;
  final ok = await gDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text('Supprimer ce lien ?', style: intText(16, weight: FontWeight.w700)),
      content: Text('« ${all[index].label.isEmpty ? all[index].url : all[index].label} » ne sera plus affiché sur votre profil.', style: intText(13.5, color: kMuted, height: 1.4)),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Annuler', style: intText(13.5))),
        TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('Supprimer', style: intText(13.5, weight: FontWeight.w700, color: kBad))),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  await _saveAll(context, ref, [...all]..removeAt(index), 'Lien supprimé.');
}

({String short, Color color}) _brand(ProfileLink l) {
  final h = l.host;
  if (h.contains('instagram')) return (short: 'Ig', color: const Color(0xFFE1306C));
  if (h.contains('linkedin')) return (short: 'in', color: const Color(0xFF0A66C2));
  if (h.contains('tiktok')) return (short: 'Tk', color: const Color(0xFF111015));
  if (h.contains('github')) return (short: 'Gh', color: const Color(0xFF24292E));
  if (h.contains('facebook')) return (short: 'f', color: const Color(0xFF1877F2));
  if (h.contains('youtube')) return (short: 'Yt', color: const Color(0xFFD92D20));
  return (short: '', color: kAccent);
}

/// Icônes du profil (écran 10) : uniquement les liens réellement enregistrés, ouverts tels quels. Au plus quatre ; la liste complète
/// est dans « Mes liens et réseaux ».
class ProfileLinkIcons extends ConsumerWidget {
  const ProfileLinkIcons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final links = ref.watch(savedProfileLinksProvider);
    return links.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => Align(alignment: Alignment.centerLeft, child: Text('Liens indisponibles', style: intText(11, color: kMuted))),
      data: (list) {
        if (list.isEmpty) return Align(alignment: Alignment.centerLeft, child: Text('Aucun lien · touchez +', style: intText(11, color: kMuted)));
        return Row(children: [
          for (final l in list.take(4))
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Semantics(
                button: true,
                label: l.label.isEmpty ? l.host : '${l.label} (${l.host})',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => openUrl(context, l.url),
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: Center(
                      child: Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: _brand(l).color, borderRadius: BorderRadius.circular(8)),
                        child: _brand(l).short.isEmpty ? const Icon(Icons.link_rounded, size: 16, color: Colors.white) : Text(_brand(l).short, style: intText(10.5, weight: FontWeight.w800, color: Colors.white)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ]);
      },
    );
  }
}

/// Liens déjà enregistrés (271) : liste avec modification et suppression.
class SavedLinksList extends ConsumerWidget {
  const SavedLinksList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final links = ref.watch(savedProfileLinksProvider);
    return links.when(
      loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))),
      error: (_, _) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Expanded(child: Text('Vos liens enregistrés ne peuvent pas être lus pour le moment.', style: intText(12.5, color: kBad))),
          TextButton(onPressed: () => ref.invalidate(savedProfileLinksProvider), child: Text('Réessayer', style: intText(12.5, weight: FontWeight.w700, color: kAccent))),
        ]),
      ),
      data: (list) {
        if (list.isEmpty) return Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Aucun lien enregistré pour le moment.', style: intText(12.5, color: kMuted)));
        return Column(children: [
          for (var i = 0; i < list.length; i++)
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(list[i].label.isEmpty ? list[i].host : list[i].label, style: intText(13, weight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(list[i].url, style: intText(11.5, color: kMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
              IconButton(tooltip: 'Modifier ce lien', constraints: const BoxConstraints(minWidth: 48, minHeight: 48), icon: const Icon(Icons.edit_outlined, size: 20, color: kInk), onPressed: () => editProfileLink(context, ref, list, i)),
              IconButton(tooltip: 'Supprimer ce lien', constraints: const BoxConstraints(minWidth: 48, minHeight: 48), icon: const Icon(Icons.delete_outline, size: 20, color: kBad), onPressed: () => deleteProfileLink(context, ref, list, i)),
            ]),
          const SizedBox(height: 6),
        ]);
      },
    );
  }
}
