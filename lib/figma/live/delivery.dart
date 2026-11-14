import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart';
import '../nav.dart';
import 'auth.dart';
import 'backend.dart';
import 'lots.dart' show formDialog;
import 'compte.dart' show addressesProvider;
import 'marche/marche_data.dart' show marcheCall;
import 'store.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

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

/// Frais de livraison du panier vers la ville de l'adresse choisie, vendeur par vendeur (tarifs par ville fixés par les vendeurs et l'administrateur).
/// Null : pas de livraison à domicile, adresse non choisie, ou ville non desservie par un vendeur (la commande l'expliquera).
final deliveryQuoteProvider = FutureProvider.autoDispose<int?>((ref) async {
  if (!Backend.ready || !ref.watch(homeDeliveryProvider)) return null;
  final id = ref.watch(selectedAddressProvider);
  if (id.isEmpty) return null;
  String? city;
  for (final a in ref.watch(addressesProvider) ?? const <Map<String, dynamic>>[]) {
    if ('${a['id']}' == id) city = '${a['city']}';
  }
  if (city == null) return null;
  final lines = ref.watch(cartProvider);
  if (lines.isEmpty) return null;
  final r = await marcheCall('delivery_quote', {'p_city': city, 'p_items': [for (final l in lines) {'title': l.title, 'qty': l.qty}]});
  if (r.error != null || r.data is! Map) return null;
  final fee = (r.data as Map)['fee'];
  return fee is num ? fee.toInt() : null;
});

/// Frais de livraison affichés : hors serveur, ceux de la maquette ; connecté, ceux du réglage (0 si domicile non proposé).
int deliveryFee(bool home, DeliverySettings? s) => !home ? 0 : (s?.fee ?? 5000);

/// 07 « Livraison à domicile » : connecté, refusée quand le réglage serveur dit qu'elle n'est pas activée (le serveur la refuserait à la commande) ;
/// sinon l'adresse est demandée (41). Réglage non lu : elle reste proposée, la commande vérifie.
Future<void> chooseHomeDelivery(BuildContext context, WidgetRef ref) async {
  if (!Backend.ready) {
    ref.read(homeDeliveryProvider.notifier).set(true);
    gToast(context, 'Livraison à domicile · 5 000 FCFA');
    return;
  }
  await ref.read(deliverySettingsProvider.notifier).refresh();
  if (!context.mounted) return;
  final s = ref.read(deliverySettingsProvider);
  if (s != null && !s.enabled) {
    gToast(context, 'Livraison à domicile non proposée pour le moment : choisissez le retrait sur campus.');
    return;
  }
  ref.read(homeDeliveryProvider.notifier).set(true);
  gToast(context, 'Livraison à domicile · ${fcfa(s?.fee ?? 5000)}');
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
    if (city.length < 2 || district.length < 2) 'ad_place': 'Indiquez la ville et le quartier (ex. Douala · Ndokoti).',
    if ((f['ad_line'] ?? '').trim().length < 3) 'ad_line': 'Adresse précise obligatoire.',
  };
  if (errs.isNotEmpty) {
    ref.read(errorsProvider.notifier).setAll(errs);
    return;
  }
  ref.read(errorsProvider.notifier).clear();
  final keep = (f['ad_save'] ?? '1') != '0';
  await discardTransientAddress(ref);
  if (!context.mounted) return;
  final r = await Backend.rpc('save_address', {
    'p_id': null, 'p_recipient': f['ad_name']!.trim(), 'p_phone': f['ad_phone']!.trim(), 'p_city': city, 'p_district': district,
    'p_line': f['ad_line']!.trim(), 'p_landmark': (f['ad_landmark'] ?? '').trim(),
  });
  if (!context.mounted) return;
  if (r.error != null) return gAlert(context, 'Adresse non enregistrée', r.error!);
  ref.read(selectedAddressProvider.notifier).set('${r.data}');
  ref.read(transientAddressProvider.notifier).set(keep ? '' : '${r.data}');
  await ref.read(addressesProvider.notifier).refresh();
  if (!context.mounted) return;
  gToast(context, keep ? 'Adresse enregistrée' : 'Adresse retenue pour cette commande');
  gOpen(context, '42');
}

/// Adresse saisie sans « Enregistrer dans mon carnet » : le serveur ne livre qu'à une adresse qu'il connaît, elle est donc créée
/// le temps de la commande, masquée du carnet, puis supprimée dès que la commande est passée (l'adresse reste copiée dans la commande).
final transientAddressProvider = NotifierProvider<StrV, String>(StrV.new);

Future<void> discardTransientAddress(WidgetRef ref) async {
  final id = ref.read(transientAddressProvider);
  if (id.isEmpty) return;
  ref.read(transientAddressProvider.notifier).set('');
  if (ref.read(selectedAddressProvider) == id) ref.read(selectedAddressProvider.notifier).set('');
  final book = ref.read(addressesProvider.notifier);
  await Backend.rpc('delete_address', {'p_id': id});
  try {
    await book.refresh();
  } catch (_) {}
}

/// Réglage administrateur (menu du compte) : active ou coupe la livraison à domicile, ville desservie et frais.
/// Enregistré par la fonction serveur set_home_delivery (réservée à l'administration, tracée dans le journal d'audit).
Future<void> homeDeliverySettingsDialog(BuildContext context, WidgetRef ref) async {
  if (!Backend.ready) return gAlert(context, 'Livraison à domicile', 'Connectez-vous avec un compte administrateur pour modifier ce réglage.');
  await ref.read(deliverySettingsProvider.notifier).refresh();
  if (!context.mounted) return;
  final s = ref.read(deliverySettingsProvider);
  final v = await formDialog(context, 'Livraison à domicile', [
    ('Proposée aux clients (oui / non)', s?.enabled == true ? 'oui' : 'non'),
    ('Ville desservie', s?.city ?? 'Douala'),
    ('Frais de livraison (FCFA)', '${s?.fee ?? 5000}'),
  ], intro: 'Actuellement : ${s?.enabled == true ? 'proposée' : 'non proposée'}.');
  if (v == null || !context.mounted) return;
  final on = v[0].trim().toLowerCase().startsWith('o');
  final fee = int.tryParse(v[2].replaceAll(RegExp(r'\D'), ''));
  if (fee == null || fee > 100000 || v[1].trim().isEmpty) return gAlert(context, 'Réglage invalide', 'Indiquez une ville et des frais entre 0 et 100 000 FCFA.');
  final r = await Backend.rpc('set_home_delivery', {'p_enabled': on, 'p_city': v[1].trim(), 'p_fee': fee});
  if (!context.mounted) return;
  if (r.error != null) return gAlert(context, 'Réglage non enregistré', r.error!);
  await ref.read(deliverySettingsProvider.notifier).refresh();
  if (context.mounted) gToast(context, on ? 'Livraison à domicile proposée · ${v[1].trim()} · $fee FCFA' : 'Livraison à domicile coupée');
}