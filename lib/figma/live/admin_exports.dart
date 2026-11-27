import 'package:flutter/material.dart' hide Text;

import '../gen.dart' show gToast;
import 'backend.dart';
import 'download_stub.dart' if (dart.library.js_interop) 'download_web.dart';

/// Exports CSV de l'administration (journal d'audit, file des rattachements, contestations de score) : le fichier est construit par le serveur (`admin_export_csv`), qui vérifie la permission,
/// limite le débit, plafonne le volume et écrit une ligne au journal d'audit. Rien n'est calculé ni reconstitué côté application : une panne ou un refus donne un message, jamais un fichier vide.
class AdminCsv {
  const AdminCsv({required this.kind, required this.filename, required this.csv, required this.rows, required this.truncated});
  final String kind, filename, csv;
  final int rows;
  final bool truncated;
}

const kAdminCsvKinds = {'audit', 'rattachements', 'contestations'};

/// Réponse du serveur → fichier ; null si la réponse n'a pas la forme attendue (le serveur n'a alors rien prouvé : pas de fichier).
AdminCsv? parseAdminCsv(Object? data) {
  if (data is! Map) return null;
  final csv = data['csv'], name = data['filename'], rows = data['rows'], kind = data['kind'];
  if (csv is! String || name is! String || rows is! num || kind is! String || csv.isEmpty) return null;
  return AdminCsv(kind: kind, filename: name, csv: csv, rows: rows.toInt(), truncated: data['truncated'] == true);
}

Future<({AdminCsv? file, String? error})> fetchAdminCsv(String kind, [Map<String, dynamic> filters = const {}]) async {
  final r = await Backend.rpc('admin_export_csv', {'p_kind': kind, 'p_filters': filters});
  if (r.error != null) return (file: null, error: Backend.userMessage(r.error!));
  final f = parseAdminCsv(r.data);
  if (f == null) return (file: null, error: 'Réponse inattendue du serveur : aucun fichier créé.');
  return (file: f, error: null);
}

/// Message de fin d'export : le nombre de lignes vient du serveur ; une liste vide est dite vide ; un plafond atteint est signalé (messages à modèle fixe, traduisibles).
String adminCsvMessage(AdminCsv f, {required bool downloaded}) {
  final n = f.rows;
  final where = downloaded ? f.filename : 'copié dans le presse-papiers';
  if (n == 0) return 'Aucune ligne à exporter : fichier vide créé (en-têtes seulement)';
  if (f.truncated) return 'Export limité aux 5 000 premières lignes ($where) : affinez les filtres';
  return n == 1 ? '1 ligne exportée ($where)' : '$n lignes exportées ($where)';
}

final _enCours = <String>{};

/// « Exporter » : demande le fichier au serveur puis l'enregistre (téléchargement dans le navigateur, copie dans le presse-papiers ailleurs).
/// Un second appui pendant l'export est ignoré ; le BOM UTF-8 permet l'ouverture directe dans un tableur.
Future<void> exportAdminCsv(BuildContext context, String kind, {Map<String, dynamic> filters = const {}}) async {
  if (!Backend.ready) return gToast(context, 'Connectez-vous avec un compte autorisé pour exporter.');
  if (!_enCours.add(kind)) return;
  try {
    final r = await fetchAdminCsv(kind, filters);
    if (!context.mounted) return;
    final f = r.file;
    if (f == null) return gToast(context, r.error ?? 'Export indisponible pour le moment.');
    final downloaded = await saveTextFile(f.filename, '\uFEFF${f.csv}', 'text/csv');
    if (!context.mounted) return;
    gToast(context, adminCsvMessage(f, downloaded: downloaded));
  } finally {
    _enCours.remove(kind);
  }
}
