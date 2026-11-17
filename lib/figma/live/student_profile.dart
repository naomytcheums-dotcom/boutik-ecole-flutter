import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../g/g_10.dart';
import '../gen.dart' show gAlert, gToast;
import '../i18n.dart' show Text;
import '../nav.dart' show gOpen;
import 'auth.dart';
import 'backend.dart';
import 'company_public_page.dart' show CompanyPublicPage;
import 'marche/marche_data.dart' show kGrey, mst;
import 'messages.dart';
import 'social_profile.dart' show SocialProfile, publicProfileProvider;
import 'talents.dart' show askText;

/// Conversations directes ouvertes depuis un profil pendant cette session (profil → conversation ; vide = envoi en cours).
/// « Écrire » ne renvoie jamais un premier message à la même personne : il rouvre la conversation déjà créée.
class DirectChats extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => const {};
  void put(String userId, String conversationId) => state = {...state, userId: conversationId};
  void clear(String userId) => state = {...state}..remove(userId);
}

final directChatsProvider = NotifierProvider<DirectChats, Map<String, String>>(DirectChats.new);

/// Profil d'une autre personne (par exemple un étudiant ouvert depuis « Rechercher des talents ») : c'est l'écran 10 du Figma, le même
/// dessin que le profil de chacun, avec le contenu de cette personne. Aucune page supplémentaire.
class StudentProfileScreen extends ConsumerWidget {
  const StudentProfileScreen({super.key, required this.userId});
  final String userId;

  Future<void> _message(BuildContext context, WidgetRef ref, SocialProfile p) async {
    if (!await requireLogin(context, ref, 'écrire à une personne') || !context.mounted) return;
    final chats = ref.read(directChatsProvider);
    final known = chats[p.id];
    if (known != null) {
      if (known.isEmpty) return;
      ref.read(selectedConversationProvider.notifier).set(known);
      gToast(context, 'Vous avez déjà écrit à ${p.name} : la conversation est ouverte.');
      return gOpen(context, '53');
    }
    final text = await askText(context, title: 'Écrire à ${p.name}', body: 'Votre message ouvre une conversation directe.', hint: 'Bonjour…', ok: 'Envoyer', min: 1);
    if (text == null || !context.mounted) return;
    final chatsN = ref.read(directChatsProvider.notifier);
    final selectedN = ref.read(selectedConversationProvider.notifier);
    final convsN = ref.read(conversationsProvider.notifier);
    chatsN.put(p.id, '');
    final r = await Backend.startDirectConversation(p.id, text.trim());
    if (r.error != null || r.id == null) {
      chatsN.clear(p.id);
      if (context.mounted) await gAlert(context, 'Message non envoyé', r.error ?? 'Réessayez dans un instant.');
      return;
    }
    chatsN.put(p.id, r.id!);
    selectedN.set(r.id!);
    await convsN.refresh();
    if (context.mounted) gOpen(context, '53');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
    if (me.isNotEmpty && me == userId) return const G_10();
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
        Widget person() => ProviderScope(
          overrides: [profileAccountProvider.overrideWithValue(acc)],
          child: G_10(viewProfile: p, onPrimary: () => _message(context, ref, p)),
        );
        // Entreprise ou organisation : la fiche réelle (raison sociale, secteur, badge vérifié) ; sans fiche visible, le profil de la personne.
        if (p.role == 'company' || p.role == 'other') return CompanyPublicPage(ownerId: p.id, fallback: person);
        return person();
      },
    );
  }
}
