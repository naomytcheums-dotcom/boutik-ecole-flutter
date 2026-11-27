import 'dart:convert';
import 'dart:typed_data';

import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/media_access.dart';
import 'package:boutik_ecole/figma/live/social_posts.dart' show uploadPostMedia;
import 'package:boutik_ecole/figma/live/stories.dart' show Story;
import 'package:cross_file/cross_file.dart' show XFile;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_supabase.dart';

/// Fichier choisi simulé : 3 octets, nom photo.jpg.
final class _Photo extends PlatformFile {
  @override
  String get name => 'photo.jpg';
  @override
  Uri get uri => Uri.parse('memory:photo.jpg');
  @override
  XFile get xFile => throw UnimplementedError();
  @override
  int? lengthSync() => 3;
  @override
  Future<int?> length() async => 3;
  @override
  Future<Uint8List> readAsBytes() async => Uint8List.fromList([1, 2, 3]);
  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(Uint8List.fromList([1, 2, 3]));
}

/// H13.1 · médias : un média non public (histoire, communauté fermée) est déposé dans le compartiment privé `post-media-private` et lu par URL signée (1 h au plus) ;
/// un média public garde l'URL publique ; les anciens fichiers basculés côté serveur sont retrouvés par `post_media_targets`. Faux serveur local.
void main() {
  late FakeSupabase srv;
  const uid = FakeSupabase.userId;
  setUpAll(() async {
    srv = await FakeSupabase.start();
    await srv.initSupabase();
  });
  tearDownAll(() => srv.close());
  setUp(() {
    Backend.ready = true;
    srv.rpc.clear();
    srv.calls.clear();
    srv.failStorage = false;
    MediaAccess.reset();
  });

  List<String> storagePaths({String? method}) => [for (final c in srv.calls) if (c.kind == 'storage' && (method == null || c.args['method'] == method)) c.name];

  test('chemins : un nouveau fichier privé porte le repère /private/, un fichier public non', () {
    final priv = MediaAccess.newPath(uid, 'jpg', private: true), pub = MediaAccess.newPath(uid, 'jpg');
    expect(priv, startsWith('$uid/private/'));
    expect(MediaAccess.isPrivatePath(priv), isTrue);
    expect(MediaAccess.isPrivatePath(pub), isFalse);
    expect(MediaAccess.isPrivatePath('$uid/ancien.jpg'), isFalse);
    expect(MediaAccess.bucketOf(priv), 'post-media-private');
    expect(MediaAccess.bucketOf(pub), 'post-media');
    expect(MediaAccess.ttlSeconds, lessThanOrEqualTo(3600));
  });

  test('média public : URL publique inchangée, aucune signature demandée', () async {
    final p = '$uid/public.jpg';
    await MediaAccess.warm([p]);
    expect(Backend.postMediaUrl(p), contains('/storage/v1/object/public/post-media/$p'));
    expect(storagePaths().where((x) => x.contains('/sign/')), isEmpty);
  });

  test('média privé : URL signée de 1 h au plus, jamais l\'URL publique', () async {
    final p = '$uid/private/1.jpg';
    expect(Backend.postMediaUrl(p), contains('/object/public/'), reason: 'avant préparation : repli sur l\'ancien comportement');
    await MediaAccess.warm([p]);
    final url = Backend.postMediaUrl(p);
    expect(url, contains('/object/sign/'));
    expect(url, isNot(contains('/object/public/')));
    final sign = srv.calls.where((c) => c.kind == 'storage' && c.name.contains('/sign/post-media-private/')).toList();
    expect(sign, hasLength(1));
    expect((jsonDecode('${sign.first.args['sign']}') as Map)['expiresIn'], lessThanOrEqualTo(3600));
    await MediaAccess.warm([p]);
    expect(srv.calls.where((c) => c.kind == 'storage' && c.name.contains('/sign/')), hasLength(1), reason: 'URL réutilisée tant qu\'elle est valable');
  });

  test('ancien fichier basculé par le serveur : retrouvé par post_media_targets puis signé ; les autres restent publics', () async {
    final moved = '$uid/ancien_bascule.jpg', open = '$uid/ancien_public.jpg';
    srv.rpc['post_media_targets'] = (a) => {moved: 'post-media-private'};
    await MediaAccess.warm([moved, open]);
    expect(srv.callsOf('post_media_targets'), hasLength(1));
    expect(srv.callsOf('post_media_targets').first.args['p_paths'], containsAll([moved, open]));
    expect(Backend.postMediaUrl(moved), contains('/object/sign/'));
    expect(Backend.postMediaUrl(open), contains('/object/public/post-media/'));
    await MediaAccess.warm([open]);
    expect(srv.callsOf('post_media_targets'), hasLength(1), reason: 'résultat public mémorisé');
  });

  test('serveur de cibles en panne : repli sur l\'URL publique, sans erreur', () async {
    srv.failRpc.add('post_media_targets');
    final p = '$uid/ancien.jpg';
    await MediaAccess.warm([p]);
    expect(Backend.postMediaUrl(p), contains('/object/public/post-media/'));
  });

  test('histoire : le média privé de la ligne est signé, le média public reste public', () async {
    await MediaAccess.warm(['$uid/private/s1.jpg', '$uid/s2.jpg']);
    Map<String, dynamic> row(String id, String path) => {'id': id, 'author_id': uid, 'author': 'Awa A.', 'media_path': path, 'media_kind': 'image', 'caption': '', 'created_at': '2026-11-27T08:00:00Z', 'seen': false};
    expect(Story.fromRow(row('1', '$uid/private/s1.jpg')).mediaUrl, contains('/object/sign/'));
    expect(Story.fromRow(row('2', '$uid/s2.jpg')).mediaUrl, contains('/object/public/'));
  });

  testWidgets('dépôt : privé => compartiment post-media-private sous <uid>/private/ ; public => post-media', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));
    final file = _Photo();
    final priv = (await tester.runAsync(() => uploadPostMedia(ctx, file, private: true)))!;
    final pub = (await tester.runAsync(() => uploadPostMedia(ctx, file)))!;
    expect(priv.path, startsWith('$uid/private/'));
    expect(pub.path, isNot(contains('/private/')));
    final up = storagePaths(method: 'POST');
    expect(up.any((p) => p.contains('/object/post-media-private/${priv.path}')), isTrue, reason: '$up');
    expect(up.any((p) => p.endsWith('/object/post-media/${pub.path}')), isTrue, reason: '$up');
  });

  test('suppression : un fichier privé est retiré du compartiment privé, un fichier public de post-media', () async {
    await Backend.removeFile('post-media', '$uid/private/x.jpg');
    await Backend.removeFile('post-media', '$uid/y.jpg');
    final del = storagePaths(method: 'DELETE');
    expect(del, contains('/storage/v1/object/post-media-private'));
    expect(del, contains('/storage/v1/object/post-media'));
  });
}
