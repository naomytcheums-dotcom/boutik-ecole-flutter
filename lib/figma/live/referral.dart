import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart';
import 'share.dart' show siteUrl, openUrl, shareText;
import 'auth.dart';
import 'backend.dart';
import 'lots.dart' show copyText;
import 'store.dart' show fcfa;
import 'talents.dart' show askText;

/// Parrainage et gains (écrans 240, 243 ; migration 20261101000400, règles § 3). Les montants viennent du serveur ;
/// rien n'est « versé » : le retrait vers Mobile Money reste indisponible tant que les paiements ne sont pas activés.

typedef Referee = ({String name, String status, int earned});

typedef ReferralRule = ({String tier, int minActive, int bonus, double sharePct});

class ReferralSummary {
  const ReferralSummary({this.tier = 'Aucun', this.active = 0, this.pending = 0, this.available = 0, this.waiting = 0, this.month = 0, this.referees = const [], this.rules = const [], this.history = const []});
  final String tier;
  final int active, pending, available, waiting, month;
  final List<Referee> referees;

  /// Barème défini par l'administrateur (table referral_rules) ; vide = « récompense non définie ».
  final List<ReferralRule> rules;
  final List<Map<String, dynamic>> history;

  int get total => available + waiting;
  bool get rewardsDefined => rules.isNotEmpty;

  factory ReferralSummary.fromJson(Map<String, dynamic> j) => ReferralSummary(
        tier: '${j['tier'] ?? 'Aucun'}',
        active: (j['active'] as num?)?.toInt() ?? 0,
        pending: (j['pending_referrals'] as num?)?.toInt() ?? 0,
        available: (j['available'] as num?)?.toInt() ?? 0,
        waiting: (j['waiting'] as num?)?.toInt() ?? 0,
        month: (j['this_month'] as num?)?.toInt() ?? 0,
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

  /// Palier suivant du barème réel : « Plus que 13 filleuls pour passer Or ». Sans barème : récompense non définie.
  String get nextLabel {
    if (rules.isEmpty) return 'Récompense non définie';
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

/// Cartes des paliers (240) construites sur le barème réel du serveur. Aucun montant n'est écrit dans l'application.
class ReferralTiers extends ConsumerWidget {
  const ReferralTiers({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(referralProvider) ?? const ReferralSummary();
    if (!s.rewardsDefined) {
      return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(color: const Color(0xFFF6F3FA), borderRadius: BorderRadius.circular(22)),
        child: const Text(
          'Récompense non définie.\nL’équipe n’a pas encore publié le barème du parrainage ; elle en est informée.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF57545F), fontWeight: FontWeight.w500),
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
                Text(r.sharePct > 0 ? 'par inscrit + ventes' : 'par inscrit', style: const TextStyle(fontSize: 9, color: Color(0xFF57545F))),
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
    if (r.error == null && r.data is Map && ref.mounted) state = ReferralSummary.fromJson(Map<String, dynamic>.from(r.data as Map));
  }
}

final referralProvider = NotifierProvider<ReferralNotifier, ReferralSummary?>(ReferralNotifier.new);

/// Code personnel (créé par le serveur à la première demande).
class ReferralCode extends Notifier<String> {
  @override
  String build() {
    if (!Backend.ready) return '';
    final uid = ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
    if (uid.isNotEmpty) {
      Future.microtask(() async {
        final r = await Backend.rpc('my_referral_code', const {});
        if (r.error == null && ref.mounted) state = '${r.data}';
      });
    }
    return '';
  }
}

final referralCodeProvider = NotifierProvider<ReferralCode, String>(ReferralCode.new);

/// Texte du lien d'invitation : le code à saisir à l'inscription (Mon compte → « J'ai un code de parrainage »).
String invitationText(String code) => code.isEmpty ? 'Connectez-vous pour obtenir votre code' : 'Code de parrainage : $code';

/// Message d'invitation commun à tous les boutons de partage.
String invitationMessage(String code) => 'Rejoins Boutik-École : $siteUrl — à l’inscription, saisis mon code de parrainage $code.';

/// 240 « Partager via » : ouvre le service choisi avec le message prérempli ; Instagram et TikTok n'ont pas de lien de partage
/// de texte : le message est copié pour être collé dans l'application.
Future<void> shareInvitation(BuildContext context, WidgetRef ref, String via) async {
  if (!Backend.ready) return gToast(context, 'Partage disponible une fois connecté au serveur.');
  final code = ref.read(referralCodeProvider);
  if (code.isEmpty) return gAlert(context, 'Parrainage', 'Connectez-vous pour obtenir votre code de parrainage.');
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
  if (!Backend.ready) return gToast(context, 'Lien copié');
  final code = ref.read(referralCodeProvider);
  if (code.isEmpty) return gAlert(context, 'Parrainage', 'Connectez-vous pour obtenir votre code de parrainage.');
  final ok = await copyText(invitationMessage(code));
  if (context.mounted) gToast(context, ok ? 'Invitation copiée' : 'Copie impossible : autorisez l’accès au presse-papiers.');
}

/// Mon compte : le filleul saisit le code reçu (30 jours après l'inscription au plus ; vérifié par le serveur).
Future<void> claimReferralDialog(BuildContext context, WidgetRef ref) async {
  if (!Backend.ready) return gAlert(context, 'Hors connexion', 'Cette action nécessite la connexion au serveur.');
  if (!await requireLogin(context, ref, 'saisir un code de parrainage') || !context.mounted) return;
  final code = await askText(context, title: 'Code de parrainage', body: 'Saisissez le code reçu (8 caractères), dans les 30 jours suivant votre inscription.', hint: 'ABCD2345', ok: 'Valider', min: 8);
  if (code == null || !context.mounted) return;
  final r = await Backend.rpc('claim_referral', {'p_code': code});
  if (!context.mounted) return;
  if (r.error != null) return gAlert(context, 'Code refusé', r.error!);
  gToast(context, 'Parrain enregistré : la prime lui sera due à votre première commande payée.');
}

/// Liste des filleuls réels (243), à la place des exemples de la maquette.
Widget refereeList(ReferralSummary s) => s.referees.isEmpty
    ? Text('Aucun filleul pour le moment. Partagez votre code depuis « Parrainer et gagner ».',
        style: const TextStyle(fontSize: 12.5, color: Color(0xFF57545F), height: 1.4))
    : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final r in s.referees.take(5))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              Expanded(child: Text(r.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111015)))),
              Text(refereeStatus(r.status), style: const TextStyle(fontSize: 11, color: Color(0xFF5A3FE0))),
              const SizedBox(width: 16),
              Text(r.earned > 0 ? '+ ${fcfa(r.earned)}' : '—', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111015))),
            ]),
          ),
      ]);
