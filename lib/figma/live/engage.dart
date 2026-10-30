import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart';
import '../nav.dart';
import 'auth.dart';
import 'backend.dart';
import 'seller.dart';
import 'share.dart';
import 'store.dart';

const _st = TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, color: Color(0xFF111015));

/// Action enregistrée sur le serveur (inscription, candidature, vote, alerte, suivi, demande…).
/// Demande la connexion au moment où l'action l'exige ; un doublon est annoncé clairement, jamais ignoré en silence.
Future<bool> engageAction(BuildContext context, WidgetRef ref, String kind, String refKey,
    {Map<String, dynamic> data = const {}, required String success, String need = 'cette action', String already = 'C’est déjà enregistré pour votre compte.'}) async {
  if (!await requireLogin(context, ref, need)) return false;
  if (!Backend.ready) {
    if (context.mounted) await gAlert(context, 'Hors connexion', 'Cette action nécessite la connexion au serveur.');
    return false;
  }
  final err = await Backend.engage(kind, refKey, data);
  if (!context.mounted) return false;
  if (err != null) {
    if (err.contains('Déjà enregistré')) {
      gToast(context, already);
    } else {
      await gAlert(context, 'Action impossible', err);
    }
    return false;
  }
  gToast(context, success);
  return true;
}

/// Action qui dépend d'un service externe non encore activé : on l'explique, on ne la simule pas.
Future<void> unavailableAction(BuildContext context, String title, String why) => gAlert(context, title, why);

/// Conditions d'utilisation : l'acceptation est mémorisée pour l'inscription et, si un compte est connecté, enregistrée côté serveur.
Future<void> acceptTerms(BuildContext context, WidgetRef ref) async {
  ref.read(termsProvider.notifier).set(true);
  if (Backend.ready && Backend.currentUserId != null) {
    await Backend.engage('terms_accepted', 'cgu-2026-10', {'accepted_at': DateTime.now().toUtc().toIso8601String()});
  }
  if (context.mounted) gBack(context);
}

/// Écran 273 : demande de suppression du compte, après confirmation explicite (traitée par l'équipe, sans effacement immédiat).
Future<void> requestAccountDeletion(BuildContext context, WidgetRef ref) async {
  final ok = await gDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text('Supprimer mon compte ?', style: _st.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
      content: Text('Votre demande est transmise à l’équipe, qui supprime votre compte et vos données personnelles. Vos commandes en cours doivent être terminées au préalable.', style: _st),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Envoyer la demande')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  await engageAction(context, ref, 'account_deletion_request', 'me', success: 'Demande de suppression envoyée. L’équipe vous répondra par e-mail.', need: 'demander la suppression du compte', already: 'Une demande de suppression est déjà en cours.');
}

/// Écran 241 : invitation partagée par WhatsApp (lien réel wa.me), avec le code de parrainage de la personne.
Future<void> shareViaWhatsApp(BuildContext context, WidgetRef ref) {
  final a = ref.read(profileAccountProvider);
  final code = a.name.trim().isEmpty ? 'iut' : a.name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  final msg = 'Salut ! Rejoins Boutik-École, la marketplace des talents de l’IUT de Douala : https://boutik-ecole.vercel.app/#/s/03 (code $code)';
  return openUrl(context, 'https://wa.me/?text=${Uri.encodeComponent(msg)}');
}

/// Produit actuellement consulté, pour les alertes de disponibilité.
String viewedProductTitle(WidgetRef ref) => ref.read(selectedProductProvider).title;
