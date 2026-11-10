import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../gen.dart';
import 'auth.dart';
import 'backend.dart';
import 'download_stub.dart' if (dart.library.js_interop) 'download_web.dart';

/// Écran 273 « Exporter mes données » : rassemble les données du titulaire lues sur le serveur (seules les lignes que la sécurité de la
/// base lui permet de voir) dans un fichier JSON téléchargé tout de suite. Aucune donnée d'une autre personne n'est demandée.
const _tables = <(String table, String ownerColumn)>[
  ('profiles', 'id'),
  ('listings', 'seller_id'),
  ('orders', 'buyer_id'),
  ('notifications', 'user_id'),
  ('user_documents', 'owner_id'),
  ('addresses', 'user_id'),
  ('earnings', 'user_id'),
  ('referrals', 'referrer_id'),
  ('certification_requests', 'user_id'),
  ('qr_codes', 'owner_id'),
];

Future<void> exportMyData(BuildContext context, WidgetRef ref) async {
  if (!Backend.ready) return gAlert(context, 'Hors connexion', 'L’export nécessite la connexion au serveur.');
  if (!await requireLogin(context, ref, 'exporter vos données') || !context.mounted) return;
  final uid = ref.read(authProvider).current?.serverId ?? Backend.currentUserId ?? '';
  if (uid.isEmpty) return gAlert(context, 'Export impossible', 'Votre session n’est pas reconnue. Reconnectez-vous.');
  gToast(context, 'Préparation de l’export…');
  final out = <String, dynamic>{
    'exporte_le': DateTime.now().toUtc().toIso8601String(),
    'compte': uid,
    'note': 'Données du compte lisibles par son titulaire. Les messages et fichiers déposés restent disponibles dans l’application.',
  };
  final missing = <String>[];
  for (final (table, col) in _tables) {
    final r = await Backend.rows(table, '*', eq: {col: uid}, limit: 1000);
    if (r.error != null) {
      missing.add(table);
    } else {
      out[table] = r.rows;
    }
  }
  // seconde lecture : filleul de quelqu'un (le parrain figure dans le premier jeu, le filleul ici)
  final asReferee = await Backend.rows('referrals', '*', eq: {'referee_id': uid});
  if (asReferee.error == null) out['referrals_en_tant_que_filleul'] = asReferee.rows;
  if (missing.isNotEmpty) out['tables_non_lues'] = missing;
  final name = 'boutik-ecole-mes-donnees-${DateTime.now().toIso8601String().substring(0, 10)}.json';
  final text = const JsonEncoder.withIndent('  ').convert(out);
  var saved = false;
  try {
    if (kIsWeb) {
      saved = await saveTextFile(name, text, 'application/json');
    } else {
      await SharePlus.instance.share(ShareParams(files: [XFile.fromData(Uint8List.fromList(utf8.encode(text)), name: name, mimeType: 'application/json')], fileNameOverrides: [name]));
      saved = true;
    }
  } catch (_) {
    saved = false;
  }
  if (!context.mounted) return;
  if (!saved) return gAlert(context, 'Export non enregistré', 'Le fichier n’a pas pu être enregistré sur cet appareil. Réessayez depuis le navigateur.');
  final bytes = utf8.encode(text).length;
  gToast(context, kIsWeb ? 'Export téléchargé : $name (${(bytes / 1024).ceil()} Ko)' : 'Export prêt : choisissez où l’enregistrer.');
  if (missing.isNotEmpty && context.mounted) {
    await gAlert(context, 'Export partiel', 'Ces éléments n’ont pas pu être lus et ne figurent pas dans le fichier : ${missing.join(', ')}.');
  }
}
