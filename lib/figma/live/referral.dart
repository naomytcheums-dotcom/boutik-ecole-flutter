import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../gen.dart';
import 'share.dart' show siteUrl, openUrl, shareText;
import 'auth.dart';
import 'backend.dart';
import 'lots.dart' show copyText, formDialog;
import 'store.dart' show fcfa;
import 'talents.dart' show askText;

/// Parrainage et gains (écrans 240, 243 ; migration 20261101000400, règles § 3). Les montants viennent du serveur ;
/// rien n'est « versé » : le retrait vers Mobile Money reste indisponible tant que les paiements ne sont pas activés.

typedef Referee = ({String name, String status, int earned});

typedef ReferralRule = ({String tier, int minActive, int bonus, double sharePct});

class ReferralSummary {
  const ReferralSummary({this.tier = 'Aucun', this.active = 0, this.pending = 0, this.available = 0, this.waiting = 0, this.month = 0, this.referees = const [], this.rules = const [], this.history = const [], this.unavailable = false, this.payoutRequested = 0, this.payoutPaid = 0, this.payouts = const [], this.minPayout = 1000});
  final String tier;
  final int active, pending, available, waiting, month, payoutRequested, payoutPaid, minPayout;
  final List<Referee> referees;

  /// Barème défini par l'administrateur (table referral_rules) ; vide = barème pas encore publié.
  final List<ReferralRule> rules;
  final List<Map<String, dynamic>> history, payouts;

  /// Vrai quand la lecture de la synthèse a échoué : les compteurs ne sont alors pas ceux du compte.
  final bool unavailable;

  int get total => available + waiting;
  bool get rewardsDefined => rules.isNotEmpty;

  factory ReferralSummary.fromJson(Map<String, dynamic> j) => ReferralSummary(
        tier: '${j['tier'] ?? 'Aucun'}',
        active: (j['active'] as num?)?.toInt() ?? 0,
        pending: (j['pending_referrals'] as num?)?.toInt() ?? 0,
        available: (j['available'] as num?)?.toInt() ?? 0,
        waiting: (j['waiting'] as num?)?.toInt() ?? 0,
        month: (j['this_month'] as num?)?.toInt() ?? 0,
        payoutRequested: (j['payout_requested'] as num?)?.toInt() ?? 0,
        payoutPaid: (j['payout_paid'] as num?)?.toInt() ?? 0,
        minPayout: (j['min_payout'] as num?)?.toInt() ?? 1000,
        payouts: [for (final h in (j['payouts'] as List? ?? const [])) Map<String, dynamic>.from(h as Map)],
        referees: [
          for (final r in (j['referees'] as List? ?? const []))
            (name: '${(r as Map)['name']}', status: '${r['status']}', earned: (r['earned'] as num?)?.toInt() ?? 0),
        ],
        rules: [
          for (final r in (j['rules'] as List? ?? const []))
            (tier: '${(r as Map)['tier']}', minActive: (r['min_active'] as num?)?.toInt() ?? 0, bonus: (r['bonus'] as num?)?.toInt() ?? 0, sharePct: (r['share_pct'] as num?)?.toDouble() ?? 0),
        ],
        history: [for (final h in (j['history'] as List? ?? const [])) Map<String, dynamic>.from(h as Map)],
      );

  /// « Niveau Argent », ou « Aucun filleul actif ».
  String get tierLabel => tier == 'Aucun' ? 'Aucun filleul actif' : 'Niveau $tier';

  /// Palier suivant du barème réel : « Plus que 13 filleuls pour passer Or ». Sans barème : il n'est pas encore publié.
  String get nextLabel {
    if (unavailable) return 'Parrainage indisponible pour le moment.';
    if (rules.isEmpty) return 'Le barème de récompense n’est pas encore publié.';
    final next = rules.where((r) => r.minActive > active).toList();
    if (next.isEmpty) return 'Niveau maximal atteint';
    final n = next.first.minActive - active;
    return 'Plus que $n filleul${n > 1 ? 's' : ''} pour passer ${next.first.tier}';
  }

  /// Avancement vers le palier suivant (0 à 1).
  double get progress {
    final next = rules.where((r) => r.minActive > active).toList();
    if (rules.isEmpty) return 0;
    if (next.isEmpty) return 1;
    return (active / next.first.minActive).clamp(0.0, 1.0);
  }
}

/// Libellé d'un palier du barème : prime et part des ventes.
String ruleReward(ReferralRule r) {
  final pct = r.sharePct * 100;
  final pctText = pct == pct.roundToDouble() ? pct.round().toString() : pct.toStringAsFixed(1).replaceAll('.', ',');
  return '${fcfa(r.bonus)}${r.sharePct > 0 ? ' + $pctText %' : ''}';
}

const referralSignInHint = 'Connectez-vous pour voir votre parrainage.';

/// Vrai quand personne n'est connecté (visiteur) : le parrainage n'a alors ni barème ni compteur à montrer.
bool referralSignedOut(WidgetRef ref) => ref.watch(authProvider.select((a) => a.current == null));

/// Libellé du niveau (240) : jamais « Aucun filleul actif » pour un visiteur ou tant que la lecture n'a pas abouti.
String referralTierText(WidgetRef ref) {
  if (referralSignedOut(ref)) return 'Parrainage';
  final s = ref.watch(referralProvider);
  return s == null ? 'Chargement…' : (s.unavailable ? 'Parrainage' : s.tierLabel);
}

/// Avancement vers le palier suivant (240) : invitation à se connecter pour un visiteur, chargement, ou état du barème.
String referralNextText(WidgetRef ref) {
  if (referralSignedOut(ref)) return referralSignInHint;
  final s = ref.watch(referralProvider);
  return s == null ? 'Chargement…' : s.nextLabel;
}

/// Cartes des paliers (240) construites sur le barème réel du serveur. Aucun montant n'est écrit dans l'application.
class ReferralTiers extends ConsumerWidget {
  const ReferralTiers({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedOut = referralSignedOut(ref);
    final loaded = ref.watch(referralProvider);
    final s = loaded ?? const ReferralSummary();
    if (signedOut || loaded == null || !s.rewardsDefined) {
      final msg = signedOut
          ? referralSignInHint
          : loaded == null
              ? 'Chargement…'
              : s.unavailable
                  ? 'Parrainage indisponible pour le moment. Réessayez dans un instant.'
                  : 'Le barème de récompense n’est pas encore publié.';
      return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(color: const Color(0xFFF6F3FA), borderRadius: BorderRadius.circular(22)),
        child: Text(
          msg,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF57545F), fontWeight: FontWeight.w500),
        ),
      );
    }
    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Stack(children: [
          Container(height: 10, color: const Color(0xFFECE8F6)),
          FractionallySizedBox(widthFactor: s.progress, child: Container(height: 10, color: const Color(0xFF6A4DFF))),
        ]),
      ),
      const SizedBox(height: 20),
      Expanded(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          itemCount: s.rules.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final r = s.rules[i];
            final here = r.tier == s.tier;
            final next = i + 1 < s.rules.length ? s.rules[i + 1].minActive - 1 : null;
            return Container(
              width: 96,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(color: here ? const Color(0xFFEEE9FF) : const Color(0xFFF6F3FA), borderRadius: BorderRadius.circular(22)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(r.tier, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: here ? const Color(0xFF5A3FE0) : const Color(0xFF111015))),
                const SizedBox(height: 3),
                Text(next == null ? '${r.minActive} et + amis' : '${r.minActive} à $next amis', style: const TextStyle(fontSize: 9.5, color: Color(0xFF57545F))),
                const SizedBox(height: 5),
                Text(ruleReward(r), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF111015))),
                Text(r.sharePct > 0 ? 'par inscrit + % des achats' : 'par inscrit', style: const TextStyle(fontSize: 9, color: Color(0xFF57545F))),
              ]),
            );
          },
        ),
      ),
    ]);
  }
}

String refereeStatus(String s) => switch (s) { 'active' => 'Actif', 'expired' => 'Expiré', _ => 'En attente' };

/// Synthèse lue sur le serveur ; null tant qu'elle n'est pas lue (ou sans compte).
class ReferralNotifier extends Notifier<ReferralSummary?> {
  @override
  ReferralSummary? build() {
    if (!Backend.ready) return null;
    final uid = ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
    if (uid.isNotEmpty) Future.microtask(refresh);
    return null;
  }

  Future<void> refresh() async {
    final r = await Backend.rpc('my_referral_summary', const {});
    if (!ref.mounted) return;
    state = r.error == null && r.data is Map ? ReferralSummary.fromJson(Map<String, dynamic>.from(r.data as Map)) : const ReferralSummary(unavailable: true);
  }
}

final referralProvider = NotifierProvider<ReferralNotifier, ReferralSummary?>(ReferralNotifier.new);

/// Code personnel (créé par le serveur à la première demande), le même pour tous les écrans de parrainage.
/// `null` : lecture en cours ; chaîne vide : personne n'est connecté ou le code est indisponible.
class ReferralCode extends Notifier<String?> {
  @override
  String? build() {
    if (!Backend.ready) return '';
    final uid = ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
    if (uid.isEmpty) return '';
    Future.microtask(() async {
      final r = await Backend.rpc('my_referral_code', const {});
      if (ref.mounted) state = r.error == null && r.data is String ? r.data as String : '';
    });
    return null;
  }
}

final referralCodeProvider = NotifierProvider<ReferralCode, String?>(ReferralCode.new);

/// Lien d'invitation : ouvert dans l'application, il applique le code du parrain après l'inscription (paramètre `ref`).
String invitationLink(String code) => '$siteUrl/?ref=$code';

/// Lien d'invitation affiché dans l'écran 240 : le lien, sans le schéma, ou l'état du code.
String invitationText(String? code, {bool signedOut = true}) =>
    code == null ? 'Chargement du code…' : (code.isEmpty ? (signedOut ? 'Connectez-vous pour obtenir votre code' : 'Code indisponible pour le moment') : invitationLink(code).replaceFirst('https://', ''));

/// Message d'invitation commun à tous les boutons de partage : le lien applique le code à l'inscription ; le code reste saisissable à la main.
String invitationMessage(String code) =>
    'Rejoins Boutik-École, la marketplace des étudiants de l’IUT de Douala : ${invitationLink(code)} — le lien applique mon code de parrainage. Si le code n’est pas pris en compte, saisis $code dans Mon compte › J’ai un code de parrainage, avant ta première commande payée. Ma prime est due à ta 1ʳᵉ commande payée d’au moins 10 000 FCFA.';

const _pendingRefKey = 'pending_referral_code';

/// Au démarrage de l'application : mémorise le code d'un lien d'invitation (`?ref=CODE`) pour l'appliquer à la création du compte.
Future<void> capturePendingReferral([Uri? uri]) async {
  try {
    final code = normalizeReferralCode((uri ?? Uri.base).queryParameters['ref'] ?? '');
    if (code == null) return;
    await (await SharedPreferences.getInstance()).setString(_pendingRefKey, code);
  } catch (_) {}
}

/// Après une connexion ou une inscription : applique le code mémorisé (claim_referral). Un refus du serveur (déjà un parrain, délai dépassé,
/// même téléphone…) ou un succès efface le code ; une panne réseau le garde pour la prochaine connexion.
Future<String?> applyPendingReferral() async {
  if (!Backend.ready) return null;
  try {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_pendingRefKey);
    if (code == null) return null;
    final r = await Backend.rpc('claim_referral', {'p_code': code});
    if (r.error != null && Backend.isServiceMessage(Backend.userMessage(r.error!))) return null;
    await prefs.remove(_pendingRefKey);
    return r.error == null ? 'Parrain enregistré : la prime lui sera due à votre première commande payée.' : null;
  } catch (_) {
    return null;
  }
}

/// Code à partager, ou null après avoir expliqué pourquoi il n'est pas disponible (visiteur : invitation à se connecter).
Future<String?> _shareableCode(BuildContext context, WidgetRef ref) async {
  if (ref.read(authProvider).current == null) {
    await requireLogin(context, ref, 'obtenir votre code de parrainage');
    return null;
  }
  final code = ref.read(referralCodeProvider);
  if (code == null) {
    gToast(context, 'Votre code se charge. Réessayez dans un instant.');
    return null;
  }
  if (code.isEmpty) {
    gToast(context, 'Code de parrainage indisponible pour le moment.');
    return null;
  }
  return code;
}

/// 240 « Partager via » : ouvre le service choisi avec le message prérempli ; Instagram et TikTok n'ont pas de lien de partage
/// de texte : le message est copié pour être collé dans l'application.
Future<void> shareInvitation(BuildContext context, WidgetRef ref, String via) async {
  if (!Backend.ready) return gToast(context, 'Partage disponible une fois connecté au serveur.');
  final code = await _shareableCode(context, ref);
  if (code == null || !context.mounted) return;
  final msg = invitationMessage(code);
  final q = Uri.encodeComponent(msg);
  switch (via) {
    case 'whatsapp':
      return openUrl(context, 'https://wa.me/?text=$q');
    case 'facebook':
      return openUrl(context, 'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(siteUrl)}&quote=$q');
    case 'sms':
      return openUrl(context, 'sms:?&body=$q');
    default:
      // Instagram, TikTok et le reste : la feuille de partage du téléphone propose toutes les applications installées.
      return shareText(context, msg, subject: 'Invitation Boutik-École');
  }
}

/// 240 « Copier » : copie réellement le message d'invitation ; le message dit si la copie a réussi.
Future<void> copyInvitation(BuildContext context, WidgetRef ref) async {
  if (!Backend.ready) return gToast(context, 'Copie disponible une fois connecté au serveur.');
  final code = await _shareableCode(context, ref);
  if (code == null || !context.mounted) return;
  final ok = await copyText(invitationMessage(code));
  if (context.mounted) gToast(context, ok ? 'Invitation copiée' : 'Copie impossible : autorisez l’accès au presse-papiers.');
}

/// Forme attendue d'un code de parrainage serveur : 8 caractères, lettres A-Z et chiffres 2-9, sans préfixe.
final _codeShape = RegExp(r'^[A-Z2-9]{8}$');

/// Code saisi, mis en forme (majuscules, espaces retirés) ; null s'il n'a pas la forme attendue.
String? normalizeReferralCode(String raw) {
  final c = raw.replaceAll(RegExp(r'\s'), '').toUpperCase();
  return _codeShape.hasMatch(c) ? c : null;
}

/// Mon compte : le filleul saisit le code reçu (30 jours après l'inscription au plus ; vérifié par le serveur).
Future<void> claimReferralDialog(BuildContext context, WidgetRef ref) async {
  if (!Backend.ready) return gAlert(context, 'Hors connexion', 'Cette action nécessite la connexion au serveur.');
  if (!await requireLogin(context, ref, 'saisir un code de parrainage') || !context.mounted) return;
  final raw = await askText(context, title: 'Code de parrainage', body: 'Saisissez le code reçu (8 caractères : lettres et chiffres), dans les 30 jours suivant votre inscription et avant votre première commande payée.', hint: 'ABCD2345', ok: 'Valider', min: 8);
  if (raw == null || !context.mounted) return;
  final code = normalizeReferralCode(raw);
  if (code == null) return gAlert(context, 'Code invalide', 'Un code de parrainage compte exactement 8 caractères (lettres A à Z et chiffres 2 à 9), sans espace ni préfixe.');
  final r = await Backend.rpc('claim_referral', {'p_code': code});
  if (!context.mounted) return;
  if (r.error != null) return gAlert(context, 'Code refusé', Backend.userMessage(r.error!));
  gToast(context, 'Parrain enregistré : la prime lui sera due à votre première commande payée.');
}

/// 240 : « Mes gains · X FCFA » sans afficher 0 tant que la synthèse n'est pas lue.
String referralGainsText(WidgetRef ref) {
  if (referralSignedOut(ref)) return 'Mes gains';
  final s = ref.watch(referralProvider);
  if (s == null) return 'Mes gains · …';
  return s.unavailable ? 'Mes gains · indisponibles' : 'Mes gains · ${fcfa(s.total)}';
}

/// Synthèse du parrainage réellement lue (ni en cours de lecture, ni indisponible).
bool refKnown(ReferralSummary? s) => s != null && !s.unavailable;

/// Compteur du parrainage : « — » tant que la synthèse n'est pas lue ou si la lecture a échoué (jamais un zéro pour une erreur).
String refStat(ReferralSummary? s, int Function(ReferralSummary s) pick, [String suffix = '']) => refKnown(s) ? '${pick(s!)}$suffix' : '—';

/// 243 : solde disponible, jamais « 0 » tant que la synthèse n'est pas lue.
String referralBalanceText(WidgetRef ref) {
  final s = ref.watch(referralProvider);
  return s == null ? '…' : (s.unavailable ? '—' : fcfa(s.available));
}

/// 243 : ligne sous le solde — gains en attente de disponibilité et retrait déjà demandé.
String referralBalanceNote(WidgetRef ref) {
  final s = ref.watch(referralProvider);
  if (s == null || s.unavailable) return '';
  return [
    if (s.waiting > 0) '${fcfa(s.waiting)} disponibles 14 jours après la commande',
    if (s.payoutRequested > 0) 'retrait demandé : ${fcfa(s.payoutRequested)}',
  ].join(' · ');
}

/// 243 : demande de retrait. Le versement est fait sur demande par l'équipe finance (Mobile Money) : rien n'est automatique.
Future<void> requestPayoutDialog(BuildContext context, WidgetRef ref) async {
  if (!Backend.ready) return gAlert(context, 'Hors connexion', 'Cette action nécessite la connexion au serveur.');
  if (!await requireLogin(context, ref, 'demander un retrait') || !context.mounted) return;
  await ref.read(referralProvider.notifier).refresh();
  final s = ref.read(referralProvider);
  if (!context.mounted || s == null) return;
  if (s.unavailable) return gAlert(context, 'Retrait', 'Vos gains ne peuvent pas être lus pour le moment. Réessayez dans un instant.');
  if (s.payoutRequested > 0) {
    return gAlert(context, 'Retrait en cours', 'Votre demande de ${fcfa(s.payoutRequested)} est en cours de traitement par l’équipe finance. Vous serez prévenu dès qu’elle sera payée.');
  }
  if (s.available < s.minPayout) {
    return gAlert(context, 'Retrait indisponible', 'Le paiement des gains se fait sur demande à l’équipe, à partir de ${fcfa(s.minPayout)} disponibles. Solde disponible : ${fcfa(s.available)}.${s.waiting > 0 ? ' ${fcfa(s.waiting)} sont encore en attente (14 jours après la commande).' : ''}');
  }
  final v = await formDialog(
    context,
    'Demander un retrait',
    [('Montant (FCFA, ${fcfa(s.minPayout)} minimum)', '${s.available}'), ('Numéro Orange Money ou MTN MoMo (9 chiffres)', '')],
    submit: 'Envoyer la demande',
    intro: 'Le paiement de vos gains se fait sur demande : l’équipe finance verse le montant sur ce numéro Mobile Money et vous prévient. Solde disponible : ${fcfa(s.available)}.',
    numeric: true,
  );
  if (v == null || !context.mounted) return;
  final amount = int.tryParse(v[0].replaceAll(RegExp(r'\s'), ''));
  final phone = normPhone(v[1]);
  if (amount == null) return gAlert(context, 'Montant invalide', 'Saisissez un montant en chiffres.');
  final provider = RegExp(r'^69|^65[5-9]').hasMatch(phone) ? 'orange_money' : 'mtn_momo';
  final r = await Backend.rpc('request_referral_payout', {'p_amount': amount, 'p_phone': phone, 'p_provider': provider});
  if (!context.mounted) return;
  if (r.error != null) return gAlert(context, 'Demande non envoyée', Backend.userMessage(r.error!));
  await ref.read(referralProvider.notifier).refresh();
  if (context.mounted) gToast(context, 'Demande de retrait envoyée : l’équipe finance vous répond.');
}

/// Liste des filleuls réels (243), à la place des exemples de la maquette : tous les filleuls, la légende des statuts et l'historique des gains.
Widget refereeList(ReferralSummary? s, {bool signedOut = false}) {
  const grey = TextStyle(fontSize: 12.5, color: Color(0xFF57545F), height: 1.4);
  if (signedOut) return const Text(referralSignInHint, style: grey);
  if (s == null) return const Text('Chargement…', style: grey);
  if (s.unavailable) return const Text('Parrainage indisponible pour le moment. Réessayez dans un instant.', style: grey);
  if (s.referees.isEmpty && s.history.isEmpty) return const Text('Aucun filleul pour le moment. Partagez votre code depuis « Parrainer et gagner ».', style: grey);
  String day(Object? iso) {
    final d = DateTime.tryParse('$iso')?.toLocal();
    return d == null ? '' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }

  return ListView(padding: EdgeInsets.zero, children: [
    if (s.referees.isEmpty) const Text('Aucun filleul pour le moment.', style: grey),
    for (final r in s.referees)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Expanded(child: Text(r.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111015)))),
          Text(refereeStatus(r.status), style: const TextStyle(fontSize: 11, color: Color(0xFF5A3FE0))),
          const SizedBox(width: 16),
          Text(r.earned > 0 ? '+ ${fcfa(r.earned)}' : '—', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111015))),
        ]),
      ),
    const Padding(
      padding: EdgeInsets.only(top: 4, bottom: 6),
      child: Text('Actif : 1ʳᵉ commande payée d’au moins 10 000 FCFA · En attente : pas encore de commande payée · Expiré : aucune commande sous 90 jours.', style: TextStyle(fontSize: 10.5, color: Color(0xFF57545F), height: 1.4)),
    ),
    if (s.history.isNotEmpty) ...[
      const Padding(padding: EdgeInsets.only(top: 12, bottom: 4), child: Text('Historique des gains', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111015)))),
      for (final h in s.history)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Expanded(child: Text('${day(h['at'])} · ${h['source'] == 'referral_share' ? 'part des achats de votre filleul' : 'prime de parrainage'}${h['status'] == 'void' ? ' · annulé (commande annulée)' : ''}', style: grey.copyWith(fontSize: 11.5))),
            Text('+ ${fcfa((h['amount'] as num?)?.toInt() ?? 0)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: h['status'] == 'void' ? const Color(0xFF8A8794) : const Color(0xFF111015), decoration: h['status'] == 'void' ? TextDecoration.lineThrough : null)),
          ]),
        ),
    ],
  ]);
}

/// Kit à partager (242) : textes prêts à envoyer ou à publier, chacun avec le lien d'invitation et le code.
class ReferralShareKit extends ConsumerWidget {
  const ReferralShareKit({super.key, this.width = 342});
  final double width;

  static List<(String, String)> messages(String code) {
    final link = invitationLink(code);
    return [
      ('Message court (WhatsApp, SMS)', 'Salut ! Je te recommande Boutik-École, la marketplace des étudiants de l’IUT de Douala (produits, services, talents). Inscris-toi avec mon lien : $link — mon code : $code.'),
      ('Légende de publication ou de story', 'Je soutiens les talents de l’IUT de Douala sur Boutik-École. Rejoins-moi : $link (code $code) #BoutikEcole #IUTDouala'),
      ('Message pour un ami qui cherche un service', 'Tu cherches un logo, une vidéo ou un produit local ? Des étudiants de l’IUT de Douala le font sur Boutik-École : $link (code de parrainage : $code).'),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const ink = Color(0xFF111015), grey = Color(0xFF57545F);
    Widget note(String t) => Container(width: width, height: 120, alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(t, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, height: 1.5, color: grey)));
    if (referralSignedOut(ref)) return note('Connectez-vous pour obtenir votre code et vos messages à partager.');
    final c = ref.watch(referralCodeProvider);
    if (c == null) return note('Chargement…');
    if (c.isEmpty) return note('Code indisponible pour le moment.');
    return SizedBox(
      width: width,
      child: ListView(padding: EdgeInsets.zero, children: [
        const Text('Votre lien d’invitation', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ink)),
        const SizedBox(height: 8),
        Container(width: width, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFEEE9FF), borderRadius: BorderRadius.circular(16)), child: SelectableText(invitationLink(c), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF5A3FE0)))),
        const SizedBox(height: 6),
        const Text('Le filleul qui ouvre ce lien et crée son compte vous est rattaché automatiquement.', style: TextStyle(fontSize: 11.5, color: grey, height: 1.4)),
        for (final (title, text) in messages(c)) ...[
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ink)),
          const SizedBox(height: 6),
          Container(width: width, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE6E1EE))), child: Text(text, style: const TextStyle(fontSize: 12.5, height: 1.45, color: ink))),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => shareText(context, text, subject: 'Invitation Boutik-École'), child: const Text('Partager'))),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final ok = await copyText(text);
                  if (context.mounted) gToast(context, ok ? 'Message copié' : 'Copie impossible : autorisez l’accès au presse-papiers.');
                },
                child: const Text('Copier'),
              ),
            ),
          ]),
        ],
        const SizedBox(height: 24),
      ]),
    );
  }
}
