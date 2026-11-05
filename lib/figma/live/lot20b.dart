import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth.dart';
import 'backend.dart';
import 'console.dart';
import 'entreprise.dart';
import 'store.dart';

/// Deuxième lot de 20 écrans : paramètres, partage, boutique, projets, candidatures, favoris. Données du compte ou lecture serveur
/// protégée ; chargement, état vide et erreur explicites ; aucune ligne de maquette hors démonstration.

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

/// Annonces du compte (lecture protégée) : le serveur renvoie les siennes et les publiées ; le filtre garde celles dont on est vendeur.
final myListingsProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('listings', 'title,status,category,price,created_at,seller_id', order: 'created_at'));

String _status(Object? s) => switch ('$s') { 'approved' => 'Publiée', 'draft' => 'Brouillon', 'removed' => 'Retirée', _ => '$s' };

/// Nom et adresse e-mail du compte connecté (écran 148_1).
class AccountHeader extends ConsumerWidget {
  const AccountHeader({super.key, this.width = 300});
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(authProvider.select((s) => s.current));
    if (a == null) return SizedBox(width: width, child: Text('Non connecté', style: _st(14, c: _grey)));
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(17, w: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(a.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(12.5, c: _grey)),
      ]),
    );
  }
}

/// Titre et prix du produit choisi (écran 173).
class ProductLine extends ConsumerWidget {
  const ProductLine({super.key, this.width = 260});
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(selectedProductProvider);
    return SizedBox(width: width, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(15, w: FontWeight.w700)), const SizedBox(height: 4), Text(fcfa(p.price), style: _st(12.5, c: _grey))]));
  }
}

/// Annonces dont le compte est le vendeur (écran 248 : boutique).
class MyListings extends ConsumerWidget {
  const MyListings({super.key, this.width = 342, this.height = 620});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget note(String t) => Container(width: width, height: 150, alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(t, textAlign: TextAlign.center, style: _st(13, c: _grey).copyWith(height: 1.5)));
    if (ref.watch(authProvider.select((a) => a.current == null))) return note('Connectez-vous pour voir votre boutique.');
    final all = ref.watch(myListingsProvider);
    if (all == null) return note('Chargement…');
    final uid = Backend.userId;
    final mine = [for (final r in all) if (uid != null && '${r['seller_id']}' == uid) r];
    return SizedBox(
      width: width,
      height: height,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${mine.length} annonce${mine.length > 1 ? 's' : ''}', style: _st(15, w: FontWeight.w700)),
        const SizedBox(height: 12),
        if (mine.isEmpty)
          note('Vous n’avez encore publié aucune annonce.')
        else
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: mine.length,
              separatorBuilder: (_, _) => const Divider(height: 22, color: Color(0xFFF2EFF6)),
              itemBuilder: (_, i) {
                final r = mine[i];
                return Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${r['title']}', style: _st(13.5, w: FontWeight.w700)), const SizedBox(height: 3), Text('${r['category'] ?? ''} · ${fcfa(((r['price'] as num?) ?? 0).toInt())}', style: _st(11.5, c: _grey))])),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFEEE9FF), borderRadius: BorderRadius.circular(11)), child: Text(_status(r['status']), style: _st(11, w: FontWeight.w600, c: const Color(0xFF5A3FE0)))),
                ]);
              },
            ),
          ),
      ]),
    );
  }
}

/// Produits mis en favoris par le compte (écran 25b : collections).
class FavoritesList extends ConsumerWidget {
  const FavoritesList({super.key, this.width = 342, this.height = 560});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authProvider.select((a) => a.current == null))) return SizedBox(width: width, height: 140, child: Center(child: Text('Connectez-vous pour voir vos favoris.', style: _st(13, c: _grey))));
    final favs = ref.watch(favoritesProvider);
    if (favs.isEmpty) return SizedBox(width: width, height: 140, child: Center(child: Text('Aucun favori pour le moment.\nTouchez le cœur d’un produit pour l’ajouter ici.', textAlign: TextAlign.center, style: _st(13, c: _grey).copyWith(height: 1.5))));
    return SizedBox(
      width: width,
      height: height,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: favs.length,
        separatorBuilder: (_, _) => const Divider(height: 22, color: Color(0xFFF2EFF6)),
        itemBuilder: (_, i) => Row(children: [const Icon(Icons.favorite, size: 18, color: Color(0xFFE5484D)), const SizedBox(width: 12), Expanded(child: Text(favs[i], style: _st(13.5, w: FontWeight.w600)))]),
      ),
    );
  }
}

Widget proposalsMobile({double width = 342, double height = 560}) => MobileList(
      provider: companyProposalsProvider,
      title: (r) => '${r['author']}',
      subtitle: (r) => '${r['mission']} · ${fcfa(((r['amount'] as num?) ?? 0).toInt())} · ${r['delay_days']} jours',
      trailing: (r) => proposalStatus(r['status']),
      emptyText: 'Aucune proposition reçue pour le moment.',
      width: width,
      height: height,
    );

Widget missionsMobile({double width = 342, double height = 560}) => MobileList(
      provider: companyMissionsProvider,
      title: (r) => '${r['title']}',
      subtitle: (r) => '${r['proposals']} proposition${(r['proposals'] as num?) == 1 ? '' : 's'} · publié le ${dateCourte(r['created_at'])}${'${r['team']}'.isEmpty ? '' : ' · équipe : ${r['team']}'}',
      trailing: (r) => missionStatus(r['status']),
      emptyText: 'Aucun besoin publié pour le moment.',
      width: width,
      height: height,
    );

Widget projectsMobile({double width = 342, double height = 520}) => MobileList(
      provider: projectsCatalogProvider,
      title: (r) => '${r['title']}',
      subtitle: (r) => [if ('${r['department'] ?? ''}'.isNotEmpty) '${r['department']}', '${r['summary'] ?? ''}'].where((e) => e.isNotEmpty).join(' · '),
      trailing: (r) => projectStatus(r['status']),
      emptyText: 'Aucun projet pour le moment.',
      width: width,
      height: height,
    );
