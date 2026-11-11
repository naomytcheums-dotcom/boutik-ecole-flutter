import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/repositories.dart' show cartProvider;
import 'backend.dart';
import 'marche/marche_data.dart' show marcheCall;

/// Code promo saisi par le client (appliqué par le serveur à la création de la commande).
class PromoCodeNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String v) {
    state = v.trim();
    Backend.promoCode = state;
  }
}

final promoCodeProvider = NotifierProvider<PromoCodeNotifier, String>(PromoCodeNotifier.new);

/// Promotion automatique en cours, créée par l'administrateur (Nouvel An, Pâques…) : null s'il n'y en a pas.
/// Elle s'applique d'elle-même à chaque commande ; le champ du code promo est alors rempli et verrouillé.
final marcheAutoPromoProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  if (!Backend.ready) return null;
  final r = await marcheCall('active_auto_promo', const {});
  if (r.error != null || r.data is! Map) return null;
  return Map<String, dynamic>.from(r.data as Map);
});

/// Réduction en FCFA que le serveur accorde au panier actuel (code saisi, sinon promotion automatique) ; 0 sans code ou hors connexion.
final promoDiscountProvider = FutureProvider.autoDispose<int>((ref) async {
  final lines = ref.watch(cartProvider);
  if (lines.isEmpty || !Backend.ready) return 0;
  var code = ref.watch(promoCodeProvider);
  if (code.isEmpty) {
    final auto = await ref.watch(marcheAutoPromoProvider.future);
    code = '${auto?['code'] ?? ''}';
  }
  if (code.isEmpty) return 0;
  final r = await marcheCall('promo_preview', {'p_code': code, 'p_items': [for (final l in lines) {'title': l.title, 'qty': l.qty}]});
  if (r.error != null || r.data is! Map) return 0;
  final m = Map<String, dynamic>.from(r.data as Map);
  return m['valid'] == true ? ((m['discount'] as num?)?.toInt() ?? 0) : 0;
});

/// « −15 % » ou « −2 000 FCFA » d'une promotion.
String promoValueLabel(Map<String, dynamic> p) => p['kind'] == 'percent' ? '−${p['value']} %' : '−${p['value']} FCFA';
