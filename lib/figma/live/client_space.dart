import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gToast;
import '../i18n.dart' show Text;
import 'auth.dart';
import 'backend.dart';
import 'marche/marche_appels.dart' show marcheLoginRequired;
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';

/// Espace personnel de la personne connectée : compteurs réels (favoris, adresses, avis, litiges et réclamations ouverts) lus par `my_client_space`.
/// `null` : aperçu hors serveur, personne de connecté, ou lecture impossible (le résumé n'affiche alors aucun chiffre inventé).
final clientSpaceProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final uid = ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  if (!Backend.ready || uid.isEmpty) return null;
  final r = await Backend.rpc('my_client_space', const {});
  return r.error == null && r.data is Map ? Map<String, dynamic>.from(r.data as Map) : null;
});

/// Avis publiés par la personne connectée (articles et boutiques), fonction serveur `my_reviews`.
final myReviewsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final r = await marcheCall('my_reviews', const {});
  if (r.error != null) throw MarcheException(r.error);
  return [for (final x in (r.data as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
});

/// « Mes avis » : ce que la personne a publié, avec la possibilité de retirer un avis. Aucune écriture sans compte (le serveur refuse l'anonyme).
class MyReviewsScreen extends ConsumerWidget {
  const MyReviewsScreen({super.key});

  Future<void> _remove(BuildContext context, WidgetRef ref, Map<String, dynamic> r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Retirer cet avis ?'),
        content: Text('Votre avis sur « ${r['title']} » ne sera plus visible. Pour un article, vous pourrez en publier un nouveau.'),
        actions: [
          TextButton(style: TextButton.styleFrom(minimumSize: const Size(48, 48)), onPressed: () => Navigator.pop(c, false), child: Text('Garder')),
          TextButton(style: TextButton.styleFrom(minimumSize: const Size(48, 48)), onPressed: () => Navigator.pop(c, true), child: Text('Retirer')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final res = await marcheCall('review_delete', {'p_kind': r['kind'], 'p_id': r['id']});
    if (!context.mounted) return;
    gToast(context, res.error != null ? Backend.userMessage('${res.error}') : 'Avis retiré.');
    ref.invalidate(myReviewsProvider);
    ref.invalidate(clientSpaceProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (Backend.ready && ref.watch(authProvider.select((a) => a.current == null))) {
      return marcheLoginRequired(context, ref, title: 'Mes avis', pour: 'voir vos avis');
    }
    return MarchePage(
      title: 'Mes avis',
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 90), children: [
        mAsync<List<Map<String, dynamic>>>(
          ref.watch(myReviewsProvider),
          (l) => l.isEmpty
              ? mNote('Vous n’avez publié aucun avis.\nAprès réception d’une commande, vous pouvez noter l’article depuis « Mes commandes ».')
              : Column(children: [
                  for (final r in l)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: kLine)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${r['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: mst(15, w: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Row(children: [
                          for (var i = 1; i <= 5; i++) Icon(i <= (r['rating'] as num? ?? 0) ? Icons.star_rounded : Icons.star_border_rounded, size: 20, color: const Color(0xFFE0A21B)),
                          const SizedBox(width: 8),
                          Flexible(child: Text(r['kind'] == 'shop' ? 'Boutique' : 'Article${r['order_number'] == null ? '' : ' · ${r['order_number']}'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: mst(12, c: kGrey))),
                        ]),
                        if ('${r['comment'] ?? ''}'.isNotEmpty) ...[const SizedBox(height: 6), Text('${r['comment']}', style: mst(13.5).copyWith(height: 1.4))],
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(child: Text('${r['created_at']}'.split('T').first, style: mst(11.5, c: kGrey))),
                          mButton('Retirer', () => _remove(context, ref, r), dark: false),
                        ]),
                      ]),
                    ),
                ]),
        ),
      ]),
    );
  }
}
