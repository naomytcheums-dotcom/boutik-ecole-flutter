import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../gen.dart';
import 'auth.dart';

/// Brouillons de formulaires enregistrés sur l'appareil (jamais envoyés au serveur tant que l'utilisateur ne valide pas).
/// Chargés au démarrage, ils pré-remplissent les champs (draftValue) et l'état du formulaire (FormValues) ;
/// effacés après un envoi réussi et à la déconnexion (l'utilisateur suivant sur l'appareil ne les voit pas).
class Drafts {
  static const _prefix = 'boutik.draft.';
  static Map<String, String> values = {};

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final out = <String, String>{};
      for (final k in p.getKeys().where((k) => k.startsWith(_prefix))) {
        final m = jsonDecode(p.getString(k) ?? '{}');
        if (m is Map) out.addAll({for (final e in m.entries) '${e.key}': '${e.value}'});
      }
      values = out;
    } catch (_) {
      values = {};
    }
  }

  static Future<bool> save(String id, Map<String, String> fields) async {
    try {
      final p = await SharedPreferences.getInstance();
      final ok = await p.setString('$_prefix$id', jsonEncode(fields));
      if (ok) values = {...values, ...fields};
      return ok;
    } catch (_) {
      return false;
    }
  }

  static Future<void> clear(String id, Iterable<String> keys) async {
    values = {for (final e in values.entries) if (!keys.contains(e.key)) e.key: e.value};
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove('$_prefix$id');
    } catch (_) {}
  }

  static Future<void> clearAll() async {
    values = {};
    try {
      final p = await SharedPreferences.getInstance();
      for (final k in p.getKeys().where((k) => k.startsWith(_prefix)).toList()) {
        await p.remove(k);
      }
    } catch (_) {}
  }
}

/// Valeur initiale d'un champ : le brouillon enregistré s'il existe, sinon le texte de la maquette.
String draftValue(String key, [String shown = '']) => Drafts.values[key] ?? shown;

/// « Enregistrer / Brouillon » : n'annonce l'enregistrement que s'il a réellement eu lieu sur l'appareil.
Future<void> saveDraft(BuildContext context, WidgetRef ref, String id, List<String> keys) async {
  final f = ref.read(formProvider);
  final fields = {for (final k in keys) if ((f[k] ?? '').trim().isNotEmpty) k: f[k]!.trim()};
  if (fields.isEmpty) {
    gToast(context, 'Rien à enregistrer : modifiez au moins un champ.');
    return;
  }
  final ok = await Drafts.save(id, fields);
  if (!context.mounted) return;
  gToast(context, ok ? 'Brouillon enregistré sur cet appareil (il n’est pas encore envoyé).' : 'Brouillon non enregistré : stockage de l’appareil indisponible.');
}
