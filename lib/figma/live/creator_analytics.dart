import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'backend.dart';
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';

/// Statistiques de créateur (migration 20261126042000) : tout vient de `creator_analytics(p_days)`, qui ne renvoie que les chiffres de l'appelant.
/// Les données non mesurées (durée de visionnage des publications, conversions, revenus en argent) sont annoncées comme indisponibles, jamais à zéro.

const creatorPeriods = [7, 30, 90];

const _unavailableLabels = {
  'post_watch_time': 'Durée de visionnage des publications',
  'conversions': 'Conversions',
  'revenue_money': 'Revenus en argent',
};

class CreatorAnalyticsException implements Exception {
  CreatorAnalyticsException(this.message);
  final String message;
  @override
  String toString() => message;
}

final creatorAnalyticsProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, days) async {
  final r = await marcheCall('creator_analytics', {'p_days': days});
  if (r.error != null) {
    final e = r.error!;
    throw CreatorAnalyticsException(e == 'offline'
        ? 'Vos statistiques sont disponibles une fois l’application connectée au serveur.'
        : (e == 'missing' ? 'Les statistiques de créateur ne sont pas encore installées sur le serveur.' : Backend.userMessage(e)));
  }
  if (r.data is! Map) throw CreatorAnalyticsException('Réponse illisible du serveur. Réessayez dans un instant.');
  return Map<String, dynamic>.from(r.data as Map);
}, retry: (_, _) => null);

class CreatorAnalyticsScreen extends ConsumerStatefulWidget {
  const CreatorAnalyticsScreen({super.key});

  @override
  ConsumerState<CreatorAnalyticsScreen> createState() => _CreatorAnalyticsScreenState();
}

class _CreatorAnalyticsScreenState extends ConsumerState<CreatorAnalyticsScreen> {
  int days = 30;

  Map<String, dynamic> _m(Map<String, dynamic> d, String k) => d[k] is Map ? Map<String, dynamic>.from(d[k] as Map) : const {};

  @override
  Widget build(BuildContext context) => MarchePage(
        title: 'Statistiques de créateur',
        child: ref.watch(creatorAnalyticsProvider(days)).when(
              loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                mNote(e is CreatorAnalyticsException ? e.message : Backend.userMessage('$e')),
                mButton('Réessayer', () => ref.invalidate(creatorAnalyticsProvider(days)), dark: false),
              ]),
              data: _body,
            ),
      );

  Widget _body(Map<String, dynamic> d) {
    final hasActivity = d['has_activity'] == true;
    final views = _m(d, 'views'), eng = _m(d, 'engagement'), fol = _m(d, 'followers'), lives = _m(d, 'lives'), gifts = _m(d, 'gifts'), posts = _m(d, 'posts');
    final top = [for (final p in (d['top_posts'] as List? ?? const [])) Map<String, dynamic>.from(p as Map)];
    final unavailable = [for (final u in (d['unavailable'] as List? ?? const [])) _unavailableLabels['$u'] ?? '$u'];
    final rate = eng['rate_pct'];
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
      Wrap(spacing: 8, children: [
        for (final p in creatorPeriods)
          ChoiceChip(label: Text('$p jours'), selected: days == p, onSelected: (_) => setState(() => days = p)),
      ]),
      const SizedBox(height: 12),
      if (!hasActivity) mNote('Aucune activité de créateur pour le moment : publiez une publication ou lancez un live, vos chiffres apparaîtront ici.'),
      if (hasActivity) ...[
        _card('Publications', [
          _line('Publiées sur la période', '${mInt(posts['published_period'])}'),
          _line('Publiées au total', '${mInt(posts['published_total'])}'),
        ]),
        _card('Vues', [
          _line('Vues sur la période', '${mInt(views['period'])}'),
          _line('Personnes différentes', '${mInt(views['reach_period'])}'),
          _line('Vues depuis le début', '${mInt(views['total'])}'),
          Text('Seules les personnes connectées sont comptées : les visites anonymes ne sont pas mesurées.', style: mst(12, c: kGrey)),
        ]),
        _card('Interactions', [
          _line('J’aime', '${mInt(eng['likes'])}'),
          _line('Commentaires', '${mInt(eng['comments'])}'),
          _line('Partages', '${mInt(eng['shares'])}'),
          _line('Enregistrements', '${mInt(eng['saves'])}'),
          _line('Taux d’interaction', rate == null ? 'Non calculable (aucune vue)' : '${('$rate').replaceAll('.', ',')} %'),
        ]),
        _card('Abonnés', [
          _line('Abonnés', '${mInt(fol['total'])}'),
          _line('Nouveaux sur la période', '${mInt(fol['gained_period'])}'),
        ]),
        _card('Lives', [
          _line('Lives sur la période', '${mInt(lives['count'])}'),
          _line('Pic de spectateurs', '${mInt(lives['peak_viewers'])}'),
          _line('Minutes de visionnage', '${mInt(lives['watch_minutes'])}'),
        ]),
        _card('Cadeaux reçus', [
          _line('Nombre de cadeaux', '${mInt(gifts['count'])}'),
          _line('Crédits reçus', '${mInt(gifts['credits_received'])}'),
          Text('Montant en crédits : aucune conversion en argent n’est affichée.', style: mst(12, c: kGrey)),
        ]),
        _card('Publications les plus vues', [
          if (top.isEmpty) Text('Aucune publication publiée.', style: mst(13, c: kGrey)),
          for (final p in top)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${p['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: mst(13.5, w: FontWeight.w700)),
                Text('${mInt(p['views'])} vue(s) · ${mInt(p['likes'])} j’aime · ${mInt(p['comments'])} commentaire(s)', style: mst(12, c: kGrey)),
              ]),
            ),
        ]),
      ],
      if (unavailable.isNotEmpty) mNote('Non mesuré pour le moment : ${unavailable.join(', ')}.'),
    ]);
  }

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [Expanded(child: Text(label, style: mst(13, c: kGrey))), Text(value, style: mst(13.5, w: FontWeight.w800))]),
      );

  Widget _card(String title, List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: mst(15, w: FontWeight.w800)), const SizedBox(height: 6), ...children]),
      );
}
