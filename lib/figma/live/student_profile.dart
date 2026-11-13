import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../g/g_10.dart';
import '../gen.dart' show gAlert;
import '../i18n.dart' show Text;
import '../nav.dart' show gOpen;
import 'auth.dart';
import 'backend.dart';
import 'marche/marche_data.dart' show kGrey, mst;
import 'messages.dart';
import 'social_profile.dart' show SocialProfile, publicProfileProvider;
import 'talents.dart' show askText;

/// Profil d'une autre personne (par exemple un étudiant ouvert depuis « Rechercher des talents ») : c'est l'écran 10 du Figma, le même
/// dessin que le profil de chacun, avec le contenu de cette personne. Aucune page supplémentaire.
class StudentProfileScreen extends ConsumerWidget {
  const StudentProfileScreen({super.key, required this.userId});
  final String userId;

  Future<void> _message(BuildContext context, WidgetRef ref, SocialProfile p) async {
    if (!await requireLogin(context, ref, 'écrire à une personne') || !context.mounted) return;
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
    final async = ref.watch(publicProfileProvider(userId));
    return async.when(
      loading: () => const Scaffold(backgroundColor: Color(0xFFF7F4FA), body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(backgroundColor: const Color(0xFFF7F4FA), appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, foregroundColor: Colors.black), body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Ce profil est introuvable pour le moment.', textAlign: TextAlign.center, style: mst(14, c: kGrey))))),
      data: (p) {
        final acc = Account(
          name: p.name,
          phone: '',
          email: '',
          password: '',
          role: p.role == 'company' ? 2 : (p.role == 'student' ? 1 : 0),
          city: p.city,
          institution: p.institution,
          department: p.department,
          bio: p.bio,
          skills: p.skills,
          avatarUrl: p.avatarUrl,
          certification: p.certified ? 'approved' : 'none',
          serverId: p.id,
        );
        return ProviderScope(
          overrides: [profileAccountProvider.overrideWithValue(acc)],
          child: G_10(viewProfile: p, onPrimary: () => _message(context, ref, p)),
        );
      },
    );
  }
}
