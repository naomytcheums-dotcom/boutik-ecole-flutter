import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../gen.dart' show gToast;
import '../../i18n.dart' show Text;
import '../backend.dart';
import 'marche_data.dart';
import 'marche_widgets.dart';

/// Tarifs de livraison par ville. Chaque vendeur fixe les siens (ex. Yaoundé : 1 000 FCFA, Bafoussam : 10 000 FCFA, ou 0 pour une livraison gratuite) ;
/// l'administrateur fixe ceux de la plateforme, utilisés quand un vendeur n'a pas de tarif pour la ville du client.
/// Sans tarif pour une ville, la livraison vers cette ville n'est pas proposée par ce vendeur.

final marcheDeliveryZonesProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, bool>((ref, platform) async {
  final r = await marcheCall('my_delivery_zones', {'p_platform': platform});
  if (r.error != null) throw MarcheException(r.error);
  return [for (final x in (r.data as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
});

class LivraisonTarifsScreen extends ConsumerWidget {
  const LivraisonTarifsScreen({super.key, this.platform = false});

  /// Vrai : tarifs de la plateforme (administrateur) ; faux : tarifs du vendeur connecté.
  final bool platform;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final to = TextEditingController(), fee = TextEditingController(), from = TextEditingController();
    InputDecoration deco(String l, {String? hint}) => InputDecoration(labelText: l, hintText: hint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)));
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(c).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Nouveau tarif de livraison', style: mst(18, w: FontWeight.w800)),
            const SizedBox(height: 14),
            TextField(controller: to, decoration: deco('Ville de livraison', hint: 'Ex. Yaoundé, Bafoussam')),
            const SizedBox(height: 12),
            TextField(controller: fee, keyboardType: TextInputType.number, decoration: deco('Frais (FCFA)', hint: '0 pour une livraison gratuite')),
            const SizedBox(height: 12),
            TextField(controller: from, decoration: deco('Depuis la ville (facultatif)', hint: 'Ex. Douala ; vide : depuis toutes les villes')),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: mButton('Annuler', () => Navigator.pop(c, false), dark: false)),
              const SizedBox(width: 12),
              Expanded(child: mButton('Enregistrer', () => Navigator.pop(c, true))),
            ]),
          ]),
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final r = await marcheCall('delivery_zone_save', {
      'p_to_city': to.text,
      'p_fee': int.tryParse(fee.text.replaceAll(RegExp(r'[^0-9]'), '')),
      'p_from_city': from.text,
      'p_platform': platform,
    });
    if (!context.mounted) return;
    gToast(context, r.error != null ? Backend.userMessage('${r.error}') : 'Tarif enregistré.');
    ref.invalidate(marcheDeliveryZonesProvider(platform));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Map<String, dynamic> z) async {
    final r = await marcheCall('delivery_zone_delete', {'p_id': z['id']});
    if (!context.mounted) return;
    if (r.error != null) gToast(context, Backend.userMessage('${r.error}'));
    ref.invalidate(marcheDeliveryZonesProvider(platform));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MarchePage(
      title: platform ? 'Livraison de la plateforme' : 'Mes tarifs de livraison',
      child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            platform
                ? 'Ces tarifs s’appliquent quand un vendeur n’a pas fixé le sien pour la ville du client.'
                : 'Fixez vos frais pour chaque ville où vous livrez. Sans tarif pour une ville, vous ne livrez pas là-bas. Mettez 0 pour une livraison gratuite : elle sera indiquée au client.',
            style: mst(13, c: kGrey).copyWith(height: 1.5),
          ),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), child: mButton('Ajouter une ville', () => _add(context, ref), icon: Icons.add)),
        mAsync<List<Map<String, dynamic>>>(
          ref.watch(marcheDeliveryZonesProvider(platform)),
          (l) => l.isEmpty
              ? mNote(platform ? 'Aucun tarif de plateforme.' : 'Aucun tarif pour le moment.\nLa livraison reste proposée dans votre ville avec les frais de l’IUT.')
              : Column(children: [
                  for (final z in l)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: kLine)),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${z['to_city']}', style: mst(14.5, w: FontWeight.w800)),
                            if ('${z['from_city'] ?? ''}'.isNotEmpty) Text('Depuis ${z['from_city']}', style: mst(12, c: kGrey)),
                          ]),
                        ),
                        Text(mInt(z['fee']) == 0 ? 'Gratuit' : mFcfa(z['fee']), style: mst(14, w: FontWeight.w800, c: mInt(z['fee']) == 0 ? kGreen : kInk)),
                        IconButton(tooltip: 'Supprimer ce tarif', onPressed: () => _delete(context, ref, z), icon: const Icon(Icons.delete_outline, size: 20)),
                      ]),
                    ),
                ]),
        ),
      ]),
    );
  }
}
