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
import 'entreprise.dart' show invalidateCompanyData;
import 'quote_negotiation.dart' show openQuoteNegotiation;
import 'produit_fiche.dart' show openForProduct, providerCardProvider;
import 'marche/marche_widgets.dart' show MarchePage, mButton, mNote;
import 'seller.dart';
import 'store.dart';

const _st = TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF111015));

/// Services publiés par les étudiants : annonces validées de catégorie « Services ».
class ServiceListings extends Notifier<List<Listing>> {
  @override
  List<Listing> build() {
    if (!Backend.ready) return const [];
    Future.microtask(() async {
      final l = await Backend.serviceListings();
      if (ref.mounted) state = l;
    });
    return const [];
  }
}

final serviceListingsProvider = NotifierProvider<ServiceListings, List<Listing>>(ServiceListings.new);

final servicesProvider = Provider<List<Listing>>((ref) {
  final seen = <String>{};
  return [
    for (final l in [...ref.watch(serviceListingsProvider), ...ref.watch(publicListingsProvider)])
      if (l.category == 'Services' && l.published && seen.add(l.id.isNotEmpty ? l.id : l.title)) l,
  ];
});

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

/// Prestataire d'un service : nom abrégé, photo, filière, note du service (fonction publique provider_card).
AsyncValue<Map<String, dynamic>?> providerOf(WidgetRef ref, Listing? l) =>
    l == null || l.id.isEmpty ? const AsyncData(null) : ref.watch(providerCardProvider('listing:${l.id}'));

/// « Prestataire : Yannick M. · Génie civil » ; vide pendant le chargement, honnête quand le prestataire n'est pas identifiable.
String providerLine(WidgetRef ref, Listing? l) {
  if (l == null) return '';
  return providerOf(ref, l).when(
    data: (c) => c == null ? (l.platform ? 'Service proposé par Boutik-École' : 'Prestataire non identifié') : 'Prestataire : ${c['name']}${'${c['department'] ?? ''}'.isEmpty ? '' : ' · ${c['department']}'}',
    loading: () => '',
    error: (_, _) => 'Prestataire non identifié',
  );
}

/// Photo du prestataire (vide : aucune photo, jamais celle de l'utilisateur connecté).
String providerAvatar(WidgetRef ref, Listing? l) => '${providerOf(ref, l).value?['avatar_url'] ?? ''}';

/// Le service vu comme un produit de la sélection (écrans 31, 38 et 172 lisent la sélection).
LiveProduct serviceAsProduct(Listing l, String sellerName) =>
    LiveProduct(l.title, l.department, l.price, sellerName, l.description, _photo(l), sellerId: (l.sellerId ?? '').isEmpty ? null : l.sellerId, id: l.id.isEmpty ? null : l.id);

/// Écran 36 : note du service, avis, réputation du prestataire.
class ServiceTrustBlock extends ConsumerWidget {
  const ServiceTrustBlock({super.key, this.width = 342});
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = currentService(ref);
    if (l == null) return const SizedBox.shrink();
    final c = providerOf(ref, l).value;
    final n = ((c?['rating_count'] as num?) ?? 0).toInt();
    final name = '${c?['name'] ?? ''}';
    Widget link(String label, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SizedBox(width: width, child: OutlinedButton(onPressed: onTap, style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: const StadiumBorder(), side: const BorderSide(color: Color(0xFFD9D3E6))), child: Text(label, style: _st.copyWith(fontWeight: FontWeight.w600)))),
        );
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(n == 0 ? 'Aucun avis sur ce service pour le moment.' : '★ ${c?['rating_avg']} · $n avis sur ce service', style: _st.copyWith(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700)),
        link('Voir les avis du service', () => openServiceScreen(context, ref, l, name, '31')),
        if ((l.sellerId ?? '').isNotEmpty) link('Réputation du prestataire', () => openServiceScreen(context, ref, l, name, '38', seller: true)),
      ]),
    );
  }
}

void openServiceScreen(BuildContext context, WidgetRef ref, Listing l, String sellerName, String screen, {bool seller = false}) =>
    openForProduct(context, ref, serviceAsProduct(l, sellerName), screen, seller: seller);

void openService(BuildContext context, WidgetRef ref, Listing l) {
  ref.read(selectedServiceProvider.notifier).set(l.title);
  gOpen(context, '36');
}

/// Écran 36, « Commander au tarif affiché » : le service passe par le panier et le paiement, comme un produit.
/// Un visiteur doit d'abord se connecter (un panier de visiteur échouerait au paiement). Pour un tarif sur mesure : « Demander un devis ».
Future<void> orderService(BuildContext context, WidgetRef ref) async {
  final l = currentService(ref);
  if (l == null) return gToast(context, 'Choisissez un service dans la liste.');
  if (l.stock <= 0) return gToast(context, 'Ce service n’est plus disponible pour le moment. Demandez un devis au prestataire.');
  if ((l.sellerId ?? '').isNotEmpty && l.sellerId == Backend.userId) return gToast(context, 'C’est votre propre service : vous ne pouvez pas le commander.');
  if (l.price <= 0) return gToast(context, 'Ce service est « Sur devis » : demandez un devis au prestataire pour connaître le montant.');
  if (!await requireLogin(context, ref, 'commander ce service') || !context.mounted) return;
  ref.read(cartProvider.notifier).add(CartLine(l.title, 'Prestation étudiante', l.price, _photo(l)));
  gToast(context, 'Ajouté au panier au tarif affiché');
  gOpen(context, '06');
}

/// Rôle exclu du formulaire 95b (direction, finance, support) : message clair plutôt qu'une page d'accès réservé ou une erreur du serveur.
bool _quoteAllowed(BuildContext context, WidgetRef ref) {
  if (canOpen(ref.read(authProvider).current, '95b')) return true;
  gAlert(context, 'Action réservée', 'Cette action est réservée aux clients, étudiants-vendeurs, organisations, responsables de département et administrateurs. Votre rôle ne permet pas de demander un devis.');
  return false;
}

/// Écran 36, « Demander un devis » : ouvre le formulaire 95b pour le service consulté.
Future<void> askQuote(BuildContext context, WidgetRef ref) async {
  if (!Backend.ready) return gAlert(context, 'Hors connexion', 'La demande de devis nécessite la connexion au serveur.');
  if (currentService(ref) == null) return gToast(context, 'Choisissez un service dans la liste.');
  final mine = currentService(ref)!;
  if ((mine.sellerId ?? '').isNotEmpty && mine.sellerId == Backend.userId) return gToast(context, 'C’est votre propre service : vous ne pouvez pas demander un devis pour lui.'); 
  if (!await requireLogin(context, ref, 'demander un devis') || !context.mounted) return;
  if (_quoteAllowed(context, ref)) gOpen(context, '95b');
}

/// Budget maximal d'une demande de devis (FCFA) : au-delà, le serveur refuse ; le message est donné avant l'envoi.
const kMaxQuoteBudget = 100000000;

/// Montant en FCFA saisi à la main : « 2500 », « 2 500 », « 2.500 », « 2 500,50 » (arrondi au franc) ; null si illisible.
int? parseFcfa(String input) {
  var s = input.toUpperCase().replaceAll(RegExp(r'[\s\u00A0\u202F]'), '').replaceAll(RegExp(r'(FCFA|XAF|CFA|F)$'), '');
  if (!RegExp(r'^\d+([.,]\d+)*$').hasMatch(s)) return null;
  if (s.contains('.') && s.contains(',')) {
    final decimal = s[s.lastIndexOf(RegExp(r'[.,]'))];
    s = s.replaceAll(decimal == '.' ? ',' : '.', '');
  }
  final parts = s.split(RegExp(r'[.,]'));
  if (parts.length == 1) return int.tryParse(s);
  final seps = RegExp(r'[.,]').allMatches(s).map((m) => m.group(0)).toSet();
  final grouped = parts.first.length <= 3 && parts.skip(1).every((p) => p.length == 3) && seps.length == 1;
  if (grouped) return int.tryParse(parts.join());
  if (parts.length != 2) return null;
  return double.tryParse('${parts[0]}.${parts[1]}')?.round();
}

/// Message d'erreur d'un montant de devis : null si la valeur est acceptable (entre 1 et [kMaxQuoteBudget] FCFA).
String? quoteAmountError(String raw) {
  final v = parseFcfa(raw);
  if (v == null) return 'Montant illisible : saisissez un nombre de FCFA, par exemple 25 000.';
  if (v < 1 || v > kMaxQuoteBudget) return 'Le montant doit être compris entre 1 et ${_fcfa(kMaxQuoteBudget)}.';
  return null;
}

/// Champs de l'écran 95b et clé de remise à zéro : les champs se vident après un envoi réussi.
final quoteFormResetProvider = NotifierProvider<IntV, int>(IntV.new);

/// Écran 95b : envoi de la demande de devis (objet, besoin, quantité, budget, date).
Future<void> submitQuoteRequest(BuildContext context, WidgetRef ref) async {
  final l = currentService(ref);
  if (l == null) return gAlert(context, 'Service manquant', 'Ouvrez d’abord la fiche d’un service.');
  if (Backend.ready && !_quoteAllowed(context, ref)) return;
  final f = ref.read(formProvider);
  final obj = (f['q95_obj'] ?? '').trim(), desc = (f['q95_desc'] ?? '').trim(), qty = (f['q95_qty'] ?? '').trim();
  final budgetRaw = (f['q95_budget'] ?? '').trim();
  if (obj.length < 3) return gAlert(context, 'Objet manquant', 'Indiquez l’objet de votre demande (3 caractères minimum).');
  if (desc.length < 10) return gAlert(context, 'Besoin manquant', 'Décrivez votre besoin en 10 caractères minimum.');
  if (qty.isNotEmpty && ((int.tryParse(qty) ?? 0) < 1 || qty.length > 6)) return gAlert(context, 'Quantité invalide', 'La quantité doit être un nombre entre 1 et 999 999.');
  int? budget;
  if (budgetRaw.isNotEmpty) {
    final e = quoteAmountError(budgetRaw);
    if (e != null) return gAlert(context, 'Budget invalide', e);
    budget = parseFcfa(budgetRaw);
  }
  final brief = ['Objet : $obj', desc, if (qty.isNotEmpty) 'Quantité : $qty'].join('\n');
  final err = await Backend.requestQuote(l.title, brief, budget, (f['q95_date'] ?? '').trim());
  if (!context.mounted) return;
  if (err != null) return gAlert(context, 'Demande non envoyée', err);
  ref.read(formProvider.notifier).clear(const ['q95_obj', 'q95_desc', 'q95_qty', 'q95_budget', 'q95_date']);
  ref.read(quoteFormResetProvider.notifier).set(ref.read(quoteFormResetProvider) + 1);
  invalidateCompanyData(context);
  gToast(context, 'Demande envoyée. Le prestataire vous répondra avec un devis.');
  gBack(context);
}

/// Écran 40 (ouvert depuis le profil, sans service désigné) : le devis s'adresse toujours à un service choisi explicitement
/// dans la liste, jamais à un service resté en mémoire d'une consultation précédente.
Future<void> submitGeneralQuote(BuildContext context, WidgetRef ref) async {
  // Maquette (aucun serveur) : lien du prototype Figma 40 → 06, sans aucun message de succès.
  if (!Backend.ready) return gOpen(context, '06');
  await askGeneralQuoteFromList(context, ref);
}

String quoteStatusLabel(String s) => switch (s) {
      'requested' => 'En attente du devis',
      'quoted' => 'Devis reçu',
      'accepted' => 'Devis accepté',
      'declined' => 'Devis refusé',
      'rejected' => 'Demande déclinée par le prestataire',
      'expired' => 'Devis expiré',
      _ => 'Demande annulée',
    };

/// Un devis « reçu » dont la date de validité est passée ne s'accepte plus (le serveur le refuse aussi ; la tâche planifiée le clôture).
bool quoteIsExpired(Map<String, dynamic> r, [DateTime? now]) {
  if (r['status'] == 'expired') return true;
  final until = DateTime.tryParse('${r['valid_until'] ?? ''}');
  return r['status'] == 'quoted' && until != null && until.isBefore(now ?? DateTime.now());
}

/// Mes devis : demandes envoyées (on y accepte, refuse ou annule) et reçues (on y répond avec un montant et un délai).
Future<void> quotesDialog(BuildContext context, WidgetRef ref) async {
  if (!Backend.ready) return gAlert(context, 'Hors connexion', 'Cette action nécessite la connexion au serveur.');
  if (!await requireLogin(context, ref, 'consulter vos devis')) return;
  final me = ref.read(profileAccountProvider).serverId;
  final rows = await Backend.myQuotes();
  final orders = {for (final o in await Backend.myOrders() ?? const <Map<String, dynamic>>[]) '${o['number']}': o};
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
              order: orders['${r['order_number']}'],
              close: () => Navigator.pop(ctx),
              parent: context,
              ref: ref,
            ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer'))],
    ),
  );
}

class _QuoteTile extends StatelessWidget {
  const _QuoteTile({required this.r, required this.mine, required this.order, required this.close, required this.parent, required this.ref});
  final Map<String, dynamic> r;
  final bool mine;
  final WidgetRef ref;

  /// Commande créée au prix du devis (null : aucune, ou non lisible).
  final Map<String, dynamic>? order;
  final VoidCallback close;
  final BuildContext parent;

  @override
  Widget build(BuildContext context) {
    final s = r['status'] as String;
    final title = (r['listings'] as Map?)?['title'] ?? 'Service';
    final amount = r['quote_amount'] as int?;
    final expired = quoteIsExpired(r);
    final until = DateTime.tryParse('${r['valid_until'] ?? ''}')?.toLocal();
    final who = mine ? '${r['provider_name'] ?? ''}' : '${r['requester_name'] ?? ''}';
    final lines = [
      '${mine ? 'Demande envoyée' : 'Demande reçue'}${who.isEmpty ? '' : (mine ? ' à $who' : ' de $who')} · ${expired && s == 'quoted' ? quoteStatusLabel('expired') : quoteStatusLabel(s)}',
      (r['brief'] as String),
      if (amount != null) 'Devis : ${_fcfa(amount)} en ${r['quote_delay_days']} jour(s)${(r['quote_message'] ?? '').toString().isEmpty ? '' : ' — ${r['quote_message']}'}',
      if (s == 'quoted' && until != null && !expired) 'Valable jusqu’au ${until.day.toString().padLeft(2, '0')}/${until.month.toString().padLeft(2, '0')}/${until.year}',
      if (s == 'rejected' && '${r['decline_reason'] ?? ''}'.isNotEmpty) 'Motif : ${r['decline_reason']}',
    ].join('\n');
    final open = (s == 'requested' || s == 'quoted') && !(expired && s == 'quoted');
    final cancelledOrder = order != null && (order!['cancelled'] == true || order!['cancelled_at'] != null);
    final hasOrder = r['order_number'] != null;
    final orderState = cancelledOrder ? 'annulée' : (order?['paid'] == true ? 'payée' : (order == null ? 'créée' : 'en attente de paiement'));
    final serverState = switch ('${r['order_state'] ?? ''}') { 'cancelled' => 'annulée', 'paid' => 'payée', 'pending' => 'en attente de paiement', _ => orderState };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$title', style: _st.copyWith(fontWeight: FontWeight.w700)),
        Text(lines, style: _st.copyWith(fontSize: 12, color: const Color(0xFF57545F))),
        Wrap(spacing: 6, children: [
          TextButton(onPressed: () { close(); openQuoteNegotiation(parent, ref, r); }, child: const Text('Fil et négociation')),
          if (!mine && (s == 'requested' || s == 'quoted')) TextButton(onPressed: () { close(); _answer(parent, r['id'] as String, amount); }, child: Text(s == 'quoted' ? 'Modifier mon devis' : 'Répondre avec un devis')),
          if (!mine && (s == 'requested' || s == 'quoted')) TextButton(onPressed: () { close(); _declineQuote(parent, r['id'] as String); }, child: const Text('Décliner')),
          if (s != 'cancelled') TextButton(onPressed: () { close(); _contactQuote(parent, r['id'] as String, mine ? 'au prestataire' : 'au demandeur'); }, child: Text(mine ? 'Écrire au prestataire' : 'Écrire au demandeur')),
          if (mine && s == 'quoted' && !expired) TextButton(onPressed: () { close(); _decide(parent, r['id'] as String, true, amount: amount, days: r['quote_delay_days'] as int?); }, child: const Text('Accepter')),
          if (mine && s == 'quoted') TextButton(onPressed: () { close(); _decide(parent, r['id'] as String, false); }, child: const Text('Refuser')),
          if (mine && open) TextButton(onPressed: () { close(); _cancel(parent, r['id'] as String); }, child: const Text('Annuler la demande')),
          if (mine && s == 'accepted' && (!hasOrder || cancelledOrder)) TextButton(onPressed: () { close(); _checkout(parent, r['id'] as String); }, child: Text(cancelledOrder ? 'Commander de nouveau au prix du devis' : 'Commander au prix du devis')),
          if (s == 'accepted' && hasOrder) Text('Commande ${r['order_number']} · $serverState', style: _st.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: serverState == 'annulée' ? const Color(0xFFE5484D) : const Color(0xFF0F7A52))),
        ]),
        const Divider(height: 14),
      ]),
    );
  }
}

Future<void> _declineQuote(BuildContext context, String id) async {
  final ctrl = TextEditingController();
  final ok = await gDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text('Décliner cette demande ?', style: _st.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Le demandeur est prévenu et pourra faire une nouvelle demande.', style: _st),
        TextField(controller: ctrl, maxLength: 500, maxLines: 2, style: _st, decoration: const InputDecoration(labelText: 'Motif (facultatif)')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Retour')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Décliner')),
      ],
    ),
  );
  final reason = ctrl.text.trim();
  ctrl.dispose();
  if (ok != true || !context.mounted) return;
  final r = await Backend.rpc('decline_quote', {'p_id': id, 'p_reason': reason.isEmpty ? null : reason});
  if (!context.mounted) return;
  if (r.error != null) return gAlert(context, 'Action impossible', r.error!);
  invalidateCompanyData(context);
  gToast(context, 'Demande déclinée : le demandeur est prévenu.');
}

/// Message lié au devis : la réponse arrive dans la messagerie, dans la conversation de l'annonce.
Future<void> _contactQuote(BuildContext context, String id, String to) async {
  final ctrl = TextEditingController();
  final ok = await gDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text('Écrire $to', style: _st.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
      content: TextField(controller: ctrl, maxLength: 1000, maxLines: 4, style: _st, decoration: const InputDecoration(labelText: 'Votre message')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Envoyer')),
      ],
    ),
  );
  final body = ctrl.text.trim();
  ctrl.dispose();
  if (ok != true || body.isEmpty || !context.mounted) return;
  final r = await Backend.rpc('quote_contact', {'p_quote': id, 'p_body': body});
  if (!context.mounted) return;
  if (r.error != null) return gAlert(context, 'Message non envoyé', r.error!);
  gToast(context, 'Message envoyé : la réponse arrive dans vos messages.');
}

Future<void> _decide(BuildContext context, String id, bool accept, {int? amount, int? days}) async {
  if (accept) {
    final ok = await gDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Accepter ce devis ?', style: _st.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('Montant du devis : ${amount == null ? 'non indiqué' : _fcfa(amount)}${days == null ? '' : ' · délai $days jour(s)'}.\nLe prestataire sera prévenu. Vous pourrez ensuite commander au prix du devis ; rien n’est payé maintenant.', style: _st),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Revoir')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Accepter ce montant')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
  }
  final err = await Backend.decideQuote(id, accept, amount: amount);
  if (!context.mounted) return;
  if (err != null) return gAlert(context, 'Action impossible', err);
  invalidateCompanyData(context);
  gToast(context, accept ? 'Devis accepté. Le prestataire est prévenu.' : 'Devis refusé.');
}

Future<void> _checkout(BuildContext context, String id) async {
  final r = await Backend.rpc('quote_checkout', {'p_quote': id});
  if (!context.mounted) return;
  if (r.error != null) return gAlert(context, 'Commande impossible', Backend.userMessage(r.error!));
  final d = r.data is Map ? Map<String, dynamic>.from(r.data as Map) : const <String, dynamic>{};
  final n = '${d['number'] ?? ''}';
  gToast(context, d['existing'] == true ? 'La commande $n existe déjà : payez-la depuis « Mes commandes ».' : 'Commande $n créée au prix du devis. Payez-la depuis « Mes commandes ».');
}

Future<void> _cancel(BuildContext context, String id) async {
  final err = await Backend.cancelQuote(id);
  if (!context.mounted) return;
  if (err != null) return gAlert(context, 'Action impossible', err);
  invalidateCompanyData(context);
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
            final a = parseFcfa(amount.text), d = int.tryParse(days.text.trim());
            if (a == null || d == null) {
              await gAlert(ctx, 'Devis incomplet', 'Indiquez un montant lisible (par exemple 25 000 ou 2 500,50) et un délai en jours.');
              return;
            }
            if (a > kMaxQuoteBudget || d > 365 || d < 1 || a < 1) {
              await gAlert(ctx, 'Devis invalide', 'Le montant doit être compris entre 1 et ${_fcfa(kMaxQuoteBudget)} et le délai entre 1 et 365 jours.');
              return;
            }
            final err = await Backend.answerQuote(id, a, d, msg.text);
            if (!ctx.mounted) return;
            Navigator.pop(ctx);
            if (!context.mounted) return;
            if (err != null) {
              await gAlert(context, 'Devis non envoyé', err);
            } else {
              invalidateCompanyData(context);
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


/// Écran 40 en mode connecté : le devis s'adresse toujours à un service choisi explicitement (jamais à un service resté en mémoire).
class QuoteServicePicker extends ConsumerWidget {
  const QuoteServicePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MarchePage(
        title: 'Demande de devis',
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          mNote('Une demande de devis est adressée au prestataire d’un service. Choisissez le service qui vous intéresse : le formulaire s’ouvre avec le prestataire clairement indiqué.'),
          mButton('Choisir un service', () => askGeneralQuoteFromList(context, ref)),
        ]),
      );
}

/// Bandeau « Un service sur mesure ? » : choisit un service de la liste puis ouvre la demande de devis ; sans service publié, le dit.
Future<void> askGeneralQuoteFromList(BuildContext context, WidgetRef ref) async {
  if (!Backend.ready) return gAlert(context, 'Hors connexion', 'La demande de devis nécessite la connexion au serveur.');
  final me = Backend.currentUserId;
  final l = [for (final x in ref.read(servicesProvider)) if (me == null || x.sellerId != me) x];
  if (l.isEmpty) return gAlert(context, 'Aucun service publié', 'Aucun autre prestataire n’a encore publié de service. Revenez bientôt ou contactez directement un talent depuis son profil.');
  final v = await tpPick(context, 'Pour quel service ?', [for (final x in l) x.title], allowCustom: false);
  if (v == null || !context.mounted) return;
  ref.read(selectedServiceProvider.notifier).set(v);
  await askQuote(context, ref);
}
