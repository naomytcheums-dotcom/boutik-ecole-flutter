import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/creator_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/render.dart';

/// H10 · social : statistiques de créateur. Serveur muet / panne / aucune activité / chiffres du serveur / changement de période / données non mesurées.
/// Faux serveur local ; aucun chiffre d'exemple.
Map<String, dynamic> _stats({bool activity = true, Object? rate = 12.5}) => {
      'days': 30,
      'has_activity': activity,
      'posts': {'published_total': 7, 'published_period': 3},
      'views': {'period': 40, 'total': 90, 'reach_period': 25, 'logged_in_only': true},
      'engagement': {'likes': 4, 'comments': 2, 'shares': 1, 'saves': 3, 'total': 10, 'rate_pct': rate},
      'followers': {'total': 18, 'gained_period': 5},
      'lives': {'count': 2, 'peak_viewers': 31, 'watch_minutes': 120},
      'gifts': {'credits_received': 250, 'count': 6},
      'top_posts': [
        {'id': 'p1', 'title': 'Ma première vidéo', 'views': 22, 'likes': 3, 'comments': 1},
      ],
      'unavailable': ['post_watch_time', 'conversions', 'revenue_money'],
    };

void main() {
  late FakeSupabase srv;
  setUpAll(() async {
    await loadAppFonts();
    srv = await FakeSupabase.start();
    await srv.initSupabase();
  });
  tearDownAll(() => srv.close());

  setUp(() {
    GScreen.mockupFrame = false;
    GAnim.enabled = false;
    Backend.ready = true;
    srv.rpc.clear();
    srv.tables.clear();
    srv.calls.clear();
    srv.failRpc.clear();
    srv.unknownIsError = false;
  });
  tearDown(() => GScreen.mockupFrame = true);

  Future<void> host(WidgetTester t) async {
    t.view.physicalSize = const Size(420, 3200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(const ProviderScope(child: MaterialApp(home: CreatorAnalyticsScreen())));
    await t.pump(const Duration(milliseconds: 200));
  }

  Future<void> attendre(WidgetTester t, Finder f) async {
    for (var i = 0; i < 60 && f.evaluate().isEmpty; i++) {
      await settleReal(t, rounds: 2, ms: 100);
    }
  }

  Future<void> fin(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 60));
  }

  testWidgets('serveur muet (404) : message honnête, aucun chiffre', (t) async {
    srv.unknownIsError = true;
    await host(t);
    await attendre(t, find.text('Réessayer'));
    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.text('Vues'), findsNothing);
    await fin(t);
  });

  testWidgets('panne serveur (500) : erreur lisible, jamais « aucune activité »', (t) async {
    srv.failRpc.add('creator_analytics');
    await host(t);
    await attendre(t, find.text('Réessayer'));
    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.textContaining('Aucune activité'), findsNothing);
    await fin(t);
  });

  testWidgets('aucune activité : état vide sans chiffre', (t) async {
    srv.rpc['creator_analytics'] = (_) => _stats(activity: false);
    await host(t);
    await attendre(t, find.textContaining('Aucune activité'));
    expect(find.textContaining('Aucune activité de créateur'), findsOneWidget);
    expect(find.text('Vues'), findsNothing);
    await fin(t);
  });

  testWidgets('chiffres du serveur, taux, publications les plus vues et données non mesurées déclarées', (t) async {
    srv.rpc['creator_analytics'] = (_) => _stats();
    await host(t);
    await attendre(t, find.text('Vues'));
    expect(find.text('Vues sur la période'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
    expect(find.text('12,5 %'), findsOneWidget);
    expect(find.text('Ma première vidéo'), findsOneWidget);
    expect(find.textContaining('visites anonymes ne sont pas mesurées'), findsOneWidget);
    expect(find.textContaining('aucune conversion en argent'), findsOneWidget);
    expect(find.textContaining('Non mesuré pour le moment'), findsOneWidget);
    expect(find.textContaining('Conversions'), findsOneWidget);
    await fin(t);
  });

  testWidgets('taux nul côté serveur (aucune vue) : « Non calculable », jamais 0 %', (t) async {
    srv.rpc['creator_analytics'] = (_) => _stats(rate: null);
    await host(t);
    await attendre(t, find.text('Vues'));
    expect(find.textContaining('Non calculable'), findsOneWidget);
    expect(find.textContaining('0 %'), findsNothing);
    await fin(t);
  });

  testWidgets('changer de période : nouvel appel avec p_days', (t) async {
    srv.rpc['creator_analytics'] = (_) => _stats();
    await host(t);
    await attendre(t, find.text('Vues'));
    await t.tap(find.text('90 jours'));
    await settleReal(t, rounds: 6, ms: 60);
    final days = srv.calls.where((c) => c.name == 'creator_analytics').map((c) => c.args['p_days']).toList();
    expect(days, containsAllInOrder([30, 90]));
    await fin(t);
  });
}
