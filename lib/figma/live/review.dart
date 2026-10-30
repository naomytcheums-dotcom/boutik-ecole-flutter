import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:async';

import '../gen.dart';
import 'audit.dart';
import 'auth.dart';
import 'backend.dart';
import 'seller.dart';
import 'store.dart';

/// Tableaux de bord web : validation des annonces (département) et flux financiers.

class ReviewItem {
  const ReviewItem(this.title, this.seller, this.category, this.price, this.submitted, {this.seed = true, this.id = '', this.status = 'pending', this.note = ''});
  final String title, seller, category, submitted;
  final int price;
  final bool seed;

  /// Identifiant serveur, statut (pending · approved · rejected) et motif de refus : renseignés quand les données viennent de Supabase.
  final String id, status, note;

  String get code => '${title.replaceAll(RegExp('[^A-Za-zÀ-ÿ]'), '').toUpperCase().padRight(3, 'X').substring(0, 3)}-${(price % 97 + 1).toString().padLeft(3, '0')}';
}

const _seedReviews = [
  ReviewItem('Lampe en bois recyclé', 'Yannick Mouanga', 'Maison', 25000, 'Hier'),
  ReviewItem('Développement web', 'Mariam Essono', 'Service', 30000, 'Hier'),
  ReviewItem('Sac à dos design', 'Aminata Bello', 'Mode', 25000, 'Il y a 2 j'),
  ReviewItem('Pots connectés', 'Brice Ndoumbe', 'Maison', 15000, 'Il y a 2 j'),
  ReviewItem('Logo et identité', 'Aminata Bello', 'Service', 15000, 'Il y a 3 j'),
];

/// File de validation réelle (département / administrateur) : annonces soumises par tous les vendeurs.
/// Les autres rôles n'y reçoivent rien : la politique RLS ne leur renvoie aucune ligne.
class ReviewQueue extends Notifier<List<ReviewItem>> {
  @override
  List<ReviewItem> build() {
    if (!Backend.ready) return const [];
    final uid = ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
    if (uid.isNotEmpty) {
      Future.microtask(refresh);
      final t = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
      ref.onDispose(t.cancel);
    }
    return const [];
  }

  Future<void> refresh() async {
    final rows = await Backend.reviewQueue();
    if (!ref.mounted) return;
    state = [
      for (final r in rows)
        ReviewItem(
          (r['title'] ?? '').toString(),
          'Étudiant-vendeur',
          (r['category'] ?? '').toString(),
          (r['price'] as num?)?.toInt() ?? 0,
          _ago((r['updated_at'] ?? r['created_at'] ?? '').toString()),
          seed: false,
          id: (r['id'] ?? '').toString(),
          status: (r['status'] ?? 'pending').toString(),
          note: (r['review_note'] ?? '').toString(),
        ),
    ];
  }
}

String _ago(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  final m = DateTime.now().difference(d.toLocal()).inMinutes;
  if (m < 1) return 'À l’instant';
  if (m < 60) return 'Il y a $m min';
  if (m < 1440) return 'Il y a ${m ~/ 60} h';
  return 'Il y a ${m ~/ 1440} j';
}

final reviewQueueProvider = NotifierProvider<ReviewQueue, List<ReviewItem>>(ReviewQueue.new);

/// Décisions du valideur : titre → 1 validée, 2 refusée (avec motif).
/// Avec le serveur, elles sont déduites du statut enregistré de chaque annonce.
class ReviewDecisions extends Notifier<Map<String, (int, String)>> {
  @override
  Map<String, (int, String)> build() {
    if (Backend.ready) {
      return {for (final r in ref.watch(reviewQueueProvider)) if (r.status != 'pending') r.title: (r.status == 'approved' ? 1 : 2, r.note)};
    }
    return const {};
  }

  void decide(String title, int d, String note) => state = {...state, title: (d, note)};
}

final reviewDecisionsProvider = NotifierProvider<ReviewDecisions, Map<String, (int, String)>>(ReviewDecisions.new);

final reviewTabProvider = NotifierProvider<IntV, int>(IntV.new);

/// Toutes les annonces soumises : celles des vendeurs (dans cette appli) d'abord, puis les exemples.
final allReviewsProvider = Provider<List<ReviewItem>>((ref) {
  if (Backend.ready) return ref.watch(reviewQueueProvider);
  final mine = ref.watch(listingsProvider);
  final decided = ref.watch(reviewDecisionsProvider);
  final who = 'Mariam Essono';
  bool isSeed(String t) => _seedReviews.any((r) => r.title == t);
  return [
    for (final l in mine)
      if (l.inReview || (decided.containsKey(l.title) && !isSeed(l.title))) ReviewItem(l.title, who, l.category, l.price, 'À l’instant', seed: false),
    ..._seedReviews,
  ];
});

final pendingReviewsProvider = Provider<List<ReviewItem>>((ref) {
  final d = ref.watch(reviewDecisionsProvider);
  return [for (final r in ref.watch(allReviewsProvider)) if (!d.containsKey(r.title)) r];
});

final decidedReviewsProvider = Provider<List<ReviewItem>>((ref) {
  final d = ref.watch(reviewDecisionsProvider);
  return [for (final r in ref.watch(allReviewsProvider)) if (d.containsKey(r.title)) r];
});

/// Liste affichée selon l'onglet : 0 À valider · 1 Validées · 2 Refusées.
final visibleReviewsProvider = Provider<List<ReviewItem>>((ref) {
  final tab = ref.watch(reviewTabProvider);
  final d = ref.watch(reviewDecisionsProvider);
  if (tab == 0) return ref.watch(pendingReviewsProvider);
  return [for (final r in ref.watch(decidedReviewsProvider)) if (d[r.title]!.$1 == tab) r];
});

int reviewCount(Map<String, (int, String)> d, int kind) => d.values.where((e) => e.$1 == kind).length;

/// Boîte de dialogue d'examen d'une annonce : valider ou refuser avec motif.
Future<void> reviewDialog(BuildContext context, WidgetRef ref, ReviewItem r) {
  final note = TextEditingController();
  const st = TextStyle(inherit: false, fontFamily: 'PlusJakartaSans', fontSize: 13, color: Color(0xFF111015), textBaseline: TextBaseline.alphabetic);
  return gDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text('Examiner « ${r.title} »', style: st.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 360,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Vendeur : ${r.seller}\nCatégorie : ${r.category}\nPrix : ${fcfa(r.price)}\nSoumise : ${r.submitted}', style: st.copyWith(height: 1.6)),
          const SizedBox(height: 14),
          TextField(
            controller: note,
            style: st,
            decoration: const InputDecoration(hintText: 'Motif (obligatoire en cas de refus)', border: OutlineInputBorder()),
          ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (note.text.trim().length < 5) {
              gToast(ctx, 'Indiquez un motif de refus (5 caractères minimum).');
              return;
            }
            _decide(context, ctx, ref, r, false, note.text.trim());
          },
          child: Text('Refuser', style: st.copyWith(color: const Color(0xFFE5484D), fontWeight: FontWeight.w600)),
        ),
        TextButton(
          onPressed: () {
            _decide(context, ctx, ref, r, true, note.text.trim());
          },
          child: Text('Valider', style: st.copyWith(color: const Color(0xFF0F7A52), fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

/// Décision du valideur : enregistrée sur le serveur (statut, auteur, motif) avant d'être affichée comme prise.
Future<void> _decide(BuildContext context, BuildContext ctx, WidgetRef ref, ReviewItem r, bool approve, String note) async {
  if (Backend.ready && r.id.isNotEmpty) {
    final err = await Backend.decideListing(r.id, approve, note);
    if (err != null) {
      if (context.mounted) await gAlert(context, 'Décision non enregistrée', err);
      return;
    }
    await ref.read(reviewQueueProvider.notifier).refresh();
  } else {
    ref.read(reviewDecisionsProvider.notifier).decide(r.title, approve ? 1 : 2, note);
    if (!r.seed) ref.read(listingsProvider.notifier).review(r.title, approve);
  }
  final who = ref.read(profileAccountProvider).name;
  ref.read(auditProvider.notifier).log(who.isEmpty ? 'Valideur' : who, approve ? 'Annonce validée' : 'Annonce refusée', r.title, 'Validations', level: approve ? 'Normal' : 'Sensible');
  if (ctx.mounted) Navigator.of(ctx).pop();
  if (context.mounted) gToast(context, approve ? 'Annonce validée et publiée' : 'Annonce refusée : le vendeur est averti');
}

// ------------------------------------------------------------------ flux financiers

class FlowRow {
  const FlowRow(this.ref, this.sub, this.type, this.status, this.amount, {this.orderId});
  final String ref, sub, type, status;
  final int amount;
  final String? orderId;
}

const _seedFlows = [
  FlowRow('TX-88421', '22 oct. · Orange Money', 'Encaissement', 'Vérifié', 25000),
  FlowRow('RV-1204', '22 oct. · Mobile Money', 'Reversement', 'Programmé', 23750),
  FlowRow('TX-88420', '22 oct. · Espèces kiosque', 'Encaissement', 'À vérifier', 17000),
  FlowRow('TX-88419', '21 oct. · Orange Money', 'Encaissement', 'Vérifié', 45000),
  FlowRow('RV-1203', '21 oct. · Mobile Money', 'Reversement', 'Programmé', 60000),
];

/// Flux : les paiements des commandes passées dans l'appli, puis les exemples.
final flowRowsProvider = Provider<List<FlowRow>>((ref) {
  final orders = ref.watch(ordersProvider);
  return [
    for (final o in orders)
      FlowRow('TX-${o.id.substring(o.id.length - 4)}${o.id.length}', '${o.date} · ${o.method}', 'Encaissement', o.paid ? 'Vérifié' : 'À vérifier', o.total, orderId: o.id),
    ..._seedFlows,
  ];
});

int flowTotal(WidgetRef ref) => ref.watch(ordersProvider).fold(0, (a, o) => a + o.total);

String flowPillLabel(String s) => s;

Color flowFill(String s) => switch (s) {
      'Vérifié' => const Color(0xFFDDF5EC),
      'Programmé' => const Color(0xFFEFEBFA),
      _ => const Color(0xFFFFF1DC),
    };

Color flowInk(String s) => switch (s) {
      'Vérifié' => const Color(0xFF0F7A52),
      'Programmé' => const Color(0xFF5A3FE0),
      _ => const Color(0xFF8F5400),
    };
