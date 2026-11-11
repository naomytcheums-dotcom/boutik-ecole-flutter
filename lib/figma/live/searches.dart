import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
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


/// Catégories du guide (179) : chaque onglet filtre les articles d'aide réels ; chaque article ouvre l'écran concerné.
const guideCategories = <String, List<String>>{
  'Débuter': ['Compléter mon dossier', 'Changer mon mot de passe', 'Parrainer un ami', 'Contacter le support'],
  'Acheter': ['Suivre ma commande', 'Annuler une commande', 'Retirer ma commande au kiosque', 'Payer par Mobile Money'],
  'Vendre': ['Créer et publier une annonce', 'Publier un reel'],
  'Opportunités': ['Déposer un besoin de mission'],
  'Hackathons': ['S’inscrire à un hackathon'],
};

class GuideBrowser extends StatefulWidget {
  const GuideBrowser({super.key});
  @override
  State<GuideBrowser> createState() => _GuideBrowserState();
}

class _GuideBrowserState extends State<GuideBrowser> {
  String _cat = guideCategories.keys.first;

  @override
  Widget build(BuildContext context) {
    final rows = [for (final t in guideCategories[_cat]!) helpArticles.firstWhere((a) => a.$1 == t)];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 42,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          children: [
            for (final c in guideCategories.keys)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(c, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _cat == c ? Colors.white : const Color(0xFF57545F))),
                  selected: _cat == c,
                  showCheckmark: false,
                  selectedColor: const Color(0xFF111015),
                  backgroundColor: const Color(0xFFF2EFF6),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                  onSelected: (_) => setState(() => _cat = c),
                ),
              ),
          ],
        ),
      ),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF2EFF6)),
          itemBuilder: (_, i) => ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFFF1EEFB), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.menu_book_outlined, size: 20, color: Color(0xFF5A3FE0))),
            title: Text(rows[i].$1, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF111015))),
            subtitle: const Text('Guide pas à pas', style: TextStyle(fontSize: 11.5, color: Color(0xFF57545F))),
            trailing: const Icon(Icons.chevron_right, color: Color(0xFF57545F)),
            onTap: () => gOpen(context, rows[i].$3),
          ),
        ),
      ),
    ]);
  }
}
