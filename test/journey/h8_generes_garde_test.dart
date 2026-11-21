import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// H8 · Garde statique des écrans générés (lib/figma/g/g_*), corrigés à la main en H6/H7/H8 (voir docs/transformation/H8_GENERES_G.md).
/// Échoue si une régénération par tool/figma_export/convert.py (ou une retouche) fait perdre une protection critique :
///  - consoles admin / personnel / département : au moins une garde `demoContent` (en-tête de maquette masqué connecté) ;
///  - écrans 151/154/159/189 : orbe Kéla (`kelaOrb`) et non les deux SVG génériques de la maquette ;
///  - menu département 108-116 : pied de menu `deptFooterText`.
const adminPersonnel = [
  '108', '109', '110', '111', '112', '113', '114', '115', '116', '117', '118', '119', '120', '121', '122', '123', '124', '125', '126', //
  '127', '128', '129', '130', '131', '132', '133', '134', '135', '136', '137', '138', //
  '145', '146_1', '146_2', '147_1', '147_2', '147_3', '180', '181', //
  '264', '265', '266', '267', '268', '269', '277', '280', '281', '282', '283',
];
const ecransKela = ['151', '154', '159', '189'];
const svgGeneriques = ['d177b28382093d', '6fd6a3c35cbbc1'];

String _source(String id) {
  final f = File('lib/figma/g/g_$id.dart');
  expect(f.existsSync(), isTrue, reason: 'écran généré g_$id.dart introuvable');
  return f.readAsStringSync();
}

void main() {
  test('consoles admin / personnel : au moins une garde demoContent par écran', () {
    final sans = [for (final id in adminPersonnel) if (!_source(id).contains('demoContent')) id];
    expect(sans, isEmpty, reason: 'écrans sans garde demoContent (maquette visible connecté ?) : $sans');
  });

  test('écrans 151/154/159/189 : orbe Kéla présent', () {
    final sans = [for (final id in ecransKela) if (!_source(id).contains('kelaOrb')) id];
    expect(sans, isEmpty, reason: 'orbe Kéla perdu : $sans');
  });

  test('aucun écran généré ne réaffiche les deux SVG génériques de l\'orbe de maquette', () {
    final dir = Directory('lib/figma/g');
    final fautifs = <String>[];
    for (final f in dir.listSync().whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final s = f.readAsStringSync();
      if (svgGeneriques.any(s.contains)) fautifs.add(f.uri.pathSegments.last);
    }
    expect(fautifs, isEmpty, reason: 'SVG génériques de la maquette réintroduits : $fautifs');
  });

  test('menu département 108-116 : pied de menu deptFooterText', () {
    final sans = [for (var n = 108; n <= 116; n++) if (!_source('$n').contains('deptFooterText')) '$n'];
    expect(sans, isEmpty, reason: 'pied de menu figé de la maquette : $sans');
  });
}
