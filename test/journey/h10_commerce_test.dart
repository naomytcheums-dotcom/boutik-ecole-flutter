import 'dart:typed_data';

import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/digital_seller.dart';
import 'package:boutik_ecole/figma/live/downloads.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/render.dart';

/// H10 · commerce : ressources numériques livrables. « Mes téléchargements » (muet / vide / liste / refus serveur / erreur 500),
/// formulaire vendeur (licence, fichiers vers le compartiment privé, refus), mention sur la fiche produit. Faux serveur local, aucune ressource d'exemple.
const _listing = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

Map<String, dynamic> _file(String id, String name, {int size = 2048, String v = '1.0'}) => {'id': id, 'file_name': name, 'mime_type': 'application/pdf', 'size_bytes': size, 'version': v};

Map<String, dynamic> _item(String line, String title, {String status = 'active', int used = 1, int max = 5, List<Map<String, dynamic>>? files, String? reason, String kind = 'commercial'}) => {
      'order_line': line,
      'listing_id': _listing,
      'title': title,
      'order_number': '#BE-2026-0$line',
      'license_kind': kind,
      'license_label': 'Un seul client final',
      'status': status,
      'reason': reason,
      'downloads_used': used,
      'max_downloads': max,
      'granted_at': '2026-11-20T10:00:00Z',
      'files': files ?? [_file('f$line', 'modele-$line.pdf')],
      'history': const [],
    };

void main() {
  late FakeSupabase srv;
  setUpAll(() async {
    await loadAppFonts();
    srv = await FakeSupabase.start();
    await srv.initSupabase();
  });
  tearDownAll(() => srv.close());

  final openedUrls = <String>[];
  final signed = <String>[];
  var signResult = 'https://signed.test/fichier?token=t';
  var openResult = true;

  setUp(() {
    GScreen.mockupFrame = false;
    GAnim.enabled = false;
    Backend.ready = true;
    srv.rpc.clear();
    srv.tables.clear();
    srv.calls.clear();
    srv.failRpc.clear();
    srv.unknownIsError = false;
    srv.failStorage = false;
    openedUrls.clear();
    signed.clear();
    signResult = 'https://signed.test/fichier?token=t';
    openResult = true;
    digitalSigner = (bucket, path, seconds) async {
      signed.add('$bucket|$path|$seconds');
      return signResult.isEmpty ? null : signResult;
    };
    digitalOpener = (url) async {
      openedUrls.add(url);
      return openResult;
    };
  });
  tearDown(() => GScreen.mockupFrame = true);

  Future<void> host(WidgetTester t, Widget child) async {
    t.view.physicalSize = const Size(420, 3200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(child: MaterialApp(home: child)));
    await t.pump(const Duration(milliseconds: 200));
  }

  Future<void> settle(WidgetTester t) => settleReal(t, rounds: 6, ms: 40);

  Future<void> attendre(WidgetTester t, Finder f) async {
    for (var i = 0; i < 60 && f.evaluate().isEmpty; i++) {
      await settleReal(t, rounds: 2, ms: 100);
    }
  }

  Future<void> fin(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 60));
  }

  group('Mes téléchargements (acheteur)', () {
    testWidgets('serveur muet (404) : message honnête, aucune ressource, bouton Réessayer', (t) async {
      srv.unknownIsError = true;
      await host(t, const DownloadsScreen());
      await attendre(t, find.text('Réessayer'));
      expect(find.textContaining('n’est pas disponible pour le moment'), findsOneWidget);
      expect(find.text('Télécharger'), findsNothing);
      await fin(t);
    });

    testWidgets('panne serveur (500) sur la liste : erreur lisible, jamais « aucune ressource »', (t) async {
      srv.failRpc.add('my_downloads');
      await host(t, const DownloadsScreen());
      await attendre(t, find.text('Réessayer'));
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.textContaining('aucune ressource numérique'), findsNothing);
      await fin(t);
    });

    testWidgets('liste vide : état vide, pas d\'exemple', (t) async {
      srv.rpc['my_downloads'] = (_) => <Map<String, dynamic>>[];
      await host(t, const DownloadsScreen());
      await attendre(t, find.textContaining('aucune ressource numérique'));
      expect(find.textContaining('aucune ressource numérique'), findsOneWidget);
      expect(find.text('Télécharger'), findsNothing);
      await fin(t);
    });

    testWidgets('liste : disponible, révoquée (remboursée) et limite atteinte ; téléchargement = RPC puis URL signée courte', (t) async {
      srv.rpc['my_downloads'] = (_) => [
            _item('1', 'Template A'),
            _item('2', 'Plan B', status: 'revoked', files: const [], reason: 'Commande remboursée : téléchargement impossible'),
            _item('3', 'Guide C', used: 2, max: 2),
          ];
      srv.rpc['digital_download_url'] = (a) => {'bucket': 'digital-files', 'path': 'u/l/modele-1.pdf', 'file_name': 'modele-1.pdf', 'expires_in': 60, 'downloads_used': 2, 'max_downloads': 5, 'remaining': 3};
      await host(t, const DownloadsScreen());
      await attendre(t, find.text('Template A'));
      expect(find.text('Disponible · 1 téléchargement sur 5'), findsOneWidget);
      expect(find.text('Accès révoqué : Commande remboursée : téléchargement impossible'), findsOneWidget);
      expect(find.text('Limite de téléchargements atteinte (2 sur 2)'), findsOneWidget);
      expect(find.text('Télécharger'), findsNWidgets(2));
      expect(find.textContaining('Licence commerciale : Un seul client final'), findsNWidgets(3));
      expect(find.text('PDF · 2 Ko · version 1.0'), findsNWidgets(2));
      // le bouton de la ressource à limite atteinte est inactif : aucun appel
      await t.tap(find.text('Télécharger').at(1));
      await settle(t);
      expect(srv.callsOf('digital_download_url'), isEmpty);
      await t.tap(find.text('Télécharger').first);
      await settle(t);
      await attendre(t, find.textContaining('Téléchargement lancé'));
      final calls = srv.callsOf('digital_download_url');
      expect(calls, hasLength(1));
      expect(calls.first.args, {'p_order_line': '1', 'p_asset': 'f1'});
      expect(signed, ['digital-files|u/l/modele-1.pdf|60']);
      expect(openedUrls, ['https://signed.test/fichier?token=t']);
      expect(find.textContaining('Téléchargement lancé : modele-1.pdf'), findsOneWidget);
      await fin(t);
    });

    testWidgets('refus du serveur (limite, paiement, remboursement) : message du serveur, aucune URL créée ni ouverte', (t) async {
      srv.rpc['my_downloads'] = (_) => [_item('1', 'Template A')];
      srv.rpc['digital_download_url'] = (_) => throw const FakeRpcError('Limite de téléchargements atteinte (5 sur 5)');
      await host(t, const DownloadsScreen());
      await attendre(t, find.text('Télécharger'));
      await t.tap(find.text('Télécharger'));
      await settle(t);
      await attendre(t, find.textContaining('Limite de téléchargements atteinte (5 sur 5)'));
      expect(find.textContaining('Limite de téléchargements atteinte (5 sur 5)'), findsWidgets);
      expect(find.textContaining('Téléchargement lancé'), findsNothing);
      expect(signed, isEmpty);
      expect(openedUrls, isEmpty);
      await fin(t);
    });

    testWidgets('erreur 500 sur le téléchargement : aucune confirmation, aucune URL', (t) async {
      srv.rpc['my_downloads'] = (_) => [_item('1', 'Template A')];
      srv.failRpc.add('digital_download_url');
      await host(t, const DownloadsScreen());
      await attendre(t, find.text('Télécharger'));
      await t.tap(find.text('Télécharger'));
      await settle(t);
      expect(srv.callsOf('digital_download_url'), hasLength(1));
      expect(find.textContaining('Téléchargement lancé'), findsNothing);
      expect(signed, isEmpty);
      expect(openedUrls, isEmpty);
      await fin(t);
    });

    testWidgets('URL signée impossible à créer : message honnête (le serveur a compté), rien n\'est ouvert', (t) async {
      srv.rpc['my_downloads'] = (_) => [_item('1', 'Template A')];
      srv.rpc['digital_download_url'] = (_) => {'bucket': 'digital-files', 'path': 'u/l/a.pdf', 'file_name': 'a.pdf', 'expires_in': 60};
      signResult = '';
      await host(t, const DownloadsScreen());
      await attendre(t, find.text('Télécharger'));
      await t.tap(find.text('Télécharger'));
      await settle(t);
      await attendre(t, find.textContaining('n’a pas pu être créé'));
      expect(find.textContaining('n’a pas pu être créé'), findsWidgets);
      expect(find.textContaining('Téléchargement lancé'), findsNothing);
      expect(openedUrls, isEmpty);
      await fin(t);
    });
  });

  group('Fiche produit : mention ressource numérique', () {
    Future<void> info(WidgetTester t) => host(t, const Scaffold(body: SingleChildScrollView(child: DigitalProductInfo(listingId: _listing))));

    testWidgets('ressource numérique : licence du vendeur, format, taille, version, limite', (t) async {
      srv.rpc['product_digital_info'] = (_) => {
            'digital': true,
            'license_kind': 'educational',
            'license_label': 'Usage en classe, un enseignant',
            'max_downloads': 3,
            'files': [{'format': 'ZIP', 'mime_type': 'application/zip', 'size_bytes': 3145728, 'version': '2.1'}],
          };
      await info(t);
      await attendre(t, find.text('Ressource numérique'));
      expect(find.text('Licence éducative : Usage en classe, un enseignant'), findsOneWidget);
      expect(find.text('ZIP · 3,0 Mo · version 2.1'), findsOneWidget);
      expect(find.textContaining('3 téléchargements au maximum'), findsOneWidget);
      await fin(t);
    });

    testWidgets('produit ordinaire : aucune mention ; panne 500 : message honnête, pas de mention inventée', (t) async {
      srv.rpc['product_digital_info'] = (_) => {'digital': false};
      await info(t);
      await settle(t);
      expect(find.text('Ressource numérique'), findsNothing);
      await fin(t);
      srv.failRpc.add('product_digital_info');
      await info(t);
      await attendre(t, find.textContaining('Informations de licence indisponibles'));
      expect(find.textContaining('Informations de licence indisponibles'), findsOneWidget);
      expect(find.text('Ressource numérique'), findsNothing);
      await fin(t);
    });
  });

  group('Formulaire vendeur de ressource numérique', () {
    var digital = false;
    final assets = <Map<String, dynamic>>[];

    setUp(() {
      digital = false;
      assets.clear();
      srv.rpc['my_digital_listing'] = (_) => digital
          ? {'digital': true, 'license_kind': 'commercial', 'license_label': 'Un seul client final', 'max_downloads': 4, 'assets': List<Map<String, dynamic>>.from(assets)}
          : {'digital': false};
      srv.rpc['seller_digital_sales'] = (_) => [
            {'id': 'e1', 'listing_id': _listing, 'title': 'Template', 'order_number': '#BE-2026-0001', 'status': 'active', 'downloads_used': 1, 'max_downloads': 4},
            {'id': 'e2', 'listing_id': 'autre', 'title': 'Autre', 'order_number': '#BE-2026-0002', 'status': 'active', 'downloads_used': 0, 'max_downloads': 4},
          ];
      pickDigitalFile = () async => (name: 'plan.pdf', bytes: Uint8List.fromList(List.filled(2048, 1)));
    });

    Future<void> form(WidgetTester t) => host(t, const DigitalResourceScreen(listing: {'id': _listing, 'title': 'Template', 'status': 'draft'}));

    testWidgets('annonce non numérique : pas d\'ajout de fichier avant la licence ; les ventes d\'une autre annonce ne sont pas listées', (t) async {
      await form(t);
      await attendre(t, find.text('Enregistrer la licence'));
      expect(find.text('Enregistrez la licence pour pouvoir ajouter des fichiers.'), findsOneWidget);
      expect(find.text('Ajouter un fichier'), findsNothing);
      expect(find.text('Envoyer en validation'), findsNothing);
      expect(find.textContaining('Commande #BE-2026-0001'), findsOneWidget);
      expect(find.textContaining('Commande #BE-2026-0002'), findsNothing);
      await fin(t);
    });

    testWidgets('licence : libellé trop court refusé sans appel ; enregistrement = RPC avec les valeurs saisies', (t) async {
      srv.rpc['digital_listing_save'] = (a) {
        digital = true;
        return {'digital': true};
      };
      await form(t);
      await attendre(t, find.text('Enregistrer la licence'));
      await t.tap(find.text('Enregistrer la licence'));
      await settle(t);
      expect(srv.callsOf('digital_listing_save'), isEmpty);
      expect(find.textContaining('Décrivez votre licence'), findsOneWidget);
      await t.enterText(find.byType(TextField).at(0), 'Un seul client final');
      await t.tap(find.text('Commerciale'));
      await t.pump();
      await t.tap(find.text('Enregistrer la licence'));
      await settle(t);
      await attendre(t, find.text('Ajouter un fichier'));
      final c = srv.callsOf('digital_listing_save');
      expect(c, hasLength(1));
      expect(c.first.args, {'p_listing': _listing, 'p_kind': 'commercial', 'p_label': 'Un seul client final', 'p_max': 5});
      expect(find.text('Ajouter un fichier'), findsOneWidget);
      expect(find.textContaining('Commande #BE-2026-0001'), findsOneWidget);
      await fin(t);
    });

    testWidgets('licence : erreur 500 → message, aucune confirmation, ajout de fichier toujours fermé', (t) async {
      srv.failRpc.add('digital_listing_save');
      await form(t);
      await attendre(t, find.text('Enregistrer la licence'));
      await t.enterText(find.byType(TextField).at(0), 'Un seul client final');
      await t.tap(find.text('Enregistrer la licence'));
      await settle(t);
      expect(srv.callsOf('digital_listing_save'), hasLength(1));
      expect(find.text('Licence enregistrée.'), findsNothing);
      expect(find.text('Ajouter un fichier'), findsNothing);
      await fin(t);
    });

    testWidgets('fichier : téléversement dans digital-files puis enregistrement serveur ; la liste se recharge', (t) async {
      digital = true;
      srv.rpc['digital_asset_register'] = (a) {
        assets.add({'id': 'a1', 'file_name': a['p_name'], 'mime_type': a['p_mime'], 'size_bytes': a['p_size'], 'version': a['p_version']});
        return 'a1';
      };
      await form(t);
      await attendre(t, find.text('Ajouter un fichier'));
      await t.tap(find.text('Ajouter un fichier'));
      await settle(t);
      await attendre(t, find.text('plan.pdf'));
      expect(srv.calls.where((c) => c.kind == 'storage' && c.name.contains('/digital-files/')), isNotEmpty);
      final reg = srv.callsOf('digital_asset_register');
      expect(reg, hasLength(1));
      expect(reg.first.args['p_listing'], _listing);
      expect(reg.first.args['p_mime'], 'application/pdf');
      expect(reg.first.args['p_size'], 2048);
      expect(reg.first.args['p_version'], '1.0');
      expect((reg.first.args['p_path'] as String).startsWith('${FakeSupabase.userId}/$_listing/'), isTrue);
      expect(find.text('plan.pdf'), findsOneWidget);
      expect(find.text('Envoyer en validation'), findsOneWidget);
      await fin(t);
    });

    testWidgets('fichier : type interdit (.exe) refusé sans aucun envoi ; stockage en panne : message, aucun enregistrement', (t) async {
      digital = true;
      await form(t);
      await attendre(t, find.text('Ajouter un fichier'));
      pickDigitalFile = () async => (name: 'virus.exe', bytes: Uint8List.fromList([1, 2, 3]));
      await t.tap(find.text('Ajouter un fichier'));
      await settle(t);
      expect(find.textContaining('Type de fichier refusé'), findsOneWidget);
      expect(srv.calls.where((c) => c.kind == 'storage'), isEmpty);
      pickDigitalFile = () async => (name: 'plan.pdf', bytes: Uint8List.fromList(List.filled(100, 1)));
      srv.failStorage = true;
      await t.tap(find.text('Ajouter un fichier'));
      await settle(t);
      expect(srv.calls.where((c) => c.kind == 'storage'), isNotEmpty);
      expect(srv.callsOf('digital_asset_register'), isEmpty);
      expect(find.textContaining('Fichier ajouté'), findsNothing);
      await fin(t);
    });

    testWidgets('fichier refusé par le serveur : fichier retiré du stockage, message affiché, aucune confirmation', (t) async {
      digital = true;
      srv.rpc['digital_asset_register'] = (_) => throw const FakeRpcError('Fichier trop lourd (50 Mo au maximum)');
      await form(t);
      await attendre(t, find.text('Ajouter un fichier'));
      await t.tap(find.text('Ajouter un fichier'));
      await settle(t);
      await attendre(t, find.textContaining('Fichier trop lourd'));
      expect(find.textContaining('Fichier trop lourd'), findsWidgets);
      expect(srv.calls.where((c) => c.kind == 'storage').length, greaterThanOrEqualTo(2));
      expect(find.textContaining('Fichier ajouté'), findsNothing);
      await fin(t);
    });

    testWidgets('envoi en validation : erreur du serveur affichée, statut inchangé', (t) async {
      digital = true;
      assets.add({'id': 'a1', 'file_name': 'plan.pdf', 'mime_type': 'application/pdf', 'size_bytes': 2048, 'version': '1.0'});
      await form(t);
      await attendre(t, find.text('Envoyer en validation'));
      await t.tap(find.text('Envoyer en validation'));
      await settle(t);
      expect(srv.calls.any((c) => c.kind == 'write' && c.name == 'listings'), isTrue);
      expect(find.text('Cette ressource est en validation.'), findsNothing);
      expect(find.text('Ressource envoyée en validation.'), findsNothing);
      await fin(t);
    });
  });
}
