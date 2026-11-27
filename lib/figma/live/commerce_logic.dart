/// Extension d'une image de variante d'après son type MIME (null : format refusé). Le serveur n'accepte que jpg, jpeg, png ou webp.
String? variantImageExtension(String mime) => switch (mime.toLowerCase()) {
      'image/jpeg' || 'image/jpg' => 'jpg',
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => null,
    };

/// Chemin d'une image de variante : `<vendeur>/<annonce>/variante-<horodatage>.<ext>`. Le nom du fichier choisi par l'utilisateur n'est jamais repris
/// (extension absente, caractères ou longueur refusés par la validation serveur) ; le dossier est celui du vendeur, seul autorisé à écrire.
String variantImagePath(String uid, String listingId, String ext, int stamp) => '$uid/$listingId/variante-$stamp.$ext';

/// Vrai pour un fichier déposé par le formulaire de variante (donc supprimable sans risque : jamais une photo de l'annonce).
bool isVariantImageUpload(String path) {
  final parts = path.split('/');
  return (parts.length >= 3 && parts.last.startsWith('variante-')) || path.contains('/variantes/');
}

/// Quantité maximale que le panier propose pour une ligne : le plus petit des plafonds connus (stock restant annoncé par le serveur, limite de 20).
int cartQtyCap(int hardMax, {int? variantLeft, int? productStock}) {
  var m = hardMax;
  for (final c in [variantLeft, productStock]) {
    if (c != null && c < m) m = c;
  }
  return m < 1 ? 1 : m;
}

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
