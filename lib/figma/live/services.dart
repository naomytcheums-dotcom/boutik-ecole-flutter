import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/demo/section_a_demo.dart';
import '../../data/repositories/repositories.dart' show cartProvider;
import '../gen.dart';
import '../nav.dart';
import 'auth.dart';
import 'backend.dart';
import 'seller.dart';
import 'store.dart';

const _st = TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF111015));

/// Services publiés par les étudiants : annonces validées de catégorie « Services ».
final servicesProvider = Provider<List<Listing>>((ref) => [
      for (final l in ref.watch(publicListingsProvider))
        if (l.category == 'Services' && l.published) l,
    ]);

final selectedServiceProvider = NotifierProvider<StrV, String>(StrV.new);

Listing? serviceAt(WidgetRef ref, int i) {
  final l = ref.watch(servicesProvider);
  return i < l.length ? l[i] : null;
}

Listing? currentService(WidgetRef ref) {
  final t = ref.watch(selectedServiceProvider);
  for (final l in ref.watch(servicesProvider)) {
    if (l.title == t) return l;
  }
  return null;
}

String _photo(Listing l) {
  if (l.images.isEmpty) return 'placeholder';
  final u = Backend.listingImageUrl(l.images.first);
  return u.isEmpty ? 'placeholder' : u;
}

String servicePhoto(Listing? l) => l == null ? 'placeholder' : _photo(l);

String servicePriceLine(Listing l) => 'À partir de ${_fcfa(l.price)}';

String _fcfa(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return '$b FCFA';
}

void openService(BuildContext context, WidgetRef ref, Listing l) {
  ref.read(selectedServiceProvider.notifier).set(l.title);
  gOpen(context, '36');
}

/// Écran 36, « Commander » : le service passe par le panier et le paiement, comme un produit.
void orderService(BuildContext context, WidgetRef ref) {
  final l = currentService(ref);
  if (l == null) return gToast(context, 'Choisissez un service dans la liste.');
  ref.read(cartProvider.notifier).add(CartLine(l.title, 'Prestation étudiante', l.price, _photo(l)));
  gToast(context, 'Ajouté au panier');
  gOpen(context, '06');
}

/// Écran 36, « Demander un devis » : ouvre le formulaire 95b pour le service consulté.
Future<void> askQuote(BuildContext context, WidgetRef ref) async {
  if (!Backend.ready) return gAlert(context, 'Hors connexion', 'La demande de devis nécessite la connexion au serveur.');
  if (currentService(ref) == null) return gToast(context, 'Choisissez un service dans la liste.');
  if (!await requireLogin(context, ref, 'demander un devis')) return;
  if (context.mounted) gOpen(context, '95b');
}

int? _digits(String s) {
  final d = s.replaceAll(RegExp(r'[^0-9]'), '');
  return d.isEmpty ? null : int.tryParse(d);
}

/// Écran 95b : envoi de la demande de devis (objet, besoin, quantité, budget, date).
Future<void> submitQuoteRequest(BuildContext context, WidgetRef ref) async {
  final l = currentService(ref);
  if (l == null) return gAlert(context, 'Service manquant', 'Ouvrez d’abord la fiche d’un service.');
  final f = ref.read(formProvider);
  final obj = (f['q_obj'] ?? '').trim(), desc = (f['q_desc'] ?? '').trim(), qty = (f['q_qty'] ?? '').trim();
  final brief = [if (obj.isNotEmpty) 'Objet : $obj', if (desc.isNotEmpty) desc, if (qty.isNotEmpty) 'Quantité : $qty'].join('\n');
  if (brief.trim().length < 10) return gAlert(context, 'Besoin manquant', 'Décrivez votre besoin en 10 caractères minimum.');
  final err = await Backend.requestQuote(l.title, brief, _digits(f['q_budget'] ?? ''), (f['q_date'] ?? '').trim());
  if (!context.mounted) return;
  if (err != null) return gAlert(context, 'Demande non envoyée', err);
  ref.read(formProvider.notifier).clear(const ['q_obj', 'q_desc', 'q_qty', 'q_budget', 'q_date']);
  gToast(context, 'Demande envoyée. Le prestataire vous répondra avec un devis.');
  gBack(context);
}

String quoteStatusLabel(String s) => switch (s) {
      'requested' => 'En attente du devis',
      'quoted' => 'Devis reçu',
      'accepted' => 'Devis accepté',
      'declined' => 'Devis refusé',
      _ => 'Demande annulée',
    };

/// Mes devis : demandes envoyées (on y accepte, refuse ou annule) et reçues (on y répond avec un montant et un délai).
Future<void> quotesDialog(BuildContext context, WidgetRef ref) async {
  if (!Backend.ready) return gAlert(context, 'Hors connexion', 'Cette action nécessite la connexion au serveur.');
  if (!await requireLogin(context, ref, 'consulter vos devis')) return;
  final me = ref.read(profileAccountProvider).serverId;
  final rows = await Backend.myQuotes();
  if (!context.mounted) return;
  if (rows.isEmpty) return gAlert(context, 'Mes devis', 'Aucune demande de devis pour le moment.');
  await gDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text('Mes devis', style: _st.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 340,
        child: ListView(shrinkWrap: true, children: [
          for (final r in rows)
            _QuoteTile(
              r: r,
              mine: r['requester_id'] == me,
              close: () => Navigator.pop(ctx),
              parent: context,
            ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer'))],
    ),
  );
}

class _QuoteTile extends StatelessWidget {
  const _QuoteTile({required this.r, required this.mine, required this.close, required this.parent});
  final Map<String, dynamic> r;
  final bool mine;
  final VoidCallback close;
  final BuildContext parent;

  @override
  Widget build(BuildContext context) {
    final s = r['status'] as String;
    final title = (r['listings'] as Map?)?['title'] ?? 'Service';
    final amount = r['quote_amount'] as int?;
    final lines = [
      '${mine ? 'Demande envoyée' : 'Demande reçue'} · ${quoteStatusLabel(s)}',
      (r['brief'] as String),
      if (amount != null) 'Devis : ${_fcfa(amount)} en ${r['quote_delay_days']} jour(s)${(r['quote_message'] ?? '').toString().isEmpty ? '' : ' — ${r['quote_message']}'}',
    ].join('\n');
    final open = s == 'requested' || s == 'quoted';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$title', style: _st.copyWith(fontWeight: FontWeight.w700)),
        Text(lines, style: _st.copyWith(fontSize: 12, color: const Color(0xFF66636E))),
        Wrap(spacing: 6, children: [
          if (!mine && open) TextButton(onPressed: () { close(); _answer(parent, r['id'] as String, amount); }, child: Text(s == 'quoted' ? 'Modifier mon devis' : 'Répondre avec un devis')),
          if (mine && s == 'quoted') TextButton(onPressed: () { close(); _decide(parent, r['id'] as String, true); }, child: const Text('Accepter')),
          if (mine && s == 'quoted') TextButton(onPressed: () { close(); _decide(parent, r['id'] as String, false); }, child: const Text('Refuser')),
          if (mine && open) TextButton(onPressed: () { close(); _cancel(parent, r['id'] as String); }, child: const Text('Annuler la demande')),
        ]),
        const Divider(height: 14),
      ]),
    );
  }
}

Future<void> _decide(BuildContext context, String id, bool accept) async {
  final err = await Backend.decideQuote(id, accept);
  if (!context.mounted) return;
  if (err != null) return gAlert(context, 'Action impossible', err);
  gToast(context, accept ? 'Devis accepté. Le prestataire est prévenu.' : 'Devis refusé.');
}

Future<void> _cancel(BuildContext context, String id) async {
  final err = await Backend.cancelQuote(id);
  if (!context.mounted) return;
  if (err != null) return gAlert(context, 'Action impossible', err);
  gToast(context, 'Demande annulée.');
}

Future<void> _answer(BuildContext context, String id, int? current) async {
  final amount = TextEditingController(text: current?.toString() ?? '');
  final days = TextEditingController();
  final msg = TextEditingController();
  await gDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text('Votre devis', style: _st.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 340,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: amount, keyboardType: TextInputType.number, style: _st, decoration: const InputDecoration(labelText: 'Montant (FCFA)')),
          TextField(controller: days, keyboardType: TextInputType.number, style: _st, decoration: const InputDecoration(labelText: 'Délai (jours)')),
          TextField(controller: msg, maxLines: 3, maxLength: 2000, style: _st, decoration: const InputDecoration(labelText: 'Message (facultatif)')),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        FilledButton(
          onPressed: () async {
            final a = _digits(amount.text), d = _digits(days.text);
            if (a == null || d == null) {
              await gAlert(ctx, 'Devis incomplet', 'Indiquez un montant et un délai en jours.');
              return;
            }
            if (a > 100000000 || d > 365 || d < 1 || a < 1) {
              await gAlert(ctx, 'Devis invalide', 'Le montant doit être compris entre 1 et 100 000 000 FCFA et le délai entre 1 et 365 jours.');
              return;
            }
            final err = await Backend.answerQuote(id, a, d, msg.text);
            if (!ctx.mounted) return;
            Navigator.pop(ctx);
            if (!context.mounted) return;
            if (err != null) {
              await gAlert(context, 'Devis non envoyé', err);
            } else {
              gToast(context, 'Devis envoyé. Le demandeur est prévenu.');
            }
          },
          child: const Text('Envoyer le devis'),
        ),
      ],
    ),
  );
  amount.dispose();
  days.dispose();
  msg.dispose();
}
