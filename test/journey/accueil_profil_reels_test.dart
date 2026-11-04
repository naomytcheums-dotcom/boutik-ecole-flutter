import 'package:boutik_ecole/figma/g/g_03.dart';
import 'package:boutik_ecole/figma/g/g_18c.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/home_live.dart';
import 'package:boutik_ecole/figma/live/profile_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

class _Talents extends TalentsNotifier {
  _Talents(this.v);
  final List<LiveTalent>? v;
  @override
  List<LiveTalent>? build() => v;
}

class _Docs extends DocsNotifier {
  _Docs(this.v);
  final List<UserDoc>? v;
  @override
  List<UserDoc>? build() => v;
}

void main() {
  setUpAll(loadAppFonts);
  setUp(() => GScreen.mockupFrame = false);
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = false;
  });

  Future<void> monter(WidgetTester t, Widget ecran, {required bool connecte, List<LiveTalent>? talents, List<UserDoc>? docs, bool connectedUser = false, Size size = const Size(393, 852)}) async {
    Backend.ready = connecte;
    GAnim.enabled = false;
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(
      overrides: [liveTalentsProvider.overrideWith(() => _Talents(talents)), myDocsProvider.overrideWith(() => _Docs(docs))],
      child: MaterialApp(home: ecran),
    ));
    await t.pumpAndSettle();
    if (connectedUser) {
      ProviderScope.containerOf(t.element(find.byWidget(ecran))).read(authProvider.notifier).login(demoAccount);
      await t.pumpAndSettle();
    }
  }

  testWidgets('accueil connecté : aucun produit ni profil de maquette, états vides explicites', (t) async {
    await monter(t, const G_03(), connecte: true, talents: const []);
    expect(find.text('Lampe en bois recyclé'), findsNothing);
    expect(find.text('Drone éducatif'), findsNothing);
    expect(find.textContaining('Ngoné'), findsNothing);
    expect(find.text('Aucun produit publié pour le moment.\nLes créations des étudiants apparaîtront ici dès leur publication.'), findsOneWidget);
  });

  testWidgets('accueil connecté : « Talents à découvrir » est atteignable au défilement, au-dessus du menu', (t) async {
    final talents = [
      const LiveTalent(id: '1', name: 'Alice Test', department: 'Informatique', skills: 'Flutter, API', avatarUrl: '', certified: true),
      const LiveTalent(id: '2', name: 'Bruno Test', department: '', skills: 'Montage', avatarUrl: '', certified: false),
    ];
    for (final size in const [Size(360, 640), Size(393, 852)]) {
      await monter(t, const G_03(), connecte: true, talents: talents, connectedUser: true, size: size);
      final scroll = t.state<ScrollableState>(find.descendant(of: find.byType(SingleChildScrollView).first, matching: find.byType(Scrollable)).first);
      for (var i = 0; i < 30 && scroll.position.pixels < scroll.position.maxScrollExtent; i++) {
        await t.dragFrom(Offset(size.width / 2, size.height / 2), const Offset(0, -300));
        await t.pump();
      }
      expect(scroll.position.pixels, scroll.position.maxScrollExtent);
      expect(find.text('Alice Test'), findsOneWidget);
      // la carte est entièrement visible et ne passe pas sous le menu fixe du bas
      final carte = t.getRect(find.text('Alice Test'));
      expect(carte.bottom, lessThan(size.height - 80), reason: 'le talent est masqué par le menu à ${size.width}×${size.height}');
      expect(carte.top, greaterThan(0));
    }
  });

  testWidgets('accueil hors connexion : la démonstration reste affichée', (t) async {
    await monter(t, const G_03(), connecte: false);
    expect(find.text('Lampe en bois recyclé'), findsWidgets);
  });

  testWidgets('18c connecté : matricule vide (jamais prérempli), aucune pièce fictive', (t) async {
    await monter(t, const G_18c(), connecte: true, docs: const []);
    expect(find.text('IUT-2023-0412'), findsNothing);
    expect(find.text('Génie informatique'), findsNothing);
    expect(find.text('carte_etudiant.jpg • 1,2 Mo'), findsNothing);
    expect(find.text('Sélectionnez votre filière'), findsOneWidget);
    expect(find.text('Appuyez pour téléverser'), findsOneWidget);
  });

  testWidgets('18c connecté : la pièce envoyée est affichée avec son nom, sa taille et son état', (t) async {
    final d = UserDoc(id: '1', kind: 'student_card', name: 'ma_carte.jpg', path: 'u/student_card/1', size: 1300000, status: 'pending', note: '', createdAt: DateTime(2026, 11, 4));
    await monter(t, const G_18c(), connecte: true, docs: [d]);
    expect(find.text('ma_carte.jpg • 1,2 Mo • En attente'), findsOneWidget);
  });

  group('contrôles d’envoi et de saisie', () {
    const docs = {'application/pdf', 'image/jpeg', 'image/png', 'image/webp'};
    test('format accepté, refusé, taille et fichier vide', () {
      expect(checkUpload(name: 'cert.PDF', size: 1000, mimes: docs, maxBytes: maxDocBytes), isNull);
      expect(checkUpload(name: 'virus.exe', size: 1000, mimes: docs, maxBytes: maxDocBytes), contains('Format refusé'));
      expect(checkUpload(name: 'a.pdf', size: maxDocBytes + 1, mimes: docs, maxBytes: maxDocBytes), contains('trop lourd'));
      expect(checkUpload(name: 'a.pdf', size: 0, mimes: docs, maxBytes: maxDocBytes), contains('vide'));
      expect(checkUpload(name: 'v.mp4', size: 10, mimes: const {'image/jpeg'}, maxBytes: maxAvatarBytes), contains('Format refusé'));
    });
    test('taille lisible', () {
      expect(sizeLabel(1300000), '1,2 Mo');
      expect(sizeLabel(2048), '2 Ko');
    });
  });
}
