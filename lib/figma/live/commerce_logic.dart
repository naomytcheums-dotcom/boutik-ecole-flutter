/// Message clair quand `cart_check` (migration 20261128030000) refuse un ou plusieurs articles du panier : une ligne par article, avec sa boutique.
/// Null quand tout est valide. La commande est atomique : si un article est refusé, aucune commande n'est créée (le message le dit).
String? cartIssuesMessage(Object? check) {
  if (check is! Map || check['ok'] != false) return null;
  final bad = [for (final l in (check['lines'] as List? ?? const [])) if (l is Map && l['ok'] == false) l];
  if (bad.isEmpty) return null;
  final lines = [
    for (final l in bad) '• ${l['shop'] == null ? '' : '${l['shop']} — '}${l['message'] ?? l['title'] ?? 'article indisponible'}',
  ];
  return '${bad.length == 1 ? 'Un article de votre panier pose problème' : '${bad.length} articles de votre panier posent problème'} : aucune commande n’a été créée.\n${lines.join('\n')}';
}
