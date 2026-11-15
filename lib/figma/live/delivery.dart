import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../gen.dart';
import '../nav.dart';
import 'auth.dart';
import 'backend.dart';
import 'lots.dart' show formDialog;
import 'compte.dart' show addressLine, addressesProvider;
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

/// Adresse du carnet retenue pour la commande en cours (identifiant serveur) : réinitialisée au changement de compte.
class SelectedAddress extends Notifier<String> {
  @override
  String build() {
    ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
    return '';
  }

  void set(String v) => state = v;
}

final selectedAddressProvider = NotifierProvider<SelectedAddress, String>(SelectedAddress.new);

/// Contenu (destinataire, téléphone, ville, quartier, adresse) de l'adresse retenue, y compris une adresse non enregistrée dans le carnet.
class SelectedAddressInfo extends Notifier<Map<String, dynamic>?> {
  @override
  Map<String, dynamic>? build() {
    ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
    return null;
  }

  void set(Map<String, dynamic>? v) => state = v;
}

final selectedAddressInfoProvider = NotifierProvider<SelectedAddressInfo, Map<String, dynamic>?>(SelectedAddressInfo.new);

/// Adresse retenue (carnet ou adresse temporaire) : null si aucune n'est choisie ou si elle n'est plus connue.
final selectedAddressDataProvider = Provider<Map<String, dynamic>?>((ref) {
  final id = ref.watch(selectedAddressProvider);
  if (id.isEmpty) return null;
  final info = ref.watch(selectedAddressInfoProvider);
  if (info != null && '${info['id']}' == id) return info;
  for (final a in ref.watch(addressesProvider) ?? const <Map<String, dynamic>>[]) {
    if ('${a['id']}' == id) return a;
  }
  return null;
});

/// Devis de livraison d'un panier : frais total, ou liste des vendeurs qui ne livrent pas dans la ville ([fee] null).
class DeliveryQuote {
  const DeliveryQuote(this.fee, this.unserved);
  final int? fee;
  final List<String> unserved;
}

/// Frais de livraison du panier vers la ville de l'adresse choisie, vendeur par vendeur (tarifs par ville fixés par les vendeurs et l'administrateur).
/// Null : pas de livraison à domicile, adresse non choisie ou panier vide. Les lignes « Pack » sont envoyées avec leur clé pack.
final deliveryQuoteProvider = FutureProvider.autoDispose<DeliveryQuote?>((ref) async {
  if (!Backend.ready || !ref.watch(homeDeliveryProvider)) return null;
  if (ref.watch(selectedAddressProvider).isEmpty) return null;
  final data = ref.watch(selectedAddressDataProvider);
  if (data == null) return ref.watch(addressesProvider) == null ? null : const DeliveryQuote(null, []);
  final lines = ref.watch(cartProvider);
  if (lines.isEmpty) return null;
  final r = await marcheCall('delivery_quote', {'p_city': '${data['city']}', 'p_items': Backend.orderItems(lines)});
  if (r.error != null || r.data is! Map) return const DeliveryQuote(null, []);
  final m = r.data as Map;
  final fee = m['fee'];
  return DeliveryQuote(fee is num ? fee.toInt() : null, [for (final u in (m['unserved'] as List? ?? const [])) '$u']);
}, retry: (_, _) => null);

/// Frais de livraison affichés : hors serveur, ceux de la maquette ; connecté, ceux du réglage (0 si domicile non proposé).
int deliveryFee(bool home, DeliverySettings? s) => !home ? 0 : (s?.fee ?? 5000);

/// 07 « Livraison à domicile » : connecté, refusée quand le réglage serveur dit qu'elle n'est pas activée (le serveur la refuserait à la commande) ;
/// sinon l'adresse la plus récente du carnet est retenue, ou la saisie d'une adresse (41) est proposée si le carnet est vide.
/// Réglage non lu : elle reste proposée, la commande vérifie.
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
  gToast(context, 'Livraison à domicile : frais calculés selon votre adresse');
  if (ref.read(selectedAddressProvider).isNotEmpty) return;
  var book = ref.read(addressesProvider);
  if (book == null) {
    try {
      await ref.read(addressesProvider.notifier).refresh();
    } catch (_) {}
    book = ref.read(addressesProvider);
  }
  if (!context.mounted) return;
  if (book != null && book.isNotEmpty) {
    pickAddress(ref, book.first);
  } else {
    gOpen(context, '41');
  }
}

/// Retient une adresse du carnet pour la commande en cours.
void pickAddress(WidgetRef ref, Map<String, dynamic> a) {
  ref.read(selectedAddressProvider.notifier).set('${a['id']}');
  ref.read(selectedAddressInfoProvider.notifier).set(a);
}

/// 07 « Continuer » : le récapitulatif (42) s'ouvre ; en livraison à domicile, une adresse desservie est exigée (sinon retrait proposé).
Future<void> continueFromDelivery(BuildContext context, WidgetRef ref) async {
  if (!Backend.ready) return gOpen(context, '08');
  if (ref.read(cartProvider).isEmpty) return gToast(context, 'Ajoutez un article pour commander');
  if (ref.read(homeDeliveryProvider)) {
    if (ref.read(selectedAddressProvider).isEmpty) return gToast(context, 'Choisissez une adresse de livraison.');
    final problem = ref.read(totalsProvider).feeProblem;
    if (problem != null) {
      final pickup = await gConfirm(context, 'Livraison à domicile impossible', problem, yes: 'Retrait sur campus', no: 'Changer d’adresse');
      if (pickup) ref.read(homeDeliveryProvider.notifier).set(false);
      return;
    }
  }
  gOpen(context, '42');
}

const _addressKeys = ['ad_name', 'ad_phone', 'ad_place', 'ad_line', 'ad_landmark', 'ad_save'];

/// Valeur d'un champ de 41 telle qu'affichée : la saisie en cours, sinon (nom, téléphone) celle du profil. Écran et validation lisent la même valeur.
String addressField(WidgetRef ref, String key) {
  final v = ref.read(formProvider)[key];
  if (v != null) return v;
  final me = ref.read(authProvider).current;
  return key == 'ad_name' ? (me?.name ?? '') : (key == 'ad_phone' ? (me?.phone ?? '') : '');
}

/// 41 « Continuer » : connecté, l'adresse est enregistrée dans le carnet (save_address) puis retenue pour la commande.
/// Carnet complet (5 adresses) ou case décochée : l'adresse sert à cette commande seulement, sans prendre de place dans le carnet.
Future<void> saveDeliveryAddress(BuildContext context, WidgetRef ref) async {
  if (!Backend.ready) return gOpen(context, '42');
  if (!await requireLogin(context, ref, 'enregistrer une adresse') || !context.mounted) return;
  final f = {for (final k in _addressKeys) k: addressField(ref, k)};
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
  final bookFull = (ref.read(addressesProvider) ?? const []).length >= 5;
  await discardTransientAddress(ref.read);
  if (!context.mounted) return;
  Future<({Object? data, String? error})> save(bool transient) => Backend.rpc('save_address', {
        'p_id': null, 'p_recipient': f['ad_name']!.trim(), 'p_phone': f['ad_phone']!.trim(), 'p_city': city, 'p_district': district,
        'p_line': f['ad_line']!.trim(), 'p_landmark': (f['ad_landmark'] ?? '').trim(), 'p_transient': transient,
      });
  var transient = !keep || bookFull;
  var r = await save(transient);
  if (r.error != null && !transient && r.error!.contains('Carnet complet')) {
    transient = true;
    r = await save(true);
  }
  if (!context.mounted) return;
  if (r.error != null) return gAlert(context, 'Adresse non enregistrée', r.error!);
  final id = '${r.data}';
  ref.read(selectedAddressProvider.notifier).set(id);
  ref.read(selectedAddressInfoProvider.notifier).set({
    'id': id, 'recipient': f['ad_name']!.trim(), 'phone': f['ad_phone']!.trim(), 'city': city, 'district': district, 'line': f['ad_line']!.trim(), 'landmark': (f['ad_landmark'] ?? '').trim(),
  });
  ref.read(transientAddressProvider.notifier).set(transient ? id : '');
  ref.read(formProvider.notifier).clear(_addressKeys);
  try {
    await ref.read(addressesProvider.notifier).refresh();
  } catch (_) {}
  if (!context.mounted) return;
  gToast(context, transient ? (keep && bookFull ? 'Carnet complet (5 adresses) : adresse retenue pour cette commande seulement' : 'Adresse retenue pour cette commande') : 'Adresse enregistrée');
  gOpen(context, '42');
}

/// Adresse saisie sans « Enregistrer dans mon carnet » (ou carnet plein) : le serveur ne livre qu'à une adresse qu'il connaît, elle est donc créée
/// le temps de la commande (marquée transitoire : elle ne compte pas dans les 5 du carnet et n'y apparaît pas), puis supprimée une fois la commande passée
/// (l'adresse reste copiée dans la commande).
final transientAddressProvider = NotifierProvider<StrV, String>(StrV.new);

typedef RefRead = T Function<T>(ProviderListenable<T> provider);

Future<void> discardTransientAddress(RefRead read) async {
  final id = read(transientAddressProvider);
  if (id.isEmpty) return;
  read(transientAddressProvider.notifier).set('');
  if (read(selectedAddressProvider) == id) {
    read(selectedAddressProvider.notifier).set('');
    read(selectedAddressInfoProvider.notifier).set(null);
  }
  final book = read(addressesProvider.notifier);
  await Backend.rpc('delete_address', {'p_id': id});
  try {
    await book.refresh();
  } catch (_) {}
}

/// 07 : choix de l'adresse de livraison parmi le carnet, ou saisie d'une nouvelle adresse (41).
class AddressPicker extends ConsumerWidget {
  const AddressPicker({super.key, this.width = 344, this.height = 96});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(addressesProvider) ?? const <Map<String, dynamic>>[];
    final selected = ref.watch(selectedAddressProvider);
    final data = ref.watch(selectedAddressDataProvider);
    final chosen = data == null ? null : [if ('${data['recipient'] ?? ''}'.isNotEmpty) '${data['recipient']}', addressLine(data)].join(' · ');
    return SizedBox(
      width: width,
      height: height,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: EdgeInsets.zero, children: [
            for (final a in book)
              _chip('${a['city']}${'${a['district'] ?? ''}'.isNotEmpty ? ' · ${a['district']}' : ''}', selected == '${a['id']}', () => pickAddress(ref, a)),
            _chip('+ Nouvelle adresse', false, () => gOpen(context, '41')),
          ]),
        ),
        const SizedBox(height: 6),
        Expanded(child: gText(chosen ?? 'Aucune adresse choisie : choisissez-en une dans votre carnet ou ajoutez-en une.', 11.5, chosen == null ? const Color(0xFFE5484D) : const Color(0xFF57545F), wrap: true, maxLines: 3)),
      ]),
    );
  }

  Widget _chip(String label, bool on, VoidCallback tap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: tap,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: on ? const Color(0xFF111015) : const Color(0xFFFFFFFF), borderRadius: BorderRadius.circular(22), border: Border.all(color: on ? const Color(0xFF111015) : const Color(0xFFE6E1EE))),
            child: gText(label, 12.5, on ? const Color(0xFFFFFFFF) : const Color(0xFF111015), weight: 600),
          ),
        ),
      );
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