import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart';
import '../nav.dart';
import 'backend.dart';
import 'store.dart' show favoritesProvider, normText, productByTitle, selectedProductProvider;
import 'talents.dart' show talentQueryProvider;

/// Recherches des écrans 49 (aide), 179 (guide), 52 (messages), 25b (mes listes) et 104 (carte de l'innovation) :
/// chaque saisie produit un vrai résultat (articles du guide, conversations, favoris, talents) ou dit qu'il n'y en a pas.

/// Articles d'aide : chacun ouvre l'écran qui réalise l'action décrite.
const helpArticles = <(String, String, String)>[
  ('Créer et publier une annonce', 'annonce produit vendre publier stock prix photo', '58'),
  ('Suivre ma commande', 'commande suivi livraison retrait code', '45'),
  ('Annuler une commande', 'annuler commande remboursement', '45'),
  ('Retirer ma commande au kiosque', 'retrait kiosque code six chiffres borne', '45'),
  ('Payer par Mobile Money', 'paiement orange money mobile money payer', '08'),
  ('S’inscrire à un hackathon', 'hackathon concours inscription équipe', '160'),
  ('Déposer un besoin de mission', 'mission besoin devis prestataire', '191'),
  ('Compléter mon dossier', 'profil dossier certification étudiant', '10'),
  ('Parrainer un ami', 'parrainage filleul gains code', '240'),
  ('Publier un reel', 'reel vidéo publication', '250'),
  ('Changer mon mot de passe', 'mot de passe sécurité compte connexion', '15'),
  ('Contacter le support', 'support aide réclamation problème', '53'),
];

List<(String, String, String)> searchHelp(String q) {
  final n = normText(q.trim());
  if (n.length < 2) return const [];
  final words = n.split(RegExp(r'\s+')).where((w) => w.length >= 2);
  return [for (final a in helpArticles) if (words.any((w) => normText('${a.$1} ${a.$2}').contains(w))) a];
}

Future<void> _sheet(BuildContext context, String title, List<Widget> items, String empty) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          ListTile(title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
          if (items.isEmpty) ListTile(title: Text(empty)),
          ...items,
        ]),
      ),
    );

/// 49 et 179 : articles d'aide correspondants ; chacun ouvre l'écran concerné.
Future<void> helpSearch(BuildContext context, String q) async {
  if (q.trim().length < 2) return gToast(context, 'Saisissez au moins 2 caractères.');
  final r = searchHelp(q);
  await _sheet(context, 'Aide : « ${q.trim()} »', [
    for (final a in r)
      ListTile(leading: const Icon(Icons.help_outline), title: Text(a.$1), onTap: () {
        Navigator.of(context).pop();
        gOpen(context, a.$3);
      }),
  ], 'Aucun article. Écrivez au support depuis « Contacter le support ».');
}

/// 52 : conversations réelles dont l'interlocuteur ou l'annonce correspond.
Future<void> conversationSearch(BuildContext context, String q) async {
  if (q.trim().length < 2) return gToast(context, 'Saisissez au moins 2 caractères.');
  if (!Backend.ready) return gToast(context, 'Recherche disponible avec un compte connecté.');
  final rows = await Backend.conversations();
  if (!context.mounted) return;
  final n = normText(q.trim());
  final hits = [for (final c in rows) if (normText('${c['other_name'] ?? ''} ${c['listing_title'] ?? ''} ${c['last_body'] ?? ''}').contains(n)) c];
  await _sheet(context, 'Conversations : « ${q.trim()} »', [
    for (final c in hits)
      ListTile(leading: const Icon(Icons.chat_bubble_outline), title: Text('${c['other_name'] ?? 'Conversation'}'), subtitle: Text('${c['listing_title'] ?? ''}'), onTap: () {
        Navigator.of(context).pop();
        gOpen(context, '53');
      }),
  ], 'Aucune conversation ne correspond.');
}

/// 25b : favoris enregistrés dont le titre correspond ; chacun ouvre la fiche produit.
Future<void> favoritesSearch(BuildContext context, WidgetRef ref, String q) async {
  if (q.trim().length < 2) return gToast(context, 'Saisissez au moins 2 caractères.');
  final n = normText(q.trim());
  final hits = [for (final t in ref.read(favoritesProvider)) if (normText(t).contains(n)) t];
  await _sheet(context, 'Mes listes : « ${q.trim()} »', [
    for (final t in hits)
      ListTile(leading: const Icon(Icons.favorite_border), title: Text(t), onTap: () {
        Navigator.of(context).pop();
        ref.read(selectedProductProvider.notifier).select(productByTitle(t).title);
        gOpen(context, '05');
      }),
  ], 'Aucun favori ne correspond.');
}

/// 104 : recherche d'acteurs dans l'annuaire des talents (70).
void innovationMapSearch(BuildContext context, WidgetRef ref, String q) {
  if (q.trim().length < 2) return gToast(context, 'Saisissez au moins 2 caractères.');
  ref.read(talentQueryProvider.notifier).set(q.trim());
  gOpen(context, '70');
}
