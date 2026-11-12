import 'package:boutik_ecole/figma/live/community_media.dart';
import 'package:boutik_ecole/figma/live/innovations_screens.dart' show LevelBadge;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester t, Widget w) async {
  t.view.physicalSize = const Size(420, 1200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(home: Scaffold(body: w)));
  await t.pumpAndSettle();
}

void main() {
  niveauTests();
  test('lien : mêmes règles que le serveur', () {
    expect(isValidWebLink('https://developer.mozilla.org/fr/'), isTrue);
    expect(isValidWebLink('http://exemple.cm'), isTrue);
    expect(isValidWebLink(' https://exemple.cm '), isTrue, reason: 'les espaces autour sont retirés');
    expect(isValidWebLink('javascript:alert(1)'), isFalse);
    expect(isValidWebLink('exemple.cm'), isFalse);
    expect(isValidWebLink('https://a.cm/ x'), isFalse);
    expect(isValidWebLink('https://${'a' * 600}.cm'), isFalse);
  });

  test('pièce jointe : libellé', () {
    expect(const PostAttachment.link('https://a.cm').label, 'https://a.cm');
    expect(const PostAttachment.media(kind: 'image', path: 'u/1.jpg', name: 'labo.jpg').label, 'labo.jpg');
    expect(const PostAttachment.media(kind: 'video', path: 'u/1.mp4').label, 'Vidéo');
    expect(const PostAttachment.media(kind: 'image', path: 'u/1.jpg').label, 'Photo');
  });

  testWidgets('aperçu de la pièce jointe : on peut la retirer', (t) async {
    var removed = false;
    await _pump(t, AttachmentChip(attachment: const PostAttachment.link('https://a.cm/page'), onRemove: () => removed = true));
    expect(find.text('https://a.cm/page'), findsOneWidget);
    await t.tap(find.byTooltip('Retirer la pièce jointe'));
    expect(removed, isTrue);
  });

  testWidgets('fil : lien cliquable, vidéo avec lecteur, publication simple sans pièce jointe', (t) async {
    await _pump(t, Column(children: [
      PostAttachmentView(post: const {'link_url': 'https://developer.mozilla.org/fr/'}),
      PostAttachmentView(post: const {'media_path': 'u/2.mp4', 'media_kind': 'video'}),
      PostAttachmentView(post: const {}),
    ]));
    expect(find.text('https://developer.mozilla.org/fr/'), findsOneWidget);
    expect(find.text('Lire la vidéo'), findsOneWidget);
    expect(find.byIcon(Icons.link), findsOneWidget);
  });
}

// ---- badge de niveau (points) sur les profils
void niveauTests() {
  testWidgets('badge de niveau : visible seulement avec un niveau', (t) async {
    await _pump(t, const Column(children: [LevelBadge(level: 'silver'), LevelBadge(level: 'none'), LevelBadge(level: 'legend', compact: true)]));
    expect(find.text('Aidant Argent'), findsOneWidget);
    expect(find.text('Légende IUT'), findsOneWidget);
    expect(find.text('Pas encore de niveau'), findsNothing);
  });
}
