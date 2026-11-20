import 'dart:convert';
import 'dart:io';

import 'package:boutik_ecole/app.dart';
import 'package:boutik_ecole/core/router/app_router.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/access.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/registry.dart' show gWidths;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/render.dart';

/// H7 · LOT ETU : parcours Client et Étudiant-vendeur PROPRES en mode connecté (`Backend.ready`, faux serveur Supabase, `mockupFrame = false`).
/// Pour CHAQUE écran du registre accessible au rôle (client ou étudiant-vendeur ; hors espaces du personnel et des organisations), trois contrôles :
///  (i)   serveur muet / en erreur : aucun chiffre (ni zéro : une erreur n'est jamais un zéro, ni une donnée) ;
///  (ii)  listes vides : seuls des zéros réels sont admis (jamais un chiffre non nul, un pourcentage, un montant ou une heure) ;
///  (iii) aucun jeton de maquette (noms, entités : tool/maquette_tokens.json ; heure 9:41 ; photos de maquette), aucune exception.
/// Un chiffre est toléré seulement s'il fait partie d'un libellé structurel (indicatif, étape, version, placeholders de saisie) listé ci-dessous.
final _tokens = jsonDecode(File('tool/maquette_tokens.json').readAsStringSync()) as Map<String, dynamic>;
final _noms = <String>{...(_tokens['personas'] as List).cast<String>(), ...(_tokens['entities'] as List).cast<String>(), ...(_tokens['self'] as List).cast<String>()}.where((e) => e.length >= 4).toList();

/// Libellés à chiffres qui ne décrivent aucune donnée : indicatif, étapes, versions, gabarits de saisie, durées de règle (« 72 h », « 30 min »)
/// et textes juridiques/explicatifs fixes.
final _structurel = RegExp(
  r'^\+237$|^Étape \d|^Version \d|^Version d|^\d{1,2}\s*/\s*\d{1,2}$|^\d{1,3}/\d{1,3}$|^Ex\. |^Ex : |^6\s?[\dX]{2}|^\+?237|\b\d+\s*(Mo|Ko|caractères|chiffres|px)\b|^Article \d|^CGU|^CGV|^Étape|Boutik-École 20\d\d|^©|\bcg[uv]-\d{4}|\(\d+ à \d+\)|\d+ au (plus|maximum)|3D\b|2 étapes|champs? à corriger|3 à 80|Taille 18 px|44 × 44|≥ 4,5|1ʳᵉ commande|FCFA et plus|Délai de rétractation de 30 jours|\(2 heures, 48 heures|date limite dans les 3 jours|Échéances sous 7 jours|Proposer 3 mentors|^(30|90) jours$|^(7|30) jours$|^(6|12) mois$|\(30 jours\)|30 derniers jours|sous 7 jours',
);

/// Zéros et valeurs légitimes d'un écran précis : le panier est un état LOCAL (vide = vraiment 0), 150-1 décrit l'état de synchronisation réel (rien n'est encore à jour),
/// 154 calcule son dossier sur des pièces réellement absentes (liste vide) et 210 imprime l'horloge de l'appareil.
final _toleresParEcran = <String, RegExp>{
  '06': RegExp(r'^0 FCFA$|^0 article$|^Total 0 FCFA$'),
  '08': RegExp(r'^Articles \(0\)$|^0 FCFA$|^Total 0 FCFA$'),
  '42': RegExp(r'^0 FCFA$'),
  '261': RegExp(r'^0$'),
  '150-1': RegExp(r'^0%$|sur 3 à jour|Aujourd’hui \d\d:\d\d'),
  '154': RegExp(r'^0 %$|Dossier complet à 0 %|^Encore \d éléments? à fournir\.$'),
  '210': RegExp(r'^\d{1,2} \S+ 20\d\d$|^\d\d:\d\d$'),
};

/// Valeurs légitimes UNIQUEMENT quand la lecture a réussi (listes vides) : en cas d'erreur elles seraient une fausse donnée.
final _toleresVide = <String, RegExp>{
  '204': RegExp(r'^Projets validés : 0$'),
  '18': RegExp(r'^0 justificatif vérifié sur 3'),
  '69': RegExp(r'^0 justificatif vérifié sur 3'),
  '62': RegExp(r'^30 unités$'), // seuil de stock bas par défaut tant que le vendeur n'en a pas réglé un autre
};

/// Écrans qui contiennent un calendrier réel (jours du mois courant, calculés sur l'horloge) : ses numéros de jour ne sont pas des données.
const _ecransCalendrier = {'78', '100'};

String _norm(String s) => s.replaceAll('\u00a0', ' ').replaceAll('\u202f', ' ').trim();

/// Photos décoratives de l'application (fonds, illustrations d'accueil, visuel de guide) déjà tolérées par maquette_interdite_test.dart.
const _photosTolerees = ['cbf050b9', '4ca68f79', '768cf16e', '46d80b34', '8f6ca1bb', 'b49b6a24'];

bool _accessible(String role, String id) {
  if (isStaffScreenId(id)) return false;
  if (role == 'visitor') return allowedRoles(id) == null;
  return canOpen(Account(name: 'x', phone: '', email: '', password: '', role: role == 'student' ? 1 : 0, staff: ''), id);
}

List<String> _ecrans(String role) => [for (final s in screensById.values) if (_accessible(role, s.id)) s.id];

Map<String, dynamic> _session() {
  final exp = DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000;
  String b64(Map m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return {
    'access_token': '${b64({'alg': 'HS256', 'typ': 'JWT'})}.${b64({'sub': FakeSupabase.userId, 'role': 'authenticated', 'exp': exp})}.signature',
    'token_type': 'bearer',
    'expires_in': 7200,
    'expires_at': exp,
    'refresh_token': 'refresh-test',
    'user': {'id': FakeSupabase.userId, 'aud': 'authenticated', 'role': 'authenticated', 'email': 'essai.test@example.test', 'app_metadata': <String, dynamic>{}, 'user_metadata': <String, dynamic>{}, 'created_at': '2026-01-01T00:00:00Z'},
  };
}

void main() {
  late FakeSupabase srv;
  setUpAll(() async {
    await loadAppFonts();
    srv = await FakeSupabase.start();
    await srv.initSupabase();
  });
  tearDownAll(() => srv.close());

  for (final role in ['client', 'student', 'visitor']) {
    for (final muet in [true, false]) {
      group('dynamique : $role connecté, ${muet ? 'serveur muet ou en erreur' : 'listes vides'}', () {
        final trouves = <String, List<String>>{};
        final textes = StringBuffer();

        setUp(() async {
          GScreen.mockupFrame = false; // comportement réel de l'application (la configuration de test force le cadre de maquette)
          GAnim.enabled = false;
          srv.unknownIsError = muet;
          srv.calls.clear();
          srv.rpc.clear();
          // un écran peut fermer la session du faux compte : chaque test repart d'une session ouverte (ou fermée pour le visiteur)
          final auth = Supabase.instance.client.auth;
          if (role == 'visitor') {
            if (auth.currentUser != null) await auth.signOut(scope: SignOutScope.local);
          } else if (auth.currentUser == null) {
            await auth.recoverSession(jsonEncode(_session()));
          }
          // un étudiant-vendeur dont les conditions sont réunies ouvre l'espace vendeur (le serveur reste l'autorité)
          if (role == 'student') {
            srv.rpc['my_seller_capability'] = (_) => {'can_sell': true, 'can_publish': true, 'role': 'student', 'paused': false, 'conditions': <Object>[]};
          }
        });
        tearDown(() {
          GScreen.mockupFrame = true;
          Backend.ready = true;
        });
        tearDownAll(() {
          final b = StringBuffer();
          for (final e in trouves.entries) {
            b.writeln('${e.key}: ${e.value.join(' | ')}');
          }
          b.writeln('TOTAL ${trouves.length}');
          Directory('build').createSync(recursive: true);
          File('build/h7_${role}_${muet ? 'muet' : 'vide'}.txt').writeAsStringSync(b.toString());
          File('build/h7_textes_${role}_${muet ? 'muet' : 'vide'}.txt').writeAsStringSync(textes.toString());
          expect(trouves, isEmpty, reason: 'Écrans $role avec fausses données :\n$b');
        });

        final compte = role == 'visitor'
            ? null
            : Account(
                name: 'Compte Essai',
                phone: '690000999',
                email: 'essai.test@example.test',
                password: '',
                role: role == 'student' ? 1 : 0,
                verified: false,
                institution: '',
                department: '',
                city: '',
                serverId: FakeSupabase.userId,
              );

        for (final id in _ecrans(role)) {
          testWidgets('$role $id', (tester) async {
            final w = gWidths[id] ?? 390;
            tester.view.physicalSize = w >= 1000 ? const Size(1280, 900) : (w == 720 ? const Size(720, 1280) : const Size(390, 900));
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            await tester.pumpWidget(ProviderScope(overrides: [initialAccountProvider.overrideWithValue(compte)], child: BoutikEcoleApp(initialLocation: '/s/$id')));
            await settleReal(tester);
            final hits = <String>{};
            final err = tester.takeException();
            if (err != null) hits.add('exception/débordement : ${'$err'.split('\n').first}');
            textes.writeln('== $id');
            for (final t in tester.widgetList<RichText>(find.byType(RichText))) {
              final txt = _norm(t.text.toPlainText());
              if (txt.isEmpty || txt.startsWith('Ex.')) continue; // exemples de saisie (placeholders)
              textes.writeln('  $txt');
              final nombres = RegExp(r'\d+').allMatches(txt).map((m) => m.group(0)!);
              final zeroReel = !muet && nombres.isNotEmpty && nombres.every((n) => int.parse(n) == 0) && !txt.contains('%') && !txt.contains(':');
              final calendrier = _ecransCalendrier.contains(id) && (RegExp(r'^\d{1,2}$').hasMatch(txt) || RegExp(r'^\p{L}+ 20\d\d$', unicode: true).hasMatch(txt));
              final tolere = (_toleresParEcran[id]?.hasMatch(txt) ?? false) || (!muet && (_toleresVide[id]?.hasMatch(txt) ?? false));
              if (nombres.isNotEmpty && !_structurel.hasMatch(txt) && !zeroReel && !calendrier && !tolere) hits.add('chiffre « $txt »');
              for (final n in _noms) {
                if (txt.contains(n)) hits.add('maquette « $n »');
              }
              if (txt.contains('9:41')) hits.add('heure 9:41');
            }
            void photo(ImageProvider p) {
              if (p is AssetImage && gIsMockPhoto(p.assetName) && !_photosTolerees.any(p.assetName.contains)) hits.add('photo ${p.assetName.split('/').last}');
            }

            for (final i in tester.widgetList<Image>(find.byType(Image))) {
              photo(i.image);
            }
            for (final d in tester.widgetList<DecoratedBox>(find.byType(DecoratedBox))) {
              final dec = d.decoration;
              if (dec is BoxDecoration && dec.image != null) photo(dec.image!.image);
            }
            if (hits.isNotEmpty) trouves[id] = hits.toList();
            await tester.pumpWidget(const SizedBox());
            await tester.pump(const Duration(seconds: 60));
          });
        }
      });
    }
  }
}
