import 'package:boutik_ecole/figma/i18n.dart' show I18n;
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/translate_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_supabase.dart' hide settleReal;
import '../helpers/fake_supabase.dart' as fs show settleReal;
import '../helpers/render.dart';

Future<void> settleReal(WidgetTester t) => fs.settleReal(t, rounds: 25, ms: 60);

/// H10 · IA : bouton « Traduire » d'un message (faux serveur local, aucun fournisseur réel).
/// Prouve : états non configuré / en cours / erreur / traduit ; jamais de texte sans réponse du serveur ; appels vers la fonction `translate` avec message et langue ;
/// seuls les messages texte reçus et enregistrés sont traduisibles.
void main() {
  late FakeSupabase fake;

  setUpAll(() async {
    await loadAppFonts();
    fake = await FakeSupabase.start();
    await fake.initSupabase();
  });
  tearDownAll(() => fake.close());

  setUp(() {
    Backend.ready = true;
    fake.functions.clear();
    fake.calls.clear();
    I18n.lang = 'fr';
  });
  tearDown(() => Backend.ready = false);

  Future<void> fin(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 60));
  }

  Widget host() => const MaterialApp(home: Scaffold(body: Padding(padding: EdgeInsets.all(20), child: TranslateMessageButton(messageId: 42))));

  testWidgets('serveur non configuré (503 not_configured) : message honnête, aucun texte traduit, nouvel essai possible', (tester) async {
    fake.functions['translate'] = (_) => (status: 503, body: {'error': 'not_configured', 'code': 'not_configured', 'message': 'La traduction n’est pas configurée pour le moment. Aucun texte n’est inventé.'});
    await tester.pumpWidget(host());
    expect(find.text('Traduire'), findsOneWidget);
    await tester.tap(find.text('Traduire'));
    await tester.pump();
    expect(find.text('Traduction en cours…'), findsOneWidget);
    await settleReal(tester);
    expect(find.textContaining('n’est pas configurée pour le moment'), findsOneWidget);
    expect(find.text('Masquer la traduction'), findsNothing);
    expect(find.byType(SelectableText), findsNothing);
    expect(fake.callsOf('translate').single.args, {'message_id': 42, 'target_lang': 'fr'});
    await tester.tap(find.textContaining('Réessayer'));
    await settleReal(tester);
    expect(fake.callsOf('translate'), hasLength(2));
    await fin(tester);
  });

  testWidgets('erreur du fournisseur (502) : échec annoncé, pas de texte ; réessai réussi : traduction affichée puis masquable', (tester) async {
    var n = 0;
    fake.functions['translate'] = (_) {
      n++;
      return n == 1
          ? (status: 502, body: {'error': 'provider_error', 'code': 'provider_error', 'message': 'Le service de traduction est momentanément indisponible. Réessayez plus tard.'})
          : (status: 200, body: {'status': 'translated', 'text': 'Hello, the quote is ready.', 'source_lang': 'fr', 'target_lang': 'en', 'cached': false});
    };
    I18n.lang = 'en';
    await tester.pumpWidget(host());
    await tester.tap(find.text('Traduire'));
    await settleReal(tester);
    expect(find.textContaining('momentanément indisponible'), findsOneWidget);
    expect(find.byType(SelectableText), findsNothing);
    await tester.tap(find.textContaining('Réessayer'));
    await settleReal(tester);
    expect(find.text('Hello, the quote is ready.'), findsOneWidget);
    expect(fake.callsOf('translate').last.args['target_lang'], 'en');
    await tester.tap(find.text('Masquer la traduction'));
    await tester.pump();
    expect(find.text('Hello, the quote is ready.'), findsNothing);
    await tester.tap(find.text('Voir la traduction'));
    await tester.pump();
    expect(find.text('Hello, the quote is ready.'), findsOneWidget);
    expect(fake.callsOf('translate'), hasLength(2));
    await fin(tester);
  });

  testWidgets('réponse vide ou inattendue du serveur : erreur, jamais une traduction vide', (tester) async {
    fake.functions['translate'] = (_) => (status: 200, body: {'status': 'translated', 'text': '   '});
    await tester.pumpWidget(host());
    await tester.tap(find.text('Traduire'));
    await settleReal(tester);
    expect(find.textContaining('n’a pas pu être obtenue'), findsOneWidget);
    expect(find.byType(SelectableText), findsNothing);
    await fin(tester);
  });

  testWidgets('message d\'une conversation étrangère (404) et session expirée (401) : messages dédiés', (tester) async {
    fake.functions['translate'] = (_) => (status: 404, body: {'error': 'not_found', 'code': 'not_found', 'message': 'Message introuvable.'});
    await tester.pumpWidget(host());
    await tester.tap(find.text('Traduire'));
    await settleReal(tester);
    expect(find.textContaining('Message introuvable.'), findsOneWidget);
    fake.functions['translate'] = (_) => (status: 401, body: {'error': 'unauthorized', 'code': 'unauthorized', 'message': 'Connexion requise.'});
    await tester.tap(find.textContaining('Réessayer'));
    await settleReal(tester);
    expect(find.textContaining('session a expiré'), findsOneWidget);
    await fin(tester);
  });

  test('seuls les messages texte reçus et enregistrés sont traduisibles', () {
    expect(translatableMessageId(id: '12', kind: 'text', mine: false, status: 'ok'), 12);
    expect(translatableMessageId(id: '12', kind: 'text', mine: true, status: 'ok'), isNull);
    expect(translatableMessageId(id: '12', kind: 'voice', mine: false, status: 'ok'), isNull);
    expect(translatableMessageId(id: '12', kind: 'image', mine: false, status: 'ok'), isNull);
    expect(translatableMessageId(id: 'p1730000', kind: 'text', mine: false, status: 'ok'), isNull);
    expect(translatableMessageId(id: '12', kind: 'text', mine: false, status: 'sending'), isNull);
  });
}
