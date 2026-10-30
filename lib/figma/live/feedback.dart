import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart';
import '../nav.dart';
import 'auth.dart';
import 'backend.dart';
import 'store.dart';

const _st = TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF111015));

/// Motifs de réclamation (écran 48), dans l'ordre de l'écran ; la valeur est celle enregistrée par le serveur.
const claimReasons = ['not_received', 'damaged', 'cancel_before_prep', 'refund'];
const claimReasonLabels = ['Article non reçu', 'Article endommagé ou non conforme', 'Annulation avant préparation', 'Demande de remboursement'];

/// Motifs de signalement d'annonce (écran 170).
const reportReasonCodes = ['fraud', 'copied', 'price', 'other'];

/// Notes publiques par titre d'annonce ; chargées au premier affichage, rechargées après un avis.
class Ratings extends Notifier<Map<String, ({double average, int total})>> {
  @override
  Map<String, ({double average, int total})> build() {
    if (Backend.ready) refresh();
    return const {};
  }

  Future<void> refresh() async {
    final r = await Backend.allRatings();
    if (ref.mounted) state = r;
  }
}

final ratingsProvider = NotifierProvider<Ratings, Map<String, ({double average, int total})>>(Ratings.new);

String ratingLabel(({double average, int total}) r) => '${r.average.toStringAsFixed(1)} (${r.total})';

/// Étoile + note moyenne d'une annonce (catalogue) ; rien tant qu'aucun avis n'a été publié.
Widget ratingChip(String title) => Consumer(
      builder: (context, ref, _) {
        final r = ref.watch(ratingsProvider.select((m) => m[title]));
        if (r == null) return const SizedBox.shrink();
        return Row(children: [
          const Icon(Icons.star_rounded, size: 13, color: Color(0xFFF5A524)),
          const SizedBox(width: 2),
          Text(ratingLabel(r), style: _st.copyWith(fontSize: 10.5, fontWeight: FontWeight.w600)),
        ]);
      },
    );

/// Fiche produit : note moyenne et nombre d'avis, ou « Aucun avis » ; maquette inchangée hors connexion serveur.
Widget ratingAverageText(String title, {required bool count}) => Consumer(
      builder: (context, ref, _) {
        const ink = Color(0xFF111015), grey = Color(0xFF66636E);
        if (!Backend.ready) return gText(count ? '(24 avis)' : '4.8', count ? 12.904 : 13.621, count ? grey : ink, weight: count ? 400 : 700);
        final r = ref.watch(ratingsProvider.select((m) => m[title]));
        if (count) return gText(r == null ? 'Aucun avis pour le moment' : '(${r.total} avis)', 12.904, grey);
        return gText(r == null ? '' : r.average.toStringAsFixed(1), 13.621, ink, weight: 700);
      },
    );

final claimReasonProvider = NotifierProvider<IntV, int>(IntV.new);

/// Case ronde d'un motif : pleine et cochée quand le motif est choisi (remplace la case figée de la maquette).
Widget reasonBox(NotifierProvider<IntV, int> p, int i) => Consumer(
      builder: (context, ref, _) {
        final on = ref.watch(p) == i;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: on ? const Color(0xFF111015) : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: on ? null : Border.all(color: const Color(0xFFDAD5E4), width: 1.5),
          ),
          child: on ? Padding(padding: const EdgeInsets.all(3), child: FittedBox(child: SizedBox(width: 14.667, height: 11.958, child: gImg('assets/figma/v/w_check.svg')))) : null,
        );
      },
    );

/// Faux si l'action n'est pas possible ici : pas de compte connecté (la connexion est proposée) ou pas de serveur.
Future<bool> _allowed(BuildContext context, WidgetRef ref, String pour) async {
  if (!await requireLogin(context, ref, pour)) return false;
  if (!Backend.ready) {
    if (context.mounted) await gAlert(context, 'Hors connexion', 'Cette action nécessite la connexion au serveur.');
    return false;
  }
  return true;
}

/// Commande consultée, relue sur le serveur (la liste peut ne pas être encore chargée à l'ouverture de l'écran).
Future<Order> _viewedOrder(WidgetRef ref) async {
  if (Backend.ready) await ref.read(ordersProvider.notifier).refresh();
  return ref.read(viewedOrderProvider);
}

/// Écran 30 : l'acheteur note l'article de sa commande (avis vérifié par le serveur).
Future<void> reviewOrderDialog(BuildContext context, WidgetRef ref) async {
  if (!await _allowed(context, ref, 'publier un avis')) return;
  final o = await _viewedOrder(ref);
  if (o.lines.isEmpty) return gToast(context, 'Aucun article à évaluer.');
  var line = 0, stars = 5, busy = false;
  final comment = TextEditingController();
  await gDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Évaluer votre commande', style: _st.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 340,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (o.lines.length > 1)
              DropdownButton<int>(
                value: line,
                isExpanded: true,
                style: _st,
                items: [for (var i = 0; i < o.lines.length; i++) DropdownMenuItem(value: i, child: Text(o.lines[i].title, style: _st, overflow: TextOverflow.ellipsis))],
                onChanged: (v) => set(() => line = v ?? line),
              )
            else
              Text(o.lines.first.title, style: _st.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(children: [
              for (var i = 1; i <= 5; i++)
                GestureDetector(
                  onTap: () => set(() => stars = i),
                  child: Icon(i <= stars ? Icons.star_rounded : Icons.star_outline_rounded, size: 34, color: const Color(0xFFF5A524)),
                ),
            ]),
            const SizedBox(height: 10),
            TextField(controller: comment, maxLines: 3, maxLength: 1000, style: _st, decoration: const InputDecoration(hintText: 'Votre commentaire (facultatif)')),
          ]),
        ),
        actions: [
          TextButton(onPressed: busy ? null : () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    set(() => busy = true);
                    final err = await Backend.submitReview(o.id, o.lines[line].title, stars, comment.text);
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (!context.mounted) return;
                    if (err != null) {
                      await gAlert(context, 'Avis non enregistré', err);
                    } else {
                      ref.read(ratingsProvider.notifier).refresh();
                      gToast(context, 'Merci ! Votre avis a été publié.');
                    }
                  },
            child: Text(busy ? 'Envoi…' : 'Publier mon avis'),
          ),
        ],
      ),
    ),
  );
  comment.dispose();
}

/// Écran 48 : envoi de la réclamation pour la commande consultée.
Future<void> submitClaimForm(BuildContext context, WidgetRef ref) async {
  if (!await _allowed(context, ref, 'déposer une réclamation')) return;
  final o = await _viewedOrder(ref);
  final details = ref.read(formProvider)['claim_details'] ?? '';
  if (details.trim().length < 10) return gAlert(context, 'Détails manquants', 'Décrivez le problème en 10 caractères minimum pour que l’équipe puisse vous répondre.');
  final err = await Backend.submitClaim(o.id, claimReasons[ref.read(claimReasonProvider).clamp(0, 3)], details);
  if (!context.mounted) return;
  if (err != null) return gAlert(context, 'Réclamation non envoyée', err);
  ref.read(formProvider.notifier).clear(const ['claim_details']);
  gToast(context, 'Réclamation envoyée. Le vendeur et l’équipe ont été prévenus.');
  gBack(context);
}

/// Réclamations de la personne connectée : les siennes (acheteur) ou celles de ses ventes (vendeur, qui peut répondre).
Future<void> claimsDialog(BuildContext context, WidgetRef ref) async {
  if (!await _allowed(context, ref, 'consulter vos réclamations')) return;
  final me = ref.read(profileAccountProvider).serverId;
  final rows = await Backend.claims();
  if (!context.mounted) return;
  if (rows.isEmpty) return gAlert(context, 'Réclamations', 'Aucune réclamation pour le moment.');
  await gDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text('Réclamations', style: _st.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 340,
        child: ListView(shrinkWrap: true, children: [
          for (final r in rows)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(claimReasonLabels[claimReasons.indexOf(r['reason'] as String).clamp(0, 3)], style: _st.copyWith(fontWeight: FontWeight.w600)),
              subtitle: Text('${r['details']}\n${r['status'] == 'open' ? 'En attente de réponse' : 'Réponse : ${r['answer']}'}', style: _st.copyWith(fontSize: 12, color: const Color(0xFF66636E))),
              isThreeLine: true,
              trailing: r['status'] == 'open' && r['claimant_id'] != me
                  ? TextButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _answerDialog(context, r['id'] as String);
                      },
                      child: const Text('Répondre'))
                  : null,
            ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer'))],
    ),
  );
}

Future<void> _answerDialog(BuildContext context, String id) async {
  final c = TextEditingController();
  await gDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text('Répondre à la réclamation', style: _st.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
      content: SizedBox(width: 340, child: TextField(controller: c, maxLines: 4, maxLength: 2000, style: _st, decoration: const InputDecoration(hintText: 'Votre réponse'))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        FilledButton(
          onPressed: () async {
            final err = await Backend.answerClaim(id, c.text);
            if (!ctx.mounted) return;
            Navigator.pop(ctx);
            if (!context.mounted) return;
            if (err != null) {
              await gAlert(context, 'Réponse non envoyée', err);
            } else {
              gToast(context, 'Réponse envoyée. L’acheteur est prévenu.');
            }
          },
          child: const Text('Envoyer'),
        ),
      ],
    ),
  );
  c.dispose();
}
