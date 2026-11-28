import 'backend.dart';

/// Médias non publics (histoires, publications de communautés fermées) : stockés dans le compartiment PRIVÉ `post-media-private`
/// (migration 20261129010000) et lus par URL signée de 1 h au plus, recréée au besoin. Les médias publics restent dans `post-media` (URL publique, inchangée).
/// Un nouveau fichier privé est déposé sous `<uid>/private/…` : ce repère suffit à savoir, sans appel réseau, qu'il faut le signer.
/// Les anciens fichiers déjà basculés par la procédure serveur (même chemin) sont retrouvés par `post_media_targets`.
class MediaAccess {
  static const publicBucket = 'post-media';
  static const privateBucket = 'post-media-private';

  /// Durée de validité d'une URL signée (secondes) : 1 h au maximum.
  static const ttlSeconds = 3600;
  static const _reuse = Duration(minutes: 50);
  static final Map<String, ({String url, DateTime until})> _signed = {};
  static final Map<String, DateTime> _publicUntil = {};
  static final Set<String> _privateKnown = {};

  static bool isPrivatePath(String path) {
    final p = path.split('/');
    return p.length > 2 && p[1] == 'private';
  }

  /// Chemin d'un nouveau fichier : `<uid>/<horodatage>.<ext>` (public) ou `<uid>/private/<horodatage>.<ext>` (privé).
  static String newPath(String uid, String ext, {bool private = false}) => '$uid/${private ? 'private/' : ''}${DateTime.now().microsecondsSinceEpoch}.$ext';

  static String bucketOf(String path) => isPrivatePath(path) || _privateKnown.contains(path) ? privateBucket : publicBucket;

  /// URL signée encore valable pour ce chemin, sinon null (l'appelant retombe sur l'URL publique : ancien comportement).
  static String? cached(String path) {
    final c = _signed[path];
    if (c == null || c.until.isBefore(DateTime.now())) return null;
    return c.url;
  }

  static Future<String?> sign(String path) async {
    final hit = cached(path);
    if (hit != null) return hit;
    final url = await Backend.signedFileUrl(privateBucket, path);
    if (url == null || url.isEmpty) return null;
    _signed[path] = (url: url, until: DateTime.now().add(_reuse));
    _privateKnown.add(path);
    return url;
  }

  /// Prépare l'affichage d'une liste : signe les fichiers privés (repère `/private/` ou déjà basculés côté serveur) pour que `Backend.postMediaUrl` renvoie l'URL signée.
  static Future<void> warm(Iterable<String?> paths) async {
    final now = DateTime.now();
    final todo = <String>{for (final p in paths) if (p != null && p.length > 4 && !p.startsWith('{') && !p.startsWith('[')) p};
    final unknown = <String>[];
    for (final p in todo) {
      if (isPrivatePath(p) || _privateKnown.contains(p)) {
        await sign(p);
      } else if (_publicUntil[p]?.isAfter(now) != true) {
        unknown.add(p);
      }
    }
    for (var i = 0; i < unknown.length; i += 200) {
      final chunk = unknown.sublist(i, i + 200 > unknown.length ? unknown.length : i + 200);
      final r = await Backend.rpc('post_media_targets', {'p_paths': chunk});
      if (r.error != null || r.data is! Map) continue;
      final priv = (r.data as Map).keys.map((k) => '$k').toSet();
      for (final p in chunk) {
        if (priv.contains(p)) {
          await sign(p);
        } else {
          _publicUntil[p] = now.add(const Duration(minutes: 30));
        }
      }
    }
  }

  /// URL à utiliser tout de suite pour un chemin : signée si disponible, sinon publique.
  static String urlFor(String path) => cached(path) ?? Backend.publicFileUrl(publicBucket, path);

  /// Oublie les URL signées et les chemins privés connus : à la déconnexion, un autre compte ne réutilise rien du précédent.
  static void reset() {
    _signed.clear();
    _publicUntil.clear();
    _privateKnown.clear();
  }
}
