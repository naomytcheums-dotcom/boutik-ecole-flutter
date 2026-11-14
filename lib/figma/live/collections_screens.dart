import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gToast;
import '../i18n.dart' show Text;
import 'auth.dart';
import 'backend.dart';
import 'store.dart' show favoritesProvider;
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';

/// Mes collections : listes nommées de favoris, privées (le partage par lien et la publication ne sont pas encore proposés : aucune page ne les lit).
/// Tout vient du serveur (migration 20261114001600). Les produits d'une liste sont retenus par leur titre.

const collectionVisibilities = {'private': 'Privée', 'shared': 'Partagée', 'public': 'Publique'};

class ProductCollection {
  const ProductCollection({required this.id, required this.name, required this.visibility, this.items = const []});
  final String id, name, visibility;
  final List<String> items;
  factory ProductCollection.fromJson(Map<String, dynamic> j) =>
      ProductCollection(id: '${j['id']}', name: '${j['name']}', visibility: '${j['visibility']}', items: [for (final x in (j['items'] as List? ?? const [])) '$x']);
}

/// « 12 articles · Privée », « 1 article · Publique », « Vide · Partagée ».
String collectionSubtitle(ProductCollection c) =>
    '${c.items.isEmpty ? 'Vide' : c.items.length == 1 ? '1 article' : '${c.items.length} articles'} · ${collectionVisibilities[c.visibility] ?? 'Privée'}';

final collectionsProvider = FutureProvider.autoDispose<List<ProductCollection>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final r = await marcheCall('collections_list', const {});
  if (r.error != null) throw MarcheException(r.error);
  return [for (final x in (r.data as List? ?? const [])) ProductCollection.fromJson(Map<String, dynamic>.from(x as Map))];
});

Future<bool> _call(BuildContext context, String fn, Map<String, dynamic> params, {String? ok}) async {
  final r = await marcheCall(fn, params);
  if (!context.mounted) return false;
  if (r.error != null) {
    gToast(context, Backend.userMessage('${r.error}'));
    return false;
  }
  if (ok != null) gToast(context, ok);
  return true;
}

/// Crée (ou renomme) une collection : nom + visibilité. Appelée par le bouton « + » de la page et par « Créer une collection ».
Future<void> editCollection(BuildContext context, WidgetRef ref, {ProductCollection? current}) async {
  if (!await requireLogin(context, ref, 'créer une collection') || !context.mounted) return;
  final name = TextEditingController(text: current?.name ?? '');
  var vis = current?.visibility ?? 'private';
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
    builder: (c) => StatefulBuilder(
      builder: (c, setS) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(c).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(current == null ? 'Nouvelle collection' : 'Modifier la collection', style: mst(18, w: FontWeight.w800)),
          const SizedBox(height: 12),
          TextField(controller: name, autofocus: true, maxLength: 60, decoration: InputDecoration(labelText: 'Nom', hintText: 'Cadeaux d’anniversaire', border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 6),
          // Aucune page ne lit encore les collections d'autrui : seule « Privée » est proposée (une collection déjà partagée garde son état tant qu'on ne la modifie pas).
          MDropdown(label: 'Visibilité', value: vis, items: {'private': 'Privée', if (vis != 'private') vis: collectionVisibilities[vis] ?? vis}, onChanged: (v) => setS(() => vis = v)),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(vis == 'private' ? 'Vous seul la voyez. Le partage par lien sera proposé ultérieurement.' : 'Cette collection est marquée comme partagée, mais aucune page ne l’affiche encore. Privée, elle reste visible par vous seul.', style: mst(12, c: kGrey)),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: mButton('Annuler', () => Navigator.pop(c, false), dark: false)),
            const SizedBox(width: 10),
            Expanded(child: mButton(current == null ? 'Créer' : 'Enregistrer', () => Navigator.pop(c, true))),
          ]),
        ]),
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  if (await _call(context, 'collection_save', {'p_id': current?.id, 'p_name': name.text, 'p_visibility': vis}, ok: current == null ? 'Collection créée' : 'Collection modifiée')) ref.invalidate(collectionsProvider);
}

/// Contenu d'une collection : retirer un produit, ajouter parmi les favoris, modifier, supprimer.
class CollectionSheet extends ConsumerWidget {
  const CollectionSheet({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(collectionsProvider).asData?.value.where((x) => x.id == id).firstOrNull;
    if (c == null) return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
    final favs = ref.watch(favoritesProvider);
    final addable = [for (final f in favs) if (!c.items.contains(f)) f];
    Future<void> toggle(String t) async {
      if (await _call(context, 'collection_item_toggle', {'p_id': id, 'p_title': t})) ref.invalidate(collectionsProvider);
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: ListView(padding: const EdgeInsets.all(20), shrinkWrap: true, children: [
        Row(children: [
          Expanded(child: Text(c.name, style: mst(18, w: FontWeight.w800))),
          IconButton(tooltip: 'Modifier', icon: const Icon(Icons.edit_outlined), onPressed: () => editCollection(context, ref, current: c)),
          IconButton(
            tooltip: 'Supprimer',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final yes = await showDialog<bool>(
                context: context,
                builder: (d) => AlertDialog(
                  title: Text('Supprimer « ${c.name} » ?'),
                  content: Text('Les produits restent dans vos favoris : seule la liste disparaît.'),
                  actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: Text('Annuler')), TextButton(onPressed: () => Navigator.pop(d, true), child: Text('Supprimer'))],
                ),
              );
              if (yes != true || !context.mounted) return;
              if (await _call(context, 'collection_delete', {'p_id': id}, ok: 'Collection supprimée')) {
                ref.invalidate(collectionsProvider);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ]),
        Text(collectionSubtitle(c), style: mst(12.5, c: kGrey)),
        const SizedBox(height: 10),
        if (c.items.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('Cette collection est vide. Ajoutez des produits depuis vos favoris ci-dessous.', style: mst(13, c: kGrey))),
        for (final t in c.items)
          ListTile(contentPadding: EdgeInsets.zero, title: Text(t, style: mst(13.5, w: FontWeight.w600)), trailing: IconButton(tooltip: 'Retirer', icon: const Icon(Icons.remove_circle_outline), onPressed: () => toggle(t))),
        if (addable.isNotEmpty) ...[
          mSectionTitle('Ajouter depuis mes favoris'),
          for (final t in addable) ListTile(contentPadding: EdgeInsets.zero, title: Text(t, style: mst(13.5)), trailing: IconButton(tooltip: 'Ajouter', icon: const Icon(Icons.add_circle_outline), onPressed: () => toggle(t))),
        ] else if (favs.isEmpty)
          Text('Touchez le cœur d’un produit pour l’ajouter à vos favoris, puis rangez-le ici.', style: mst(12.5, c: kGrey)),
      ]),
    );
  }
}

/// Page « Mes collections » (connecté) : mes listes, bouton de création, puis tous mes favoris.
class CollectionsPanel extends ConsumerWidget {
  const CollectionsPanel({super.key, this.width = 342, this.height = 560});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (Backend.ready && ref.watch(authProvider.select((a) => a.current == null))) return SizedBox(width: width, height: 140, child: Center(child: Text('Connectez-vous pour voir vos collections.', style: mst(13, c: kGrey))));
    final cols = ref.watch(collectionsProvider);
    final favs = ref.watch(favoritesProvider);
    return SizedBox(
      width: width,
      height: height,
      child: ListView(padding: EdgeInsets.zero, children: [
        Text('Mes listes', style: mst(15, w: FontWeight.w800)),
        const SizedBox(height: 8),
        cols.when(
          loading: () => const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text(e is MarcheException ? e.toString() : marcheErrorText('$e'), style: mst(13, c: kGrey)),
          data: (rows) => Column(children: [
            if (rows.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Align(alignment: Alignment.centerLeft, child: Text('Aucune collection pour le moment.', style: mst(13, c: kGrey)))),
            for (final c in rows)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))), builder: (_) => CollectionSheet(id: c.id)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(children: [
                    Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFEFEBFA), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.collections_bookmark_outlined, color: Color(0xFF5A3FE0))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: mst(13.5, w: FontWeight.w700)), Text(collectionSubtitle(c), style: mst(11.5, c: kGrey))])),
                    const Icon(Icons.chevron_right, color: kGrey),
                  ]),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        mButton('Créer une collection', () => editCollection(context, ref), dark: false, icon: Icons.add),
        const SizedBox(height: 18),
        Text('Tous mes favoris', style: mst(15, w: FontWeight.w800)),
        const SizedBox(height: 8),
        if (favs.isEmpty) Text('Aucun favori pour le moment.\nTouchez le cœur d’un produit pour l’ajouter ici.', style: mst(13, c: kGrey).copyWith(height: 1.5)),
        for (final t in favs) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [const Icon(Icons.favorite, size: 18, color: Color(0xFFE5484D)), const SizedBox(width: 12), Expanded(child: Text(t, style: mst(13.5, w: FontWeight.w600)))])),
      ]),
    );
  }
}
