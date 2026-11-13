import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gAlert;
import '../nav.dart' show gOpen;
import '../i18n.dart' show Text;
import 'auth.dart';
import 'backend.dart';
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';
import 'messages.dart';
import 'profile_extras.dart';
import 'social_posts.dart' show socialAvatar;
import 'social_profile.dart' show SocialProfile, profileSubtitle, publicProfileProvider;
import 'talent_pages.dart' show PortfolioPage;
import 'talents.dart' show askText;

/// Profil étudiant vu par une entreprise (depuis « Rechercher des talents ») : identité, présentation, compétences, disponibilités,
/// langues et portfolio. Aucune donnée privée (téléphone, e-mail). Le profil du réseau social reste réservé au réseau social.
class StudentProfileScreen extends ConsumerWidget {
  const StudentProfileScreen({super.key, required this.userId});
  final String userId;

  Future<void> _message(BuildContext context, WidgetRef ref, SocialProfile p) async {
    if (!await requireLogin(context, ref, 'écrire à un étudiant') || !context.mounted) return;
    final text = await askText(context, title: 'Écrire à ${p.name}', body: 'Votre message ouvre une conversation directe.', hint: 'Bonjour…', ok: 'Envoyer', min: 1);
    if (text == null || !context.mounted) return;
    final r = await Backend.startDirectConversation(p.id, text.trim());
    if (!context.mounted) return;
    if (r.error != null) return gAlert(context, 'Message non envoyé', r.error!);
    ref.read(selectedConversationProvider.notifier).set(r.id!);
    await ref.read(conversationsProvider.notifier).refresh();
    if (context.mounted) gOpen(context, '53');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
    final async = ref.watch(publicProfileProvider(userId));
    return MarchePage(
      title: 'Profil étudiant',
      child: mAsync<SocialProfile>(async, (p) {
        final skills = [for (final s in p.skills.split(RegExp(r'[,;•\n]'))) if (s.trim().isNotEmpty) s.trim()];
        return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            socialAvatar(p.avatarUrl, p.name, 76),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: mst(19, w: FontWeight.w800))),
                  if (p.certified) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.verified, size: 18, color: Color(0xFF2F6BFF))),
                ]),
                const SizedBox(height: 2),
                Text(profileSubtitle(p), style: mst(12.5, c: kGrey)),
                if (p.city.trim().isNotEmpty) Text(p.city.trim(), style: mst(12.5, c: kGrey)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          if (p.id != me) mButton('Écrire à ${p.name.split(' ').first}', () => _message(context, ref, p), icon: Icons.chat_bubble_outline, width: double.infinity),
          const SizedBox(height: 14),
          if (p.bio.trim().isNotEmpty) ...[
            mSectionTitle('Présentation'),
            Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: Text(p.bio.trim(), style: mst(13.5, c: kInk).copyWith(height: 1.5))),
          ],
          if (skills.isNotEmpty) ...[
            mSectionTitle('Compétences'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final s in skills) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFEDE9F6), borderRadius: BorderRadius.circular(100)), child: Text(s, style: mst(12, w: FontWeight.w600))),
              ]),
            ),
          ],
          ProfileExtrasCard(userId: p.id),
          mButton('Voir le portfolio', () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PortfolioPage(userId: p.id, ownerName: p.name))), icon: Icons.folder_open_outlined, dark: false, width: double.infinity),
        ]);
      }),
    );
  }
}
