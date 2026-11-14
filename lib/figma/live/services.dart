import 'tp_ui.dart' show tpPick;
import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/demo/section_a_demo.dart';
import '../../data/repositories/repositories.dart' show cartProvider;
import '../gen.dart';
import '../nav.dart';
import 'auth.dart';
import 'access.dart' show canOpen;
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

/// Pastille choisie sur l'écran 22b : 0 Tous, 1 Design, 2 Développement, 3 Tutorat, 4 Audiovisuel.
final serviceFilterProvider = NotifierProvider<IntV, int>(IntV.new);

const _serviceKeywords = <List<String>>[
  [],
  ['design', 'logo', 'graphi', 'identite', 'affiche', 'visuel', 'maquette', 'illustration'],
  ['develop', 'web', 'application', 'site', 'logiciel', 'programm', 'code', 'mobile', 'flutter'],
  ['tutorat', 'cours', 'soutien', 'maths', 'repetition', 'enseign', 'revision', 'formation'],
  ['video', 'audio', 'montage', 'photo', 'film', 'musique', 'podcast', 'audiovisuel'],
];

/// Services de la pastille choisie : mot-clé cherché dans le titre, la description et la catégorie ; « Tous » ne filtre rien.
final filteredServicesProvider = Provider<List<Listing>>((ref) {
  final all = ref.watch(servicesProvider);
  final words = _serviceKeywords[ref.watch(serviceFilterProvider).clamp(0, _serviceKeywords.length - 1)];
  if (words.isEmpty) return all;
  return [
    for (final l in all)
      if (words.any(normText('${l.title} ${l.description} ${l.category} ').contains)) l,
  ];
});

/// Distingue « aucun service publié » d'un chargement en cours ou d'une lecture en échec : -1 si la lecture échoue, sinon 0 (aucun service) ou 1 (au moins un).
final servicesReadProvider = FutureProvider.autoDispose<int>((ref) async {
  if (!Backend.ready) return 0;
  final r = await Backend.rows('listings', 'id', eq: const {'status': 'approved', 'category': 'Services'}, limit: 1);
  return r.error != null ? -1 : r.rows.length;
});

/// Liste défilante de tous les services publiés (écran 22b), avec ses états de chargement, d'erreur et de liste vide.
class ServicesList extends ConsumerWidget {
  const ServicesList({super.key, this.width = 342, this.height = 396});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget note(String t) => SizedBox(width: width, height: 90, child: Center(child: Text(t, textAlign: TextAlign.center, style: _st.copyWith(fontSize: 12.5, color: const Color(0xFF57545F), height: 1.45))));
    final all = ref.watch(servicesProvider);
    final list = ref.watch(filteredServicesProvider);
    final read = ref.watch(servicesReadProvider);
    if (all.isEmpty) {
      return read.when(
        loading: () => note('Chargement des services…'),
        error: (_, _) => note('Les services ne peuvent pas être chargés pour le moment.'),
        data: (n) => n < 0 ? note('Les services ne peuvent pas être chargés pour le moment.') : (n > 0 ? note('Chargement des services…') : note('Aucun service publié pour le moment. Les étudiants peuvent en proposer depuis leur espace vendeur.')),
      );
    }
    if (list.isEmpty) return note('Aucun service dans cette catégorie pour le moment.');
    return SizedBox(
      width: width,
      height: height,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: list.length,
        separatorBuilder: (_, _) => const Divider(height: 16, thickness: 1, color: Color(0xFFF2EFF6)),
        itemBuilder: (_, i) {
          final l = list[i];
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => openService(context, ref, l),
            child: Row(children: [
              const SizedBox(width: 12),
              SizedBox(width: 50, height: 50, child: gBox(image: servicePhoto(l), fit: BoxFit.cover, radii: const [12, 12, 12, 12])),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(l.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st.copyWith(fontFamily: 'PlusJakartaSans', fontSize: 13.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(servicePriceLine(l), maxLines: 1, overflow: TextOverflow.ellipsis, style: _st.copyWith(fontFamily: 'PlusJakartaSans', fontSize: 11.5, color: const Color(0xFF57545F))),
                ]),
              ),
              const Icon(Icons.chevron_right, size: 20, color: Color(0xFF57545F)),
              const SizedBox(width: 8),
            ]),
          );
        },
      ),
    );
  }
}

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

String servicePriceLine(Listing l) => l.price <= 0 ? 'Sur devis' : 'À partir de ${_fcfa(l.price)}';

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

/// Écran 36, « Commander au tarif affiché » : le service passe par le panier et le paiement, comme un produit.
/// Un visiteur doit d'abord se connecter (un panier de visiteur échouerait au paiement). Pour un tarif sur mesure : « Demander un devis ».
Future<void> orderService(BuildContext context, WidgetRef ref) async {
  final l = currentService(ref);
  if (l == null) return gToast(context, 'Choisissez un service dans la liste.');
  if (!await requireLogin(context, ref, 'commander ce service') || !context.mounted) return;
  ref.read(cartProvider.notifier).add(CartLine(l.title, 'Prestation étudiante', l.price, _photo(l)));
  gToast(context, 'Ajouté au panier au tarif affiché');
  gOpen(context, '06');
}

/// Rôle exclu du formulaire 95b (direction, finance, support) : message clair plutôt qu'une page d'accès réservé ou une erreur du serveur.
bool _quoteAllowed(BuildContext context, WidgetRef ref) {
  if (canOpen(ref.read(authProvider).current, '95b')) return true;
  gAlert(context, 'Action réservée', 'Cette action est réservée aux clients, étudiants-vendeurs, entreprises, responsables de département et administrateurs. Votre rôle ne permet pas de demander un devis.');
  return false;
}

/// Écran 36, « Demander un devis » : ouvre le formulaire 95b pour le service consulté.
Future<void> askQuote(BuildContext context, WidgetRef ref) async {
  if (!Backend.ready) return gAlert(context, 'Hors connexion', 'La demande de devis nécessite la connexion au serveur.');
  if (currentService(ref) == null) return gToast(context, 'Choisissez un service dans la liste.');
  if (!await requireLogin(context, ref, 'demander un devis') || !context.mounted) return;
  if (_quoteAllowed(context, ref)) gOpen(context, '95b');
}

int? _digits(String s) {
  final d = s.replaceAll(RegExp(r'[^0-9]'), '');
  return d.isEmpty ? null : int.tryParse(d);
}

/// Écran 95b : envoi de la demande de devis (objet, besoin, quantité, budget, date).
Future<void> submitQuoteRequest(BuildContext context, WidgetRef ref) async {
  final l = currentService(ref);
  if (l == null) return gAlert(context, 'Service manquant', 'Ouvrez d’abord la fiche d’un service.');
  if (Backend.ready && !_quoteAllowed(context, ref)) return;
  final f = ref.read(formProvider);
  final obj = (f['q_obj'] ?? '').trim(), desc = (f['q_desc'] ?? '').trim(), qty = (f['q_qty'] ?? '').trim();
  final brief = [if (obj.isNotEmpty) 'Objet : $obj', if (desc.isNotEmpty) desc, if (qty.isNotEmpty) 'Quantité : $qty'].join('\n');
  if ((obj + desc + qty).length < 10) return gAlert(context, 'Besoin manquant', 'Décrivez votre besoin en 10 caractères minimum.');
  final err = await Backend.requestQuote(l.title, brief, _digits(f['q_budget'] ?? ''), (f['q_date'] ?? '').trim());
  if (!context.mounted) return;
  if (err != null) return gAlert(context, 'Demande non envoyée', err);
  ref.read(formProvider.notifier).clear(const ['q_obj', 'q_desc', 'q_qty', 'q_budget', 'q_date']);
  gToast(context, 'Demande envoyée. Le prestataire vous répondra avec un devis.');
  gBack(context);
}

/// Écran 40 (ouvert depuis le profil, sans service désigné) : la demande n'est envoyée que pour le service consulté ;
/// sinon, rien n'est envoyé et l'utilisateur sait comment désigner le prestataire.
Future<void> submitGeneralQuote(BuildContext context, WidgetRef ref) async {
  // Maquette (aucun serveur) : lien du prototype Figma 40 → 06, sans aucun message de succès.
  if (!Backend.ready) return gOpen(context, '06');
  if (currentService(ref) == null) {
    return gAlert(context, 'Choisissez un service',
        'Une demande de devis est adressée au prestataire d’un service. Ouvrez la fiche du service qui vous intéresse, puis « Demander un devis ». Rien n’a été envoyé.');
  }
  if (!await requireLogin(context, ref, 'demander un devis')) return;
  if (context.mounted) await submitQuoteRequest(context, ref);
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
        Text(lines, style: _st.copyWith(fontSize: 12, color: const Color(0xFF57545F))),
        Wrap(spacing: 6, children: [
          if (!mine && open) TextButton(onPressed: () { close(); _answer(parent, r['id'] as String, amount); }, child: Text(s == 'quoted' ? 'Modifier mon devis' : 'Répondre avec un devis')),
          if (mine && s == 'quoted') TextButton(onPressed: () { close(); _decide(parent, r['id'] as String, true); }, child: const Text('Accepter')),
          if (mine && s == 'quoted') TextButton(onPressed: () { close(); _decide(parent, r['id'] as String, false); }, child: const Text('Refuser')),
          if (mine && open) TextButton(onPressed: () { close(); _cancel(parent, r['id'] as String); }, child: const Text('Annuler la demande')),
          if (mine && s == 'accepted' && r['order_number'] == null) TextButton(onPressed: () { close(); _checkout(parent, r['id'] as String); }, child: const Text('Commander au prix du devis')),
          if (mine && s == 'accepted' && r['order_number'] != null) Text('Commande ${r['order_number']}', style: _st.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F7A52))),
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

Future<void> _checkout(BuildContext context, String id) async {
  final r = await Backend.rpc('quote_checkout', {'p_quote': id});
  if (!context.mounted) return;
  if (r.error != null) return gAlert(context, 'Commande impossible', Backend.userMessage(r.error!));
  final n = r.data is Map ? '${(r.data as Map)['number']}' : '';
  gToast(context, 'Commande $n créée au prix du devis. Payez-la depuis « Mes commandes ».');
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


/// Bandeau « Un service sur mesure ? » : choisit un service de la liste puis ouvre la demande de devis ; sans service publié, le dit.
Future<void> askGeneralQuoteFromList(BuildContext context, WidgetRef ref) async {
  if (!Backend.ready) return gAlert(context, 'Hors connexion', 'La demande de devis nécessite la connexion au serveur.');
  final l = ref.read(servicesProvider);
  if (l.isEmpty) return gAlert(context, 'Aucun service publié', 'Aucun prestataire n’a encore publié de service. Revenez bientôt ou contactez directement un talent depuis son profil.');
  final v = await tpPick(context, 'Pour quel service ?', [for (final x in l) x.title], allowCustom: false);
  if (v == null || !context.mounted) return;
  ref.read(selectedServiceProvider.notifier).set(v);
  await askQuote(context, ref);
}
