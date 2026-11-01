import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart';
import '../nav.dart';
import 'auth.dart';
import 'backend.dart';
import 'store.dart';

/// Livraison (écrans 07, 41 ; migration 20261101000300, règles § 5) : retrait sur campus par défaut ; la livraison à domicile
/// n'est proposée que si l'administrateur l'a activée, dans la ville desservie, avec une adresse du carnet.

typedef DeliverySettings = ({bool enabled, String city, int fee});

/// Réglage lu sur le serveur ; null tant qu'il n'est pas lu (ou si la migration n'est pas appliquée) : domicile non proposé.
class DeliverySettingsNotifier extends Notifier<DeliverySettings?> {
  @override
  DeliverySettings? build() {
    if (!Backend.ready) return null;
    Future.microtask(refresh);
    return null;
  }

  Future<void> refresh() async {
    final r = await Backend.rows('institution_settings', 'home_delivery_enabled,home_delivery_city,home_delivery_fee', limit: 1);
    if (r.error != null || r.rows.isEmpty || !ref.mounted) return;
    final x = r.rows.first;
    state = (enabled: x['home_delivery_enabled'] == true, city: '${x['home_delivery_city'] ?? 'Douala'}', fee: (x['home_delivery_fee'] as num?)?.toInt() ?? 5000);
  }
}

final deliverySettingsProvider = NotifierProvider<DeliverySettingsNotifier, DeliverySettings?>(DeliverySettingsNotifier.new);

/// Adresse du carnet retenue pour la commande en cours (identifiant serveur).
final selectedAddressProvider = NotifierProvider<StrV, String>(StrV.new);

/// Frais de livraison affichés : hors serveur, ceux de la maquette ; connecté, ceux du réglage (0 si domicile non proposé).
int deliveryFee(bool home, DeliverySettings? s) => !home ? 0 : (!Backend.ready ? 5000 : (s != null && s.enabled ? s.fee : 0));

/// 07 « Livraison à domicile » : connecté, refusée tant qu'elle n'est pas activée ; sinon l'adresse est demandée (41).
void chooseHomeDelivery(BuildContext context, WidgetRef ref) {
  if (!Backend.ready) {
    ref.read(homeDeliveryProvider.notifier).set(true);
    gToast(context, 'Livraison à domicile · 5 000 FCFA');
    return;
  }
  final s = ref.read(deliverySettingsProvider);
  if (s == null || !s.enabled) {
    ref.read(homeDeliveryProvider.notifier).set(false);
    gAlert(context, 'Livraison à domicile', 'Livraison à domicile non proposée pour le moment. Votre commande sera à retirer sur campus, gratuitement, avec un code à 6 chiffres.');
    return;
  }
  ref.read(homeDeliveryProvider.notifier).set(true);
  gToast(context, 'Livraison à domicile · ${s.city} · ${fcfa(s.fee)}');
  if (ref.read(selectedAddressProvider).isEmpty) gOpen(context, '41');
}

/// 41 « Continuer » : connecté, l'adresse est enregistrée dans le carnet (save_address) puis retenue pour la commande.
Future<void> saveDeliveryAddress(BuildContext context, WidgetRef ref) async {
  if (!Backend.ready) return gOpen(context, '42');
  if (!await requireLogin(context, ref, 'enregistrer une adresse') || !context.mounted) return;
  final f = ref.read(formProvider);
  final place = (f['ad_place'] ?? '').split(RegExp(r'[·,]'));
  final city = place.first.trim();
  final district = place.length > 1 ? place.sublist(1).join(' ').trim() : '';
  final errs = <String, String>{
    if ((f['ad_name'] ?? '').trim().length < 2) 'ad_name': 'Nom du destinataire obligatoire.',
    if (!RegExp(r'^\+?[0-9 ]{8,20}$').hasMatch((f['ad_phone'] ?? '').trim())) 'ad_phone': 'Téléphone invalide (chiffres uniquement).',
    if (city.length < 2) 'ad_place': 'Indiquez la ville et le quartier (ex. Douala · Ndokoti).',
    if ((f['ad_line'] ?? '').trim().length < 3) 'ad_line': 'Adresse précise obligatoire.',
  };
  if (errs.isNotEmpty) {
    ref.read(errorsProvider.notifier).setAll(errs);
    return;
  }
  ref.read(errorsProvider.notifier).clear();
  final r = await Backend.rpc('save_address', {
    'p_id': null, 'p_recipient': f['ad_name']!.trim(), 'p_phone': f['ad_phone']!.trim(), 'p_city': city, 'p_district': district,
    'p_line': f['ad_line']!.trim(), 'p_landmark': (f['ad_landmark'] ?? '').trim(),
  });
  if (!context.mounted) return;
  if (r.error != null) return gAlert(context, 'Adresse non enregistrée', r.error!);
  ref.read(selectedAddressProvider.notifier).set('${r.data}');
  gToast(context, 'Adresse enregistrée');
  gOpen(context, '42');
}
