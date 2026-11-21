import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../gen.dart';
import '../nav.dart';
import 'audit.dart';
import 'auth.dart';
import 'backend.dart';
import 'drafts.dart';
import 'engage.dart' show unavailableAction;
import 'entreprise.dart' show invalidateCompanyData;
import 'lots.dart' show firstInt, formDialog, lastInt, publishMissionBrief, myNeedsDialog;
import 'marche/marche_catalogue.dart' show marcheFetcherProvider;
import 'marche/marche_data.dart' show mImageUrl, mInt;
import 'kiosk_mode.dart';
import 'qr.dart';
import 'seller.dart';
import 'store.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

// ================================================================== BORNE (206 à 210)

/// Session de transfert borne → téléphone : code signé, valable 5 minutes, à usage unique.
class QrSession {
  const QrSession(this.token, this.product, this.createdAt, {this.used = false, this.server = false, this.pair = false});
  final String token;
  final LiveProduct product;
  final DateTime createdAt;
  final bool used;

  /// Jeton créé par le serveur (donc réellement scannable) et non code de démonstration local.
  final bool server;

  /// Code d'appariement émis par une borne enregistrée, sans compte (le téléphone le réclame avec son propre compte).
  final bool pair;

  /// Code de suivi affiché sur le ticket (BE-xxxx-XXXX).
  String get tracking => 'BE-${token.substring(0, 4)}-${token.substring(4, 8).toUpperCase()}';
  int secondsLeft([DateTime? now]) => (300 - (now ?? DateTime.now()).difference(createdAt).inSeconds).clamp(0, 300);
  bool get expired => secondsLeft() == 0;
  QrSession consumed() => QrSession(token, product, createdAt, used: true, server: server, pair: pair);
}

/// Jeton pseudo-signé (démonstration) : empreinte du produit + heure + secret.
String signToken(String product, DateTime t) {
  var h = 17;
  for (final c in '$product|${t.millisecondsSinceEpoch}|boutik-secret'.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  final a = (h % 9000 + 1000).toString();
  final b = (h * 7919 % 0xffffff).toRadixString(16).padLeft(6, '0');
  return '$a${b.substring(0, 4)}';
}

class KioskSession extends Notifier<QrSession?> {
  @override
  QrSession? build() => null;

  /// Code de démonstration (hors connexion au serveur uniquement).
  void start(LiveProduct p) {
    final now = DateTime.now();
    state = QrSession(signToken(p.title, now), p, now);
  }

  /// Connecté : le code est créé par le serveur (jeton aléatoire unique, 5 minutes, usage unique). Retourne le message d'erreur, ou null.
  Future<String?> issue(LiveProduct p) async {
    if (KioskTerminal.active) {
      final id = p.id ?? '';
      if (id.isEmpty) return 'Cet article ne peut pas être transféré sur un téléphone pour le moment.';
      final r = await KioskTerminal.pairIssue(id);
      final t = r.token;
      if (t == null) return r.error ?? 'Code indisponible pour le moment.';
      if (ref.mounted) state = QrSession(t, p, DateTime.now(), server: true, pair: true);
      return null;
    }
    final r = await issueQr('kiosk_transfer', p.title, label: p.title, ttlSeconds: 300);
    final t = r.token;
    if (t == null) return r.error ?? 'Code QR indisponible pour le moment.';
    if (ref.mounted) state = QrSession(t, p, DateTime.now(), server: true);
    return null;
  }

  void clear() => state = null;

  /// Téléphone qui vient de scanner le code d'une borne : la confirmation reprend le produit et le code réellement transférés.
  void confirm(LiveProduct p, String token) => state = QrSession(token, p, DateTime.now(), used: true, server: true);
  /// Abandon par l'utilisateur de la borne : le code serveur encore valable est révoqué.
  void cancel() {
    final s = state;
    state = null;
    if (s == null || !s.server || s.used) return;
    if (s.pair) {
      KioskTerminal.pairRevoke(s.token);
    } else {
      Backend.rpc('qr_revoke', {'p_token': s.token});
    }
  }

  void use() => state = state?.consumed();
}

final kioskSessionProvider = NotifierProvider<KioskSession, QrSession?>(KioskSession.new);
final kioskProductProvider = NotifierProvider<StrV, String>(StrV.new);
final kioskQueryProvider = NotifierProvider<StrV, String>(StrV.new);

/// Filtre de la borne (207) : 0 tout, 1 produits, 2 services.
class KioskKind extends Notifier<int> {
  @override
  int build() => 0;
  void set(int v) => state = v;
}

final kioskKindProvider = NotifierProvider<KioskKind, int>(KioskKind.new);

/// Page affichée de la grille de la borne (4 articles par page).
final kioskPageProvider = NotifierProvider<IntV, int>(IntV.new);
const kioskPageSize = 4;

bool kioskIsService(LiveProduct p) => p.category == 'Services';

/// Carte de la fonction publique `marketplace_search` vue comme un article de la borne (un service : prix « à partir de », stock sans objet).
LiveProduct kioskServiceFromCard(Map<String, dynamic> c) {
  final shop = '${c['shop_name'] ?? ''}'.trim();
  final img = mImageUrl(c['image']);
  final id = '${c['id'] ?? ''}';
  return LiveProduct('${c['title']}', 'Service étudiant', mInt(c['price']), shop.isEmpty ? 'Prestataire étudiant' : shop, '', img.isEmpty ? 'placeholder' : img,
      category: 'Services', stock: mInt(c['stock']), id: id.isEmpty ? null : id);
}

/// Services approuvés, lus comme le catalogue Découverte (RPC `marketplace_search` avec `p_offer_type` = service). Hors connexion : aucun.
/// Un échec de lecture reste une erreur (affichée honnêtement), jamais une liste vide.
final kioskServicesProvider = FutureProvider<List<LiveProduct>>((ref) async {
  if (!Backend.ready) return const <LiveProduct>[];
  final rows = await ref.read(marcheFetcherProvider)('marketplace_search', const {'p_offer_type': 'service', 'p_sort': 'recent', 'p_limit': 100});
  return [for (final c in rows) if ('${c['title'] ?? ''}'.isNotEmpty) kioskServiceFromCard(c)];
}, retry: (_, _) => null);

/// Prix affiché à la borne : un service sans tarif est « sur devis », sinon « à partir de ».
String kioskPrice(LiveProduct p) => p.title == 'Aucun article disponible' && p.price == 0 ? '' : (!kioskIsService(p) ? fcfa(p.price) : (p.price <= 0 ? 'Sur devis' : 'Dès ${fcfa(p.price)}'));

/// Tous les résultats de la recherche (filtre et texte), avant découpage en pages.
final kioskMatchesProvider = Provider<List<LiveProduct>>((ref) {
  final q = normText(ref.watch(kioskQueryProvider).trim());
  final k = ref.watch(kioskKindProvider);
  final services = Backend.ready && k != 1 ? (ref.watch(kioskServicesProvider).value ?? const <LiveProduct>[]) : const <LiveProduct>[];
  final seen = <String>{};
  return [
    for (final p in [...ref.watch(allProductsProvider), ...services])
      if ((q.isEmpty || normText('${p.title} ${p.department}').contains(q)) && (k == 0 || (k == 2) == kioskIsService(p)) && seen.add(p.title)) p,
  ];
});

/// Message de la grille vide : distingue chargement, échec de lecture, aucun service approuvé et recherche sans résultat.
String kioskEmptyText(WidgetRef ref) {
  if (ref.watch(kioskKindProvider) != 2) return 'Aucun article ne correspond à votre recherche.';
  if (ref.watch(kioskQueryProvider).trim().isNotEmpty && (ref.watch(kioskServicesProvider).value ?? const []).isNotEmpty) return 'Aucun service ne correspond à votre recherche.';
  return ref.watch(kioskServicesProvider).when(
        loading: () => 'Chargement des services…',
        error: (_, _) => 'Les services ne peuvent pas être chargés pour le moment. Touchez « Services » pour réessayer.',
        data: (l) => l.isEmpty ? 'Aucun service approuvé pour le moment. Les étudiants peuvent en proposer depuis leur espace vendeur.' : 'Aucun service ne correspond à votre recherche.',
      );
}

int kioskPageCount(int total) => total == 0 ? 1 : (total + kioskPageSize - 1) ~/ kioskPageSize;

/// Articles de la page courante.
final kioskProductsProvider = Provider<List<LiveProduct>>((ref) {
  final all = ref.watch(kioskMatchesProvider);
  final page = ref.watch(kioskPageProvider).clamp(0, kioskPageCount(all.length) - 1).toInt();
  return all.skip(page * kioskPageSize).take(kioskPageSize).toList();
});

final kioskCurrentProvider = Provider<LiveProduct>((ref) {
  final all = ref.watch(allProductsProvider);
  final t = ref.watch(kioskProductProvider);
  final hit = all.where((p) => p.title == t);
  if (hit.isNotEmpty) return hit.first;
  // un service choisi dans la grille n'est pas dans le catalogue des produits
  if (Backend.ready && t.isNotEmpty) {
    final s = (ref.watch(kioskServicesProvider).value ?? const <LiveProduct>[]).where((p) => p.title == t);
    if (s.isNotEmpty) return s.first;
  }
  // catalogue vide (serveur sans annonce publiée) : fiche neutre, non vendable, plutôt qu'une erreur d'affichage
  if (all.isEmpty) return const LiveProduct('Aucun article disponible', '', 0, '', '', 'placeholder', showcase: true);
  return all.first;
});

/// Compte à rebours en direct (désactivé dans les tests pour des rendus stables).
final kioskTickProvider = StreamProvider.autoDispose<int>((ref) {
  if (!GAnim.enabled) return Stream.value(0);
  return Stream.periodic(const Duration(seconds: 1), (i) => i);
});

/// Produit affiché sur le ticket : celui du code actif, sinon celui de la fiche ouverte.
LiveProduct kioskView(WidgetRef ref) {
  final s = ref.watch(kioskSessionProvider);
  return s != null ? s.product : ref.watch(kioskCurrentProvider);
}

String countdown(WidgetRef ref) {
  ref.watch(kioskTickProvider);
  final s = ref.watch(kioskSessionProvider)?.secondsLeft();
  if (s == null) return Backend.ready ? '--:--' : '5:00';
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

Future<void> startPhoneTransfer(WidgetRef ref, BuildContext context) async {
  final p = ref.read(kioskCurrentProvider);
  if (Backend.ready && p.showcase) {
    gToast(context, 'Produit d’exemple : aucun code possible pour le moment.');
    return;
  }
  if (Backend.ready && kioskIsService(p)) return kioskAskQuote(context, p);
  if (Backend.ready) {
    final err = await ref.read(kioskSessionProvider.notifier).issue(p);
    if (!context.mounted) return;
    if (err != null) {
      await gAlert(context, 'Code indisponible', Backend.userMessage(err));
      return;
    }
  } else {
    ref.read(kioskSessionProvider.notifier).start(p);
  }
  ref.read(auditProvider.notifier).log(KioskTerminal.label, 'Code de transfert créé', p.title, 'Connexions');
  gOpen(context, '209');
}

/// Un service ne se commande pas au panier : il passe par la demande de devis de sa fiche (connexion demandée à l'envoi).
void kioskAskQuote(BuildContext context, LiveProduct p) {
  final id = p.id ?? '';
  if (id.isEmpty) {
    gToast(context, 'Ce service se demande sur devis depuis l’application.');
    return;
  }
  gToast(context, 'Les services se demandent sur devis : ouverture de la fiche.');
  GoRouter.maybeOf(context)?.push('/marche/produit/$id');
}

/// 208 « Commander » : crée une vraie commande par le chemin du panier de la marketplace. L'article rejoint le panier enregistré du
/// compte connecté, puis le panier existant mène à la livraison et au paiement, où `marketplace_checkout` vérifie prix, quantité et stock
/// côté serveur (erreurs affichées telles quelles). Aucune commande anonyme : un visiteur est invité à se connecter.
Future<void> kioskOrder(WidgetRef ref, BuildContext context) async {
  final p = ref.read(kioskCurrentProvider);
  if (p.showcase) {
    gToast(context, 'Produit d’exemple : non disponible à la vente');
    return;
  }
  if (!Backend.ready) {
    // démonstration (hors connexion au serveur) : panier local, aucune commande réelle
    ref.read(cartProvider.notifier).add(p.toLine());
    gToast(context, 'Ajouté au panier de cet appareil. Terminez la commande depuis le panier ou avec « Sur mon téléphone ».');
    return;
  }
  if (kioskIsService(p)) return kioskAskQuote(context, p);
  if (KioskTerminal.active) {
    // terminal public : aucune connexion ici, la commande se poursuit sur le téléphone de la personne
    gToast(context, 'Pour commander, continuez sur votre téléphone : scannez le code.');
    return startPhoneTransfer(ref, context);
  }
  final mineSeller = p.sellerId;
  if (mineSeller != null && mineSeller.isNotEmpty && mineSeller == Backend.userId) {
    gToast(context, 'C’est votre propre annonce : vous ne pouvez pas l’acheter.');
    return;
  }
  if (!await requireLogin(context, ref, 'commander cet article') || !context.mounted) return;
  final stock = p.stock;
  if (stock != null && stock <= 0) {
    gToast(context, 'Cet article n’est plus disponible.');
    return;
  }
  final inCart = ref.read(cartProvider).where((l) => l.title == p.title).fold<int>(0, (a, l) => a + l.qty);
  if (stock != null && inCart >= stock) {
    gToast(context, 'Stock insuffisant : $stock exemplaire(s) disponible(s), déjà dans votre panier.');
  } else {
    ref.read(cartProvider.notifier).add(p.toLine());
    gToast(context, 'Ajouté à votre panier : vérifiez la quantité puis validez pour créer votre commande.');
  }
  gOpen(context, '06');
}

/// Surveille le code affiché à la borne : dès que le téléphone l'a scanné (le serveur le déclare « utilisé »), la confirmation s'ouvre.
/// Hors connexion au serveur, il n'y a rien à surveiller.
class KioskTransferWatcher extends ConsumerStatefulWidget {
  const KioskTransferWatcher({super.key});

  @override
  ConsumerState<KioskTransferWatcher> createState() => _KioskTransferWatcherState();
}

class _KioskTransferWatcherState extends ConsumerState<KioskTransferWatcher> {
  Timer? _timer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (Backend.ready) _timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  Future<void> _poll() async {
    final s = ref.read(kioskSessionProvider);
    if (_busy || s == null || !s.server || s.used || s.expired) return;
    _busy = true;
    if (s.pair) {
      final st = await KioskTerminal.pairStatus(s.token);
      _busy = false;
      if (!mounted || st != 'used' || ref.read(kioskSessionProvider)?.token != s.token) return;
      ref.read(kioskSessionProvider.notifier).use();
      gOpen(context, '210');
      return;
    }
    final r = await Backend.rpc('qr_resolve', {'p_token': s.token, 'p_consume': false});
    _busy = false;
    final d = r.data;
    if (!mounted || d is! Map || d['reason'] != 'used' || ref.read(kioskSessionProvider)?.token != s.token) return;
    ref.read(kioskSessionProvider.notifier).use();
    gOpen(context, '210');
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Le téléphone scanne le code : vérifie la validité, l'usage unique et envoie l'article dans le panier.
void scanQr(WidgetRef ref, BuildContext context) {
  if (Backend.ready) {
    // connecté : lecture réelle par la caméra ; le serveur valide le code (expiration, usage unique)
    scanAndHandleQr(context, ref);
    return;
  }
  var s = ref.read(kioskSessionProvider);
  if (s == null) {
    // Accès direct à l'écran 209 : on génère le code du produit courant (comme l'écran 208 l'aurait fait).
    ref.read(kioskSessionProvider.notifier).start(ref.read(kioskCurrentProvider));
    s = ref.read(kioskSessionProvider);
  }
  if (s == null) return;
  if (s.used) {
    ref.read(auditProvider.notifier).log('Téléphone', 'Code déjà utilisé (rejeu refusé)', s.tracking, 'Connexions', level: 'Critique');
    gToast(context, 'Code déjà utilisé : demandez un nouveau code à la borne.');
    return;
  }
  if (s.expired) {
    ref.read(auditProvider.notifier).log('Téléphone', 'Code expiré refusé', s.tracking, 'Connexions', level: 'Sensible');
    gToast(context, 'Code expiré (5 minutes). Recommencez sur la borne.');
    return;
  }
  ref.read(kioskSessionProvider.notifier).use();
  ref.read(cartProvider.notifier).add(s.product.toLine());
  ref.read(auditProvider.notifier).log(ref.read(profileAccountProvider).name, 'Code de borne utilisé', s.tracking, 'Connexions');
  gOpen(context, '210');
}

// ================================================================== MISSIONS (191 à 201)

class Mission {
  const Mission({
    required this.id,
    required this.kind,
    required this.desc,
    required this.total,
    required this.date,
    this.accepted = false,
    this.funded = 0,
    this.proof = 0,
    this.released = 0,
    this.team = '',
    this.deadline = '',
    this.status = '',
    this.milestoneAmounts = const [],
    this.steps = const [],
    this.real = false,
    this.uuid = '',
    this.role = '',
    this.counterpart = '',
    this.invoice = '',
    this.pays = const [],
    this.proofs = const [],
  });
  final String id, kind, desc, date;
  final int total;
  final bool accepted;
  final int funded, proof, released; // nombre de jalons financés / avec preuve / libérés

  /// Identifiant serveur de la mission réelle (vide pour la mission d'exemple).
  final String uuid;

  /// Rôle du compte sur cette mission (« client » ou « provider ») ; vide pour la mission d'exemple.
  final String role;

  /// Nom abrégé du prestataire (vu par le client) et numéro de facture de mission (accord conclu).
  final String counterpart, invoice;

  /// Par jalon : état du règlement entre les parties (unpaid · declared · confirmed) et preuve de livraison (texte).
  final List<String> pays, proofs;

  bool get isProvider => role == 'provider';
  bool get isClient => role == 'client';

  /// Mission lue sur le serveur : équipe attribuée, échéance, statut serveur et montants réels des jalons.
  final String team, deadline, status;
  final List<int> milestoneAmounts;

  /// Jalons réels : titre et état lisible (« Validé », « Livré, à valider », « Correction demandée », « À venir »).
  final List<(String, String)> steps;
  final bool real;

  /// Titre et état du jalon i (vides s'il n'existe pas).
  (String, String) step(int i) => i < steps.length ? steps[i] : (i == 0 && real && steps.isEmpty ? ('Jalons à définir par l’équipe', '') : ('', ''));

  /// Aucune mission (compte connecté qui n'en a pas) : rien de la maquette n'est affiché à sa place.
  static const none = Mission(id: '', kind: '', desc: '', total: 0, date: '');

  /// Ligne serveur (missions, proposition acceptée, jalons) ; le séquestre n'est pas activé : rien n'est « financé ».
  factory Mission.fromServer(Map<String, dynamic> m, int? acceptedAmount, List<Map<String, dynamic>> miles) {
    final st = (m['status'] ?? '').toString();
    final validated = miles.where((x) => x['status'] == 'validated').length;
    final delivered = miles.where((x) => x['status'] == 'submitted' || x['status'] == 'validated').length;
    return Mission(
      id: (m['number'] ?? '').toString(),
      kind: ((m['title'] ?? '').toString().trim().isNotEmpty ? m['title'] : (m['kind'] ?? 'Mission')).toString(),
      desc: (m['description'] ?? '').toString(),
      total: acceptedAmount ?? (m['total'] as num?)?.toInt() ?? (m['budget_max'] as num?)?.toInt() ?? 0,
      date: missionDate(m['created_at']),
      accepted: const {'assigned', 'in_progress', 'delivered', 'closed'}.contains(st),
      proof: delivered,
      released: validated,
      team: (m['assigned_team'] ?? '').toString(),
      deadline: (m['deadline'] ?? '').toString(),
      status: st,
      milestoneAmounts: [for (final x in miles) (x['amount'] as num?)?.toInt() ?? 0],
      steps: [
        for (final x in miles)
          (
            (x['title'] ?? '').toString(),
            switch ((x['status'] ?? '').toString()) {
              'validated' => 'Validé',
              'submitted' => 'Livré, à valider',
              'correction' => 'Correction demandée',
              _ => 'À venir',
            },
          ),
      ],
      real: true,
      uuid: (m['id'] ?? '').toString(),
      role: (m['role'] ?? '').toString(),
      counterpart: (m['counterpart'] ?? '').toString(),
      invoice: ((m['agreement'] as Map?)?['invoice_number'] ?? '').toString(),
      pays: [for (final x in miles) (x['pay_status'] ?? 'unpaid').toString()],
      proofs: [for (final x in miles) (x['proof_note'] ?? '').toString()],
    );
  }

  static const shares = [30, 40, 30];
  int amountOf(int i) => milestoneAmounts.isNotEmpty ? milestoneAmounts[i.clamp(0, milestoneAmounts.length - 1)] : total * shares[i.clamp(0, 2)] ~/ 100;

  /// Montant du jalon i seulement s'il est connu : pour une mission du serveur sans jalon, aucun 30/40/30 n'est inventé.
  int? knownAmountOf(int i) => (milestoneAmounts.isNotEmpty || !real) ? amountOf(i) : null;

  /// Montant affichable du jalon i : « — » s'il n'est pas connu.
  String amountLabel(int i) => knownAmountOf(i) == null ? '—' : fcfa(knownAmountOf(i)!);

  /// Commission et gain étudiant : estimations de l'aperçu hors connexion uniquement. Le serveur n'écrit aucune ligne « mission »
  /// dans le séquestre ; pour une mission réelle ils sont indisponibles (null), calculés à l'encaissement.
  int? get fee => real ? null : total ~/ 10;
  int get releasedAmount => [for (var i = 0; i < released; i++) amountOf(i)].fold(0, (a, b) => a + b);
  int? get studentEarned => real ? null : releasedAmount * 70 ~/ 100;
  int get pendingAmount => proof > released ? (knownAmountOf(released) ?? 0) : 0;

  /// Montants réels d'une mission du serveur (aucun séquestre) : jalons dont le règlement est confirmé par le prestataire,
  /// jalons validés mais pas encore réglés, jalons livrés en attente de validation du client.
  int get confirmedPaid => real ? _sumWhere((i) => i < pays.length && pays[i] == 'confirmed') : 0;
  int get validatedUnpaid => real ? _sumWhere((i) => i < steps.length && steps[i].$2 == 'Validé' && (i >= pays.length || pays[i] != 'confirmed')) : 0;
  int get awaitingValidation => real ? _sumWhere((i) => i < steps.length && steps[i].$2 == 'Livré, à valider') : 0;
  int _sumWhere(bool Function(int) test) => [for (var i = 0; i < milestoneAmounts.length; i++) if (test(i)) milestoneAmounts[i]].fold(0, (a, b) => a + b);

  int get nextToFund => funded.clamp(0, 3);
  int get milestoneCount => milestoneAmounts.isNotEmpty ? milestoneAmounts.length : 3;
  int get pct => real
      ? (milestoneAmounts.isEmpty ? 0 : (released * 100 / milestoneAmounts.length).round())
      : ((released * 3 + proof * 2 + funded) * 100 / 9).round().clamp(0, 100);

  Mission copyWith({bool? accepted, int? funded, int? proof, int? released}) => Mission(
        id: id, kind: kind, desc: desc, total: total, date: date, team: team, deadline: deadline, status: status, milestoneAmounts: milestoneAmounts, steps: steps, real: real, uuid: uuid,
        role: role, counterpart: counterpart, invoice: invoice, pays: pays, proofs: proofs,
        accepted: accepted ?? this.accepted, funded: funded ?? this.funded, proof: proof ?? this.proof, released: released ?? this.released);
}

/// « 12 oct. 2026 » à partir d'une date serveur.
String missionDate(Object? iso) {
  const m = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
  final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
  return d == null ? '' : '${d.day} ${m[d.month - 1]} ${d.year}';
}

/// « Équipe MMI · livraison le 28 nov. » à partir de la mission réelle.
String missionTeamLine(Mission m) => [m.team.isEmpty ? 'Équipe à attribuer' : 'Équipe ${m.team}', if (m.deadline.isNotEmpty) 'livraison le ${m.deadline}'].join(' · ');

/// Libellé d'un statut serveur de mission.
String missionStatusLabel(String s) => switch (s) {
      'published' => 'Propositions en cours',
      'assigned' => 'Équipe attribuée',
      'in_progress' => 'En cours',
      'delivered' => 'Livrée',
      'closed' => 'Terminée',
      _ => s,
    };

const missionKinds = ['Identité visuelle', 'Savons et parfums', 'Vidéo et photo', 'Site ou application', 'Prototype', 'Étude ou audit'];

/// Pastille d'un jalon dans la frise de la mission : validé (coche verte), livré à valider (point sombre), à venir (anneau).
/// En démonstration, l'état de la maquette (premier jalon fait, deuxième en cours).
List<Widget> missionDot(Mission m, int i, double y) {
  final state = demoContent ? const ['Validé', 'Livré, à valider', 'À venir', 'À venir'][i] : m.step(i).$2;
  if (state == 'Validé') {
    return [gP(24, y, 20, 20, gBox(color: const Color(0xFF1F9D6B), oval: true)), gP(27.333, y + 4.25, 13.333, 11.042, gImg('assets/figma/v/23149818a3337a.svg'))];
  }
  if (state == 'Livré, à valider') return [gP(24, y, 20, 20, gBox(color: const Color(0xFF111015), oval: true))];
  return [gP(24, y, 20, 20, gBox(color: const Color(0xFFFFFFFF), border: const Color(0xFFE6E1EE), bw: 2, oval: true))];
}

class MissionNotifier extends Notifier<Mission> {
  @override
  Mission build() {
    if (Backend.ready) {
      // connecté : la mission réelle du compte, ou aucune ; jamais la mission d'exemple de la maquette
      final uid = ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
      if (uid.isNotEmpty) Future.microtask(refresh);
      return Mission.none;
    }
    return const Mission(
        id: '#BR-0412', kind: 'Identité visuelle', desc: 'Identité visuelle complète pour la marque de parfums Mbella.', total: 180000, date: '12 oct. 2026',
        accepted: true, funded: 2, proof: 1, released: 1);
  }

  /// Relit les missions sur le serveur (client ET prestataire) et garde celle choisie (selectedMissionIdProvider), à défaut la plus récente ;
  /// une lecture échouée laisse l'état inchangé (et non « aucune mission »).
  Future<void> refresh() async {
    final all = await Backend.myMissionsList();
    if (!ref.mounted) return;
    if (all != null) {
      ref.read(missionChoicesProvider.notifier).set(all);
      final pick = pickMissionJson(all, ref.read(selectedMissionIdProvider));
      state = pick == null ? Mission.none : missionFromMyMissions(pick);
      ref.read(missionLoadedProvider.notifier).set(true);
      return;
    }
    final r = await Backend.currentMission();
    if (!ref.mounted) return;
    if (r == null) {
      if (!ref.read(missionLoadedProvider)) ref.read(missionFailedProvider.notifier).set(true);
      return;
    }
    ref.read(missionFailedProvider.notifier).set(false);
    state = r.mission == null ? Mission.none : Mission.fromServer(r.mission!, r.accepted, r.milestones);
    ref.read(missionLoadedProvider.notifier).set(true);
  }

  void create(Mission m) => state = m;
  void accept() => state = state.copyWith(accepted: true);
  void fund() => state = state.copyWith(funded: (state.funded + 1).clamp(0, 3));
  void sendProof() => state = state.copyWith(proof: (state.proof + 1).clamp(0, 3));
  void retractProof() => state = state.copyWith(proof: state.released);
  void release() => state = state.copyWith(released: (state.released + 1).clamp(0, 3), proof: state.proof < state.released + 1 ? state.released + 1 : state.proof);
}

final missionProvider = NotifierProvider<MissionNotifier, Mission>(MissionNotifier.new);

/// Mission choisie par le compte (vide : la plus récemment modifiée). Voir selectMission.
final selectedMissionIdProvider = NotifierProvider<StrV, String>(StrV.new);

class _MissionChoices extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() {
    ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
    return const [];
  }

  void set(List<Map<String, dynamic>> v) => state = v;
}

/// Toutes les missions du compte (client et prestataire), pour choisir celle que les écrans 192 à 197 affichent.
final missionChoicesProvider = NotifierProvider<_MissionChoices, List<Map<String, dynamic>>>(_MissionChoices.new);

/// Mission choisie dans la liste (la plus récente à défaut) ; null s'il n'y en a aucune.
Map<String, dynamic>? pickMissionJson(List<Map<String, dynamic>> all, String selected) {
  if (all.isEmpty) return null;
  if (selected.isNotEmpty) {
    for (final m in all) {
      if ('${m['id']}' == selected) return m;
    }
  }
  return all.first;
}

/// Mission construite depuis une ligne de my_missions (jalons avec preuve et règlement, accord).
Mission missionFromMyMissions(Map<String, dynamic> m) {
  final miles = [for (final x in (m['milestones'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
  final amount = ((m['agreement'] as Map?)?['amount'] as num?)?.toInt();
  return Mission.fromServer({...m, 'assigned_team': m['team']}, amount, miles);
}

/// Les écrans 192 à 197 passent à la mission [id] (notification, liste « Mes missions »).
void selectMission(WidgetRef ref, String id) {
  ref.read(selectedMissionIdProvider.notifier).set(id);
  ref.read(missionProvider.notifier).refresh();
}

class _MissionLoaded extends Notifier<bool> {
  @override
  bool build() {
    ref.watch(authProvider.select((a) => a.current?.serverId ?? '')); // nouveau compte : rien n'est encore lu
    return false;
  }

  void set(bool v) => state = v;
}

/// Vrai dès qu'une lecture de la mission a réussi (Mission.none signifie alors « aucune mission »).
final missionLoadedProvider = NotifierProvider<_MissionLoaded, bool>(_MissionLoaded.new);

class _MissionFailed extends Notifier<bool> {
  @override
  bool build() {
    ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
    return false;
  }

  void set(bool v) => state = v;
}

/// Vrai quand la lecture de la mission a échoué sans jamais réussir : les écrans de suivi le disent au lieu d'afficher des zéros.
final missionFailedProvider = NotifierProvider<_MissionFailed, bool>(_MissionFailed.new);

/// Écrans du suivi d'une mission : sans mission réelle, ils ne montrent pas la mission d'exemple.
const missionScreens = {'192', '193', '194', '195', '196', '197', '201'};

/// Redirection vers « Votre besoin » (191) : seulement pour un compte sans mission sur un écran qui n'a rien à montrer sans mission.
/// 195 et 201 sont les écrans du prestataire : un talent sans mission retenue y voit ses propositions, pas le formulaire du client.
bool redirectMissionScreen({required bool ready, required bool loaded, required Mission mission, String screen = '', String role = ''}) {
  if (!(ready && loaded && !mission.real)) return false;
  return !(providerMissionScreens.contains(screen) && const {'student', 'dept', 'admin'}.contains(role));
}

/// Écrans du prestataire (195 « Ajouter une preuve », 201 « Mes missions ») : un compte qui n'est pas talent (Client, entreprise) est renvoyé
/// vers le suivi de sa propre mission (194), qui redirige à son tour vers « Votre besoin » (191) s'il n'en a aucune.
const providerMissionScreens = {'195', '201'};

bool redirectProviderScreen({required bool ready, required String screen, required String role}) =>
    ready && providerMissionScreens.contains(screen) && !const {'student', 'dept', 'admin'}.contains(role);
final missionKindProvider = NotifierProvider<IntV, int>(IntV.new);

String _today() {
  const m = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
  final d = DateTime.now();
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

/// Fourchette de budget saisie : « 100 000 » ou « 100 000 – 150 000 FCFA » ; null si aucun montant exploitable.
({int min, int max})? parseBudgetRange(String s) {
  final a = firstInt(s), b = lastInt(s);
  if (a == null || b == null || a <= 0 || b <= 0 || a > 100000000 || b > 100000000) return null;
  return a <= b ? (min: a, max: b) : (min: b, max: a);
}

/// Date souhaitée « JJ/MM/AAAA » (aujourd'hui ou plus tard) ; null si elle est mal écrite, inexistante ou passée.
DateTime? parseBriefDate(String s, [DateTime? now]) {
  final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(s.trim());
  if (m == null) return null;
  final d = int.parse(m.group(1)!), mo = int.parse(m.group(2)!), y = int.parse(m.group(3)!);
  final date = DateTime(y, mo, d);
  if (date.year != y || date.month != mo || date.day != d) return null;
  final t = now ?? DateTime.now();
  return date.isBefore(DateTime(t.year, t.month, t.day)) ? null : date;
}

void submitBrief(WidgetRef ref, BuildContext context) {
  final f = ref.read(formProvider);
  final desc = (f['ms_desc'] ?? '').trim();
  final bud = (f['ms_budget'] ?? '').trim(), when = (f['ms_date'] ?? '').trim();
  final errors = <String, String>{};
  if (desc.length < 20) errors['ms_desc'] = 'Décrivez votre besoin (20 caractères minimum).';
  final range = bud.isEmpty ? null : parseBudgetRange(bud);
  if (bud.isNotEmpty && range == null) errors['ms_budget'] = 'Indiquez un montant en FCFA (ex. 100 000 ou 100 000 – 150 000).';
  if (when.isNotEmpty && parseBriefDate(when) == null) errors['ms_date'] = 'Date invalide : JJ/MM/AAAA, à partir d’aujourd’hui.';
  if (errors.isNotEmpty) {
    ref.read(errorsProvider.notifier).setAll(errors);
    return;
  }
  ref.read(errorsProvider.notifier).clear();
  final kind = missionKinds[ref.read(missionKindProvider).clamp(0, 5)];
  if (Backend.ready) {
    _serverBrief(context, ref, kind, desc, range, when);
    return;
  }
  final id = '#BR-${(413 + DateTime.now().second).toString().padLeft(4, '0')}';
  ref.read(missionProvider.notifier).create(Mission(id: id, kind: kind, desc: desc, total: 180000, date: _today()));
  ref.read(auditProvider.notifier).log(ref.read(profileAccountProvider).name, 'Brief envoyé', '$id · $kind', 'Validations');
  gToast(context, 'Besoin envoyé : l’administrateur prépare votre devis');
  gOpen(context, '192');
}

/// Avec le serveur, le parcours de mission (191 à 201) passe par les fonctions serveur (missions, propositions, jalons) :
/// la mission d'exemple de la maquette n'est jamais modifiée ni présentée comme réelle, et aucun paiement n'est simulé.
Future<void> _serverBrief(BuildContext context, WidgetRef ref, String kind, String desc, ({int min, int max})? range, String when) async {
  if (!await publishMissionBrief(context, ref, kind, desc, budgetMin: range?.min, budgetMax: range?.max, deadline: when) || !context.mounted) return;
  ref.read(formProvider.notifier).clear(const ['ms_desc', 'ms_budget', 'ms_date']);
  ref.read(missionProvider.notifier).refresh();
  gToast(context, 'Besoin envoyé : le département est prévenu et qualifie les équipes ; vous recevrez les propositions.');
  await myNeedsDialog(context, ref);
}

Future<void> _milestonePaymentUnavailable(BuildContext context) => unavailableAction(context, 'Paiement du jalon non géré ici',
    'Boutik-École ne bloque ni ne verse l’argent d’une mission : le paiement de chaque jalon se convient directement avec le prestataire. L’application suit seulement la livraison et la validation des jalons.');

void acceptQuote(WidgetRef ref, BuildContext context) {
  if (Backend.ready) {
    myNeedsDialog(context, ref); // propositions réellement reçues : accepter ou refuser
    return;
  }
  ref.read(missionProvider.notifier).accept();
  ref.read(auditProvider.notifier).log(ref.read(profileAccountProvider).name, 'Devis accepté', ref.read(missionProvider).id, 'Finances');
  gOpen(context, '193');
}

void payNextMilestone(WidgetRef ref, BuildContext context) {
  if (Backend.ready) {
    _milestonePaymentUnavailable(context);
    return;
  }
  final m = ref.read(missionProvider);
  if (m.funded >= 3) {
    gToast(context, 'Tous les jalons sont déjà financés.');
    gOpen(context, '194');
    return;
  }
  final amount = m.amountOf(m.funded);
  ref.read(missionProvider.notifier).fund();
  ref.read(auditProvider.notifier).log(ref.read(profileAccountProvider).name, 'Jalon financé (séquestre)', '${m.id} · ${fcfa(amount)}', 'Finances');
  gToast(context, 'Paiement de ${fcfa(amount)} bloqué en séquestre');
  gOpen(context, '194');
}

void submitProof(WidgetRef ref, BuildContext context) {
  if (Backend.ready) {
    // La preuve (texte, photo, fichier) se saisit et s'envoie dans le panneau de l'écran 195 (submit_milestone) ; ici : retour au suivi des missions.
    gOpen(context, '201');
    return;
  }
  final f = ref.read(formProvider);
  final txt = (f['ms_proof'] ?? 'Trois pistes de logo, déclinées en couleurs').trim();
  final m = ref.read(missionProvider);
  if (txt.length < 15) {
    ref.read(errorsProvider.notifier).setAll({'ms_proof': 'Décrivez ce qui a été réalisé (15 caractères minimum).'});
    return;
  }
  if (m.proof > m.released) {
    gToast(context, 'Une preuve est déjà en attente de validation.');
    return;
  }
  if (m.funded <= m.released) {
    gToast(context, 'Le client n’a pas encore financé ce jalon.');
    return;
  }
  ref.read(errorsProvider.notifier).clear();
  ref.read(missionProvider.notifier).sendProof();
  Drafts.clear('195', const ['ms_proof']);
  ref.read(auditProvider.notifier).log(ref.read(profileAccountProvider).name, 'Preuve envoyée', m.id, 'Validations');
  gToast(context, 'Preuve envoyée : le client est notifié');
  gOpen(context, '201');
}

/// Jalon livré à valider de la mission réelle (1er jalon « Livré, à valider »), position serveur comprise ; null s'il n'y en a pas.
({String uuid, int position, String title})? deliveredMilestone(Mission m) {
  if (!m.real || m.uuid.isEmpty) return null;
  for (var i = 0; i < m.steps.length; i++) {
    if (m.steps[i].$2 == 'Livré, à valider') return (uuid: m.uuid, position: i + 1, title: m.steps[i].$1);
  }
  return null;
}

/// Décision du client sur le jalon affiché : valide (statut seulement : aucun argent n'est libéré par l'application) ou demande une correction.
Future<void> _decideDelivered(WidgetRef ref, BuildContext context, {required bool validate}) async {
  if (ref.read(missionProvider).isProvider) {
    gToast(context, 'Seul le client valide un jalon livré : vous serez prévenu de sa décision.');
    return;
  }
  final j = deliveredMilestone(ref.read(missionProvider));
  if (j == null) {
    gToast(context, 'Aucun jalon livré à valider pour le moment.');
    return;
  }
  var note = '';
  if (validate) {
    final yes = await gDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Valider « ${j.title} » ?'),
        content: const Text('Vous acceptez la livraison de ce jalon. Boutik-École ne verse aucun argent : le paiement se règle directement avec le prestataire.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Valider la livraison'))],
      ),
    );
    if (yes != true || !context.mounted) return;
  } else {
    final v = await formDialog(context, 'Demander une correction', [('Correction attendue', '')], submit: 'Envoyer');
    if (v == null || !context.mounted) return;
    note = v.first;
  }
  final r = await Backend.rpc('decide_milestone', {'p_mission': j.uuid, 'p_position': j.position, 'p_validate': validate, 'p_note': note});
  if (!context.mounted) return;
  if (r.error != null) {
    await gAlert(context, 'Action impossible', r.error!);
    return;
  }
  await ref.read(missionProvider.notifier).refresh();
  if (!context.mounted) return;
  invalidateCompanyData(context);
  gToast(context, validate ? 'Jalon validé : la livraison est acceptée.' : 'Correction demandée au prestataire.');
  gOpen(context, '194');
}

void releaseMilestone(WidgetRef ref, BuildContext context) {
  if (Backend.ready) {
    _decideDelivered(ref, context, validate: true);
    return;
  }
  final m = ref.read(missionProvider);
  if (m.proof <= m.released) {
    gToast(context, 'Aucune preuve à valider pour le moment.');
    return;
  }
  final amount = m.amountOf(m.released);
  ref.read(missionProvider.notifier).release();
  ref.read(auditProvider.notifier).log(ref.read(profileAccountProvider).name, 'Jalon validé, paiement libéré', '${m.id} · ${fcfa(amount)}', 'Finances');
  gToast(context, 'Jalon validé : ${fcfa(amount)} libérés');
  gOpen(context, '194');
}

void askCorrection(WidgetRef ref, BuildContext context) {
  if (Backend.ready) {
    _decideDelivered(ref, context, validate: false);
    return;
  }
  final m = ref.read(missionProvider);
  if (m.proof <= m.released) {
    gToast(context, 'Aucune preuve à corriger.');
    return;
  }
  ref.read(missionProvider.notifier).retractProof();
  ref.read(auditProvider.notifier).log(ref.read(profileAccountProvider).name, 'Correction demandée', m.id, 'Validations', level: 'Sensible');
  gToast(context, 'Correction demandée : l’équipe est notifiée');
  gOpen(context, '194');
}
