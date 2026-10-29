import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/common.dart';

/// Pilote des tests d'intégration : affiche le résultat, les étapes atteintes (`data.visited`)
/// et, en cas d'échec, le détail complet renvoyé par l'application.
Future<void> main() async {
  final driver = await FlutterDriver.connect();
  final raw = await driver.requestData(null, timeout: const Duration(minutes: 10));
  await driver.close();
  final response = Response.fromJson(raw);
  stdout.writeln('Étapes atteintes : ${jsonEncode(response.data?['visited'])}');
  if (response.data?['error'] != null) stdout.writeln('Erreur : ${response.data?['error']}');
  if (response.allTestsPassed) {
    stdout.writeln('Tous les tests sont passés.');
    exit(0);
  }
  stdout.writeln('Échec :\n$raw');
  exit(1);
}
