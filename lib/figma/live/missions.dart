import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart';
import '../nav.dart';
import 'audit.dart';
import 'auth.dart';
import 'seller.dart';
import 'store.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

// ================================================================== BORNE (206 à 210)

/// Session de transfert borne → téléphone : code signé, valable 5 minutes, à usage unique.
class QrSession {
  const QrSession(this.token, this.product, this.createdAt, {this.used = false});
  final String token;
  final LiveProduct product;
  final DateTime createdAt;
  final bool used;

  /// Code de suivi affiché sur le ticket (BE-xxxx-XXXX).
  String get tracking => 'BE-${token.substring(0, 4)}-${token.substring(4, 8).toUpperCase()}';
  int secondsLeft([DateTime? now]) => (300 - (now ?? DateTime.now()).difference(createdAt).inSeconds).clamp(0, 300);
  bool get expired => secondsLeft() == 0;
  QrSession consumed() => QrSession(token, product, createdAt, used: true);
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

  void start(LiveProduct p) {
    final now = DateTime.now();
    state = QrSession(signToken(p.title, now), p, now);
  }

  void clear() => state = null;
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

final kioskProductsProvider = Provider<List<LiveProduct>>((ref) {
  final q = normText(ref.watch(kioskQueryProvider).trim());
  final k = ref.watch(kioskKindProvider);
  return [
    for (final p in ref.watch(allProductsProvider))
      if ((q.isEmpty || normText('${p.title} ${p.department}').contains(q)) && (k == 0 || (k == 2) == (p.category == 'Services'))) p,
  ];
});

final kioskCurrentProvider = Provider<LiveProduct>((ref) {
  final all = ref.watch(allProductsProvider);
  final t = ref.watch(kioskProductProvider);
  return all.firstWhere((p) => p.title == t, orElse: () => all.first);
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
  final s = ref.watch(kioskSessionProvider)?.secondsLeft() ?? 300;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

void startPhoneTransfer(WidgetRef ref, BuildContext context) {
  ref.read(kioskSessionProvider.notifier).start(ref.read(kioskCurrentProvider));
  ref.read(auditProvider.notifier).log('Borne n°2', 'Code de transfert créé', ref.read(kioskCurrentProvider).title, 'Connexions');
  gOpen(context, '209');
}

/// Le téléphone scanne le code : vérifie la validité, l'usage unique et envoie l'article dans le panier.
void scanQr(WidgetRef ref, BuildContext context) {
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
  });
  final String id, kind, desc, date;
  final int total;
  final bool accepted;
  final int funded, proof, released; // nombre de jalons financés / avec preuve / libérés

  static const shares = [30, 40, 30];
  int amountOf(int i) => total * shares[i.clamp(0, 2)] ~/ 100;
  int get fee => total ~/ 10;
  int get releasedAmount => [for (var i = 0; i < released; i++) amountOf(i)].fold(0, (a, b) => a + b);
  int get studentEarned => releasedAmount * 70 ~/ 100;
  int get pendingAmount => proof > released ? amountOf(released) : 0;
  int get nextToFund => funded.clamp(0, 3);
  int get pct => ((released * 3 + proof * 2 + funded) * 100 / 9).round().clamp(0, 100);

  Mission copyWith({bool? accepted, int? funded, int? proof, int? released}) => Mission(
        id: id, kind: kind, desc: desc, total: total, date: date,
        accepted: accepted ?? this.accepted, funded: funded ?? this.funded, proof: proof ?? this.proof, released: released ?? this.released);
}

const missionKinds = ['Identité visuelle', 'Savons et parfums', 'Vidéo et photo', 'Site ou application', 'Prototype', 'Étude ou audit'];

class MissionNotifier extends Notifier<Mission> {
  @override
  Mission build() => const Mission(
        id: '#BR-0412', kind: 'Identité visuelle', desc: 'Identité visuelle complète pour la marque de parfums Mbella.', total: 180000, date: '12 oct. 2026',
        accepted: true, funded: 2, proof: 1, released: 1);

  void create(Mission m) => state = m;
  void accept() => state = state.copyWith(accepted: true);
  void fund() => state = state.copyWith(funded: (state.funded + 1).clamp(0, 3));
  void sendProof() => state = state.copyWith(proof: (state.proof + 1).clamp(0, 3));
  void retractProof() => state = state.copyWith(proof: state.released);
  void release() => state = state.copyWith(released: (state.released + 1).clamp(0, 3), proof: state.proof < state.released + 1 ? state.released + 1 : state.proof);
}

final missionProvider = NotifierProvider<MissionNotifier, Mission>(MissionNotifier.new);
final missionKindProvider = NotifierProvider<IntV, int>(IntV.new);

String _today() {
  const m = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
  final d = DateTime.now();
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

void submitBrief(WidgetRef ref, BuildContext context) {
  final f = ref.read(formProvider);
  final desc = (f['ms_desc'] ?? '').trim();
  if (desc.length < 20) {
    ref.read(errorsProvider.notifier).setAll({'ms_desc': 'Décrivez votre besoin (20 caractères minimum).'});
    return;
  }
  ref.read(errorsProvider.notifier).clear();
  final kind = missionKinds[ref.read(missionKindProvider).clamp(0, 5)];
  final id = '#BR-${(413 + DateTime.now().second).toString().padLeft(4, '0')}';
  ref.read(missionProvider.notifier).create(Mission(id: id, kind: kind, desc: desc, total: 180000, date: _today()));
  ref.read(auditProvider.notifier).log(ref.read(profileAccountProvider).name, 'Brief envoyé', '$id · $kind', 'Validations');
  gToast(context, 'Besoin envoyé : l’administrateur prépare votre devis');
  gOpen(context, '192');
}

void acceptQuote(WidgetRef ref, BuildContext context) {
  ref.read(missionProvider.notifier).accept();
  ref.read(auditProvider.notifier).log(ref.read(profileAccountProvider).name, 'Devis accepté', ref.read(missionProvider).id, 'Finances');
  gOpen(context, '193');
}

void payNextMilestone(WidgetRef ref, BuildContext context) {
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
  ref.read(auditProvider.notifier).log(ref.read(profileAccountProvider).name, 'Preuve envoyée', m.id, 'Validations');
  gToast(context, 'Preuve envoyée : le client est notifié');
  gOpen(context, '201');
}

void releaseMilestone(WidgetRef ref, BuildContext context) {
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
