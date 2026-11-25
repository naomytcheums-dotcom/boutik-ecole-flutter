import 'package:flutter/material.dart' hide Text;

import '../i18n.dart' show Text;
import 'backend.dart';
import 'tp_ui.dart';

/// Outils communs de la console « Classement et talents » : appels serveur honnêtes (une erreur est une erreur, jamais un zéro ni une liste vide),
/// permissions du classement et petits éléments d'affichage. Le serveur est l'autorité : cette couche n'affiche que ce qu'il renvoie.

/// Permissions du classement (équipe `ranking`, sensibles : jamais attribuées par défaut ; l'administrateur global les a toutes).
const kRankingPerms = {'institutions.manage', 'ranking.rules', 'ranking.publish', 'ranking.moderate'};

class Top100Error implements Exception {
  const Top100Error(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Message lisible d'une erreur de la console (le texte du serveur est conservé : 2FA requise, motif trop court, période déjà publiée…).
String top100Msg(Object e) => e is Top100Error ? e.message : Backend.userMessage('$e'.replaceFirst('Exception: ', ''));

Future<Object?> top100Call(String fn, [Map<String, dynamic> params = const {}]) async {
  if (!Backend.ready) throw const Top100Error('Cette console est disponible une fois l’application connectée au serveur.');
  final r = await Backend.rpc(fn, params);
  if (r.error != null) {
    final low = r.error!.toLowerCase();
    if (low.contains('could not find the function') || low.contains('pgrst202')) throw const Top100Error('Cette fonction n’est pas encore installée sur le serveur.');
    throw Top100Error(Backend.userMessage(r.error!));
  }
  return r.data;
}

Future<Map<String, dynamic>> top100Map(String fn, [Map<String, dynamic> params = const {}]) async {
  final d = await top100Call(fn, params);
  if (d is! Map) throw const Top100Error('Réponse illisible du serveur.');
  return Map<String, dynamic>.from(d);
}

Future<List<Map<String, dynamic>>> top100List(String fn, [Map<String, dynamic> params = const {}]) async {
  final d = await top100Call(fn, params);
  if (d is! List) throw const Top100Error('Réponse illisible du serveur.');
  return [for (final x in d) if (x is Map) Map<String, dynamic>.from(x)];
}

List<Map<String, dynamic>> top100Rows(Object? d) => [for (final x in (d is List ? d : const [])) if (x is Map) Map<String, dynamic>.from(x)];

Map<String, dynamic> top100Obj(Object? d) => d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};

String top100Str(Object? v, [String fallback = '']) => v == null || '$v'.isEmpty ? fallback : '$v';

int? top100Int(Object? v) => v is num ? v.toInt() : int.tryParse('$v');

/// Nombre affiché : « — » quand la valeur est absente (jamais 0 à la place d'une valeur inconnue).
String top100Num(Object? v) {
  if (v is! num) return '—';
  final s = v is int || v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
  return s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ');
}

String top100CurrentPeriod() {
  final n = DateTime.now().toUtc();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}';
}

bool top100ValidPeriod(String p) => RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(p);

Widget top100Failed(String message, VoidCallback retry) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Column(children: [
        const Icon(Icons.error_outline_rounded, size: 36, color: tpRed),
        const SizedBox(height: 10),
        Text(message, textAlign: TextAlign.center, style: tpSt(13, c: tpGrey, h: 1.5)),
        const SizedBox(height: 12),
        TpButton('Réessayer', retry, dark: false, icon: Icons.refresh_rounded, compact: true),
      ]),
    );

Widget top100Loading() => const Padding(padding: EdgeInsets.symmetric(vertical: 26), child: Center(child: CircularProgressIndicator()));

Widget top100Stat(String label, Object? value) => Container(
      width: 164,
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xCCFFFFFF), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white, width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value is String ? value : top100Num(value), maxLines: 1, overflow: TextOverflow.ellipsis, style: tpSt(20, w: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(label, style: tpSt(11.5, c: tpGrey, h: 1.35)),
      ]),
    );

Widget top100Chip(String label, {Color c = tpViolet}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: c.withValues(alpha: .1), borderRadius: BorderRadius.circular(100)),
      child: Text(label, style: tpSt(11.5, w: FontWeight.w600, c: c)),
    );

/// Une ligne « libellé : valeur » (valeur absente : « — »).
Widget top100Line(String label, Object? value) => Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(label, style: tpSt(12, c: tpGrey, h: 1.4))),
        const SizedBox(width: 8),
        Flexible(child: Text(value is num ? top100Num(value) : top100Str(value, '—'), textAlign: TextAlign.right, style: tpSt(12.5, w: FontWeight.w600, h: 1.4))),
      ]),
    );
