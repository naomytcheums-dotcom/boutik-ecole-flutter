import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../gen.dart' show gAlert;
import '../i18n.dart' show Text;
import '../nav.dart' show gOpen;
import 'auth.dart';
import 'backend.dart';
import 'l8_common.dart';
import 'messages.dart';
import 'talents.dart' show askText;

/// Écrire à une personne depuis un écran (mentor accepté, étudiant accompagné, recruteur) : vraie conversation directe, ouverte ensuite dans la messagerie.
Future<void> l8WriteTo(BuildContext context, WidgetRef ref, String userId, String name, {String need = 'écrire à une personne'}) async {
  if (userId.isEmpty) return;
  if (!await requireLogin(context, ref, need) || !context.mounted) return;
  final text = await askText(context, title: 'Écrire à $name', body: 'Votre message ouvre une conversation directe.', hint: 'Bonjour…', ok: 'Envoyer', min: 1);
  if (text == null || !context.mounted) return;
  final r = await Backend.startDirectConversation(userId, text.trim());
  if (!context.mounted) return;
  if (r.error != null || r.id == null) return gAlert(context, 'Message non envoyé', r.error ?? 'Le message n’a pas pu être envoyé.');
  ref.read(selectedConversationProvider.notifier).set(r.id!);
  await ref.read(conversationsProvider.notifier).refresh();
  if (context.mounted) gOpen(context, '53');
}

/// Écran 77 (profil de mentor) en production : il n'existe pas de faux profil. L'identifiant du mentor choisi (`?mentor=…`) ouvre sa vraie fiche, sinon l'annuaire des mentors.
class MentorEntryRedirect extends StatefulWidget {
  const MentorEntryRedirect({super.key});

  @override
  State<MentorEntryRedirect> createState() => _MentorEntryRedirectState();
}

class _MentorEntryRedirectState extends State<MentorEntryRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final router = GoRouter.maybeOf(context);
      if (router == null || !mounted) return;
      final id = (router.routeInformationProvider.value.uri.queryParameters['mentor'] ?? '').trim();
      router.pushReplacement(id.isEmpty ? '/mentors' : '/mentors/$id');
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: const Color(0xFFF4EFE6), body: Center(child: Text('Ouverture des mentors…', style: l8St(13, c: l8Grey))));
}
