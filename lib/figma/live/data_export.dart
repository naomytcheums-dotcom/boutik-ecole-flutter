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

/// Écran 273 « Exporter mes données » : la fonction serveur `export_my_data` rassemble toutes les données du titulaire (profil, annonces,
/// commandes, messages envoyés, favoris, publications, avis, adresses, gains, appareils, consentements…) dans un fichier JSON téléchargé tout de suite.
/// Aucune donnée d'une autre personne n'est demandée ; les jetons actifs (codes de retrait, codes QR) sont retirés du fichier.
/// Si la fonction serveur n'est pas encore installée, une lecture directe, plus restreinte, la remplace et le fichier le dit.
const _legacyTables = <(String table, String ownerColumn)>[
  ('profiles', 'id'),
  ('listings', 'seller_id'),
  ('orders', 'buyer_id'),
  ('notifications', 'user_id'),
  ('user_documents', 'owner_id'),
  ('addresses', 'user_id'),
  ('earnings', 'user_id'),
  ('referrals', 'referrer_id'),
  ('certification_requests', 'user_id'),
];

const _secretKeys = {'pickup_code', 'token', 'secret'};

Future<Map<String, dynamic>> _legacyExport(String uid) async {
  final out = <String, dynamic>{};
  final missing = <String>[];
  for (final (table, col) in _legacyTables) {
    final r = await Backend.rows(table, '*', eq: {col: uid}, limit: 1000);
    if (r.error != null) {
      missing.add(table);
    } else {
      out[table] = [
        for (final row in r.rows) {for (final e in row.entries) if (!_secretKeys.contains(e.key)) e.key: e.value},
      ];
    }
  }
  final asReferee = await Backend.rows('referrals', '*', eq: {'referee_id': uid});
  if (asReferee.error == null) out['referrals_filleul'] = asReferee.rows;
  return {
    'donnees': out,
    'tables_non_lues': missing,
    'tronque': [for (final e in out.entries) if (e.value is List && (e.value as List).length >= 1000) e.key],
    'avertissement': 'Export restreint : la fonction d’export complet n’est pas disponible sur le serveur pour le moment. Les messages, favoris, publications et avis ne sont pas inclus.',
  };
}

Future<void> exportMyData(BuildContext context, WidgetRef ref) async {
  if (!Backend.ready) return gAlert(context, 'Hors connexion', 'L’export nécessite la connexion au serveur.');
  if (!await requireLogin(context, ref, 'exporter vos données') || !context.mounted) return;
  final uid = ref.read(authProvider).current?.serverId ?? Backend.currentUserId ?? '';
  if (uid.isEmpty) return gAlert(context, 'Export impossible', 'Votre session n’est pas reconnue. Reconnectez-vous.');
  gToast(context, 'Préparation de l’export…');
  final r = await Backend.rpc('export_my_data', const {}, timeout: const Duration(seconds: 60), timeoutMessage: 'La préparation de l’export prend trop de temps. Réessayez dans un instant.');
  Map<String, dynamic> body;
  var complete = true;
  if (r.error == null && r.data is Map) {
    body = Map<String, dynamic>.from(r.data as Map);
  } else {
    body = await _legacyExport(uid);
    complete = false;
  }
  final missing = [for (final m in (body['tables_non_lues'] as List? ?? const [])) '$m'];
  final truncated = [for (final m in (body['tronque'] as List? ?? const [])) '$m'];
  final out = <String, dynamic>{
    'exporte_le': DateTime.now().toUtc().toIso8601String(),
    'compte': uid,
    'note': 'Données de votre compte : profil, annonces, commandes, messages envoyés, favoris, publications, avis, adresses, gains, parrainage, demandes, appareils, acceptation des conditions. Les fichiers déposés (photos, pièces justificatives) ne sont pas inclus ; les codes de retrait et jetons actifs sont volontairement retirés.',
    ...body,
  };
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
  final notes = [
    if (!complete) 'L’export complet n’est pas disponible pour le moment : ce fichier est restreint (profil, annonces, commandes, notifications, documents, adresses, gains, parrainage, certification).',
    if (missing.isNotEmpty) 'Ces éléments n’ont pas pu être lus : ${missing.join(', ')}.',
    if (truncated.isNotEmpty) 'Ces éléments dépassent la limite d’une lecture et sont tronqués : ${truncated.join(', ')}.',
  ];
  if (notes.isNotEmpty && context.mounted) {
    await gAlert(context, 'Export partiel', notes.join('\n\n'));
  }
}
